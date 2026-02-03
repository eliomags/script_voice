defmodule ScriptVoice.Repo.Migrations.AddEpisodeFieldsToScreenplays do
  use Ecto.Migration

  def change do
    alter table(:screenplays) do
      # Parent references (nullable for standalone screenplays)
      add :project_id, references(:screenplay_projects, type: :binary_id, on_delete: :nilify_all)
      add :season_id, references(:screenplay_seasons, type: :binary_id, on_delete: :nilify_all)

      # Episode organization
      add :episode_number, :integer
      add :episode_code, :string  # "S01E05", "E005", etc.
      add :screenplay_type, :string, null: false, default: "standalone"
      add :is_published, :boolean, null: false, default: true
      add :air_date, :date

      # Episode-specific content
      add :cold_open, :text
      add :act_breaks, {:array, :integer}
    end

    # Indexes for efficient querying
    create index(:screenplays, [:project_id])
    create index(:screenplays, [:season_id])
    create index(:screenplays, [:screenplay_type])
    create index(:screenplays, [:project_id, :episode_number])
    create index(:screenplays, [:season_id, :episode_number])
  end
end
