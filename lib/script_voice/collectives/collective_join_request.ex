defmodule ScriptVoice.Collectives.CollectiveJoinRequest do
  @moduledoc """
  Schema for collective join requests.

  Join requests are initiated by voice artists who want to join a collective.
  Admins can approve or reject the request.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(pending approved rejected)

  schema "collective_join_requests" do
    field :status, :string, default: "pending"
    field :message, :string
    field :response_message, :string
    field :reviewed_at, :utc_datetime

    belongs_to :collective, ScriptVoice.Collectives.Collective
    belongs_to :user, ScriptVoice.Accounts.User
    belongs_to :reviewed_by, ScriptVoice.Accounts.User

    has_many :messages, ScriptVoice.Collectives.JoinRequestMessage, foreign_key: :join_request_id

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating a new join request.
  """
  def changeset(request, attrs) do
    request
    |> cast(attrs, [:collective_id, :user_id, :message])
    |> validate_required([:collective_id, :user_id])
    |> validate_length(:message, max: 500)
    |> foreign_key_constraint(:collective_id)
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Changeset for reviewing a join request (approve/reject).
  """
  def review_changeset(request, attrs) do
    request
    |> cast(attrs, [:status, :response_message, :reviewed_by_id, :reviewed_at])
    |> validate_required([:status, :reviewed_by_id, :reviewed_at])
    |> validate_inclusion(:status, ["approved", "rejected"])
    |> validate_length(:response_message, max: 500)
    |> foreign_key_constraint(:reviewed_by_id)
  end

  @doc """
  Changeset for adding an admin note/message to a pending request.
  """
  def note_changeset(request, attrs) do
    request
    |> cast(attrs, [:response_message])
    |> validate_length(:response_message, max: 500)
  end
end
