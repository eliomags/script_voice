defmodule ScriptVoice.Repo.Migrations.CreateSeriesBibles do
  use Ecto.Migration

  def change do
    create table(:series_bibles, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :content, :text
      add :pdf_url, :string
      add :world_building, :text
      add :tone_style, :text
      add :themes, {:array, :string}, null: false, default: []
      add :version, :integer, null: false, default: 1
      add :last_updated_at, :utc_datetime

      add :project_id, references(:screenplay_projects, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    # One bible per project
    create unique_index(:series_bibles, [:project_id])
  end
end
