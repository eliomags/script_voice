defmodule ScriptVoiceWeb.PaymentSuccessLive do
  @moduledoc """
  Handles successful Stripe Checkout payments.
  Creates the commission and payment records after payment confirmation.
  """
  use ScriptVoiceWeb, :live_view

  alias ScriptVoice.Commissions
  alias ScriptVoice.Notifications
  alias ScriptVoice.Stripe, as: StripeService

  require Logger

  @impl true
  def mount(%{"session_id" => session_id}, session, socket) do
    current_user = get_current_user(session)

    case current_user do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Please sign in")
         |> push_navigate(to: ~p"/verify?type=visitor")}

      user ->
        socket =
          socket
          |> assign(:current_user, user)
          |> assign(:status, :processing)
          |> assign(:error, nil)
          |> assign(:commission, nil)
          |> assign(:page_title, "Processing Payment...")

        # Process the checkout session
        if connected?(socket) do
          send(self(), {:process_checkout, session_id})
        end

        {:ok, socket}
    end
  end

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> put_flash(:error, "Invalid payment session")
     |> push_navigate(to: ~p"/dashboard")}
  end

  defp get_current_user(session) do
    case session["user_id"] do
      nil -> nil
      user_id -> ScriptVoice.Accounts.get_user(user_id)
    end
  end

  @impl true
  def handle_info({:process_checkout, session_id}, socket) do
    case process_checkout_session(session_id, socket.assigns.current_user) do
      {:ok, commission} ->
        {:noreply,
         socket
         |> assign(:status, :success)
         |> assign(:commission, commission)}

      {:error, reason} ->
        Logger.error("Payment processing error: #{inspect(reason)}")
        {:noreply,
         socket
         |> assign(:status, :error)
         |> assign(:error, format_error(reason))}
    end
  end

  defp process_checkout_session(session_id, current_user) do
    with {:ok, checkout_session} <- StripeService.get_checkout_session(session_id),
         :ok <- verify_payment_status(checkout_session),
         {:ok, commission_data} <- extract_commission_data(checkout_session),
         :ok <- verify_user(commission_data, current_user),
         {:ok, commission} <- create_commission_and_payment(commission_data, checkout_session) do
      # Notify performer
      Notifications.notify_commission_request_received(
        commission_data["performer_id"],
        commission_data["writer_name"],
        commission_data["screenplay_title"],
        commission.id
      )

      {:ok, commission}
    end
  end

  defp verify_payment_status(%{payment_status: "paid"}), do: :ok
  defp verify_payment_status(%{payment_status: status}), do: {:error, {:payment_not_complete, status}}
  defp verify_payment_status(_), do: {:error, :invalid_session}

  defp extract_commission_data(%{metadata: %{"commission_data" => json}}) do
    case Jason.decode(json) do
      {:ok, data} -> {:ok, data}
      {:error, _} -> {:error, :invalid_metadata}
    end
  end
  defp extract_commission_data(_), do: {:error, :no_metadata}

  defp verify_user(commission_data, current_user) do
    if commission_data["writer_id"] == current_user.id do
      :ok
    else
      {:error, :unauthorized}
    end
  end

  defp create_commission_and_payment(commission_data, checkout_session) do
    # Parse deadline if present
    deadline = case commission_data["deadline"] do
      nil -> nil
      "" -> nil
      date_str -> Date.from_iso8601!(date_str)
    end

    # Create commission
    commission_attrs = %{
      screenplay_id: commission_data["screenplay_id"],
      writer_id: commission_data["writer_id"],
      performer_id: commission_data["performer_id"],
      calculated_amount_cents: commission_data["calculated_amount_cents"],
      offered_amount_cents: commission_data["amount_cents"],
      writer_message: commission_data["writer_message"],
      deadline: deadline,
      is_rush: commission_data["is_rush"] || false,
      retakes_included: commission_data["retakes_included"] || 2
    }

    case Commissions.create_commission_request(commission_attrs) do
      {:ok, commission} ->
        # Create payment record
        {:ok, _payment} = Commissions.create_payment_with_stripe(
          commission.id,
          commission_data["amount_cents"],
          checkout_session.payment_intent
        )

        {:ok, Commissions.get_commission_request(commission.id)}

      {:error, changeset} ->
        {:error, {:commission_creation_failed, changeset}}
    end
  end

  defp format_error({:payment_not_complete, status}), do: "Payment status: #{status}. Please try again."
  defp format_error(:invalid_session), do: "Invalid payment session."
  defp format_error(:invalid_metadata), do: "Could not process commission data."
  defp format_error(:unauthorized), do: "You are not authorized to complete this payment."
  defp format_error({:commission_creation_failed, _}), do: "Failed to create commission. Please contact support."
  defp format_error(_), do: "An unexpected error occurred. Please contact support."

  @impl true
  def render(assigns) do
    ~H"""
    <div class="py-12 px-4 sm:px-6">
      <div class="max-w-md mx-auto text-center">
        <%= case @status do %>
          <% :processing -> %>
            <div class="bg-white rounded-xl border p-8">
              <div class="animate-spin w-12 h-12 border-4 border-emerald-200 border-t-emerald-600 rounded-full mx-auto mb-4"></div>
              <h1 class="text-xl font-bold mb-2">Processing Payment...</h1>
              <p class="text-gray-500">Please wait while we confirm your payment.</p>
            </div>

          <% :success -> %>
            <div class="bg-white rounded-xl border p-8">
              <div class="w-16 h-16 bg-emerald-100 rounded-full flex items-center justify-center mx-auto mb-4">
                <.icon name="hero-check" class="w-8 h-8 text-emerald-600" />
              </div>
              <h1 class="text-xl font-bold mb-2 text-emerald-600">Payment Successful!</h1>
              <p class="text-gray-600 mb-6">
                Your commission request has been sent to the performer.
                Payment is held in escrow until the commission is completed.
              </p>

              <%= if @commission do %>
                <div class="bg-gray-50 rounded-lg p-4 mb-6 text-left">
                  <p class="text-sm text-gray-600">
                    <span class="font-medium">Screenplay:</span> <%= @commission.screenplay.title %>
                  </p>
                  <p class="text-sm text-gray-600">
                    <span class="font-medium">Performer:</span> <%= @commission.performer.name %>
                  </p>
                  <p class="text-sm text-gray-600">
                    <span class="font-medium">Amount:</span> $<%= :erlang.float_to_binary((@commission.offered_amount_cents || 0) / 100, decimals: 2) %>
                  </p>
                </div>

                <.link
                  navigate={~p"/commissions/#{@commission.id}"}
                  class="inline-block bg-emerald-600 text-white px-6 py-3 rounded-lg font-medium hover:bg-emerald-700"
                >
                  View Commission
                </.link>
              <% end %>
            </div>

          <% :error -> %>
            <div class="bg-white rounded-xl border p-8">
              <div class="w-16 h-16 bg-red-100 rounded-full flex items-center justify-center mx-auto mb-4">
                <.icon name="hero-x-mark" class="w-8 h-8 text-red-600" />
              </div>
              <h1 class="text-xl font-bold mb-2 text-red-600">Payment Error</h1>
              <p class="text-gray-600 mb-6"><%= @error %></p>

              <.link
                navigate={~p"/dashboard"}
                class="inline-block bg-gray-600 text-white px-6 py-3 rounded-lg font-medium hover:bg-gray-700"
              >
                Return to Dashboard
              </.link>
            </div>
        <% end %>
      </div>
    </div>
    """
  end
end
