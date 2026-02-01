defmodule ScriptVoice.Stripe do
  @moduledoc """
  Stripe integration for ScriptVoice commission payments.
  Handles Stripe Connect for marketplace payments.
  """

  alias ScriptVoice.Commissions
  alias ScriptVoice.Commissions.{CommissionRequest, Payment, PriceCalculator}

  @platform_fee_percent Application.compile_env(:script_voice, [:stripe, :platform_fee_percent], 10)

  # =============================================================================
  # Stripe Connect - Account Onboarding
  # =============================================================================

  @doc """
  Creates a Stripe Connect account for a performer and returns the onboarding URL.
  """
  def create_connect_account(user) do
    params = %{
      type: "express",
      country: "US",
      email: user.email,
      capabilities: %{
        card_payments: %{requested: true},
        transfers: %{requested: true}
      },
      business_type: "individual",
      metadata: %{
        user_id: user.id,
        platform: "scriptvoice"
      }
    }

    case Stripe.Account.create(params) do
      {:ok, account} ->
        # Save the Stripe account ID
        {:ok, _stripe_account} = Commissions.create_stripe_account(%{
          user_id: user.id,
          stripe_account_id: account.id,
          country: account.country,
          default_currency: account.default_currency || "USD"
        })

        {:ok, account}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Creates an account link for onboarding or updating account details.
  """
  def create_account_link(stripe_account_id, return_url, refresh_url) do
    params = %{
      account: stripe_account_id,
      refresh_url: refresh_url,
      return_url: return_url,
      type: "account_onboarding"
    }

    case Stripe.AccountLink.create(params) do
      {:ok, link} -> {:ok, link.url}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Retrieves the current status of a Stripe Connect account.
  """
  def get_account_status(stripe_account_id) do
    case Stripe.Account.retrieve(stripe_account_id) do
      {:ok, account} ->
        {:ok, %{
          charges_enabled: account.charges_enabled,
          payouts_enabled: account.payouts_enabled,
          details_submitted: account.details_submitted,
          requirements: account.requirements
        }}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Creates a login link for a connected account to access their Stripe dashboard.
  """
  def create_login_link(stripe_account_id) do
    case Stripe.LoginLink.create(stripe_account_id) do
      {:ok, link} -> {:ok, link.url}
      {:error, error} -> {:error, error}
    end
  end

  # =============================================================================
  # Payment Intents - Creating and Capturing Payments
  # =============================================================================

  @doc """
  Creates a Payment Intent for a commission.
  The payment will be held until the commission is completed.
  """
  def create_payment_intent(%CommissionRequest{} = commission, performer_stripe_account_id) do
    amount_cents = commission.agreed_amount_cents || commission.offered_amount_cents
    breakdown = PriceCalculator.calculate_full_breakdown(amount_cents)

    # Platform fee is taken from the transfer, not the payment
    platform_fee_cents = breakdown.platform_fee_cents

    params = %{
      amount: breakdown.total_cents,
      currency: "usd",
      payment_method_types: ["card", "link"],
      capture_method: "automatic",
      # Transfer data for Connect
      transfer_data: %{
        destination: performer_stripe_account_id
      },
      # Hold platform fee
      application_fee_amount: platform_fee_cents,
      # Metadata for tracking
      metadata: %{
        commission_request_id: commission.id,
        screenplay_id: commission.screenplay_id,
        writer_id: commission.writer_id,
        performer_id: commission.performer_id,
        platform: "scriptvoice"
      },
      # For separate charges and transfers (escrow-like behavior)
      # We'll use "manual" transfers instead if we want true escrow
      description: "ScriptVoice commission payment"
    }

    case Stripe.PaymentIntent.create(params) do
      {:ok, intent} ->
        # Create payment record in our database
        {:ok, _payment} = Commissions.create_payment(commission.id, amount_cents)
        {:ok, intent}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Creates a PaymentIntent with manual capture for escrow-style payments.
  Payment is authorized but not captured until completion.
  """
  def create_payment_intent_with_escrow(%CommissionRequest{} = commission, performer_stripe_account_id) do
    amount_cents = commission.agreed_amount_cents || commission.offered_amount_cents
    breakdown = PriceCalculator.calculate_full_breakdown(amount_cents)
    platform_fee_cents = breakdown.platform_fee_cents

    params = %{
      amount: breakdown.total_cents,
      currency: "usd",
      payment_method_types: ["card", "link"],
      capture_method: "manual",  # Authorize only, capture later
      transfer_data: %{
        destination: performer_stripe_account_id
      },
      application_fee_amount: platform_fee_cents,
      metadata: %{
        commission_request_id: commission.id,
        platform: "scriptvoice"
      },
      description: "ScriptVoice commission payment (escrow)"
    }

    Stripe.PaymentIntent.create(params)
  end

  @doc """
  Captures a previously authorized payment (for escrow release).
  """
  def capture_payment_intent(payment_intent_id) do
    Stripe.PaymentIntent.capture(payment_intent_id)
  end

  @doc """
  Cancels a payment intent (for refunds before capture).
  """
  def cancel_payment_intent(payment_intent_id) do
    Stripe.PaymentIntent.cancel(payment_intent_id)
  end

  # =============================================================================
  # Refunds
  # =============================================================================

  @doc """
  Creates a refund for a payment.
  """
  def create_refund(payment_intent_id, opts \\ []) do
    params = %{
      payment_intent: payment_intent_id,
      reason: Keyword.get(opts, :reason, "requested_by_customer")
    }

    # Add amount for partial refunds
    params = if amount = Keyword.get(opts, :amount) do
      Map.put(params, :amount, amount)
    else
      params
    end

    Stripe.Refund.create(params)
  end

  @doc """
  Reverses a transfer to a connected account.
  Use this when refunding after a transfer has been made.
  """
  def reverse_transfer(transfer_id, opts \\ []) do
    params = %{}

    params = if amount = Keyword.get(opts, :amount) do
      Map.put(params, :amount, amount)
    else
      params
    end

    Stripe.Transfer.Reversal.create(transfer_id, params)
  end

  # =============================================================================
  # Transfers - Manual transfers for escrow release
  # =============================================================================

  @doc """
  Creates a transfer to a connected account.
  Use this for manual escrow release after commission completion.
  """
  def create_transfer(amount_cents, destination_account_id, opts \\ []) do
    params = %{
      amount: amount_cents,
      currency: "usd",
      destination: destination_account_id,
      metadata: Keyword.get(opts, :metadata, %{})
    }

    # Link to source charge if provided
    params = if source_transaction = Keyword.get(opts, :source_transaction) do
      Map.put(params, :source_transaction, source_transaction)
    else
      params
    end

    Stripe.Transfer.create(params)
  end

  # =============================================================================
  # Checkout Sessions - Alternative payment flow
  # =============================================================================

  @doc """
  Creates a Stripe Checkout Session for commission payment.
  Supports Apple Pay, Google Pay, Link automatically.
  """
  def create_checkout_session(%CommissionRequest{} = commission, performer_stripe_account_id, urls) do
    amount_cents = commission.agreed_amount_cents || commission.offered_amount_cents
    breakdown = PriceCalculator.calculate_full_breakdown(amount_cents)
    platform_fee_cents = breakdown.platform_fee_cents

    params = %{
      mode: "payment",
      payment_method_types: ["card", "link"],
      line_items: [
        %{
          price_data: %{
            currency: "usd",
            product_data: %{
              name: "Commission Payment",
              description: "Voice performance commission on ScriptVoice"
            },
            unit_amount: breakdown.total_cents
          },
          quantity: 1
        }
      ],
      payment_intent_data: %{
        application_fee_amount: platform_fee_cents,
        transfer_data: %{
          destination: performer_stripe_account_id
        },
        metadata: %{
          commission_request_id: commission.id,
          platform: "scriptvoice"
        }
      },
      success_url: urls.success_url,
      cancel_url: urls.cancel_url,
      metadata: %{
        commission_request_id: commission.id
      }
    }

    Stripe.Checkout.Session.create(params)
  end

  # =============================================================================
  # Webhook Handling
  # =============================================================================

  @doc """
  Verifies and parses a Stripe webhook payload.
  """
  def construct_webhook_event(payload, signature, webhook_secret) do
    Stripe.Webhook.construct_event(payload, signature, webhook_secret)
  end

  @doc """
  Handles account.updated webhooks for Connect accounts.
  """
  def handle_account_updated(account) do
    case Commissions.get_stripe_account_by_stripe_id(account.id) do
      nil ->
        {:error, :account_not_found}

      stripe_account ->
        Commissions.update_stripe_account_status(stripe_account.user_id, %{
          charges_enabled: account.charges_enabled,
          payouts_enabled: account.payouts_enabled,
          onboarding_complete: account.details_submitted
        })
    end
  end

  @doc """
  Handles payment_intent.succeeded webhooks.
  """
  def handle_payment_succeeded(payment_intent) do
    commission_id = payment_intent.metadata["commission_request_id"]

    if commission_id do
      case Commissions.get_payment_for_commission(commission_id) do
        nil ->
          {:error, :payment_not_found}

        payment ->
          payment_method = determine_payment_method(payment_intent)
          last_four = get_last_four(payment_intent)

          Commissions.capture_payment(
            payment.id,
            payment_intent.id,
            payment_method,
            last_four
          )
      end
    else
      {:error, :no_commission_id}
    end
  end

  @doc """
  Handles transfer.created webhooks.
  """
  def handle_transfer_created(transfer) do
    if commission_id = transfer.metadata["commission_request_id"] do
      case Commissions.get_payment_for_commission(commission_id) do
        nil -> {:error, :payment_not_found}
        payment -> Commissions.release_payment(payment.id, transfer.id)
      end
    else
      {:ok, :no_commission_id}
    end
  end

  # =============================================================================
  # Helper Functions
  # =============================================================================

  defp determine_payment_method(payment_intent) do
    case payment_intent.payment_method_types do
      types when is_list(types) ->
        cond do
          "link" in types -> "link"
          "card" in types -> "card"
          true -> List.first(types) || "card"
        end

      _ ->
        "card"
    end
  end

  defp get_last_four(payment_intent) do
    case payment_intent.charges do
      %{data: [charge | _]} ->
        case charge.payment_method_details do
          %{card: %{last4: last4}} -> last4
          _ -> nil
        end

      _ ->
        nil
    end
  end

  @doc """
  Returns the platform fee percentage.
  """
  def platform_fee_percent, do: @platform_fee_percent

  @doc """
  Checks if Stripe is properly configured.
  """
  def configured? do
    case Application.get_env(:stripity_stripe, :api_key) do
      nil -> false
      "" -> false
      _ -> true
    end
  end

  @doc """
  Returns the publishable key for client-side use.
  """
  def publishable_key do
    Application.get_env(:script_voice, :stripe)[:publishable_key]
  end
end
