defmodule ScriptVoice.Repo.Migrations.AddCommissionToAudioVersions do
  use Ecto.Migration

  def change do
    alter table(:audio_versions) do
      add :commission_request_id, references(:commission_requests, type: :binary_id, on_delete: :nilify_all)
      add :is_paid_commission, :boolean, null: false, default: false
    end

    create index(:audio_versions, [:commission_request_id])
  end
end
