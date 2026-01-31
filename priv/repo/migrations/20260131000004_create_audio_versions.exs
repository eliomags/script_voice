defmodule ScriptVoice.Repo.Migrations.CreateAudioVersions do
  use Ecto.Migration

  def change do
    create table(:audio_versions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :performer_type, :string, null: false, default: "solo"
      add :group_name, :string
      add :performers, {:array, :string}, null: false, default: []
      add :casting, :map, null: false, default: %{}
      add :audio_url, :string, null: false
      add :duration, :string
      add :likes, :integer, null: false, default: 0
      add :author_pick, :boolean, null: false, default: false
      add :verified, :boolean, null: false, default: false
      add :date, :string  # Formatted date for display

      add :screenplay_id, references(:screenplays, type: :binary_id, on_delete: :delete_all), null: false
      add :submitted_by_id, references(:users, type: :binary_id, on_delete: :nilify_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:audio_versions, [:screenplay_id])
    create index(:audio_versions, [:submitted_by_id])
    create index(:audio_versions, [:author_pick])
    create index(:audio_versions, [:likes])
    create index(:audio_versions, [:inserted_at])
  end
end
