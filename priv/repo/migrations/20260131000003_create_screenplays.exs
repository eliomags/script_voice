defmodule ScriptVoice.Repo.Migrations.CreateScreenplays do
  use Ecto.Migration

  def change do
    create table(:screenplays, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :genre, :string, null: false
      add :logline, :text, null: false
      add :page_count, :integer
      add :pdf_url, :string
      add :likes, :integer, null: false, default: 0
      add :audio_version_count, :integer, null: false, default: 0

      # Denormalized for easy display
      add :writer_name, :string

      # Characters stored as JSONB array
      add :characters, {:array, :map}, null: false, default: []

      add :writer_id, references(:users, type: :binary_id, on_delete: :nilify_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:screenplays, [:writer_id])
    create index(:screenplays, [:genre])
    create index(:screenplays, [:likes])
    create index(:screenplays, [:audio_version_count])
    create index(:screenplays, [:inserted_at])
  end
end
