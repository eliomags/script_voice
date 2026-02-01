defmodule ScriptVoice.Repo.Migrations.CreateCommissionSubmissions do
  use Ecto.Migration

  def change do
    create table(:commission_submissions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :commission_request_id, references(:commission_requests, type: :binary_id, on_delete: :delete_all), null: false

      # Audio
      add :audio_url, :string, size: 500, null: false
      add :duration, :integer  # in seconds
      add :file_size_bytes, :integer

      # Submission Info
      add :submission_number, :integer, null: false  # 1 = initial, 2+ = retakes
      add :performer_notes, :text

      # Review
      add :status, :string, null: false, default: "pending_review"
      # Options: pending_review, approved, revision_requested
      add :writer_feedback, :text
      add :reviewed_at, :utc_datetime

      timestamps()
    end

    create index(:commission_submissions, [:commission_request_id])
  end
end
