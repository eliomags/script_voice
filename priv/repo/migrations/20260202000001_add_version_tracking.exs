defmodule ScriptVoice.Repo.Migrations.AddVersionTracking do
  use Ecto.Migration

  def change do
    # Add version tracking to screenplays
    alter table(:screenplays) do
      add :version, :integer, default: 1, null: false
      add :version_notes, :text  # Optional notes about what changed
      add :last_updated_at, :utc_datetime  # When content was last updated
    end

    # Add script version tracking to audio_versions
    alter table(:audio_versions) do
      add :script_version, :integer, default: 1  # Which screenplay version this was recorded for
    end

    # Index for quick lookups
    create index(:audio_versions, [:screenplay_id, :script_version])
  end
end
