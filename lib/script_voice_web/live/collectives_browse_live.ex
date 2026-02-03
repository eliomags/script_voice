defmodule ScriptVoiceWeb.CollectivesBrowseLive do
  @moduledoc """
  Browse collectives page - discover voice artist groups and ensembles.
  """
  use ScriptVoiceWeb, :live_view

  alias ScriptVoice.Collectives
  alias ScriptVoice.Audio

  @impl true
  def mount(_params, session, socket) do
    current_user = get_current_user(session)

    # Get user's membership info for showing status on cards
    user_collective_ids =
      if current_user do
        Collectives.list_collectives_for_user(current_user.id)
        |> Enum.map(& &1.id)
      else
        []
      end

    # Get user's pending join requests
    pending_request_collective_ids =
      if current_user do
        Collectives.list_pending_join_requests_for_user(current_user.id)
        |> Enum.map(& &1.collective_id)
      else
        []
      end

    # Get user's recent rejected requests (for showing status)
    rejected_requests_map =
      if current_user do
        Collectives.list_recent_rejected_requests_for_user(current_user.id)
      else
        %{}
      end

    {:ok,
     socket
     |> assign(:current_user, current_user)
     |> assign(:user_collective_ids, user_collective_ids)
     |> assign(:pending_request_collective_ids, pending_request_collective_ids)
     |> assign(:rejected_requests_map, rejected_requests_map)
     |> assign(:search_query, "")
     |> assign(:filter, "all")
     |> assign(:page_title, "Browse Collectives")
     |> load_collectives()}
  end

  defp load_collectives(socket) do
    collectives = Collectives.list_collectives()

    # Apply search filter
    collectives =
      if socket.assigns.search_query != "" do
        query = String.downcase(socket.assigns.search_query)
        Enum.filter(collectives, fn c ->
          String.contains?(String.downcase(c.name), query) ||
            (c.bio && String.contains?(String.downcase(c.bio), query))
        end)
      else
        collectives
      end

    # Apply status filter
    collectives =
      case socket.assigns.filter do
        "accepting" ->
          Enum.filter(collectives, & &1.is_accepting_commissions)
        "open" ->
          # Collectives not yet at capacity (for future feature)
          collectives
        _ ->
          collectives
      end

    # Enrich with audio count
    collectives =
      Enum.map(collectives, fn collective ->
        audio_versions = Audio.list_audio_versions_by_collective(collective.id)
        Map.put(collective, :audio_count, length(audio_versions))
      end)

    assign(socket, :collectives, collectives)
  end

  defp get_current_user(session) do
    case session["user_id"] do
      nil -> nil
      user_id -> ScriptVoice.Accounts.get_user(user_id)
    end
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    {:noreply,
     socket
     |> assign(:search_query, query)
     |> load_collectives()}
  end

  @impl true
  def handle_event("filter", %{"filter" => filter}, socket) do
    {:noreply,
     socket
     |> assign(:filter, filter)
     |> load_collectives()}
  end

  @impl true
  def handle_event("request_join", %{"id" => collective_id}, socket) do
    case socket.assigns.current_user do
      nil ->
        {:noreply, push_navigate(socket, to: ~p"/verify?type=visitor")}

      user ->
        collective = Collectives.get_collective(collective_id)

        case Collectives.create_join_request(collective, user, nil) do
          {:ok, _request} ->
            {:noreply,
             socket
             |> update(:pending_request_collective_ids, &[collective_id | &1])
             |> put_flash(:info, "Join request sent to #{collective.name}!")}

          {:error, :already_member} ->
            {:noreply, put_flash(socket, :info, "You're already a member of this collective.")}

          {:error, :request_exists} ->
            {:noreply, put_flash(socket, :info, "You already have a pending request.")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to send request. Please try again.")}
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="py-6 sm:py-8 px-4 sm:px-6">
      <div class="max-w-4xl mx-auto">
        <!-- Header -->
        <div class="mb-6">
          <h1 class="text-xl sm:text-2xl font-bold mb-2">Browse Collectives</h1>
          <p class="text-gray-600 text-sm">
            Discover voice artist groups, duos, and ensembles for collaborative performances.
          </p>
        </div>

        <!-- Search and Filters -->
        <div class="flex flex-col sm:flex-row gap-4 mb-6">
          <!-- Search -->
          <div class="flex-1">
            <form phx-change="search" phx-submit="search">
              <div class="relative">
                <.icon name="hero-magnifying-glass" class="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
                <input
                  type="text"
                  name="query"
                  value={@search_query}
                  placeholder="Search collectives..."
                  class="w-full pl-10 pr-4 py-2.5 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500"
                  phx-debounce="300"
                />
              </div>
            </form>
          </div>

          <!-- Filter Pills -->
          <div class="flex gap-2">
            <button
              phx-click="filter"
              phx-value-filter="all"
              class={[
                "px-4 py-2 rounded-full text-sm font-medium transition",
                @filter == "all" && "bg-emerald-600 text-white",
                @filter != "all" && "bg-gray-100 text-gray-700 hover:bg-gray-200"
              ]}
            >
              All
            </button>
            <button
              phx-click="filter"
              phx-value-filter="accepting"
              class={[
                "px-4 py-2 rounded-full text-sm font-medium transition",
                @filter == "accepting" && "bg-emerald-600 text-white",
                @filter != "accepting" && "bg-gray-100 text-gray-700 hover:bg-gray-200"
              ]}
            >
              Accepting Work
            </button>
          </div>
        </div>

        <!-- Collectives Grid -->
        <%= if Enum.empty?(@collectives) do %>
          <div class="bg-white border rounded-xl p-8 text-center">
            <.icon name="hero-user-group" class="w-12 h-12 text-gray-300 mx-auto mb-4" />
            <h3 class="font-semibold text-lg mb-2">No collectives found</h3>
            <p class="text-gray-600 mb-4">
              <%= if @search_query != "" do %>
                Try a different search term.
              <% else %>
                Be the first to create a collective!
              <% end %>
            </p>
            <%= if @search_query != "" do %>
              <button
                phx-click="search"
                phx-value-query=""
                class="text-emerald-600 font-medium hover:underline"
              >
                Clear search
              </button>
            <% end %>
          </div>
        <% else %>
          <div class="grid gap-4 sm:grid-cols-2">
            <%= for collective <- @collectives do %>
              <.collective_card
                collective={collective}
                is_member={collective.id in @user_collective_ids}
                has_pending_request={collective.id in @pending_request_collective_ids}
                rejected_request={Map.get(@rejected_requests_map, collective.id)}
                current_user={@current_user}
              />
            <% end %>
          </div>
        <% end %>

        <!-- Create Collective CTA (for voice artists) -->
        <%= if @current_user && @current_user.user_type == "voice_artist" do %>
          <div class="mt-8 bg-gradient-to-r from-purple-50 to-emerald-50 border border-purple-100 rounded-xl p-6 text-center">
            <.icon name="hero-sparkles" class="w-8 h-8 text-purple-500 mx-auto mb-3" />
            <h3 class="font-semibold text-lg mb-2">Start Your Own Collective</h3>
            <p class="text-gray-600 text-sm mb-4">
              Team up with other voice artists to offer ensemble performances.
            </p>
            <.link
              navigate={~p"/dashboard?tab=collectives"}
              class="inline-flex items-center gap-2 px-4 py-2 bg-purple-600 text-white rounded-lg font-medium hover:bg-purple-700 transition"
            >
              <.icon name="hero-plus" class="w-4 h-4" />
              Create Collective
            </.link>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp collective_card(assigns) do
    ~H"""
    <div class="bg-white border rounded-xl p-4 hover:shadow-md transition">
      <.link navigate={~p"/collective/#{@collective.slug}"} class="block">
        <div class="flex items-start gap-3 mb-3">
          <!-- Avatar -->
          <div class="w-12 h-12 bg-purple-100 rounded-full flex items-center justify-center flex-shrink-0">
            <%= if @collective.avatar_url do %>
              <img src={@collective.avatar_url} alt={@collective.name} class="w-full h-full rounded-full object-cover" />
            <% else %>
              <.icon name="hero-user-group" class="w-6 h-6 text-purple-600" />
            <% end %>
          </div>

          <!-- Info -->
          <div class="flex-1 min-w-0">
            <div class="flex items-center gap-2 mb-0.5">
              <h3 class="font-semibold truncate"><%= @collective.name %></h3>
              <%= if @is_member do %>
                <span class="text-xs bg-emerald-100 text-emerald-700 px-2 py-0.5 rounded-full">Member</span>
              <% end %>
            </div>
            <div class="flex items-center gap-3 text-xs text-gray-500">
              <span><%= length(@collective.memberships) %> members</span>
              <span><%= @collective.audio_count %> recordings</span>
            </div>
          </div>
        </div>

        <!-- Bio -->
        <%= if @collective.bio do %>
          <p class="text-sm text-gray-600 line-clamp-2 mb-3"><%= @collective.bio %></p>
        <% end %>

        <!-- Status badges -->
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-2">
            <%= if @collective.is_accepting_commissions do %>
              <span class="text-xs text-emerald-600 flex items-center gap-1">
                <.icon name="hero-check-circle" class="w-3.5 h-3.5" />
                Accepting work
              </span>
            <% end %>
          </div>
        </div>
      </.link>

      <!-- Action button -->
      <%= if @current_user && @current_user.user_type == "voice_artist" && !@is_member do %>
        <div class="mt-3 pt-3 border-t">
          <%= if @has_pending_request do %>
            <span class="text-xs text-amber-600 flex items-center gap-1">
              <.icon name="hero-clock" class="w-4 h-4" />
              Request pending
            </span>
          <% else %>
            <%= if @rejected_request do %>
              <!-- Show rejected status with link to collective page -->
              <div class="flex items-center justify-between">
                <span class="text-xs text-red-600 flex items-center gap-1">
                  <.icon name="hero-x-circle" class="w-4 h-4" />
                  Request declined
                </span>
                <.link
                  navigate={~p"/collective/#{@collective.slug}"}
                  class="text-xs text-gray-500 hover:text-emerald-600"
                >
                  View details →
                </.link>
              </div>
            <% else %>
              <button
                phx-click="request_join"
                phx-value-id={@collective.id}
                class="w-full text-sm text-emerald-600 hover:text-emerald-700 font-medium flex items-center justify-center gap-1 py-1"
              >
                <.icon name="hero-user-plus" class="w-4 h-4" />
                Request to Join
              </button>
            <% end %>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
end
