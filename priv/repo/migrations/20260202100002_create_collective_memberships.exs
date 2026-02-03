defmodule ScriptVoice.Repo.Migrations.CreateCollectiveMemberships do
  use Ecto.Migration

  def change do
    create table(:collective_memberships, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :role, :string, null: false, default: "member"
      add :display_order, :integer, default: 0
      add :joined_at, :utc_datetime, null: false
      add :collective_id, references(:collectives, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:collective_memberships, [:collective_id])
    create index(:collective_memberships, [:user_id])
    create unique_index(:collective_memberships, [:collective_id, :user_id])
  end
end
