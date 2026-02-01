defmodule ScriptVoice.Repo.Migrations.CreateStripeAccounts do
  use Ecto.Migration

  def change do
    create table(:stripe_accounts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      # Stripe Account Info
      add :stripe_account_id, :string, null: false
      add :onboarding_complete, :boolean, null: false, default: false
      add :charges_enabled, :boolean, null: false, default: false
      add :payouts_enabled, :boolean, null: false, default: false

      # Account Details
      add :country, :string, size: 2
      add :default_currency, :string, size: 3, default: "USD"

      timestamps()
    end

    create unique_index(:stripe_accounts, [:user_id])
    create unique_index(:stripe_accounts, [:stripe_account_id])
  end
end
