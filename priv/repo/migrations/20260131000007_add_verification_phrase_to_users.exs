defmodule ScriptVoice.Repo.Migrations.AddVerificationPhraseToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :verification_phrase, :string
    end
  end
end
