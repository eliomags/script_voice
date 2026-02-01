defmodule ScriptVoice.Repo.Migrations.CreatePayments do
  use Ecto.Migration

  def change do
    create table(:payments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :commission_request_id, references(:commission_requests, type: :binary_id, on_delete: :restrict), null: false

      # Stripe IDs
      add :stripe_payment_intent_id, :string, size: 100
      add :stripe_transfer_id, :string, size: 100

      # Amounts (all in cents)
      add :amount_cents, :integer, null: false
      add :processing_fee_cents, :integer, null: false
      add :platform_fee_cents, :integer, null: false
      add :performer_payout_cents, :integer, null: false

      # Status
      add :status, :string, null: false, default: "pending"
      # Options: pending, processing, held, completed, refunded, disputed

      # Payment method
      add :payment_method, :string, size: 50  # card, apple_pay, google_pay, link
      add :last_four, :string, size: 4

      # Timestamps for payment lifecycle
      add :captured_at, :utc_datetime
      add :released_at, :utc_datetime
      add :refunded_at, :utc_datetime

      timestamps()
    end

    create index(:payments, [:commission_request_id])
    create unique_index(:payments, [:stripe_payment_intent_id])
  end
end
