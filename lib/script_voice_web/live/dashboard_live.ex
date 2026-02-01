defmodule ScriptVoiceWeb.DashboardLive do
  @moduledoc """
  User dashboard - the central hub for users to manage their ScriptVoice activity.
  Shows different views based on user type (writer, voice_artist, visitor).
  """
  use ScriptVoiceWeb, :live_view

  alias ScriptVoice.{Accounts, Commissions, Notifications, Screenplays, Audio}

  @impl true
  def mount(_params, session, socket) do
    current_user = get_current_user(session)

    if current_user do
      # Subscribe to real-time notifications
      if connected?(socket) do
        Notifications.subscribe_to_notifications(current_user.id)
      end

      socket =
        socket
        |> assign(:current_user, current_user)
        |> assign(:page_title, "Dashboard")
        |> load_dashboard_data()

      {:ok, socket}
    else
      {:ok, push_navigate(socket, to: ~p"/demo-login")}
    end
  end

  defp load_dashboard_data(socket) do
    user = socket.assigns.current_user

    socket
    |> load_notifications(user)
    |> load_role_specific_data(user)
  end

  defp load_notifications(socket, user) do
    notifications = Notifications.list_notifications(user.id, limit: 5)
    unread_count = Notifications.get_unread_count(user.id)

    socket
    |> assign(:notifications, notifications)
    |> assign(:unread_count, unread_count)
  end

  defp load_role_specific_data(socket, %{user_type: "writer"} = user) do
    stats = Commissions.get_writer_stats(user.id)
    screenplays = Screenplays.list_screenplays(writer_id: user.id, limit: 5)

    # Get pending and active commissions
    pending_commissions = Commissions.list_commission_requests_for_writer(user.id, status: "pending")
    active_commissions = Commissions.list_commission_requests_for_writer(
      user.id,
      status: ["accepted", "in_progress", "submitted", "revision_requested"]
    )

    socket
    |> assign(:stats, stats)
    |> assign(:screenplays, screenplays)
    |> assign(:pending_commissions, pending_commissions)
    |> assign(:active_commissions, active_commissions)
  end

  defp load_role_specific_data(socket, %{user_type: "voice_artist"} = user) do
    stats = Commissions.get_performer_stats(user.id)
    audio_versions = Audio.list_audio_versions_by_user(user.id) |> Enum.take(5)

    # Check if pricing and Stripe are set up
    pricing = Commissions.get_performer_pricing(user.id)
    stripe_account = Commissions.get_stripe_account(user.id)
    stripe_ready = Commissions.performer_ready_for_payments?(user.id)

    # Get pending requests and active commissions
    pending_requests = Commissions.list_commission_requests_for_performer(user.id, status: "pending")
    active_commissions = Commissions.list_commission_requests_for_performer(
      user.id,
      status: ["accepted", "in_progress", "submitted", "revision_requested"]
    )

    socket
    |> assign(:stats, stats)
    |> assign(:audio_versions, audio_versions)
    |> assign(:pricing_set, pricing != nil)
    |> assign(:stripe_account, stripe_account)
    |> assign(:stripe_ready, stripe_ready)
    |> assign(:pending_requests, pending_requests)
    |> assign(:active_commissions, active_commissions)
  end

  defp load_role_specific_data(socket, _user) do
    # Visitor - minimal data
    socket
    |> assign(:stats, nil)
  end

  @impl true
  def handle_info({:new_notification, notification}, socket) do
    notifications = [notification | socket.assigns.notifications] |> Enum.take(5)
    unread_count = socket.assigns.unread_count + 1

    {:noreply,
     socket
     |> assign(:notifications, notifications)
     |> assign(:unread_count, unread_count)
     |> put_flash(:info, notification.title)}
  end

  @impl true
  def handle_event("mark_all_read", _params, socket) do
    Notifications.mark_all_read(socket.assigns.current_user.id)

    notifications =
      Enum.map(socket.assigns.notifications, fn n ->
        %{n | read_at: DateTime.utc_now()}
      end)

    {:noreply,
     socket
     |> assign(:notifications, notifications)
     |> assign(:unread_count, 0)}
  end

  defp get_current_user(session) do
    case session["user_id"] do
      nil -> nil
      user_id -> Accounts.get_user(user_id)
    end
  end

  defp format_money(cents) when is_integer(cents) do
    dollars = cents / 100
    "$#{:erlang.float_to_binary(dollars, decimals: 2)}"
  end
  defp format_money(_), do: "$0.00"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <div class="max-w-4xl mx-auto px-4 py-6 sm:py-8">
        <!-- Header -->
        <div class="mb-6 sm:mb-8">
          <h1 class="text-2xl sm:text-3xl font-bold text-gray-900">
            Welcome back, <%= @current_user.name %>
          </h1>
          <p class="text-gray-600 mt-1">
            <%= case @current_user.user_type do
              "writer" -> "Writer Dashboard"
              "voice_artist" -> "Voice Artist Dashboard"
              _ -> "Your ScriptVoice Activity"
            end %>
          </p>
        </div>

        <%= case @current_user.user_type do %>
          <% "writer" -> %>
            <.writer_dashboard
              current_user={@current_user}
              stats={@stats}
              screenplays={@screenplays}
              pending_commissions={@pending_commissions}
              active_commissions={@active_commissions}
              notifications={@notifications}
              unread_count={@unread_count}
            />
          <% "voice_artist" -> %>
            <.performer_dashboard
              current_user={@current_user}
              stats={@stats}
              audio_versions={@audio_versions}
              pricing_set={@pricing_set}
              stripe_ready={@stripe_ready}
              pending_requests={@pending_requests}
              active_commissions={@active_commissions}
              notifications={@notifications}
              unread_count={@unread_count}
            />
          <% _ -> %>
            <.visitor_dashboard />
        <% end %>
      </div>
    </div>
    """
  end

  # ===========================================================================
  # Writer Dashboard
  # ===========================================================================

  defp writer_dashboard(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Stats Cards -->
      <div class="grid grid-cols-2 sm:grid-cols-4 gap-4">
        <.stat_card
          icon="hero-document-text"
          icon_bg="bg-purple-100"
          icon_color="text-purple-600"
          label="My Screenplays"
          value={length(@screenplays)}
        />
        <.stat_card
          icon="hero-check-circle"
          icon_bg="bg-green-100"
          icon_color="text-green-600"
          label="Completed"
          value={@stats.completed_count}
        />
        <.stat_card
          icon="hero-clock"
          icon_bg="bg-amber-100"
          icon_color="text-amber-600"
          label="Pending"
          value={@stats.pending_count}
        />
        <.stat_card
          icon="hero-banknotes"
          icon_bg="bg-blue-100"
          icon_color="text-blue-600"
          label="Total Spent"
          value={format_money(@stats.total_spent_cents)}
        />
      </div>

      <!-- Quick Actions -->
      <div class="bg-white rounded-xl border p-4 sm:p-6">
        <h2 class="font-semibold text-gray-900 mb-4">Quick Actions</h2>
        <div class="flex flex-wrap gap-3">
          <.link
            navigate={~p"/browse"}
            class="inline-flex items-center gap-2 px-4 py-2 bg-emerald-600 text-white rounded-lg font-medium hover:bg-emerald-700 transition"
          >
            <.icon name="hero-magnifying-glass" class="w-4 h-4" />
            Find Voice Artists
          </.link>
          <.link
            navigate={~p"/commissions"}
            class="inline-flex items-center gap-2 px-4 py-2 bg-white border border-gray-300 text-gray-700 rounded-lg font-medium hover:bg-gray-50 transition"
          >
            <.icon name="hero-clipboard-document-list" class="w-4 h-4" />
            View All Commissions
          </.link>
        </div>
      </div>

      <div class="grid sm:grid-cols-2 gap-6">
        <!-- Active Commissions -->
        <div class="bg-white rounded-xl border p-4 sm:p-6">
          <div class="flex items-center justify-between mb-4">
            <h2 class="font-semibold text-gray-900">Active Commissions</h2>
            <span class="text-sm text-gray-500"><%= length(@active_commissions) %> active</span>
          </div>
          <%= if Enum.empty?(@active_commissions) do %>
            <p class="text-gray-500 text-sm">No active commissions</p>
          <% else %>
            <div class="space-y-3">
              <%= for commission <- Enum.take(@active_commissions, 3) do %>
                <.commission_item commission={commission} role="writer" />
              <% end %>
            </div>
          <% end %>
        </div>

        <!-- Notifications -->
        <.notifications_panel notifications={@notifications} unread_count={@unread_count} />
      </div>

      <!-- My Screenplays -->
      <div class="bg-white rounded-xl border p-4 sm:p-6">
        <div class="flex items-center justify-between mb-4">
          <h2 class="font-semibold text-gray-900">My Screenplays</h2>
          <.link navigate={~p"/profile/#{@current_user.id}"} class="text-sm text-emerald-600 hover:underline">
            View all →
          </.link>
        </div>
        <%= if Enum.empty?(@screenplays) do %>
          <p class="text-gray-500 text-sm">You haven't uploaded any screenplays yet.</p>
        <% else %>
          <div class="space-y-3">
            <%= for screenplay <- @screenplays do %>
              <.link
                navigate={~p"/screenplay/#{screenplay.id}"}
                class="flex items-center justify-between p-3 bg-gray-50 rounded-lg hover:bg-gray-100 transition"
              >
                <div>
                  <div class="font-medium text-gray-900"><%= screenplay.title %></div>
                  <div class="text-sm text-gray-500"><%= screenplay.genre %> · <%= screenplay.page_count %> pages</div>
                </div>
                <div class="flex items-center gap-2 text-gray-400">
                  <.icon name="hero-heart" class="w-4 h-4" />
                  <span class="text-sm"><%= screenplay.likes %></span>
                </div>
              </.link>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # ===========================================================================
  # Voice Artist/Performer Dashboard
  # ===========================================================================

  defp performer_dashboard(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Setup Alerts -->
      <%= if !@pricing_set || !@stripe_ready do %>
        <div class="bg-amber-50 border border-amber-200 rounded-xl p-4">
          <div class="flex items-start gap-3">
            <.icon name="hero-exclamation-triangle" class="w-5 h-5 text-amber-600 mt-0.5" />
            <div>
              <h3 class="font-semibold text-amber-900">Complete Your Setup</h3>
              <p class="text-sm text-amber-700 mt-1">Before you can receive commissions, you need to:</p>
              <ul class="text-sm text-amber-700 mt-2 space-y-1">
                <%= if !@pricing_set do %>
                  <li class="flex items-center gap-2">
                    <.icon name="hero-x-circle" class="w-4 h-4 text-amber-600" />
                    <.link navigate={~p"/settings/pricing"} class="underline hover:text-amber-900">
                      Set up your pricing
                    </.link>
                  </li>
                <% end %>
                <%= if !@stripe_ready do %>
                  <li class="flex items-center gap-2">
                    <.icon name="hero-x-circle" class="w-4 h-4 text-amber-600" />
                    <.link navigate={~p"/settings/payments"} class="underline hover:text-amber-900">
                      Connect your Stripe account
                    </.link>
                  </li>
                <% end %>
              </ul>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Stats Cards -->
      <div class="grid grid-cols-2 sm:grid-cols-4 gap-4">
        <.stat_card
          icon="hero-check-circle"
          icon_bg="bg-green-100"
          icon_color="text-green-600"
          label="Completed"
          value={@stats.completed_count}
        />
        <.stat_card
          icon="hero-play"
          icon_bg="bg-blue-100"
          icon_color="text-blue-600"
          label="Active"
          value={@stats.active_count}
        />
        <.stat_card
          icon="hero-inbox"
          icon_bg="bg-purple-100"
          icon_color="text-purple-600"
          label="Pending"
          value={length(@pending_requests)}
        />
        <.stat_card
          icon="hero-banknotes"
          icon_bg="bg-emerald-100"
          icon_color="text-emerald-600"
          label="Earned"
          value={format_money(@stats.total_earned_cents)}
        />
      </div>

      <!-- Pending Requests Alert -->
      <%= if length(@pending_requests) > 0 do %>
        <div class="bg-purple-50 border border-purple-200 rounded-xl p-4">
          <div class="flex items-center justify-between">
            <div class="flex items-center gap-3">
              <div class="w-10 h-10 bg-purple-100 rounded-full flex items-center justify-center">
                <.icon name="hero-inbox" class="w-5 h-5 text-purple-600" />
              </div>
              <div>
                <h3 class="font-semibold text-purple-900">
                  <%= length(@pending_requests) %> Pending Request<%= if length(@pending_requests) != 1, do: "s" %>
                </h3>
                <p class="text-sm text-purple-700">Review and respond to commission requests</p>
              </div>
            </div>
            <.link
              navigate={~p"/commissions"}
              class="px-4 py-2 bg-purple-600 text-white rounded-lg font-medium hover:bg-purple-700 transition"
            >
              Review
            </.link>
          </div>
        </div>
      <% end %>

      <!-- Quick Actions -->
      <div class="bg-white rounded-xl border p-4 sm:p-6">
        <h2 class="font-semibold text-gray-900 mb-4">Quick Actions</h2>
        <div class="flex flex-wrap gap-3">
          <.link
            navigate={~p"/settings/pricing"}
            class="inline-flex items-center gap-2 px-4 py-2 bg-emerald-600 text-white rounded-lg font-medium hover:bg-emerald-700 transition"
          >
            <.icon name="hero-currency-dollar" class="w-4 h-4" />
            Pricing Settings
          </.link>
          <.link
            navigate={~p"/settings/payments"}
            class="inline-flex items-center gap-2 px-4 py-2 bg-white border border-gray-300 text-gray-700 rounded-lg font-medium hover:bg-gray-50 transition"
          >
            <.icon name="hero-credit-card" class="w-4 h-4" />
            Payment Settings
          </.link>
          <.link
            navigate={~p"/profile/#{@current_user.id}"}
            class="inline-flex items-center gap-2 px-4 py-2 bg-white border border-gray-300 text-gray-700 rounded-lg font-medium hover:bg-gray-50 transition"
          >
            <.icon name="hero-user" class="w-4 h-4" />
            View Profile
          </.link>
        </div>
      </div>

      <div class="grid sm:grid-cols-2 gap-6">
        <!-- Active Commissions -->
        <div class="bg-white rounded-xl border p-4 sm:p-6">
          <div class="flex items-center justify-between mb-4">
            <h2 class="font-semibold text-gray-900">Active Projects</h2>
            <.link navigate={~p"/commissions"} class="text-sm text-emerald-600 hover:underline">
              View all →
            </.link>
          </div>
          <%= if Enum.empty?(@active_commissions) do %>
            <p class="text-gray-500 text-sm">No active projects</p>
          <% else %>
            <div class="space-y-3">
              <%= for commission <- Enum.take(@active_commissions, 3) do %>
                <.commission_item commission={commission} role="performer" />
              <% end %>
            </div>
          <% end %>
        </div>

        <!-- Notifications -->
        <.notifications_panel notifications={@notifications} unread_count={@unread_count} />
      </div>

      <!-- Recent Performances -->
      <div class="bg-white rounded-xl border p-4 sm:p-6">
        <div class="flex items-center justify-between mb-4">
          <h2 class="font-semibold text-gray-900">Recent Performances</h2>
          <.link navigate={~p"/profile/#{@current_user.id}"} class="text-sm text-emerald-600 hover:underline">
            View all →
          </.link>
        </div>
        <%= if Enum.empty?(@audio_versions) do %>
          <p class="text-gray-500 text-sm">You haven't recorded any performances yet.</p>
        <% else %>
          <div class="space-y-3">
            <%= for audio <- @audio_versions do %>
              <.link
                navigate={~p"/screenplay/#{audio.screenplay_id}"}
                class="flex items-center justify-between p-3 bg-gray-50 rounded-lg hover:bg-gray-100 transition"
              >
                <div>
                  <div class="font-medium text-gray-900"><%= audio.screenplay.title %></div>
                  <div class="text-sm text-gray-500">
                    <%= if audio.duration do %>
                      <%= audio.duration %>
                    <% else %>
                      Duration unknown
                    <% end %>
                  </div>
                </div>
                <div class="flex items-center gap-2 text-gray-400">
                  <.icon name="hero-heart" class="w-4 h-4" />
                  <span class="text-sm"><%= audio.likes %></span>
                </div>
              </.link>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # ===========================================================================
  # Visitor Dashboard
  # ===========================================================================

  defp visitor_dashboard(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="bg-white rounded-xl border p-6 text-center">
        <.icon name="hero-user-circle" class="w-16 h-16 text-gray-300 mx-auto mb-4" />
        <h2 class="text-xl font-semibold text-gray-900 mb-2">You're browsing as a visitor</h2>
        <p class="text-gray-600 mb-6 max-w-md mx-auto">
          To upload screenplays, commission voice artists, or offer your voice talents, choose a role below.
        </p>
        <div class="flex flex-col sm:flex-row gap-3 justify-center">
          <.link
            navigate={~p"/verify?type=writer"}
            class="inline-flex items-center justify-center gap-2 px-6 py-3 bg-purple-600 text-white rounded-lg font-medium hover:bg-purple-700 transition"
          >
            <.icon name="hero-document-text" class="w-5 h-5" />
            Become a Writer
          </.link>
          <.link
            navigate={~p"/verify?type=voice_artist"}
            class="inline-flex items-center justify-center gap-2 px-6 py-3 bg-pink-600 text-white rounded-lg font-medium hover:bg-pink-700 transition"
          >
            <.icon name="hero-microphone" class="w-5 h-5" />
            Become a Voice Artist
          </.link>
        </div>
      </div>

      <div class="bg-white rounded-xl border p-6">
        <h2 class="font-semibold text-gray-900 mb-4">Explore ScriptVoice</h2>
        <div class="flex flex-wrap gap-3">
          <.link
            navigate={~p"/browse"}
            class="inline-flex items-center gap-2 px-4 py-2 bg-emerald-600 text-white rounded-lg font-medium hover:bg-emerald-700 transition"
          >
            <.icon name="hero-book-open" class="w-4 h-4" />
            Browse Screenplays
          </.link>
        </div>
      </div>
    </div>
    """
  end

  # ===========================================================================
  # Shared Components
  # ===========================================================================

  defp stat_card(assigns) do
    ~H"""
    <div class="bg-white rounded-xl border p-4">
      <div class={["w-8 h-8 rounded-lg flex items-center justify-center mb-2", @icon_bg]}>
        <.icon name={@icon} class={["w-4 h-4", @icon_color]} />
      </div>
      <div class="text-2xl font-bold text-gray-900"><%= @value %></div>
      <div class="text-sm text-gray-500"><%= @label %></div>
    </div>
    """
  end

  defp commission_item(assigns) do
    ~H"""
    <.link
      navigate={~p"/commissions/#{@commission.id}"}
      class="flex items-center justify-between p-3 bg-gray-50 rounded-lg hover:bg-gray-100 transition"
    >
      <div class="min-w-0 flex-1">
        <div class="font-medium text-gray-900 truncate"><%= @commission.screenplay.title %></div>
        <div class="text-sm text-gray-500">
          <%= if @role == "writer" do %>
            with <%= @commission.performer.name %>
          <% else %>
            for <%= @commission.writer.name %>
          <% end %>
        </div>
      </div>
      <.status_badge status={@commission.status} />
    </.link>
    """
  end

  defp status_badge(assigns) do
    colors = %{
      "pending" => "bg-amber-100 text-amber-800",
      "accepted" => "bg-blue-100 text-blue-800",
      "in_progress" => "bg-purple-100 text-purple-800",
      "submitted" => "bg-indigo-100 text-indigo-800",
      "revision_requested" => "bg-orange-100 text-orange-800",
      "completed" => "bg-green-100 text-green-800",
      "cancelled" => "bg-gray-100 text-gray-800",
      "declined" => "bg-red-100 text-red-800"
    }

    labels = %{
      "pending" => "Pending",
      "accepted" => "Accepted",
      "in_progress" => "In Progress",
      "submitted" => "Submitted",
      "revision_requested" => "Revision",
      "completed" => "Completed",
      "cancelled" => "Cancelled",
      "declined" => "Declined"
    }

    assigns = assign(assigns, :color, Map.get(colors, assigns.status, "bg-gray-100 text-gray-800"))
    assigns = assign(assigns, :label, Map.get(labels, assigns.status, assigns.status))

    ~H"""
    <span class={["px-2 py-1 text-xs font-medium rounded-full", @color]}>
      <%= @label %>
    </span>
    """
  end

  defp notifications_panel(assigns) do
    ~H"""
    <div class="bg-white rounded-xl border p-4 sm:p-6">
      <div class="flex items-center justify-between mb-4">
        <h2 class="font-semibold text-gray-900 flex items-center gap-2">
          Notifications
          <%= if @unread_count > 0 do %>
            <span class="px-2 py-0.5 text-xs font-medium bg-red-100 text-red-800 rounded-full">
              <%= @unread_count %> new
            </span>
          <% end %>
        </h2>
        <%= if @unread_count > 0 do %>
          <button
            phx-click="mark_all_read"
            class="text-sm text-emerald-600 hover:underline"
          >
            Mark all read
          </button>
        <% end %>
      </div>
      <%= if Enum.empty?(@notifications) do %>
        <p class="text-gray-500 text-sm">No notifications yet</p>
      <% else %>
        <div class="space-y-3">
          <%= for notification <- @notifications do %>
            <.notification_item notification={notification} />
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp notification_item(assigns) do
    is_unread = is_nil(assigns.notification.read_at)
    assigns = assign(assigns, :is_unread, is_unread)

    ~H"""
    <div class={[
      "p-3 rounded-lg transition",
      @is_unread && "bg-emerald-50 border border-emerald-100",
      !@is_unread && "bg-gray-50"
    ]}>
      <%= if @notification.action_url do %>
        <.link navigate={@notification.action_url} class="block">
          <div class="font-medium text-gray-900 text-sm"><%= @notification.title %></div>
          <%= if @notification.body do %>
            <div class="text-sm text-gray-600 mt-0.5"><%= @notification.body %></div>
          <% end %>
          <div class="text-xs text-gray-400 mt-1">
            <%= format_time_ago(@notification.inserted_at) %>
          </div>
        </.link>
      <% else %>
        <div class="font-medium text-gray-900 text-sm"><%= @notification.title %></div>
        <%= if @notification.body do %>
          <div class="text-sm text-gray-600 mt-0.5"><%= @notification.body %></div>
        <% end %>
        <div class="text-xs text-gray-400 mt-1">
          <%= format_time_ago(@notification.inserted_at) %>
        </div>
      <% end %>
    </div>
    """
  end

  defp format_time_ago(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> "Just now"
      diff < 3600 -> "#{div(diff, 60)} min ago"
      diff < 86400 -> "#{div(diff, 3600)} hours ago"
      diff < 604_800 -> "#{div(diff, 86400)} days ago"
      true -> Calendar.strftime(datetime, "%b %d, %Y")
    end
  end
end
