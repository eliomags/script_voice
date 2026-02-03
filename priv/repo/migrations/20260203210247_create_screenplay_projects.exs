defmodule ScriptVoice.Repo.Migrations.CreateScreenplayProjects do
  use Ecto.Migration

  def change do
    create table(:screenplay_projects, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :project_type, :string, null: false, default: "series"
      add :genre, :string, null: false
      add :logline, :text, null: false
      add :description, :text
      add :cover_image_url, :string
      add :status, :string, null: false, default: "active"
      add :total_seasons, :integer
      add :total_episodes, :integer
      add :episode_format, :string
      add :likes, :integer, null: false, default: 0

      # Denormalized owner name for easy display
      add :owner_name, :string

      add :owner_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:screenplay_projects, [:owner_id])
    create index(:screenplay_projects, [:genre])
    create index(:screenplay_projects, [:status])
    create index(:screenplay_projects, [:project_type])
    create index(:screenplay_projects, [:inserted_at])
    create index(:screenplay_projects, [:likes])
  end
end
