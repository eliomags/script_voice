defmodule ScriptVoice.Repo.Migrations.CreateLikes do
  use Ecto.Migration

  def change do
    create table(:likes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :target_type, :string, null: false  # "screenplay" or "audio_version"
      add :target_id, :binary_id, null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:likes, [:user_id])
    create index(:likes, [:target_type, :target_id])
    create unique_index(:likes, [:user_id, :target_type, :target_id], name: :likes_user_target_unique)
  end
end
