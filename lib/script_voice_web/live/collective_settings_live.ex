defmodule ScriptVoiceWeb.CollectiveSettingsLive do
  @moduledoc """
  LiveView for managing collective settings (admin only).
  Supports invitation-based member management and join request handling.
  """
  use ScriptVoiceWeb, :live_view

  alias ScriptVoice.Collectives
  alias ScriptVoice.Accounts

  @impl true
  def mount(%{"slug" => slug}, session, socket) do
    current_user = get_current_user(session)

    case {current_user, Collectives.get_collective_by_slug(slug)} do
      {nil, _} ->
        {:ok,
         socket
         |> put_flash(:error, "Please sign in")
         |> push_navigate(to: ~p"/verify")}

      {_, nil} ->
        {:ok,
         socket
         |> put_flash(:error, "Collective not found")
         |> push_navigate(to: ~p"/browse")}

      {user, collective} ->
        if Collectives.is_admin?(collective.id, user.id) do
          {:ok, load_collective_data(socket, user, collective)}
        else
          {:ok,
           socket
           |> put_flash(:error, "You don't have permission to manage this collective")
           |> push_navigate(to: ~p"/collective/#{slug}")}
        end
    end
  end

  defp load_collective_data(socket, user, collective) do
    sorted_memberships =
      collective.memberships
      |> Enum.sort_by(fn m -> {if(m.role == "admin", do: 0, else: 1), m.display_order} end)

    pending_invitations = Collectives.list_pending_invitations_for_collective(collective.id)
    join_requests = Collectives.list_pending_join_requests_for_collective(collective.id)

    socket
    |> assign(:current_user, user)
    |> assign(:collective, collective)
    |> assign(:memberships, sorted_memberships)
    |> assign(:pending_invitations, pending_invitations)
    |> assign(:join_requests, join_requests)
    |> assign(:editing, false)
    |> assign(:show_invite_modal, false)
    |> assign(:member_search, "")
    |> assign(:search_results, [])
    |> assign(:invite_message, "")
    |> assign(:selected_user, nil)
    |> assign(:page_title, "Settings - #{collective.name}")
  end

  defp refresh_data(socket) do
    collective = Collectives.get_collective_by_slug(socket.assigns.collective.slug)
    load_collective_data(socket, socket.assigns.current_user, collective)
  end

  defp get_current_user(session) do
    case session["user_id"] do
      nil -> nil
      user_id -> Accounts.get_user(user_id)
    end
  end

  @impl true
  def handle_event("toggle_editing", _, socket) do
    {:noreply, assign(socket, :editing, !socket.assigns.editing)}
  end

  @impl true
  def handle_event("update_collective", params, socket) do
    case Collectives.update_collective(socket.assigns.collective, params) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> assign(:collective, Collectives.get_collective_by_slug(updated.slug))
         |> assign(:editing, false)
         |> put_flash(:info, "Collective updated")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update collective")}
    end
  end

  @impl true
  def handle_event("toggle_commissions", _, socket) do
    new_status = !socket.assigns.collective.is_accepting_commissions

    case Collectives.update_collective(socket.assigns.collective, %{is_accepting_commissions: new_status}) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> assign(:collective, updated)
         |> put_flash(:info, if(new_status, do: "Now accepting commissions", else: "No longer accepting commissions"))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update status")}
    end
  end

  # Invitation modal
  @impl true
  def handle_event("show_invite_modal", _, socket) do
    {:noreply, assign(socket, :show_invite_modal, true)}
  end

  @impl true
  def handle_event("hide_invite_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:show_invite_modal, false)
     |> assign(:member_search, "")
     |> assign(:search_results, [])
     |> assign(:invite_message, "")
     |> assign(:selected_user, nil)}
  end

  @impl true
  def handle_event("search_members", %{"search" => search}, socket) do
    results =
      if String.length(search) >= 2 do
        # Get existing member IDs and pending invitation invitee IDs to exclude
        existing_ids = Enum.map(socket.assigns.memberships, & &1.user_id)
        pending_ids = Enum.map(socket.assigns.pending_invitations, & &1.invitee_id)
        exclude_ids = existing_ids ++ pending_ids

        Accounts.search_voice_artists(search)
        |> Enum.reject(fn u -> u.id in exclude_ids end)
        |> Enum.take(5)
      else
        []
      end

    {:noreply,
     socket
     |> assign(:member_search, search)
     |> assign(:search_results, results)}
  end

  @impl true
  def handle_event("select_user", %{"user_id" => user_id}, socket) do
    user = Accounts.get_user(user_id)
    {:noreply,
     socket
     |> assign(:selected_user, user)
     |> assign(:search_results, [])
     |> assign(:member_search, "")}
  end

  @impl true
  def handle_event("update_invite_message", %{"message" => message}, socket) do
    {:noreply, assign(socket, :invite_message, message)}
  end

  @impl true
  def handle_event("send_invitation", _, socket) do
    user = socket.assigns.selected_user
    message = socket.assigns.invite_message

    if user do
      case Collectives.create_invitation(
        socket.assigns.collective,
        socket.assigns.current_user,
        user,
        if(message != "", do: message, else: nil)
      ) do
        {:ok, _invitation} ->
          # TODO: Send notification to invitee
          {:noreply,
           socket
           |> put_flash(:info, "Invitation sent to #{user.name}")
           |> assign(:show_invite_modal, false)
           |> assign(:selected_user, nil)
           |> assign(:invite_message, "")
           |> refresh_data()}

        {:error, :already_member} ->
          {:noreply, put_flash(socket, :error, "#{user.name} is already a member")}

        {:error, :invitation_exists} ->
          {:noreply, put_flash(socket, :error, "#{user.name} already has a pending invitation")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to send invitation")}
      end
    else
      {:noreply, put_flash(socket, :error, "Please select a user to invite")}
    end
  end

  @impl true
  def handle_event("cancel_invitation", %{"id" => id}, socket) do
    invitation = Collectives.get_invitation(id)

    if invitation && invitation.collective_id == socket.assigns.collective.id do
      case Collectives.cancel_invitation(invitation) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, "Invitation cancelled")
           |> refresh_data()}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to cancel invitation")}
      end
    else
      {:noreply, put_flash(socket, :error, "Invitation not found")}
    end
  end

  # Join request handling
  @impl true
  def handle_event("approve_request", %{"id" => id}, socket) do
    request = Collectives.get_join_request(id)

    if request && request.collective_id == socket.assigns.collective.id do
      case Collectives.approve_join_request(request, socket.assigns.current_user) do
        {:ok, _} ->
          # TODO: Send notification to requester
          {:noreply,
           socket
           |> put_flash(:info, "#{request.user.name} has been added to the collective")
           |> refresh_data()}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to approve request")}
      end
    else
      {:noreply, put_flash(socket, :error, "Request not found")}
    end
  end

  @impl true
  def handle_event("reject_request", %{"id" => id}, socket) do
    request = Collectives.get_join_request(id)

    if request && request.collective_id == socket.assigns.collective.id do
      case Collectives.reject_join_request(request, socket.assigns.current_user) do
        {:ok, _} ->
          # TODO: Send notification to requester
          {:noreply,
           socket
           |> put_flash(:info, "Request rejected")
           |> refresh_data()}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to reject request")}
      end
    else
      {:noreply, put_flash(socket, :error, "Request not found")}
    end
  end

  # Member management
  @impl true
  def handle_event("remove_member", %{"user_id" => user_id}, socket) do
    user = Accounts.get_user(user_id)

    # Prevent removing the last admin
    if Collectives.admin_count(socket.assigns.collective.id) <= 1 &&
       Collectives.is_admin?(socket.assigns.collective.id, user_id) do
      {:noreply, put_flash(socket, :error, "Cannot remove the last admin")}
    else
      case Collectives.remove_member(socket.assigns.collective, user) do
        :ok ->
          {:noreply,
           socket
           |> put_flash(:info, "#{user.name} removed from collective")
           |> refresh_data()}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to remove member")}
      end
    end
  end

  @impl true
  def handle_event("toggle_admin", %{"user_id" => user_id}, socket) do
    user = Accounts.get_user(user_id)
    is_currently_admin = Collectives.is_admin?(socket.assigns.collective.id, user_id)
    new_role = if is_currently_admin, do: "member", else: "admin"

    # Prevent demoting the last admin
    if is_currently_admin && Collectives.admin_count(socket.assigns.collective.id) <= 1 do
      {:noreply, put_flash(socket, :error, "Cannot demote the last admin")}
    else
      case Collectives.update_member_role(socket.assigns.collective, user, new_role) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, "#{user.name} is now #{new_role}")
           |> refresh_data()}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to update role")}
      end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="py-6 sm:py-8 px-4 sm:px-6">
      <div class="max-w-2xl mx-auto">
        <!-- Back Button -->
        <div class="mb-4">
          <.link navigate={~p"/collective/#{@collective.slug}"} class="text-sm text-emerald-600 hover:underline flex items-center gap-1">
            <.icon name="hero-arrow-left" class="w-4 h-4" />
            Back to Collective
          </.link>
        </div>

        <h1 class="text-2xl font-bold mb-6">Collective Settings</h1>

        <!-- Profile Section -->
        <div class="bg-white border rounded-xl p-4 sm:p-6 mb-6">
          <div class="flex items-center justify-between mb-4">
            <h2 class="font-semibold">Profile</h2>
            <button
              phx-click="toggle_editing"
              class="text-sm text-emerald-600 hover:underline"
            >
              <%= if @editing, do: "Cancel", else: "Edit" %>
            </button>
          </div>

          <%= if @editing do %>
            <form phx-submit="update_collective" class="space-y-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Name</label>
                <input
                  type="text"
                  name="name"
                  value={@collective.name}
                  class="w-full border rounded-lg px-3 py-2"
                  required
                />
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Bio</label>
                <textarea
                  name="bio"
                  rows="3"
                  class="w-full border rounded-lg px-3 py-2"
                  maxlength="500"
                ><%= @collective.bio %></textarea>
                <p class="text-xs text-gray-500 mt-1">Max 500 characters</p>
              </div>

              <button type="submit" class="w-full bg-emerald-600 text-white py-2 rounded-lg hover:bg-emerald-700">
                Save Changes
              </button>
            </form>
          <% else %>
            <div class="space-y-3">
              <div>
                <p class="text-sm text-gray-500">Name</p>
                <p class="font-medium"><%= @collective.name %></p>
              </div>
              <div>
                <p class="text-sm text-gray-500">Bio</p>
                <p><%= @collective.bio || "No bio set" %></p>
              </div>
              <div>
                <p class="text-sm text-gray-500">URL</p>
                <p class="text-emerald-600">/collective/<%= @collective.slug %></p>
              </div>
            </div>
          <% end %>
        </div>

        <!-- Commission Status -->
        <div class="bg-white border rounded-xl p-4 sm:p-6 mb-6">
          <div class="flex items-center justify-between">
            <div>
              <h2 class="font-semibold">Accepting Commissions</h2>
              <p class="text-sm text-gray-500">Allow writers to request work from this collective</p>
            </div>
            <button
              phx-click="toggle_commissions"
              class={[
                "relative inline-flex h-6 w-11 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none",
                @collective.is_accepting_commissions && "bg-emerald-600",
                !@collective.is_accepting_commissions && "bg-gray-200"
              ]}
            >
              <span class={[
                "pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out",
                @collective.is_accepting_commissions && "translate-x-5",
                !@collective.is_accepting_commissions && "translate-x-0"
              ]}></span>
            </button>
          </div>
        </div>

        <!-- Join Requests Section -->
        <%= if length(@join_requests) > 0 do %>
          <div class="bg-amber-50 border border-amber-200 rounded-xl p-4 sm:p-6 mb-6">
            <div class="flex items-center gap-2 mb-4">
              <.icon name="hero-inbox" class="w-5 h-5 text-amber-600" />
              <h2 class="font-semibold text-amber-900">Join Requests (<%= length(@join_requests) %>)</h2>
            </div>
            <div class="space-y-3">
              <%= for request <- @join_requests do %>
                <div class="bg-white rounded-lg p-4 border border-amber-200">
                  <div class="flex items-start gap-3">
                    <div class="w-10 h-10 bg-emerald-100 rounded-full flex items-center justify-center flex-shrink-0">
                      <span class="font-bold text-emerald-600">
                        <%= String.first(request.user.name) |> String.upcase() %>
                      </span>
                    </div>
                    <div class="flex-1 min-w-0">
                      <p class="font-medium text-gray-900"><%= request.user.name %></p>
                      <%= if request.message do %>
                        <p class="text-sm text-gray-600 mt-1 italic">"<%= request.message %>"</p>
                      <% end %>
                      <p class="text-xs text-gray-500 mt-1">
                        Requested <%= format_time_ago(request.inserted_at) %>
                      </p>
                    </div>
                  </div>
                  <div class="flex gap-2 mt-3">
                    <button
                      phx-click="reject_request"
                      phx-value-id={request.id}
                      class="flex-1 px-3 py-2 border border-gray-200 rounded-lg text-gray-700 hover:bg-gray-50 text-sm font-medium"
                    >
                      Reject
                    </button>
                    <button
                      phx-click="approve_request"
                      phx-value-id={request.id}
                      class="flex-1 px-3 py-2 bg-emerald-600 text-white rounded-lg hover:bg-emerald-700 text-sm font-medium"
                    >
                      Approve & Add
                    </button>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>

        <!-- Members Section -->
        <div class="bg-white border rounded-xl p-4 sm:p-6 mb-6">
          <div class="flex items-center justify-between mb-4">
            <h2 class="font-semibold">Members (<%= length(@memberships) %>)</h2>
            <button
              phx-click="show_invite_modal"
              class="text-sm bg-emerald-600 text-white px-3 py-1.5 rounded-lg hover:bg-emerald-700 flex items-center gap-1"
            >
              <.icon name="hero-envelope" class="w-4 h-4" />
              Invite
            </button>
          </div>

          <!-- Invite Modal -->
          <%= if @show_invite_modal do %>
            <div class="fixed inset-0 bg-black/50 z-50 flex items-end sm:items-center justify-center p-4">
              <div class="bg-white rounded-xl w-full max-w-md max-h-[80vh] overflow-hidden">
                <div class="p-4 border-b flex items-center justify-between">
                  <h3 class="font-semibold">Invite Member</h3>
                  <button phx-click="hide_invite_modal" class="text-gray-500 hover:text-gray-700">
                    <.icon name="hero-x-mark" class="w-5 h-5" />
                  </button>
                </div>

                <div class="p-4">
                  <%= if @selected_user do %>
                    <!-- Selected user -->
                    <div class="flex items-center gap-3 p-3 bg-emerald-50 rounded-lg mb-4">
                      <div class="w-10 h-10 bg-emerald-100 rounded-full flex items-center justify-center">
                        <span class="font-bold text-emerald-600">
                          <%= String.first(@selected_user.name) |> String.upcase() %>
                        </span>
                      </div>
                      <div class="flex-1">
                        <p class="font-medium"><%= @selected_user.name %></p>
                        <p class="text-sm text-gray-500">Voice Artist</p>
                      </div>
                      <button
                        phx-click="hide_invite_modal"
                        class="text-gray-400 hover:text-gray-600"
                      >
                        <.icon name="hero-x-mark" class="w-4 h-4" />
                      </button>
                    </div>

                    <!-- Optional message -->
                    <div class="mb-4">
                      <label class="block text-sm font-medium text-gray-700 mb-1">
                        Add a message (optional)
                      </label>
                      <textarea
                        phx-change="update_invite_message"
                        name="message"
                        rows="2"
                        class="w-full border rounded-lg px-3 py-2"
                        placeholder="We'd love to have you join our collective!"
                      ><%= @invite_message %></textarea>
                    </div>

                    <button
                      phx-click="send_invitation"
                      class="w-full bg-emerald-600 text-white py-2.5 rounded-lg font-medium hover:bg-emerald-700"
                    >
                      Send Invitation
                    </button>
                  <% else %>
                    <!-- Search -->
                    <input
                      type="text"
                      placeholder="Search voice artists..."
                      value={@member_search}
                      phx-keyup="search_members"
                      phx-debounce="300"
                      class="w-full border rounded-lg px-3 py-2 mb-4"
                      autofocus
                    />

                    <div class="space-y-2 max-h-60 overflow-y-auto">
                      <%= if @search_results == [] and @member_search != "" do %>
                        <p class="text-sm text-gray-500 text-center py-4">No voice artists found</p>
                      <% end %>

                      <%= for user <- @search_results do %>
                        <button
                          phx-click="select_user"
                          phx-value-user_id={user.id}
                          class="w-full flex items-center gap-3 p-3 rounded-lg hover:bg-gray-50 text-left"
                        >
                          <div class="w-10 h-10 bg-emerald-100 rounded-full flex items-center justify-center">
                            <span class="font-bold text-emerald-600">
                              <%= String.first(user.name) |> String.upcase() %>
                            </span>
                          </div>
                          <div>
                            <p class="font-medium"><%= user.name %></p>
                            <p class="text-sm text-gray-500">Voice Artist</p>
                          </div>
                        </button>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          <% end %>

          <!-- Pending Invitations -->
          <%= if length(@pending_invitations) > 0 do %>
            <div class="mb-4">
              <p class="text-sm text-gray-500 mb-2">Pending Invitations</p>
              <div class="space-y-2">
                <%= for invitation <- @pending_invitations do %>
                  <div class="flex items-center justify-between p-3 rounded-lg bg-amber-50 border border-amber-200">
                    <div class="flex items-center gap-3">
                      <div class="w-8 h-8 bg-amber-100 rounded-full flex items-center justify-center">
                        <span class="font-bold text-amber-600 text-sm">
                          <%= String.first(invitation.invitee.name) |> String.upcase() %>
                        </span>
                      </div>
                      <div>
                        <p class="font-medium text-sm"><%= invitation.invitee.name %></p>
                        <p class="text-xs text-gray-500">
                          Sent <%= format_time_ago(invitation.inserted_at) %>
                        </p>
                      </div>
                    </div>
                    <button
                      phx-click="cancel_invitation"
                      phx-value-id={invitation.id}
                      class="text-xs text-red-600 hover:text-red-700"
                    >
                      Cancel
                    </button>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>

          <!-- Members List -->
          <div class="space-y-3">
            <%= for membership <- @memberships do %>
              <div class="flex items-center justify-between p-3 rounded-lg bg-gray-50">
                <div class="flex items-center gap-3">
                  <div class="w-10 h-10 bg-emerald-100 rounded-full flex items-center justify-center">
                    <span class="font-bold text-emerald-600">
                      <%= String.first(membership.user.name) |> String.upcase() %>
                    </span>
                  </div>
                  <div>
                    <div class="flex items-center gap-2">
                      <span class="font-medium"><%= membership.user.name %></span>
                      <%= if membership.role == "admin" do %>
                        <span class="text-xs bg-purple-100 text-purple-700 px-1.5 py-0.5 rounded">Admin</span>
                      <% end %>
                    </div>
                    <p class="text-xs text-gray-500">
                      Joined <%= Calendar.strftime(membership.joined_at, "%b %d, %Y") %>
                    </p>
                  </div>
                </div>

                <div class="flex items-center gap-2">
                  <%= if membership.user.id != @current_user.id do %>
                    <button
                      phx-click="toggle_admin"
                      phx-value-user_id={membership.user.id}
                      class="text-xs text-gray-600 hover:text-gray-900 px-2 py-1 rounded hover:bg-gray-200"
                    >
                      <%= if membership.role == "admin", do: "Demote", else: "Make Admin" %>
                    </button>
                    <button
                      phx-click="remove_member"
                      phx-value-user_id={membership.user.id}
                      data-confirm="Remove #{membership.user.name} from the collective?"
                      class="text-xs text-red-600 hover:text-red-700 px-2 py-1 rounded hover:bg-red-50"
                    >
                      Remove
                    </button>
                  <% else %>
                    <span class="text-xs text-gray-400">You</span>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Danger Zone -->
        <div class="bg-white border border-red-200 rounded-xl p-4 sm:p-6">
          <h2 class="font-semibold text-red-600 mb-2">Danger Zone</h2>
          <p class="text-sm text-gray-600 mb-4">
            Deleting the collective will remove all members and unlink all recordings.
            This action cannot be undone.
          </p>
          <button
            class="text-sm text-red-600 border border-red-200 px-4 py-2 rounded-lg hover:bg-red-50"
            onclick="if(confirm('Are you sure you want to delete this collective?')) { /* TODO */ }"
          >
            Delete Collective
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp format_time_ago(nil), do: ""
  defp format_time_ago(%NaiveDateTime{} = naive) do
    datetime = DateTime.from_naive!(naive, "Etc/UTC")
    format_time_ago(datetime)
  end
  defp format_time_ago(%DateTime{} = datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      diff < 604_800 -> "#{div(diff, 86400)}d ago"
      true -> Calendar.strftime(datetime, "%b %d")
    end
  end
end
