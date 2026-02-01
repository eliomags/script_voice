defmodule ScriptVoiceWeb.StripeConnectLive do
  @moduledoc """
  LiveView for performers to connect their Stripe account for receiving payments.
  """
  use ScriptVoiceWeb, :live_view

  alias ScriptVoice.Commissions
  alias ScriptVoice.Stripe, as: StripeService

  @impl true
  def mount(_params, session, socket) do
    current_user = get_current_user(session)

    case current_user do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Please sign in to access this page")
         |> push_navigate(to: ~p"/verify?type=visitor")}

      user when user.user_type != "voice_artist" ->
        {:ok,
         socket
         |> put_flash(:error, "Only voice artists can connect Stripe accounts")
         |> push_navigate(to: ~p"/browse")}

      user ->
        stripe_account = Commissions.get_stripe_account(user.id)
        stats = Commissions.get_performer_stats(user.id)

        {:ok,
         socket
         |> assign(:current_user, user)
         |> assign(:stripe_account, stripe_account)
         |> assign(:stats, stats)
         |> assign(:loading, false)
         |> assign(:page_title, "Payment Settings")}
    end
  end

  defp get_current_user(session) do
    case session["user_id"] do
      nil -> nil
      user_id -> ScriptVoice.Accounts.get_user(user_id)
    end
  end

  @impl true
  def handle_event("connect_stripe", _params, socket) do
    socket = assign(socket, :loading, true)

    case StripeService.create_connect_account(socket.assigns.current_user) do
      {:ok, account} ->
        # Get onboarding URL
        return_url = url(~p"/settings/payments")
        refresh_url = url(~p"/settings/payments")

        case StripeService.create_account_link(account.id, return_url, refresh_url) do
          {:ok, onboarding_url} ->
            {:noreply,
             socket
             |> assign(:loading, false)
             |> redirect(external: onboarding_url)}

          {:error, _} ->
            {:noreply,
             socket
             |> assign(:loading, false)
             |> put_flash(:error, "Failed to create onboarding link")}
        end

      {:error, _} ->
        {:noreply,
         socket
         |> assign(:loading, false)
         |> put_flash(:error, "Failed to create Stripe account")}
    end
  end

  @impl true
  def handle_event("continue_onboarding", _params, socket) do
    stripe_account = socket.assigns.stripe_account
    socket = assign(socket, :loading, true)

    return_url = url(~p"/settings/payments")
    refresh_url = url(~p"/settings/payments")

    case StripeService.create_account_link(stripe_account.stripe_account_id, return_url, refresh_url) do
      {:ok, onboarding_url} ->
        {:noreply,
         socket
         |> assign(:loading, false)
         |> redirect(external: onboarding_url)}

      {:error, _} ->
        {:noreply,
         socket
         |> assign(:loading, false)
         |> put_flash(:error, "Failed to create onboarding link")}
    end
  end

  @impl true
  def handle_event("view_dashboard", _params, socket) do
    stripe_account = socket.assigns.stripe_account
    socket = assign(socket, :loading, true)

    case StripeService.create_login_link(stripe_account.stripe_account_id) do
      {:ok, dashboard_url} ->
        {:noreply,
         socket
         |> assign(:loading, false)
         |> redirect(external: dashboard_url)}

      {:error, _} ->
        {:noreply,
         socket
         |> assign(:loading, false)
         |> put_flash(:error, "Failed to access Stripe dashboard")}
    end
  end

  @impl true
  def handle_event("refresh_status", _params, socket) do
    stripe_account = socket.assigns.stripe_account

    case StripeService.get_account_status(stripe_account.stripe_account_id) do
      {:ok, status} ->
        # Update our local record
        {:ok, updated_account} = Commissions.update_stripe_account_status(
          socket.assigns.current_user.id,
          %{
            charges_enabled: status.charges_enabled,
            payouts_enabled: status.payouts_enabled,
            onboarding_complete: status.details_submitted
          }
        )

        {:noreply,
         socket
         |> assign(:stripe_account, updated_account)
         |> put_flash(:info, "Status updated")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to refresh status")}
    end
  end

  defp format_amount(nil), do: "$0.00"
  defp format_amount(cents), do: "$#{:erlang.float_to_binary(cents / 100, decimals: 2)}"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="py-6 sm:py-8 px-4 sm:px-6">
      <div class="max-w-2xl mx-auto">
        <!-- Header -->
        <div class="mb-6">
          <.link navigate={~p"/profile/#{@current_user.id}"} class="text-sm text-emerald-600 hover:underline mb-2 inline-block">
            &larr; Back to Profile
          </.link>
          <h1 class="text-2xl font-bold">Payment Settings</h1>
          <p class="text-gray-500 mt-1">Connect your Stripe account to receive commission payments</p>
        </div>

        <!-- Earnings Summary -->
        <div class="bg-white border rounded-xl p-4 sm:p-6 mb-6">
          <h2 class="font-semibold mb-4">Earnings Summary</h2>
          <div class="grid grid-cols-3 gap-4">
            <div>
              <p class="text-2xl font-bold text-emerald-600"><%= format_amount(@stats.total_earned_cents) %></p>
              <p class="text-sm text-gray-500">Total Earned</p>
            </div>
            <div>
              <p class="text-2xl font-bold"><%= @stats.completed_count %></p>
              <p class="text-sm text-gray-500">Completed</p>
            </div>
            <div>
              <p class="text-2xl font-bold"><%= @stats.active_count %></p>
              <p class="text-sm text-gray-500">Active</p>
            </div>
          </div>
        </div>

        <!-- Stripe Account Status -->
        <div class="bg-white border rounded-xl p-4 sm:p-6">
          <h2 class="font-semibold mb-4">Stripe Account</h2>

          <%= cond do %>
            <% is_nil(@stripe_account) -> %>
              <!-- No Stripe Account -->
              <div class="text-center py-8">
                <div class="w-16 h-16 bg-purple-100 rounded-full flex items-center justify-center mx-auto mb-4">
                  <.icon name="hero-credit-card" class="w-8 h-8 text-purple-600" />
                </div>
                <h3 class="font-semibold mb-2">Connect with Stripe</h3>
                <p class="text-gray-500 text-sm mb-6 max-w-sm mx-auto">
                  Connect your Stripe account to receive payments for commissions.
                  Stripe handles all payment processing securely.
                </p>
                <button
                  phx-click="connect_stripe"
                  disabled={@loading}
                  class="bg-purple-600 text-white px-6 py-2 rounded-lg font-medium hover:bg-purple-700 disabled:opacity-50"
                >
                  <%= if @loading, do: "Connecting...", else: "Connect Stripe Account" %>
                </button>
              </div>

            <% not @stripe_account.onboarding_complete -> %>
              <!-- Onboarding Incomplete -->
              <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4 mb-4">
                <div class="flex items-start gap-3">
                  <.icon name="hero-exclamation-triangle" class="w-5 h-5 text-yellow-600 flex-shrink-0 mt-0.5" />
                  <div>
                    <h3 class="font-medium text-yellow-800">Setup Incomplete</h3>
                    <p class="text-sm text-yellow-700 mt-1">
                      Please complete your Stripe account setup to start receiving payments.
                    </p>
                  </div>
                </div>
              </div>

              <button
                phx-click="continue_onboarding"
                disabled={@loading}
                class="w-full bg-purple-600 text-white px-6 py-2 rounded-lg font-medium hover:bg-purple-700 disabled:opacity-50"
              >
                <%= if @loading, do: "Loading...", else: "Continue Setup" %>
              </button>

            <% @stripe_account.charges_enabled and @stripe_account.payouts_enabled -> %>
              <!-- Fully Connected -->
              <div class="bg-emerald-50 border border-emerald-200 rounded-lg p-4 mb-4">
                <div class="flex items-start gap-3">
                  <.icon name="hero-check-circle" class="w-5 h-5 text-emerald-600 flex-shrink-0 mt-0.5" />
                  <div>
                    <h3 class="font-medium text-emerald-800">Account Connected</h3>
                    <p class="text-sm text-emerald-700 mt-1">
                      Your Stripe account is fully set up. You can receive commission payments.
                    </p>
                  </div>
                </div>
              </div>

              <div class="flex flex-col sm:flex-row gap-3">
                <button
                  phx-click="view_dashboard"
                  disabled={@loading}
                  class="flex-1 bg-white border border-gray-300 text-gray-700 px-4 py-2 rounded-lg font-medium hover:bg-gray-50 disabled:opacity-50"
                >
                  <%= if @loading, do: "Loading...", else: "View Stripe Dashboard" %>
                </button>
                <button
                  phx-click="refresh_status"
                  class="text-gray-500 px-4 py-2 hover:text-gray-700 text-sm"
                >
                  Refresh Status
                </button>
              </div>

            <% true -> %>
              <!-- Partial Setup -->
              <div class="bg-orange-50 border border-orange-200 rounded-lg p-4 mb-4">
                <div class="flex items-start gap-3">
                  <.icon name="hero-clock" class="w-5 h-5 text-orange-600 flex-shrink-0 mt-0.5" />
                  <div>
                    <h3 class="font-medium text-orange-800">Verification Pending</h3>
                    <p class="text-sm text-orange-700 mt-1">
                      Stripe is reviewing your account. This usually takes 1-2 business days.
                    </p>
                  </div>
                </div>
              </div>

              <div class="space-y-2 text-sm">
                <div class="flex items-center gap-2">
                  <%= if @stripe_account.charges_enabled do %>
                    <.icon name="hero-check-circle" class="w-4 h-4 text-emerald-600" />
                    <span>Can receive payments</span>
                  <% else %>
                    <.icon name="hero-clock" class="w-4 h-4 text-gray-400" />
                    <span class="text-gray-500">Payments pending verification</span>
                  <% end %>
                </div>
                <div class="flex items-center gap-2">
                  <%= if @stripe_account.payouts_enabled do %>
                    <.icon name="hero-check-circle" class="w-4 h-4 text-emerald-600" />
                    <span>Payouts enabled</span>
                  <% else %>
                    <.icon name="hero-clock" class="w-4 h-4 text-gray-400" />
                    <span class="text-gray-500">Payouts pending verification</span>
                  <% end %>
                </div>
              </div>

              <button
                phx-click="refresh_status"
                class="mt-4 text-emerald-600 text-sm hover:underline"
              >
                Refresh Status
              </button>
          <% end %>
        </div>

        <!-- Payment Info -->
        <div class="mt-6 bg-gray-50 rounded-xl p-4 text-sm text-gray-600">
          <h3 class="font-medium text-gray-900 mb-2">How Payments Work</h3>
          <ul class="space-y-2">
            <li class="flex items-start gap-2">
              <span class="text-emerald-600 font-bold">1.</span>
              <span>Writer pays when requesting a commission. Funds are held by Stripe.</span>
            </li>
            <li class="flex items-start gap-2">
              <span class="text-emerald-600 font-bold">2.</span>
              <span>You complete the commission and submit your audio.</span>
            </li>
            <li class="flex items-start gap-2">
              <span class="text-emerald-600 font-bold">3.</span>
              <span>Writer approves the submission.</span>
            </li>
            <li class="flex items-start gap-2">
              <span class="text-emerald-600 font-bold">4.</span>
              <span>Payment is released to your Stripe account (minus 10% platform fee).</span>
            </li>
          </ul>
        </div>
      </div>
    </div>
    """
  end
end
