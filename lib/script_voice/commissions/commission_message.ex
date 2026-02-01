defmodule ScriptVoice.Commissions.CommissionMessage do
  @moduledoc """
  Schema for messages within a commission thread.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @message_types ~w(message revision_request status_update)

  schema "commission_messages" do
    field :message, :string
    field :message_type, :string, default: "message"

    field :attachment_url, :string
    field :attachment_type, :string

    field :read_at, :utc_datetime

    belongs_to :commission_request, ScriptVoice.Commissions.CommissionRequest
    belongs_to :sender, ScriptVoice.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [
      :commission_request_id,
      :sender_id,
      :message,
      :message_type,
      :attachment_url,
      :attachment_type,
      :read_at
    ])
    |> validate_required([:commission_request_id, :sender_id, :message])
    |> validate_inclusion(:message_type, @message_types)
    |> validate_length(:message, min: 1, max: 10_000)
    |> foreign_key_constraint(:commission_request_id)
    |> foreign_key_constraint(:sender_id)
  end

  @doc """
  Changeset for marking a message as read.
  """
  def mark_read_changeset(message) do
    put_change(message, :read_at, DateTime.utc_now() |> DateTime.truncate(:second))
  end

  @doc """
  Returns all valid message types.
  """
  def message_types, do: @message_types
end
