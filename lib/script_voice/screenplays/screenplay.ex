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
    field :script_content, :string  # The actual screenplay text content
    field :likes, :integer, default: 0
    field :audio_version_count, :integer, default: 0

    # Version tracking
    field :version, :integer, default: 1
    field :version_notes, :string
    field :last_updated_at, :utc_datetime

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
    |> cast(attrs, [:title, :genre, :logline, :page_count, :pdf_url, :script_content, :writer_id, :writer_name, :version, :version_notes, :last_updated_at])
    |> cast_embed(:characters)
    |> validate_required([:title, :genre, :logline, :writer_id])
    |> validate_inclusion(:genre, @genres)
    |> validate_length(:title, min: 1, max: 200)
    |> validate_length(:logline, min: 10, max: 300)
    |> validate_number(:page_count, greater_than: 0, less_than: 500)
    |> foreign_key_constraint(:writer_id)
  end

  @doc """
  Changeset for updating screenplay content (increments version).
  """
  def update_changeset(screenplay, attrs) do
    # Check if content is actually changing
    content_fields = [:title, :logline, :script_content, :pdf_url, :page_count]
    content_changing = Enum.any?(content_fields, fn field ->
      new_val = Map.get(attrs, to_string(field)) || Map.get(attrs, field)
      old_val = Map.get(screenplay, field)
      new_val != nil && new_val != old_val
    end)

    changeset = changeset(screenplay, attrs)

    if content_changing do
      changeset
      |> put_change(:version, (screenplay.version || 1) + 1)
      |> put_change(:last_updated_at, DateTime.utc_now())
    else
      changeset
    end
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
