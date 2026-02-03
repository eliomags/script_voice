defmodule ScriptVoice.Repo.Migrations.CreateCollectiveInvitations do
  use Ecto.Migration

  def change do
    create table(:collective_invitations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :collective_id, references(:collectives, type: :binary_id, on_delete: :delete_all), null: false
      add :inviter_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :invitee_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :status, :string, null: false, default: "pending"  # pending, accepted, declined, expired
      add :message, :text  # optional message from inviter
      add :response_message, :text  # optional message from invitee
      add :responded_at, :utc_datetime
      add :expires_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:collective_invitations, [:collective_id])
    create index(:collective_invitations, [:invitee_id])
    create index(:collective_invitations, [:inviter_id])
    # Unique constraint: only one pending invitation per collective-invitee pair
    create unique_index(:collective_invitations, [:collective_id, :invitee_id],
      where: "status = 'pending'",
      name: :collective_invitations_pending_unique_idx
    )
  end
end
