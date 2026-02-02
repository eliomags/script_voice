defmodule ScriptVoice.Commissions do
  @moduledoc """
  The Commissions context - handles all commission-related operations between writers and performers.
  """

  import Ecto.Query, warn: false
  alias ScriptVoice.Repo

  alias ScriptVoice.Commissions.{
    PerformerPricing,
    CommissionRequest,
    CommissionSubmission,
    CommissionMessage,
    Payment,
    StripeAccount,
    PriceCalculator
  }

  # =============================================================================
  # Performer Pricing
  # =============================================================================

  @doc """
  Gets the pricing settings for a performer.
  """
  def get_performer_pricing(user_id) do
    Repo.get_by(PerformerPricing, user_id: user_id)
  end

  @doc """
  Gets the pricing settings for a performer, or returns a default struct.
  """
  def get_performer_pricing_or_default(user_id) do
    case get_performer_pricing(user_id) do
      nil -> %PerformerPricing{user_id: user_id}
      pricing -> pricing
    end
  end

  @doc """
  Creates or updates pricing settings for a performer.
  """
  def upsert_performer_pricing(user_id, attrs) do
    case get_performer_pricing(user_id) do
      nil ->
        %PerformerPricing{}
        |> PerformerPricing.changeset(Map.put(attrs, :user_id, user_id))
        |> Repo.insert()

      pricing ->
        pricing
        |> PerformerPricing.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Calculates the commission price for a screenplay based on performer pricing.
  """
  def calculate_commission_price(screenplay, performer_id) do
    case get_performer_pricing(performer_id) do
      nil -> {:error, :no_pricing_set}
      pricing -> {:ok, PriceCalculator.calculate(screenplay, pricing)}
    end
  end

  # =============================================================================
  # Commission Requests
  # =============================================================================

  @doc """
  Gets a commission request by ID.
  """
  def get_commission_request(id) do
    CommissionRequest
    |> Repo.get(id)
    |> Repo.preload([:screenplay, :writer, :performer, :submissions, :payment])
  end

  @doc """
  Gets a commission request by ID, raising if not found.
  """
  def get_commission_request!(id) do
    CommissionRequest
    |> Repo.get!(id)
    |> Repo.preload([:screenplay, :writer, :performer, :submissions, :payment])
  end

  @doc """
  Lists commission requests for a writer.
  """
  def list_commission_requests_for_writer(writer_id, opts \\ []) do
    status = Keyword.get(opts, :status)

    CommissionRequest
    |> where([c], c.writer_id == ^writer_id)
    |> maybe_filter_by_status(status)
    |> order_by([c], desc: c.inserted_at)
    |> preload([:screenplay, :performer, :submissions])
    |> Repo.all()
  end

  @doc """
  Lists commission requests for a performer.
  """
  def list_commission_requests_for_performer(performer_id, opts \\ []) do
    status = Keyword.get(opts, :status)

    CommissionRequest
    |> where([c], c.performer_id == ^performer_id)
    |> maybe_filter_by_status(status)
    |> order_by([c], desc: c.inserted_at)
    |> preload([:screenplay, :writer, :submissions])
    |> Repo.all()
  end

  defp maybe_filter_by_status(query, nil), do: query
  defp maybe_filter_by_status(query, status) when is_binary(status) do
    where(query, [c], c.status == ^status)
  end
  defp maybe_filter_by_status(query, statuses) when is_list(statuses) do
    where(query, [c], c.status in ^statuses)
  end

  @doc """
  Creates a new commission request.
  """
  def create_commission_request(attrs) do
    %CommissionRequest{}
    |> CommissionRequest.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Accepts a commission request.
  """
  def accept_commission(commission_id, performer_id, attrs \\ %{}) do
    with {:ok, commission} <- get_commission_for_performer(commission_id, performer_id),
         :ok <- validate_status(commission, "pending") do
      agreed_amount = Map.get(attrs, :agreed_amount_cents, commission.offered_amount_cents)

      commission
      |> CommissionRequest.accept_changeset(Map.put(attrs, :agreed_amount_cents, agreed_amount))
      |> Repo.update()
    end
  end

  @doc """
  Declines a commission request.
  """
  def decline_commission(commission_id, performer_id, response \\ nil) do
    with {:ok, commission} <- get_commission_for_performer(commission_id, performer_id),
         :ok <- validate_status(commission, "pending") do
      commission
      |> CommissionRequest.decline_changeset(%{performer_response: response})
      |> Repo.update()
    end
  end

  @doc """
  Cancels a commission request.
  Only allowed before submission in certain states.
  """
  def cancel_commission(commission_id, user_id, reason) do
    with {:ok, commission} <- get_commission_for_user(commission_id, user_id),
         true <- CommissionRequest.cancellable?(commission) do
      commission
      |> CommissionRequest.cancel_changeset(user_id, reason)
      |> Repo.update()
    else
      false -> {:error, :not_cancellable}
      error -> error
    end
  end

  @doc """
  Marks a commission as in progress (performer starts work).
  """
  def start_commission(commission_id, performer_id) do
    with {:ok, commission} <- get_commission_for_performer(commission_id, performer_id),
         :ok <- validate_status(commission, "accepted") do
      commission
      |> CommissionRequest.in_progress_changeset()
      |> Repo.update()
    end
  end

  defp get_commission_for_performer(commission_id, performer_id) do
    case get_commission_request(commission_id) do
      nil -> {:error, :not_found}
      %{performer_id: ^performer_id} = commission -> {:ok, commission}
      _ -> {:error, :unauthorized}
    end
  end

  defp get_commission_for_writer(commission_id, writer_id) do
    case get_commission_request(commission_id) do
      nil -> {:error, :not_found}
      %{writer_id: ^writer_id} = commission -> {:ok, commission}
      _ -> {:error, :unauthorized}
    end
  end

  defp get_commission_for_user(commission_id, user_id) do
    case get_commission_request(commission_id) do
      nil -> {:error, :not_found}
      %{writer_id: ^user_id} = commission -> {:ok, commission}
      %{performer_id: ^user_id} = commission -> {:ok, commission}
      _ -> {:error, :unauthorized}
    end
  end

  defp validate_status(%{status: expected}, expected), do: :ok
  defp validate_status(%{status: _actual}, _expected), do: {:error, :invalid_status}

  # =============================================================================
  # Commission Submissions
  # =============================================================================

  @doc """
  Submits audio for a commission.
  """
  def submit_audio(commission_id, performer_id, attrs) do
    with {:ok, commission} <- get_commission_for_performer(commission_id, performer_id),
         :ok <- validate_submission_allowed(commission) do
      submission_number = get_next_submission_number(commission_id)

      Repo.transaction(fn ->
        # Create submission
        {:ok, submission} =
          %CommissionSubmission{}
          |> CommissionSubmission.create_changeset(
            Map.merge(attrs, %{
              commission_request_id: commission_id,
              submission_number: submission_number
            })
          )
          |> Repo.insert()

        # Update commission status
        {:ok, _commission} =
          commission
          |> CommissionRequest.submitted_changeset()
          |> Repo.update()

        submission
      end)
    end
  end

  defp validate_submission_allowed(%{status: status}) when status in ["accepted", "in_progress", "revision_requested"], do: :ok
  defp validate_submission_allowed(_), do: {:error, :submission_not_allowed}

  defp get_next_submission_number(commission_id) do
    count = CommissionSubmission
    |> where([s], s.commission_request_id == ^commission_id)
    |> Repo.aggregate(:count)

    count + 1
  end

  @doc """
  Gets all submissions for a commission.
  """
  def get_submissions_for_commission(commission_id) do
    CommissionSubmission
    |> where([s], s.commission_request_id == ^commission_id)
    |> order_by([s], asc: s.submission_number)
    |> Repo.all()
  end

  @doc """
  Requests revision on a submission.
  """
  def request_revision(submission_id, writer_id, feedback) do
    with {:ok, submission} <- get_submission_for_writer(submission_id, writer_id),
         {:ok, commission} <- get_commission_for_writer(submission.commission_request_id, writer_id),
         true <- CommissionRequest.retakes_available?(commission) do
      Repo.transaction(fn ->
        {:ok, updated_submission} =
          submission
          |> CommissionSubmission.revision_changeset(feedback)
          |> Repo.update()

        {:ok, _commission} =
          commission
          |> CommissionRequest.revision_changeset()
          |> Repo.update()

        updated_submission
      end)
    else
      false -> {:error, :no_retakes_remaining}
      error -> error
    end
  end

  @doc """
  Approves a submission and completes the commission.
  Also triggers payment release to performer if payment exists.
  """
  def approve_submission(submission_id, writer_id) do
    alias ScriptVoice.Stripe, as: StripeService

    with {:ok, submission} <- get_submission_for_writer(submission_id, writer_id),
         {:ok, commission} <- get_commission_for_writer(submission.commission_request_id, writer_id) do
      Repo.transaction(fn ->
        {:ok, _submission} =
          submission
          |> CommissionSubmission.approve_changeset()
          |> Repo.update()

        {:ok, completed_commission} =
          commission
          |> CommissionRequest.complete_changeset(nil)
          |> Repo.update()

        # Release payment to performer if payment exists
        case get_payment_for_commission(commission.id) do
          nil ->
            # No payment record - commission was created without payment (dev mode)
            :ok

          %{status: "held"} = payment ->
            # Payment is held - release to performer
            case get_stripe_account(commission.performer_id) do
              nil ->
                # Performer has no Stripe account - can't transfer
                require Logger
                Logger.warning("Cannot release payment - performer #{commission.performer_id} has no Stripe account")

              stripe_account ->
                # Transfer to performer
                case StripeService.release_escrow_to_performer(payment, stripe_account.stripe_account_id) do
                  {:ok, _transfer} -> :ok
                  {:error, error} ->
                    require Logger
                    Logger.error("Failed to release payment: #{inspect(error)}")
                end
            end

          _payment ->
            # Payment in other status - no action needed
            :ok
        end

        completed_commission
      end)
    end
  end

  defp get_submission_for_writer(submission_id, writer_id) do
    submission = Repo.get(CommissionSubmission, submission_id)

    case submission do
      nil ->
        {:error, :not_found}

      submission ->
        commission = get_commission_request(submission.commission_request_id)
        if commission && commission.writer_id == writer_id do
          {:ok, submission}
        else
          {:error, :unauthorized}
        end
    end
  end

  # =============================================================================
  # Commission Messages
  # =============================================================================

  @doc """
  Sends a message in a commission thread.
  """
  def send_message(commission_id, sender_id, message, type \\ "message") do
    with {:ok, _commission} <- get_commission_for_user(commission_id, sender_id) do
      %CommissionMessage{}
      |> CommissionMessage.changeset(%{
        commission_request_id: commission_id,
        sender_id: sender_id,
        message: message,
        message_type: type
      })
      |> Repo.insert()
    end
  end

  @doc """
  Lists messages for a commission.
  """
  def list_messages(commission_id) do
    CommissionMessage
    |> where([m], m.commission_request_id == ^commission_id)
    |> order_by([m], asc: m.inserted_at)
    |> preload(:sender)
    |> Repo.all()
  end

  @doc """
  Marks all messages as read for a user in a commission thread.
  """
  def mark_messages_read(commission_id, user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    from(m in CommissionMessage,
      where: m.commission_request_id == ^commission_id,
      where: m.sender_id != ^user_id,
      where: is_nil(m.read_at)
    )
    |> Repo.update_all(set: [read_at: now])
  end

  # =============================================================================
  # Stripe Accounts
  # =============================================================================

  @doc """
  Gets the Stripe account for a user.
  """
  def get_stripe_account(user_id) do
    Repo.get_by(StripeAccount, user_id: user_id)
  end

  @doc """
  Gets a Stripe account by its Stripe account ID.
  """
  def get_stripe_account_by_stripe_id(stripe_account_id) do
    Repo.get_by(StripeAccount, stripe_account_id: stripe_account_id)
  end

  @doc """
  Creates a Stripe account record.
  """
  def create_stripe_account(attrs) do
    %StripeAccount{}
    |> StripeAccount.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates Stripe account status (usually after webhook).
  """
  def update_stripe_account_status(user_id, attrs) do
    case get_stripe_account(user_id) do
      nil -> {:error, :not_found}
      account ->
        account
        |> StripeAccount.status_changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Checks if a performer is ready to receive payments.
  """
  def performer_ready_for_payments?(user_id) do
    case get_stripe_account(user_id) do
      nil -> false
      account -> StripeAccount.ready_for_payments?(account)
    end
  end

  # =============================================================================
  # Payments
  # =============================================================================

  @doc """
  Creates a payment record for a commission.
  """
  def create_payment(commission_id, amount_cents) do
    breakdown = PriceCalculator.calculate_full_breakdown(amount_cents)

    %Payment{}
    |> Payment.changeset(%{
      commission_request_id: commission_id,
      amount_cents: breakdown.commission_amount_cents,
      processing_fee_cents: breakdown.processing_fee_cents,
      platform_fee_cents: breakdown.platform_fee_cents,
      performer_payout_cents: breakdown.performer_payout_cents
    })
    |> Repo.insert()
  end

  @doc """
  Creates a payment record with Stripe payment intent ID (already captured).
  Used after successful Stripe Checkout.
  """
  def create_payment_with_stripe(commission_id, amount_cents, payment_intent_id) do
    breakdown = PriceCalculator.calculate_full_breakdown(amount_cents)

    %Payment{}
    |> Payment.changeset(%{
      commission_request_id: commission_id,
      amount_cents: breakdown.commission_amount_cents,
      processing_fee_cents: breakdown.processing_fee_cents,
      platform_fee_cents: breakdown.platform_fee_cents,
      performer_payout_cents: breakdown.performer_payout_cents,
      stripe_payment_intent_id: payment_intent_id,
      status: "held",
      captured_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.insert()
  end

  @doc """
  Gets the payment for a commission.
  """
  def get_payment_for_commission(commission_id) do
    Repo.get_by(Payment, commission_request_id: commission_id)
  end

  @doc """
  Marks payment as captured (held in escrow).
  """
  def capture_payment(payment_id, payment_intent_id, payment_method, last_four) do
    payment = Repo.get!(Payment, payment_id)

    payment
    |> Payment.capture_changeset(payment_intent_id, payment_method, last_four)
    |> Repo.update()
  end

  @doc """
  Releases payment to performer (after completion).
  """
  def release_payment(payment_id, transfer_id) do
    payment = Repo.get!(Payment, payment_id)

    payment
    |> Payment.release_changeset(transfer_id)
    |> Repo.update()
  end

  @doc """
  Refunds a payment.
  """
  def refund_payment(payment_id) do
    payment = Repo.get!(Payment, payment_id)

    payment
    |> Payment.refund_changeset()
    |> Repo.update()
  end

  # =============================================================================
  # Statistics
  # =============================================================================

  @doc """
  Gets commission statistics for a performer.
  """
  def get_performer_stats(performer_id) do
    completed_count = CommissionRequest
    |> where([c], c.performer_id == ^performer_id and c.status == "completed")
    |> Repo.aggregate(:count)

    total_earned = Payment
    |> join(:inner, [p], c in CommissionRequest, on: p.commission_request_id == c.id)
    |> where([p, c], c.performer_id == ^performer_id and p.status == "completed")
    |> Repo.aggregate(:sum, :performer_payout_cents) || 0

    active_count = CommissionRequest
    |> where([c], c.performer_id == ^performer_id and c.status in ["accepted", "in_progress", "submitted", "revision_requested"])
    |> Repo.aggregate(:count)

    %{
      completed_count: completed_count,
      total_earned_cents: total_earned,
      active_count: active_count
    }
  end

  @doc """
  Gets commission statistics for a writer.
  """
  def get_writer_stats(writer_id) do
    completed_count = CommissionRequest
    |> where([c], c.writer_id == ^writer_id and c.status == "completed")
    |> Repo.aggregate(:count)

    total_spent = Payment
    |> join(:inner, [p], c in CommissionRequest, on: p.commission_request_id == c.id)
    |> where([p, c], c.writer_id == ^writer_id and p.status == "completed")
    |> Repo.aggregate(:sum, :amount_cents) || 0

    pending_count = CommissionRequest
    |> where([c], c.writer_id == ^writer_id and c.status == "pending")
    |> Repo.aggregate(:count)

    %{
      completed_count: completed_count,
      total_spent_cents: total_spent,
      pending_count: pending_count
    }
  end
end
