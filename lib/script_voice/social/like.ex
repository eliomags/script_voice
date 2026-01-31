defmodule ScriptVoice.Social.Like do
  @moduledoc """
  Like schema for tracking user likes on screenplays and audio versions.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @target_types ~w(screenplay audio_version)

  schema "likes" do
    field :target_type, :string  # "screenplay" or "audio_version"
    field :target_id, :binary_id

    belongs_to :user, ScriptVoice.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating a like.
  """
  def changeset(like, attrs) do
    like
    |> cast(attrs, [:target_type, :target_id, :user_id])
    |> validate_required([:target_type, :target_id, :user_id])
    |> validate_inclusion(:target_type, @target_types)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:user_id, :target_type, :target_id], name: :likes_user_target_unique)
  end
end
