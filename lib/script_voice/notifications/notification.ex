defmodule ScriptVoice.Notifications.Notification do
  @moduledoc """
  Schema for user notifications.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @types ~w(
    commission_request_received
    commission_accepted
    commission_declined
    submission_received
    revision_requested
    commission_completed
    commission_cancelled
    message_received
    payment_received
    payment_released
  )

  schema "notifications" do
    field :type, :string
    field :title, :string
    field :body, :string

    field :related_type, :string
    field :related_id, :binary_id

    field :action_url, :string

    field :read_at, :utc_datetime
    field :email_sent_at, :utc_datetime

    belongs_to :user, ScriptVoice.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [
      :user_id,
      :type,
      :title,
      :body,
      :related_type,
      :related_id,
      :action_url,
      :read_at,
      :email_sent_at
    ])
    |> validate_required([:user_id, :type, :title])
    |> validate_inclusion(:type, @types)
    |> validate_length(:title, max: 200)
    |> validate_length(:action_url, max: 500)
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Changeset for marking notification as read.
  """
  def mark_read_changeset(notification) do
    put_change(notification, :read_at, DateTime.utc_now() |> DateTime.truncate(:second))
  end

  @doc """
  Changeset for marking email as sent.
  """
  def email_sent_changeset(notification) do
    put_change(notification, :email_sent_at, DateTime.utc_now() |> DateTime.truncate(:second))
  end

  @doc """
  Returns all valid notification types.
  """
  def types, do: @types
end
