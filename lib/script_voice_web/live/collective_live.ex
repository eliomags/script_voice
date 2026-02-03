defmodule ScriptVoiceWeb.CollectiveLive do
  @moduledoc """
  LiveView for displaying a collective's profile page.
  """
  use ScriptVoiceWeb, :live_view

  alias ScriptVoice.Collectives
  alias ScriptVoice.Audio

  @impl true
  def mount(%{"slug" => slug}, session, socket) do
    current_user = get_current_user(session)

    case Collectives.get_collective_by_slug(slug) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Collective not found")
         |> push_navigate(to: ~p"/browse")}

      collective ->
        audio_versions = Audio.list_audio_versions_by_collective(collective.id)

        is_member = current_user && Collectives.is_member?(collective.id, current_user.id)
        is_admin = current_user && Collectives.is_admin?(collective.id, current_user.id)

        # Check user's join request status (pending, rejected, etc.) - with messages
        {pending_join_request, latest_join_request} =
          if current_user && !is_member do
            pending = Collectives.get_pending_join_request_with_messages(collective.id, current_user.id)
            latest = if pending, do: pending, else: Collectives.get_latest_join_request_with_messages(collective.id, current_user.id)
            {pending, latest}
          else
            {nil, nil}
          end

        # Load pending join requests for admins - with messages
        join_requests =
          if is_admin do
            Collectives.list_pending_join_requests_with_messages(collective.id)
          else
            []
          end

        # Sort members: admins first, then by display_order
        sorted_memberships =
          collective.memberships
          |> Enum.sort_by(fn m -> {if(m.role == "admin", do: 0, else: 1), m.display_order} end)

        {:ok,
         socket
         |> assign(:current_user, current_user)
         |> assign(:collective, collective)
         |> assign(:memberships, sorted_memberships)
         |> assign(:audio_versions, audio_versions)
         |> assign(:is_member, is_member)
         |> assign(:is_admin, is_admin)
         |> assign(:pending_join_request, pending_join_request)
         |> assign(:latest_join_request, latest_join_request)
         |> assign(:join_requests, join_requests)
         |> assign(:show_join_modal, false)
         |> assign(:join_message, "")
         |> assign(:show_reject_modal, false)
         |> assign(:rejecting_request, nil)
         |> assign(:page_title, collective.name)}
    end
  end

  defp get_current_user(session) do
    case session["user_id"] do
      nil -> nil
      user_id -> ScriptVoice.Accounts.get_user(user_id)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="py-6 sm:py-8 px-4 sm:px-6">
      <div class="max-w-4xl mx-auto">
        <!-- Back Button -->
        <div class="mb-4">
          <.link navigate={~p"/browse"} class="text-sm text-emerald-600 hover:underline flex items-center gap-1">
            <.icon name="hero-arrow-left" class="w-4 h-4" />
            Back
          </.link>
        </div>

        <!-- Collective Header -->
        <div class="bg-white border rounded-xl p-6 mb-6">
          <div class="flex items-start gap-4">
            <!-- Avatar -->
            <div class="w-16 h-16 sm:w-20 sm:h-20 bg-purple-100 rounded-full flex items-center justify-center flex-shrink-0">
              <%= if @collective.avatar_url do %>
                <img src={@collective.avatar_url} alt={@collective.name} class="w-full h-full rounded-full object-cover" />
              <% else %>
                <.icon name="hero-user-group" class="w-8 h-8 sm:w-10 sm:h-10 text-purple-600" />
              <% end %>
            </div>

            <!-- Info -->
            <div class="flex-1 min-w-0">
              <div class="flex flex-wrap items-center gap-2 mb-1">
                <h1 class="text-xl sm:text-2xl font-bold truncate"><%= @collective.name %></h1>
                <span class="text-xs bg-purple-100 text-purple-700 px-2 py-0.5 rounded-full">
                  Collective
                </span>
              </div>

              <!-- Stats -->
              <div class="flex gap-4 text-sm text-gray-500 mb-2">
                <span><%= length(@memberships) %> members</span>
                <span><%= length(@audio_versions) %> recordings</span>
              </div>

              <!-- Bio -->
              <%= if @collective.bio do %>
                <p class="text-gray-600 text-sm mt-2"><%= @collective.bio %></p>
              <% end %>

              <!-- Social Links -->
              <%= if @collective.social_links != [] do %>
                <div class="flex gap-2 mt-3">
                  <%= for link <- @collective.social_links do %>
                    <a
                      href={link}
                      target="_blank"
                      rel="noopener noreferrer"
                      class="text-xs bg-gray-100 px-2 py-1 rounded hover:bg-gray-200"
                    >
                      <%= get_social_name(link) %>
                    </a>
                  <% end %>
                </div>
              <% end %>

              <!-- Actions -->
              <div class="flex flex-wrap gap-2 mt-4">
                <%= if @collective.is_accepting_commissions do %>
                  <span class="text-xs text-emerald-600 flex items-center gap-1">
                    <.icon name="hero-check-circle" class="w-4 h-4" />
                    Accepting commissions
                  </span>
                <% end %>

                <%= if @is_admin do %>
                  <.link
                    navigate={~p"/collective/#{@collective.slug}/settings"}
                    class="text-xs bg-gray-100 px-3 py-1.5 rounded-lg hover:bg-gray-200 flex items-center gap-1"
                  >
                    <.icon name="hero-cog-6-tooth" class="w-4 h-4" />
                    Settings
                  </.link>
                <% end %>

                <!-- Request to Join Button (for non-members) -->
                <%= if @current_user && !@is_member do %>
                  <%= if @pending_join_request do %>
                    <div class="flex items-center gap-2">
                      <span class="text-xs text-amber-600 flex items-center gap-1 bg-amber-50 px-3 py-1.5 rounded-lg">
                        <.icon name="hero-clock" class="w-4 h-4" />
                        Request pending
                      </span>
                      <button
                        phx-click="cancel_join_request"
                        class="text-xs text-red-600 hover:text-red-700 underline"
                      >
                        Cancel
                      </button>
                    </div>

                    <!-- Full conversation thread with reply -->
                    <% messages = @pending_join_request.messages || [] %>
                    <%= if (@pending_join_request.message && @pending_join_request.message != "") || length(messages) > 0 do %>
                      <div class="mt-3 w-full space-y-2 max-h-40 overflow-y-auto">
                        <!-- Your initial message -->
                        <%= if @pending_join_request.message && @pending_join_request.message != "" do %>
                          <div class="bg-gray-50 rounded-lg px-3 py-2">
                            <p class="text-xs text-gray-500">You:</p>
                            <p class="text-sm text-gray-700">"<%= @pending_join_request.message %>"</p>
                          </div>
                        <% end %>
                        <!-- Conversation messages -->
                        <%= for msg <- messages do %>
                          <% is_my_msg = msg.sender_id == @current_user.id %>
                          <div class={[
                            "rounded-lg px-3 py-2",
                            is_my_msg && "bg-gray-50",
                            !is_my_msg && "bg-blue-50 border-l-2 border-blue-400"
                          ]}>
                            <p class={["text-xs", is_my_msg && "text-gray-500", !is_my_msg && "text-blue-600"]}>
                              <%= if is_my_msg, do: "You", else: "Collective" %>:
                            </p>
                            <p class="text-sm text-gray-700">"<%= msg.content %>"</p>
                          </div>
                        <% end %>
                      </div>
                    <% end %>

                    <!-- Reply input for requestor -->
                    <form phx-submit="send_requestor_message" class="mt-3 w-full">
                      <div class="flex gap-2">
                        <input
                          type="text"
                          name="content"
                          placeholder="Reply to collective..."
                          class="flex-1 text-sm border border-gray-200 rounded-lg px-3 py-2 focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500"
                          required
                        />
                        <button type="submit" class="px-3 py-2 bg-emerald-100 text-emerald-700 rounded-lg hover:bg-emerald-200 transition">
                          <.icon name="hero-paper-airplane" class="w-4 h-4" />
                        </button>
                      </div>
                    </form>
                  <% else %>
                    <%= if @latest_join_request && @latest_join_request.status == "rejected" do %>
                      <!-- Previously rejected - show status and allow re-request -->
                      <div class="flex flex-col gap-2">
                        <div class="bg-red-50 border border-red-200 rounded-lg px-3 py-2">
                          <div class="flex items-center gap-2 text-red-700">
                            <.icon name="hero-x-circle" class="w-4 h-4 flex-shrink-0" />
                            <span class="text-xs font-medium">Request declined</span>
                          </div>
                          <%= if @latest_join_request.response_message && @latest_join_request.response_message != "" do %>
                            <p class="text-xs text-red-600 mt-1 ml-6 italic">
                              "<%= @latest_join_request.response_message %>"
                            </p>
                          <% end %>
                          <p class="text-xs text-gray-500 mt-1 ml-6">
                            <%= format_time_ago(@latest_join_request.reviewed_at || @latest_join_request.updated_at) %>
                          </p>
                        </div>
                        <button
                          phx-click="show_join_modal"
                          class="text-xs bg-gray-100 text-gray-700 px-3 py-1.5 rounded-lg hover:bg-gray-200 flex items-center gap-1"
                        >
                          <.icon name="hero-arrow-path" class="w-4 h-4" />
                          Request Again
                        </button>
                      </div>
                    <% else %>
                      <button
                        phx-click="show_join_modal"
                        class="text-xs bg-emerald-600 text-white px-3 py-1.5 rounded-lg hover:bg-emerald-700 flex items-center gap-1"
                      >
                        <.icon name="hero-user-plus" class="w-4 h-4" />
                        Request to Join
                      </button>
                    <% end %>
                  <% end %>
                <% end %>

                <%= if @is_member && !@is_admin do %>
                  <button
                    phx-click="leave_collective"
                    data-confirm="Are you sure you want to leave this collective?"
                    class="text-xs text-red-600 hover:text-red-700 flex items-center gap-1"
                  >
                    <.icon name="hero-arrow-right-on-rectangle" class="w-4 h-4" />
                    Leave
                  </button>
                <% end %>
              </div>
            </div>
          </div>
        </div>

        <!-- Profile Video -->
        <%= if @collective.profile_video_url do %>
          <div class="bg-white border rounded-xl p-4 sm:p-6 mb-6">
            <h2 class="font-semibold mb-3 flex items-center gap-2">
              <.icon name="hero-video-camera" class="w-5 h-5 text-emerald-600" />
              About Us
            </h2>
            <div class="aspect-video bg-gray-900 rounded-lg overflow-hidden">
              <video
                controls
                playsinline
                class="w-full h-full object-contain"
                src={@collective.profile_video_url}
              >
                Your browser does not support the video tag.
              </video>
            </div>
          </div>
        <% end %>

        <!-- Join Requests Section (Admin Only) -->
        <%= if @is_admin && length(@join_requests) > 0 do %>
          <div class="bg-amber-50 border border-amber-200 rounded-xl p-4 sm:p-6 mb-6">
            <h2 class="font-semibold mb-4 flex items-center gap-2 text-amber-800">
              <.icon name="hero-user-plus" class="w-5 h-5" />
              Join Requests (<%= length(@join_requests) %>)
            </h2>

            <div class="space-y-3">
              <%= for request <- @join_requests do %>
                <div class="bg-white rounded-xl p-4 shadow-sm">
                  <!-- Header row -->
                  <div class="flex items-center gap-3">
                    <.link navigate={~p"/profile/#{request.user.id}?from=collective:#{@collective.slug}"} class="flex-shrink-0">
                      <div class="w-10 h-10 bg-gradient-to-br from-emerald-400 to-emerald-600 rounded-full flex items-center justify-center">
                        <span class="text-sm font-bold text-white">
                          <%= String.first(request.user.name) |> String.upcase() %>
                        </span>
                      </div>
                    </.link>
                    <div class="flex-1 min-w-0">
                      <.link navigate={~p"/profile/#{request.user.id}?from=collective:#{@collective.slug}"} class="font-medium text-gray-900 hover:text-emerald-600">
                        <%= request.user.name %>
                      </.link>
                      <p class="text-xs text-gray-400"><%= format_time_ago(request.inserted_at) %></p>
                    </div>
                  </div>

                  <!-- Full conversation thread -->
                  <% messages = request.messages || [] %>
                  <%= if (request.message && request.message != "") || length(messages) > 0 do %>
                    <div class="mt-3 space-y-2 max-h-48 overflow-y-auto">
                      <!-- Initial request message -->
                      <%= if request.message && request.message != "" do %>
                        <div class="bg-gray-50 rounded-lg px-3 py-2">
                          <p class="text-xs text-gray-500"><%= request.user.name %>:</p>
                          <p class="text-sm text-gray-700">"<%= request.message %>"</p>
                        </div>
                      <% end %>
                      <!-- Conversation messages -->
                      <%= for msg <- messages do %>
                        <% is_admin_msg = msg.sender_id != request.user_id %>
                        <div class={[
                          "rounded-lg px-3 py-2",
                          is_admin_msg && "bg-emerald-50 border-l-2 border-emerald-400",
                          !is_admin_msg && "bg-blue-50 border-l-2 border-blue-400"
                        ]}>
                          <p class={["text-xs", is_admin_msg && "text-emerald-600", !is_admin_msg && "text-blue-600"]}>
                            <%= if is_admin_msg, do: "You", else: request.user.name %>:
                          </p>
                          <p class="text-sm text-gray-700">"<%= msg.content %>"</p>
                        </div>
                      <% end %>
                    </div>
                  <% end %>

                  <!-- Reply input -->
                  <form phx-submit="send_message" class="mt-3">
                    <input type="hidden" name="request_id" value={request.id} />
                    <div class="flex gap-2">
                      <input
                        type="text"
                        name="content"
                        placeholder={"Reply to #{request.user.name}..."}
                        class="flex-1 text-sm border border-gray-200 rounded-lg px-3 py-2 focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500"
                        required
                      />
                      <button type="submit" class="px-3 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition">
                        <.icon name="hero-paper-airplane" class="w-4 h-4" />
                      </button>
                    </div>
                  </form>

                  <!-- Actions -->
                  <div class="mt-3 flex items-center gap-2">
                    <button
                      phx-click="reject_join_request"
                      phx-value-id={request.id}
                      class="flex-1 py-2 text-sm font-medium text-red-600 border border-red-200 rounded-lg hover:bg-red-50 transition"
                    >
                      Reject
                    </button>
                    <button
                      phx-click="approve_join_request"
                      phx-value-id={request.id}
                      class="flex-1 py-2 text-sm font-medium text-white bg-emerald-600 rounded-lg hover:bg-emerald-700 transition"
                    >
                      Approve
                    </button>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>

        <!-- Members Section -->
        <div class="bg-white border rounded-xl p-4 sm:p-6 mb-6">
          <h2 class="font-semibold mb-4 flex items-center gap-2">
            <.icon name="hero-users" class="w-5 h-5 text-emerald-600" />
            Members
          </h2>

          <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-3">
            <%= for membership <- @memberships do %>
              <.link
                navigate={~p"/profile/#{membership.user.id}?from=collective:#{@collective.slug}"}
                class="flex flex-col items-center p-3 rounded-xl bg-gray-50 hover:bg-gray-100 transition"
              >
                <!-- Member Avatar -->
                <div class="w-12 h-12 bg-emerald-100 rounded-full flex items-center justify-center mb-2">
                  <span class="text-lg font-bold text-emerald-600">
                    <%= String.first(membership.user.name) |> String.upcase() %>
                  </span>
                </div>

                <!-- Name -->
                <span class="text-sm font-medium text-center truncate w-full">
                  <%= membership.user.name %>
                </span>

                <!-- Role Badge -->
                <%= if membership.role == "admin" do %>
                  <span class="text-xs text-purple-600 mt-1 flex items-center gap-0.5">
                    <.icon name="hero-star-solid" class="w-3 h-3" />
                    Admin
                  </span>
                <% end %>

                <!-- Verified Badge -->
                <%= if membership.user.verification_status == "verified" do %>
                  <span class="text-xs text-emerald-600 mt-0.5">
                    <.icon name="hero-check-badge-solid" class="w-4 h-4" />
                  </span>
                <% end %>
              </.link>
            <% end %>
          </div>
        </div>

        <!-- Audio Recordings Section -->
        <div class="bg-white border rounded-xl p-4 sm:p-6">
          <h2 class="font-semibold mb-4 flex items-center gap-2">
            <.icon name="hero-microphone" class="w-5 h-5 text-emerald-600" />
            Recordings (<%= length(@audio_versions) %>)
          </h2>

          <%= if Enum.empty?(@audio_versions) do %>
            <div class="text-center py-8">
              <.icon name="hero-microphone" class="w-12 h-12 text-gray-300 mx-auto mb-4" />
              <p class="text-gray-500">No recordings yet</p>
            </div>
          <% else %>
            <div class="space-y-3">
              <%= for av <- @audio_versions do %>
                <.link
                  navigate={~p"/screenplay/#{av.screenplay_id}"}
                  class="block bg-gray-50 rounded-xl p-4 hover:bg-gray-100 transition"
                >
                  <div class="flex items-center justify-between">
                    <div class="flex-1 min-w-0">
                      <h3 class="font-medium truncate">
                        <%= if av.screenplay, do: av.screenplay.title, else: "Unknown Screenplay" %>
                      </h3>
                      <div class="flex items-center gap-3 text-sm text-gray-500 mt-1">
                        <span class="flex items-center gap-1">
                          <.icon name="hero-clock" class="w-4 h-4" />
                          <%= ScriptVoice.Audio.AudioVersion.display_duration(av) %>
                        </span>
                        <span class="flex items-center gap-1">
                          <.icon name="hero-heart" class="w-4 h-4" />
                          <%= av.likes %>
                        </span>
                        <%= if av.author_pick do %>
                          <span class="text-amber-600 flex items-center gap-1">
                            <.icon name="hero-trophy" class="w-4 h-4" />
                            Author's Pick
                          </span>
                        <% end %>
                      </div>
                    </div>
                    <.icon name="hero-chevron-right" class="w-5 h-5 text-gray-400 flex-shrink-0" />
                  </div>
                </.link>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </div>

    <!-- Join Request Modal -->
    <%= if @show_join_modal do %>
      <div class="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50" phx-click="close_join_modal">
        <div class="bg-white rounded-xl max-w-md w-full p-6" onclick="event.stopPropagation()">
          <div class="flex items-center justify-between mb-4">
            <h3 class="text-lg font-semibold">Request to Join</h3>
            <button phx-click="close_join_modal" class="text-gray-400 hover:text-gray-600">
              <.icon name="hero-x-mark" class="w-5 h-5" />
            </button>
          </div>

          <p class="text-sm text-gray-600 mb-4">
            Send a request to join <strong><%= @collective.name %></strong>.
            The collective admins will review your request.
          </p>

          <form phx-submit="submit_join_request">
            <div class="mb-4">
              <label class="block text-sm font-medium text-gray-700 mb-1">
                Message (optional)
              </label>
              <textarea
                name="message"
                rows="3"
                placeholder="Introduce yourself or explain why you'd like to join..."
                class="w-full border rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500"
              ><%= @join_message %></textarea>
            </div>

            <div class="flex gap-2">
              <button
                type="button"
                phx-click="close_join_modal"
                class="flex-1 px-4 py-2 border rounded-lg text-sm hover:bg-gray-50"
              >
                Cancel
              </button>
              <button
                type="submit"
                class="flex-1 px-4 py-2 bg-emerald-600 text-white rounded-lg text-sm hover:bg-emerald-700"
              >
                Send Request
              </button>
            </div>
          </form>
        </div>
      </div>
    <% end %>

    <!-- Reject Request Modal (Admin) -->
    <%= if @show_reject_modal && @rejecting_request do %>
      <div class="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50" phx-click="close_reject_modal">
        <div class="bg-white rounded-xl max-w-md w-full p-6" onclick="event.stopPropagation()">
          <div class="flex items-center justify-between mb-4">
            <h3 class="text-lg font-semibold">Reject Request</h3>
            <button phx-click="close_reject_modal" class="text-gray-400 hover:text-gray-600">
              <.icon name="hero-x-mark" class="w-5 h-5" />
            </button>
          </div>

          <p class="text-sm text-gray-600 mb-4">
            Reject <strong><%= @rejecting_request.user.name %></strong>'s request to join?
            They will be notified of your decision.
          </p>

          <form phx-submit="confirm_reject">
            <div class="mb-4">
              <label class="block text-sm font-medium text-gray-700 mb-1">
                Reason (optional)
              </label>
              <textarea
                name="reason"
                rows="2"
                placeholder="Let them know why (optional)..."
                class="w-full border rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-red-500"
              ></textarea>
              <p class="text-xs text-gray-500 mt-1">This will be included in their notification.</p>
            </div>

            <div class="flex gap-2">
              <button
                type="button"
                phx-click="close_reject_modal"
                class="flex-1 px-4 py-2 border rounded-lg text-sm hover:bg-gray-50"
              >
                Cancel
              </button>
              <button
                type="submit"
                class="flex-1 px-4 py-2 bg-red-600 text-white rounded-lg text-sm hover:bg-red-700"
              >
                Reject Request
              </button>
            </div>
          </form>
        </div>
      </div>
    <% end %>
    """
  end

  @impl true
  def handle_event("show_join_modal", _params, socket) do
    {:noreply, assign(socket, :show_join_modal, true)}
  end

  @impl true
  def handle_event("close_join_modal", _params, socket) do
    {:noreply, assign(socket, show_join_modal: false, join_message: "")}
  end

  @impl true
  def handle_event("submit_join_request", %{"message" => message}, socket) do
    alias ScriptVoice.Notifications

    case Collectives.create_join_request(
           socket.assigns.collective,
           socket.assigns.current_user,
           message
         ) do
      {:ok, request} ->
        # Notify all admins about the new join request
        socket.assigns.collective.memberships
        |> Enum.filter(& &1.role == "admin")
        |> Enum.each(fn membership ->
          Notifications.notify_join_request_received(
            membership.user_id,
            socket.assigns.current_user.name,
            socket.assigns.collective.name,
            socket.assigns.collective.slug
          )
        end)

        {:noreply,
         socket
         |> assign(:pending_join_request, request)
         |> assign(:show_join_modal, false)
         |> assign(:join_message, "")
         |> put_flash(:info, "Join request sent! The admins will review your request.")}

      {:error, :already_member} ->
        {:noreply,
         socket
         |> assign(:show_join_modal, false)
         |> put_flash(:error, "You're already a member of this collective.")}

      {:error, :request_exists} ->
        {:noreply,
         socket
         |> assign(:show_join_modal, false)
         |> put_flash(:info, "You already have a pending request for this collective.")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to submit join request. Please try again.")}
    end
  end

  @impl true
  def handle_event("cancel_join_request", _params, socket) do
    case socket.assigns.pending_join_request do
      nil ->
        {:noreply, socket}

      request ->
        case Collectives.cancel_join_request(request) do
          {:ok, _} ->
            {:noreply,
             socket
             |> assign(:pending_join_request, nil)
             |> put_flash(:info, "Join request cancelled.")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to cancel request.")}
        end
    end
  end

  @impl true
  def handle_event("leave_collective", _params, socket) do
    case Collectives.leave_collective(socket.assigns.collective.id, socket.assigns.current_user.id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:is_member, false)
         |> put_flash(:info, "You have left the collective.")}

      {:error, :last_admin} ->
        {:noreply, put_flash(socket, :error, "You cannot leave as the last admin. Transfer ownership first.")}

      {:error, :not_member} ->
        {:noreply, put_flash(socket, :error, "You're not a member of this collective.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to leave collective.")}
    end
  end

  @impl true
  def handle_event("approve_join_request", %{"id" => request_id}, socket) do
    alias ScriptVoice.Notifications
    request = Collectives.get_join_request(request_id)

    case Collectives.approve_join_request(request, socket.assigns.current_user) do
      {:ok, _} ->
        # Send notification to the user
        Notifications.notify_join_request_approved(
          request.user_id,
          socket.assigns.collective.name,
          socket.assigns.collective.slug
        )

        # Reload data
        collective = Collectives.get_collective(socket.assigns.collective.id)
        join_requests = Collectives.list_pending_join_requests_for_collective(collective.id)
        sorted_memberships =
          collective.memberships
          |> Enum.sort_by(fn m -> {if(m.role == "admin", do: 0, else: 1), m.display_order} end)

        {:noreply,
         socket
         |> assign(:collective, collective)
         |> assign(:memberships, sorted_memberships)
         |> assign(:join_requests, join_requests)
         |> put_flash(:info, "#{request.user.name} has been added to the collective!")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to approve request.")}
    end
  end

  @impl true
  def handle_event("show_reject_modal", %{"id" => request_id}, socket) do
    request = Collectives.get_join_request(request_id)
    {:noreply, assign(socket, show_reject_modal: true, rejecting_request: request)}
  end

  @impl true
  def handle_event("close_reject_modal", _params, socket) do
    {:noreply, assign(socket, show_reject_modal: false, rejecting_request: nil)}
  end

  @impl true
  def handle_event("confirm_reject", %{"reason" => reason}, socket) do
    alias ScriptVoice.Notifications
    request = socket.assigns.rejecting_request

    case Collectives.reject_join_request(request, socket.assigns.current_user, reason) do
      {:ok, _} ->
        # Send notification to the user with reason
        Notifications.notify_join_request_rejected(
          request.user_id,
          socket.assigns.collective.name,
          reason
        )

        join_requests = Collectives.list_pending_join_requests_for_collective(socket.assigns.collective.id)

        {:noreply,
         socket
         |> assign(:join_requests, join_requests)
         |> assign(:show_reject_modal, false)
         |> assign(:rejecting_request, nil)
         |> put_flash(:info, "Request rejected. #{request.user.name} has been notified.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to reject request.")}
    end
  end

  @impl true
  def handle_event("send_message", %{"content" => content, "request_id" => request_id}, socket) do
    alias ScriptVoice.Notifications
    request = Collectives.get_join_request(request_id)
    admin = socket.assigns.current_user
    collective_name = socket.assigns.collective.name

    case Collectives.create_join_request_message(request_id, admin.id, content) do
      {:ok, _message} ->
        # Send notification to the requestor
        Notifications.notify_join_request_note(
          request.user_id,
          admin.name,
          collective_name,
          content,
          socket.assigns.collective.slug
        )

        # Reload join requests with messages
        join_requests = Collectives.list_pending_join_requests_with_messages(socket.assigns.collective.id)

        {:noreply,
         socket
         |> assign(:join_requests, join_requests)
         |> put_flash(:info, "Message sent to #{request.user.name}.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to send message.")}
    end
  end

  @impl true
  def handle_event("send_requestor_message", %{"content" => content}, socket) do
    alias ScriptVoice.Notifications
    request = socket.assigns.pending_join_request
    user = socket.assigns.current_user
    collective = socket.assigns.collective

    case Collectives.create_join_request_message(request.id, user.id, content) do
      {:ok, _message} ->
        # Notify all admins about the reply
        collective.memberships
        |> Enum.filter(& &1.role == "admin")
        |> Enum.each(fn membership ->
          Notifications.notify_join_request_note(
            membership.user_id,
            user.name,
            collective.name,
            content,
            collective.slug
          )
        end)

        # Reload the pending request with messages
        updated_request = Collectives.get_pending_join_request_with_messages(collective.id, user.id)

        {:noreply,
         socket
         |> assign(:pending_join_request, updated_request)
         |> put_flash(:info, "Message sent.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to send message.")}
    end
  end

  @impl true
  def handle_event("reject_join_request", %{"id" => request_id}, socket) do
    # Show the reject modal instead of rejecting immediately
    request = Collectives.get_join_request(request_id)
    {:noreply, assign(socket, show_reject_modal: true, rejecting_request: request)}
  end

  defp format_time_ago(datetime) do
    now = DateTime.utc_now()
    diff_seconds = DateTime.diff(now, datetime)

    cond do
      diff_seconds < 60 -> "just now"
      diff_seconds < 3600 -> "#{div(diff_seconds, 60)} min ago"
      diff_seconds < 86400 -> "#{div(diff_seconds, 3600)} hours ago"
      diff_seconds < 604800 -> "#{div(diff_seconds, 86400)} days ago"
      true -> Calendar.strftime(datetime, "%b %d, %Y")
    end
  end

  defp get_social_name(url) do
    cond do
      String.contains?(url, "linkedin") -> "LinkedIn"
      String.contains?(url, "twitter") or String.contains?(url, "x.com") -> "Twitter/X"
      String.contains?(url, "imdb") -> "IMDb"
      String.contains?(url, "stage32") -> "Stage32"
      String.contains?(url, "youtube") -> "YouTube"
      String.contains?(url, "instagram") -> "Instagram"
      true -> "Website"
    end
  end
end
