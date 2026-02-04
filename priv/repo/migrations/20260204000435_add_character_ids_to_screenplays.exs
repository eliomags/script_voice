defmodule ScriptVoice.Repo.Migrations.AddCharacterIdsToScreenplays do
  use Ecto.Migration

  def change do
    alter table(:screenplays) do
      add :character_ids, {:array, :binary_id}, default: []
    end

    create index(:screenplays, [:character_ids], using: :gin)
  end
end
