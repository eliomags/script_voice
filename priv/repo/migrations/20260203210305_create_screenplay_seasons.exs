defmodule ScriptVoice.Repo.Migrations.CreateScreenplaySeasons do
  use Ecto.Migration

  def change do
    create table(:screenplay_seasons, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :season_number, :integer, null: false
      add :title, :string
      add :description, :text
      add :episode_count, :integer
      add :status, :string, null: false, default: "in_progress"
      add :premiere_date, :date

      add :project_id, references(:screenplay_projects, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:screenplay_seasons, [:project_id])
    create unique_index(:screenplay_seasons, [:project_id, :season_number], name: :seasons_project_number_unique)
  end
end
