defmodule ScriptVoiceWeb.StripeWebhookController do
  @moduledoc """
  Handles Stripe webhook events for Connect and payments.
  """
  use ScriptVoiceWeb, :controller

  alias ScriptVoice.Stripe, as: StripeService

  @doc """
  Handles incoming Stripe webhook events.
  """
  def handle(conn, _params) do
    payload = conn.assigns[:raw_body]
    signature = get_stripe_signature(conn)
    webhook_secret = get_webhook_secret()

    case StripeService.construct_webhook_event(payload, signature, webhook_secret) do
      {:ok, event} ->
        handle_event(event)
        send_resp(conn, 200, "OK")

      {:error, %Stripe.Error{message: message}} ->
        send_resp(conn, 400, "Webhook Error: #{message}")

      {:error, _} ->
        send_resp(conn, 400, "Webhook Error")
    end
  end

  defp get_stripe_signature(conn) do
    case get_req_header(conn, "stripe-signature") do
      [signature] -> signature
      _ -> ""
    end
  end

  defp get_webhook_secret do
    Application.get_env(:stripity_stripe, :connect_webhook_signing_secret) || ""
  end

  # Handle different event types
  defp handle_event(%Stripe.Event{type: "account.updated", data: %{object: account}}) do
    StripeService.handle_account_updated(account)
  end

  defp handle_event(%Stripe.Event{type: "payment_intent.succeeded", data: %{object: payment_intent}}) do
    StripeService.handle_payment_succeeded(payment_intent)
  end

  defp handle_event(%Stripe.Event{type: "payment_intent.payment_failed", data: %{object: payment_intent}}) do
    # Log failed payment, could notify user
    require Logger
    Logger.warning("Payment failed for intent: #{payment_intent.id}")
    :ok
  end

  defp handle_event(%Stripe.Event{type: "transfer.created", data: %{object: transfer}}) do
    StripeService.handle_transfer_created(transfer)
  end

  defp handle_event(%Stripe.Event{type: "charge.refunded", data: %{object: _charge}}) do
    # Handle refund confirmation
    :ok
  end

  defp handle_event(%Stripe.Event{type: type}) do
    require Logger
    Logger.info("Unhandled Stripe event type: #{type}")
    :ok
  end
end
