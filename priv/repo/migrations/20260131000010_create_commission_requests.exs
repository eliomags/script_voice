defmodule ScriptVoice.Repo.Migrations.CreateCommissionRequests do
  use Ecto.Migration

  def change do
    create table(:commission_requests, primary_key: false) do
      add :id, :binary_id, primary_key: true

      # Parties
      add :screenplay_id, references(:screenplays, type: :binary_id, on_delete: :delete_all), null: false
      add :writer_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :performer_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      # Status
      add :status, :string, null: false, default: "pending"
      # Options: pending, accepted, declined, in_progress, submitted, revision_requested, completed, cancelled, disputed

      # Pricing (all in cents)
      add :calculated_amount_cents, :integer
      add :offered_amount_cents, :integer
      add :agreed_amount_cents, :integer

      # Communication
      add :writer_message, :text
      add :performer_response, :text

      # Timeline
      add :deadline, :date
      add :is_rush, :boolean, null: false, default: false

      # Retakes
      add :retakes_included, :integer, null: false, default: 2
      add :retakes_used, :integer, null: false, default: 0

      # Result - will be set when commission is completed
      add :final_audio_version_id, :binary_id

      # Tracking timestamps
      add :accepted_at, :utc_datetime
      add :submitted_at, :utc_datetime
      add :completed_at, :utc_datetime
      add :cancelled_at, :utc_datetime
      add :cancelled_by, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :cancellation_reason, :text

      timestamps()
    end

    create index(:commission_requests, [:writer_id])
    create index(:commission_requests, [:performer_id])
    create index(:commission_requests, [:screenplay_id])
    create index(:commission_requests, [:status])
  end
end
