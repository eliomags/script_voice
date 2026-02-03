defmodule ScriptVoice.Repo.Migrations.CreateCollectives do
  use Ecto.Migration

  def change do
    create table(:collectives, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :bio, :text
      add :avatar_url, :string
      add :profile_video_url, :string
      add :social_links, {:array, :string}, default: []
      add :is_accepting_commissions, :boolean, default: true, null: false
      add :creator_id, references(:users, type: :binary_id, on_delete: :nilify_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:collectives, [:slug])
    create index(:collectives, [:creator_id])
    create index(:collectives, [:is_accepting_commissions])
  end
end
