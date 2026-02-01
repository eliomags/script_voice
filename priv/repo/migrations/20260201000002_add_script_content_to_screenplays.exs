defmodule ScriptVoice.Repo.Migrations.AddScriptContentToScreenplays do
  use Ecto.Migration

  def change do
    alter table(:screenplays) do
      add :script_content, :text
    end
  end
end
