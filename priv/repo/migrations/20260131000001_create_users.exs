defmodule ScriptVoice.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :email, :citext
      add :phone, :string
      add :password_hash, :string

      # User type and verification
      add :user_type, :string, null: false, default: "visitor"
      add :verification_status, :string, null: false, default: "unverified"
      add :verification_video_url, :string
      add :verified_via, :string
      add :verified_at, :utc_datetime

      # Voice artist specific
      add :performer_type, :string
      add :group_name, :string

      # JSON fields
      add :social_links, {:array, :string}, default: []
      add :group_members, {:array, :map}, default: []

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email], where: "email IS NOT NULL")
    create unique_index(:users, [:phone], where: "phone IS NOT NULL")
    create index(:users, [:user_type])
    create index(:users, [:verification_status])
  end
end
