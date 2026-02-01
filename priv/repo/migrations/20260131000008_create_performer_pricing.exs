defmodule ScriptVoice.Repo.Migrations.CreatePerformerPricing do
  use Ecto.Migration

  def change do
    create table(:performer_pricing, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      # Pricing Model
      add :pricing_model, :string, null: false, default: "per_page"
      # Options: per_page, per_page_per_character, flat, quote

      # Rate Settings (in cents to avoid float issues)
      add :per_page_rate_cents, :integer
      add :per_character_rate_cents, :integer
      add :flat_rate_cents, :integer
      add :minimum_rate_cents, :integer

      # Retake Policy
      add :included_retakes, :integer, null: false, default: 2
      add :retake_rate_cents, :integer

      # Rush Jobs
      add :rush_multiplier_percent, :integer, default: 50
      add :rush_days_threshold, :integer, default: 3

      # Availability
      add :is_accepting_commissions, :boolean, null: false, default: true
      add :max_concurrent_projects, :integer, default: 5
      add :typical_turnaround_days, :integer, default: 7

      # Additional Info
      add :currency, :string, null: false, default: "USD"
      add :notes, :text

      timestamps()
    end

    create unique_index(:performer_pricing, [:user_id])
  end
end
