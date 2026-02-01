defmodule ScriptVoice.Repo.Migrations.CreateNotifications do
  use Ecto.Migration

  def change do
    create table(:notifications, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      # Content
      add :type, :string, size: 50, null: false
      # Options: commission_request_received, commission_accepted, commission_declined,
      #          submission_received, revision_requested, commission_completed,
      #          commission_cancelled, message_received
      add :title, :string, size: 200, null: false
      add :body, :text

      # Related Entity
      add :related_type, :string, size: 50
      add :related_id, :binary_id

      # Link
      add :action_url, :string, size: 500

      # Status
      add :read_at, :utc_datetime
      add :email_sent_at, :utc_datetime

      timestamps()
    end

    create index(:notifications, [:user_id])
    create index(:notifications, [:user_id], where: "read_at IS NULL", name: :notifications_user_unread_idx)
  end
end
