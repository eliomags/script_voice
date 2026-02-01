defmodule ScriptVoice.Commissions.Payment do
  @moduledoc """
  Schema for payment records associated with commissions.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(pending processing held completed refunded disputed)
  @payment_methods ~w(card apple_pay google_pay link)

  schema "payments" do
    # Stripe IDs
    field :stripe_payment_intent_id, :string
    field :stripe_transfer_id, :string

    # Amounts (all in cents)
    field :amount_cents, :integer
    field :processing_fee_cents, :integer
    field :platform_fee_cents, :integer
    field :performer_payout_cents, :integer

    # Status
    field :status, :string, default: "pending"

    # Payment method
    field :payment_method, :string
    field :last_four, :string

    # Timestamps for payment lifecycle
    field :captured_at, :utc_datetime
    field :released_at, :utc_datetime
    field :refunded_at, :utc_datetime

    belongs_to :commission_request, ScriptVoice.Commissions.CommissionRequest

    timestamps()
  end

  @doc false
  def changeset(payment, attrs) do
    payment
    |> cast(attrs, [
      :commission_request_id,
      :stripe_payment_intent_id,
      :stripe_transfer_id,
      :amount_cents,
      :processing_fee_cents,
      :platform_fee_cents,
      :performer_payout_cents,
      :status,
      :payment_method,
      :last_four,
      :captured_at,
      :released_at,
      :refunded_at
    ])
    |> validate_required([
      :commission_request_id,
      :amount_cents,
      :processing_fee_cents,
      :platform_fee_cents,
      :performer_payout_cents
    ])
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:payment_method, @payment_methods, allow_nil: true)
    |> validate_number(:amount_cents, greater_than: 0)
    |> validate_number(:processing_fee_cents, greater_than_or_equal_to: 0)
    |> validate_number(:platform_fee_cents, greater_than_or_equal_to: 0)
    |> validate_number(:performer_payout_cents, greater_than: 0)
    |> validate_length(:last_four, is: 4)
    |> unique_constraint(:stripe_payment_intent_id)
    |> foreign_key_constraint(:commission_request_id)
  end

  @doc """
  Changeset for capturing payment.
  """
  def capture_changeset(payment, payment_intent_id, payment_method, last_four) do
    payment
    |> put_change(:stripe_payment_intent_id, payment_intent_id)
    |> put_change(:payment_method, payment_method)
    |> put_change(:last_four, last_four)
    |> put_change(:status, "held")
    |> put_change(:captured_at, DateTime.utc_now() |> DateTime.truncate(:second))
  end

  @doc """
  Changeset for releasing payment to performer.
  """
  def release_changeset(payment, transfer_id) do
    payment
    |> put_change(:stripe_transfer_id, transfer_id)
    |> put_change(:status, "completed")
    |> put_change(:released_at, DateTime.utc_now() |> DateTime.truncate(:second))
  end

  @doc """
  Changeset for refunding payment.
  """
  def refund_changeset(payment) do
    payment
    |> put_change(:status, "refunded")
    |> put_change(:refunded_at, DateTime.utc_now() |> DateTime.truncate(:second))
  end

  @doc """
  Returns all valid statuses.
  """
  def statuses, do: @statuses

  @doc """
  Returns all valid payment methods.
  """
  def payment_methods, do: @payment_methods

  @doc """
  Formats amount in cents to dollars string.
  """
  def format_amount(nil), do: nil
  def format_amount(cents), do: "$#{:erlang.float_to_binary(cents / 100, decimals: 2)}"
end
