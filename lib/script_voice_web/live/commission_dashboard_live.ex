defmodule ScriptVoiceWeb.CommissionDashboardLive do
  @moduledoc """
  LiveView for the commission dashboard showing all commissions for a user.
  """
  use ScriptVoiceWeb, :live_view

  alias ScriptVoice.Commissions
  alias ScriptVoice.Notifications

  @impl true
  def mount(_params, session, socket) do
    current_user = get_current_user(session)

    case current_user do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Please sign in to view commissions")
         |> push_navigate(to: ~p"/verify?type=visitor")}

      user ->
        # Subscribe to notifications
        if connected?(socket) do
          Notifications.subscribe_to_notifications(user.id)
        end

        # Default view based on user type
        view_mode = if user.user_type == "voice_artist", do: "performer", else: "writer"

        {:ok,
         socket
         |> assign(:current_user, user)
         |> assign(:view_mode, view_mode)
         |> assign(:filter, "active")
         |> assign(:page_title, "My Commissions")
         |> load_commissions()}
    end
  end

  defp get_current_user(session) do
    case session["user_id"] do
      nil -> nil
      user_id -> ScriptVoice.Accounts.get_user(user_id)
    end
  end

  defp load_commissions(socket) do
    user = socket.assigns.current_user
    view_mode = socket.assigns.view_mode
    filter = socket.assigns.filter

    statuses = case filter do
      "active" -> ["pending", "accepted", "in_progress", "submitted", "revision_requested"]
      "pending" -> ["pending"]
      "completed" -> ["completed"]
      "cancelled" -> ["cancelled", "declined"]
      _ -> nil
    end

    commissions = case view_mode do
      "writer" ->
        Commissions.list_commission_requests_for_writer(user.id, status: statuses)
      "performer" ->
        Commissions.list_commission_requests_for_performer(user.id, status: statuses)
    end

    # Group by status for display
    {pending, active, needs_action} = group_commissions(commissions, view_mode)

    socket
    |> assign(:commissions, commissions)
    |> assign(:pending_commissions, pending)
    |> assign(:active_commissions, active)
    |> assign(:needs_action, needs_action)
  end

  defp group_commissions(commissions, view_mode) do
    pending = Enum.filter(commissions, &(&1.status == "pending"))

    active = Enum.filter(commissions, &(&1.status in ["accepted", "in_progress"]))

    needs_action = case view_mode do
      "writer" ->
        # Writers need to review submitted work
        Enum.filter(commissions, &(&1.status == "submitted"))
      "performer" ->
        # Performers need to handle revision requests
        Enum.filter(commissions, &(&1.status == "revision_requested"))
    end

    {pending, active, needs_action}
  end

  @impl true
  def handle_event("set_view_mode", %{"mode" => mode}, socket) do
    {:noreply,
     socket
     |> assign(:view_mode, mode)
     |> load_commissions()}
  end

  @impl true
  def handle_event("set_filter", %{"filter" => filter}, socket) do
    {:noreply,
     socket
     |> assign(:filter, filter)
     |> load_commissions()}
  end

  @impl true
  def handle_info({:new_notification, _notification}, socket) do
    # Reload commissions when a new notification arrives
    {:noreply, load_commissions(socket)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="py-6 sm:py-8 px-4 sm:px-6">
      <div class="max-w-4xl mx-auto">
        <!-- Header -->
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-6">
          <h1 class="text-2xl font-bold">My Commissions</h1>

          <!-- View Mode Toggle (for users with both roles) -->
          <%= if @current_user.user_type in ["writer", "voice_artist"] do %>
            <div class="flex bg-gray-100 rounded-lg p-1">
              <button
                phx-click="set_view_mode"
                phx-value-mode="writer"
                class={"px-4 py-2 text-sm font-medium rounded-md transition-colors " <>
                  if @view_mode == "writer", do: "bg-white shadow text-gray-900", else: "text-gray-600 hover:text-gray-900"}
              >
                As Writer
              </button>
              <button
                phx-click="set_view_mode"
                phx-value-mode="performer"
                class={"px-4 py-2 text-sm font-medium rounded-md transition-colors " <>
                  if @view_mode == "performer", do: "bg-white shadow text-gray-900", else: "text-gray-600 hover:text-gray-900"}
              >
                As Performer
              </button>
            </div>
          <% end %>
        </div>

        <!-- Filter Tabs -->
        <div class="flex gap-2 mb-6 overflow-x-auto pb-2">
          <%= for {label, value} <- [{"Active", "active"}, {"Pending", "pending"}, {"Completed", "completed"}, {"Cancelled", "cancelled"}] do %>
            <button
              phx-click="set_filter"
              phx-value-filter={value}
              class={"px-4 py-2 text-sm font-medium rounded-full whitespace-nowrap transition-colors " <>
                if @filter == value, do: "bg-emerald-100 text-emerald-700", else: "bg-gray-100 text-gray-600 hover:bg-gray-200"}
            >
              <%= label %>
            </button>
          <% end %>
        </div>

        <!-- Needs Action Section -->
        <%= if @needs_action != [] do %>
          <div class="mb-6">
            <h2 class="text-lg font-semibold mb-3 flex items-center gap-2">
              <span class="w-2 h-2 bg-orange-500 rounded-full animate-pulse"></span>
              Needs Your Action
            </h2>
            <div class="space-y-3">
              <%= for commission <- @needs_action do %>
                <.commission_card commission={commission} view_mode={@view_mode} urgent={true} />
              <% end %>
            </div>
          </div>
        <% end %>

        <!-- Pending Requests (for performers) -->
        <%= if @view_mode == "performer" and @pending_commissions != [] do %>
          <div class="mb-6">
            <h2 class="text-lg font-semibold mb-3">Pending Requests</h2>
            <div class="space-y-3">
              <%= for commission <- @pending_commissions do %>
                <.commission_card commission={commission} view_mode={@view_mode} urgent={false} />
              <% end %>
            </div>
          </div>
        <% end %>

        <!-- Active Commissions -->
        <%= if @active_commissions != [] do %>
          <div class="mb-6">
            <h2 class="text-lg font-semibold mb-3">Active</h2>
            <div class="space-y-3">
              <%= for commission <- @active_commissions do %>
                <.commission_card commission={commission} view_mode={@view_mode} urgent={false} />
              <% end %>
            </div>
          </div>
        <% end %>

        <!-- All Commissions (filtered) -->
        <%= if @commissions == [] do %>
          <div class="bg-white border rounded-xl p-8 text-center">
            <.icon name="hero-document-text" class="w-12 h-12 text-gray-300 mx-auto mb-4" />
            <p class="text-gray-500">No commissions found</p>
            <%= if @view_mode == "writer" do %>
              <.link navigate={~p"/browse"} class="text-emerald-600 hover:underline text-sm mt-2 inline-block">
                Browse screenplays to request commissions
              </.link>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp commission_card(assigns) do
    ~H"""
    <.link
      navigate={~p"/commissions/#{@commission.id}"}
      class={"block bg-white border rounded-xl p-4 hover:shadow-md transition-shadow " <>
        if @urgent, do: "border-orange-200 bg-orange-50", else: ""}
    >
      <div class="flex items-start justify-between gap-4">
        <div class="flex-1 min-w-0">
          <!-- Screenplay Title -->
          <h3 class="font-semibold truncate">
            <%= if @commission.screenplay, do: @commission.screenplay.title, else: "Unknown Screenplay" %>
          </h3>

          <!-- Other Party -->
          <p class="text-sm text-gray-500 mt-1">
            <%= if @view_mode == "writer" do %>
              Performer: <%= if @commission.performer, do: @commission.performer.name, else: "Unknown" %>
            <% else %>
              Writer: <%= if @commission.writer, do: @commission.writer.name, else: "Unknown" %>
            <% end %>
          </p>

          <!-- Status & Date -->
          <div class="flex items-center gap-3 mt-2">
            <.status_badge status={@commission.status} />
            <span class="text-xs text-gray-400">
              <%= format_date(@commission.inserted_at) %>
            </span>
          </div>
        </div>

        <!-- Amount -->
        <div class="text-right">
          <p class="font-semibold text-emerald-600">
            <%= format_amount(@commission.agreed_amount_cents || @commission.offered_amount_cents) %>
          </p>
          <%= if @commission.deadline do %>
            <p class="text-xs text-gray-500 mt-1">
              Due: <%= format_deadline(@commission.deadline) %>
            </p>
          <% end %>
        </div>
      </div>
    </.link>
    """
  end

  defp status_badge(assigns) do
    {bg_color, text_color, label} = status_styles(assigns.status)
    assigns = assign(assigns, :bg_color, bg_color)
    assigns = assign(assigns, :text_color, text_color)
    assigns = assign(assigns, :label, label)

    ~H"""
    <span class={"text-xs px-2 py-0.5 rounded-full #{@bg_color} #{@text_color}"}>
      <%= @label %>
    </span>
    """
  end

  defp status_styles("pending"), do: {"bg-yellow-100", "text-yellow-700", "Pending"}
  defp status_styles("accepted"), do: {"bg-blue-100", "text-blue-700", "Accepted"}
  defp status_styles("in_progress"), do: {"bg-blue-100", "text-blue-700", "In Progress"}
  defp status_styles("submitted"), do: {"bg-purple-100", "text-purple-700", "Submitted"}
  defp status_styles("revision_requested"), do: {"bg-orange-100", "text-orange-700", "Revision Requested"}
  defp status_styles("completed"), do: {"bg-emerald-100", "text-emerald-700", "Completed"}
  defp status_styles("cancelled"), do: {"bg-gray-100", "text-gray-700", "Cancelled"}
  defp status_styles("declined"), do: {"bg-red-100", "text-red-700", "Declined"}
  defp status_styles("disputed"), do: {"bg-red-100", "text-red-700", "Disputed"}
  defp status_styles(_), do: {"bg-gray-100", "text-gray-700", "Unknown"}

  defp format_amount(nil), do: "-"
  defp format_amount(cents), do: "$#{:erlang.float_to_binary(cents / 100, decimals: 2)}"

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end

  defp format_deadline(date) do
    Calendar.strftime(date, "%b %d")
  end
end
