defmodule ScriptVoice.Commissions.StripeAccount do
  @moduledoc """
  Schema for Stripe Connect accounts for performers.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "stripe_accounts" do
    field :stripe_account_id, :string
    field :onboarding_complete, :boolean, default: false
    field :charges_enabled, :boolean, default: false
    field :payouts_enabled, :boolean, default: false

    field :country, :string
    field :default_currency, :string, default: "USD"

    belongs_to :user, ScriptVoice.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(account, attrs) do
    account
    |> cast(attrs, [
      :user_id,
      :stripe_account_id,
      :onboarding_complete,
      :charges_enabled,
      :payouts_enabled,
      :country,
      :default_currency
    ])
    |> validate_required([:user_id, :stripe_account_id])
    |> validate_length(:country, is: 2)
    |> validate_length(:default_currency, is: 3)
    |> unique_constraint(:user_id)
    |> unique_constraint(:stripe_account_id)
  end

  @doc """
  Changeset for updating account status after webhook.
  """
  def status_changeset(account, attrs) do
    account
    |> cast(attrs, [:onboarding_complete, :charges_enabled, :payouts_enabled, :country, :default_currency])
  end

  @doc """
  Checks if account is ready to receive payments.
  """
  def ready_for_payments?(%__MODULE__{} = account) do
    account.onboarding_complete and account.charges_enabled and account.payouts_enabled
  end
end
