defmodule ScriptVoice.Repo.Migrations.CreateVerificationCodes do
  use Ecto.Migration

  def change do
    create table(:verification_codes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :code, :string, null: false
      add :type, :string, null: false  # "phone" or "email"
      add :target, :string, null: false  # phone number or email
      add :expires_at, :utc_datetime, null: false
      add :verified_at, :utc_datetime
      add :attempts, :integer, null: false, default: 0

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:verification_codes, [:user_id])
    create index(:verification_codes, [:target, :type])
    create index(:verification_codes, [:expires_at])
  end
end
