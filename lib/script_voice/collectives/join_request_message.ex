defmodule ScriptVoice.Collectives.JoinRequestMessage do
  @moduledoc """
  Schema for messages in a join request conversation.
  Allows back-and-forth communication between requestor and collective admins.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "join_request_messages" do
    field :content, :string

    belongs_to :join_request, ScriptVoice.Collectives.CollectiveJoinRequest
    belongs_to :sender, ScriptVoice.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:join_request_id, :sender_id, :content])
    |> validate_required([:join_request_id, :sender_id, :content])
    |> validate_length(:content, min: 1, max: 1000)
    |> foreign_key_constraint(:join_request_id)
    |> foreign_key_constraint(:sender_id)
  end
end
