defmodule ScriptVoice.Repo.Migrations.CreateCommissionMessages do
  use Ecto.Migration

  def change do
    create table(:commission_messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :commission_request_id, references(:commission_requests, type: :binary_id, on_delete: :delete_all), null: false
      add :sender_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :message, :text, null: false
      add :message_type, :string, null: false, default: "message"
      # Options: message, revision_request, status_update

      # Attachments (optional)
      add :attachment_url, :string, size: 500
      add :attachment_type, :string, size: 50

      add :read_at, :utc_datetime

      timestamps()
    end

    create index(:commission_messages, [:commission_request_id])
    create index(:commission_messages, [:sender_id])
  end
end
