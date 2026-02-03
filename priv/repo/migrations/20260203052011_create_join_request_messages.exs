defmodule ScriptVoice.Repo.Migrations.CreateJoinRequestMessages do
  use Ecto.Migration

  def change do
    create table(:join_request_messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :join_request_id, references(:collective_join_requests, type: :binary_id, on_delete: :delete_all), null: false
      add :sender_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :content, :text, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:join_request_messages, [:join_request_id])
    create index(:join_request_messages, [:sender_id])
  end
end
