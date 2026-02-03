defmodule ScriptVoice.Collectives.CollectiveInvitation do
  @moduledoc """
  Schema for collective invitations.

  Invitations are sent by admins to voice artists to join a collective.
  The invitee can accept or decline the invitation.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(pending accepted declined expired)

  schema "collective_invitations" do
    field :status, :string, default: "pending"
    field :message, :string
    field :response_message, :string
    field :responded_at, :utc_datetime
    field :expires_at, :utc_datetime

    belongs_to :collective, ScriptVoice.Collectives.Collective
    belongs_to :inviter, ScriptVoice.Accounts.User
    belongs_to :invitee, ScriptVoice.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating a new invitation.
  """
  def changeset(invitation, attrs) do
    invitation
    |> cast(attrs, [:collective_id, :inviter_id, :invitee_id, :message, :expires_at])
    |> validate_required([:collective_id, :inviter_id, :invitee_id, :expires_at])
    |> validate_inclusion(:status, @statuses)
    |> validate_length(:message, max: 500)
    |> foreign_key_constraint(:collective_id)
    |> foreign_key_constraint(:inviter_id)
    |> foreign_key_constraint(:invitee_id)
  end

  @doc """
  Changeset for responding to an invitation (accept/decline).
  """
  def response_changeset(invitation, attrs) do
    invitation
    |> cast(attrs, [:status, :response_message, :responded_at])
    |> validate_required([:status, :responded_at])
    |> validate_inclusion(:status, ["accepted", "declined"])
    |> validate_length(:response_message, max: 500)
  end

  @doc """
  Default expiration for invitations (7 days from now).
  """
  def default_expiration do
    DateTime.utc_now()
    |> DateTime.add(7, :day)
    |> DateTime.truncate(:second)
  end

  @doc """
  Check if an invitation has expired.
  """
  def expired?(%__MODULE__{expires_at: expires_at, status: "pending"}) do
    DateTime.compare(DateTime.utc_now(), expires_at) == :gt
  end
  def expired?(_), do: false
end
