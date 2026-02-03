defmodule ScriptVoice.Repo.Migrations.CreateProjectCharacters do
  use Ecto.Migration

  def change do
    create table(:project_characters, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :gender, :string, null: false, default: "Unknown"
      add :age_range, :string
      add :role_type, :string, null: false, default: "recurring"
      add :description, :text
      add :backstory, :text
      add :arc_notes, :text
      add :first_appearance, :string
      add :is_active, :boolean, null: false, default: true

      add :project_id, references(:screenplay_projects, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:project_characters, [:project_id])
    create unique_index(:project_characters, [:project_id, :name], name: :project_characters_name_unique)
    create index(:project_characters, [:role_type])
  end
end
