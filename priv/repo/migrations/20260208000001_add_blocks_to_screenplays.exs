defmodule ScriptVoice.Repo.Migrations.AddBlocksToScreenplays do
  use Ecto.Migration

  def change do
    alter table(:screenplays) do
      add :blocks, :jsonb, default: "[]"
    end
  end
end
