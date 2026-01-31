defmodule ScriptVoice.Screenplays.Screenplay do
  @moduledoc """
  Screenplay schema for ScriptVoice.

  Screenplays are uploaded by writers and can have multiple audio versions.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias ScriptVoice.Screenplays.Character

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @genres ~w(Drama Comedy Thriller Sci-Fi Romance Horror Action Other)

  schema "screenplays" do
    field :title, :string
    field :genre, :string
    field :logline, :string
    field :page_count, :integer
    field :pdf_url, :string
    field :likes, :integer, default: 0
    field :audio_version_count, :integer, default: 0

    # Denormalized writer name for easy display
    field :writer_name, :string

    # Characters as embedded schema
    embeds_many :characters, Character, on_replace: :delete

    belongs_to :writer, ScriptVoice.Accounts.User
    has_many :audio_versions, ScriptVoice.Audio.AudioVersion

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating/updating a screenplay.
  """
  def changeset(screenplay, attrs) do
    screenplay
    |> cast(attrs, [:title, :genre, :logline, :page_count, :pdf_url, :writer_id, :writer_name])
    |> cast_embed(:characters)
    |> validate_required([:title, :genre, :logline, :writer_id])
    |> validate_inclusion(:genre, @genres)
    |> validate_length(:title, min: 1, max: 200)
    |> validate_length(:logline, min: 10, max: 300)
    |> validate_number(:page_count, greater_than: 0, less_than: 500)
    |> foreign_key_constraint(:writer_id)
  end

  @doc """
  Changeset for updating like count.
  """
  def like_changeset(screenplay, change) do
    new_count = max(0, screenplay.likes + change)

    screenplay
    |> change(likes: new_count)
  end

  @doc """
  Changeset for updating audio version count.
  """
  def audio_count_changeset(screenplay, change) do
    new_count = max(0, screenplay.audio_version_count + change)

    screenplay
    |> change(audio_version_count: new_count)
  end

  @doc """
  List of available genres.
  """
  def genres, do: @genres
end
