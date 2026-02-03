defmodule ScriptVoice.Repo.Migrations.AddCollectiveToAudioVersions do
  use Ecto.Migration

  def change do
    alter table(:audio_versions) do
      add :collective_id, references(:collectives, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:audio_versions, [:collective_id])
  end
end
