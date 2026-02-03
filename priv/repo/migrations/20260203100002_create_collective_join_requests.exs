defmodule ScriptVoice.Repo.Migrations.CreateCollectiveJoinRequests do
  use Ecto.Migration

  def change do
    create table(:collective_join_requests, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :collective_id, references(:collectives, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :status, :string, null: false, default: "pending"  # pending, approved, rejected
      add :message, :text  # why they want to join
      add :response_message, :text  # admin's response
      add :reviewed_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :reviewed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:collective_join_requests, [:collective_id])
    create index(:collective_join_requests, [:user_id])
    # Unique constraint: only one pending request per collective-user pair
    create unique_index(:collective_join_requests, [:collective_id, :user_id],
      where: "status = 'pending'",
      name: :collective_join_requests_pending_unique_idx
    )
  end
end
