defmodule ScriptVoice.Repo.Migrations.AddVisibilityToProjectsAndScreenplays do
  use Ecto.Migration

  def change do
    # Add is_public to projects (default false - private until ready)
    alter table(:screenplay_projects) do
      add :is_public, :boolean, default: false, null: false
    end

    # Add is_public to screenplays/episodes (default true for backwards compatibility)
    alter table(:screenplays) do
      add :is_public, :boolean, default: true, null: false
    end

    # Index for public projects query
    create index(:screenplay_projects, [:is_public])
    create index(:screenplays, [:is_public])
  end
end
