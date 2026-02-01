defmodule ScriptVoice.Commissions.PerformerPricing do
  @moduledoc """
  Schema for voice artist pricing settings.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @pricing_models ~w(per_page per_page_per_character flat quote)

  schema "performer_pricing" do
    field :pricing_model, :string, default: "per_page"

    # Rate Settings (in cents)
    field :per_page_rate_cents, :integer
    field :per_character_rate_cents, :integer
    field :flat_rate_cents, :integer
    field :minimum_rate_cents, :integer

    # Retake Policy
    field :included_retakes, :integer, default: 2
    field :retake_rate_cents, :integer

    # Rush Jobs
    field :rush_multiplier_percent, :integer, default: 50
    field :rush_days_threshold, :integer, default: 3

    # Availability
    field :is_accepting_commissions, :boolean, default: true
    field :max_concurrent_projects, :integer, default: 5
    field :typical_turnaround_days, :integer, default: 7

    # Additional Info
    field :currency, :string, default: "USD"
    field :notes, :string

    belongs_to :user, ScriptVoice.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(pricing, attrs) do
    pricing
    |> cast(attrs, [
      :user_id,
      :pricing_model,
      :per_page_rate_cents,
      :per_character_rate_cents,
      :flat_rate_cents,
      :minimum_rate_cents,
      :included_retakes,
      :retake_rate_cents,
      :rush_multiplier_percent,
      :rush_days_threshold,
      :is_accepting_commissions,
      :max_concurrent_projects,
      :typical_turnaround_days,
      :currency,
      :notes
    ])
    |> validate_required([:user_id, :pricing_model, :is_accepting_commissions, :included_retakes])
    |> validate_inclusion(:pricing_model, @pricing_models)
    |> validate_number(:per_page_rate_cents, greater_than_or_equal_to: 0)
    |> validate_number(:per_character_rate_cents, greater_than_or_equal_to: 0)
    |> validate_number(:flat_rate_cents, greater_than_or_equal_to: 0)
    |> validate_number(:minimum_rate_cents, greater_than_or_equal_to: 0)
    |> validate_number(:included_retakes, greater_than_or_equal_to: 0, less_than_or_equal_to: 10)
    |> validate_number(:retake_rate_cents, greater_than_or_equal_to: 0)
    |> validate_number(:rush_multiplier_percent, greater_than_or_equal_to: 0, less_than_or_equal_to: 200)
    |> validate_number(:rush_days_threshold, greater_than_or_equal_to: 1, less_than_or_equal_to: 14)
    |> validate_number(:max_concurrent_projects, greater_than_or_equal_to: 1, less_than_or_equal_to: 50)
    |> validate_number(:typical_turnaround_days, greater_than_or_equal_to: 1, less_than_or_equal_to: 90)
    |> validate_pricing_model_rates()
    |> unique_constraint(:user_id)
  end

  defp validate_pricing_model_rates(changeset) do
    case get_field(changeset, :pricing_model) do
      "per_page" ->
        validate_required(changeset, [:per_page_rate_cents])

      "per_page_per_character" ->
        changeset
        |> validate_required([:per_page_rate_cents, :per_character_rate_cents])

      "flat" ->
        validate_required(changeset, [:flat_rate_cents])

      "quote" ->
        changeset

      _ ->
        changeset
    end
  end

  @doc """
  Returns the pricing models available.
  """
  def pricing_models, do: @pricing_models

  @doc """
  Formats cents to dollars string.
  """
  def format_cents(nil), do: nil
  def format_cents(cents), do: "$#{:erlang.float_to_binary(cents / 100, decimals: 2)}"
end
