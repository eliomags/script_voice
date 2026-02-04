defmodule ScriptVoice.Screenplays.Screenplay do
  @moduledoc """
  Screenplay schema for ScriptVoice.

  Screenplays can be standalone or belong to a project (series).
  When part of a project, they can optionally belong to a season.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias ScriptVoice.Screenplays.{Character, ScreenplayProject, ScreenplaySeason}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @genres ~w(Drama Comedy Thriller Sci-Fi Romance Horror Action Other)
  @screenplay_types ~w(standalone episode pilot finale special)

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

    # Episode fields (for series organization)
    field :episode_number, :integer
    field :episode_code, :string  # "S01E05", "E005", etc.
    field :screenplay_type, :string, default: "standalone"
    field :is_published, :boolean, default: true
    field :is_public, :boolean, default: true  # Controls visibility within projects
    field :air_date, :date
    field :cold_open, :string
    field :act_breaks, {:array, :integer}

    # Project character IDs that appear in this episode
    field :character_ids, {:array, :binary_id}, default: []

    # Characters as embedded schema (for standalone screenplays)
    embeds_many :characters, Character, on_replace: :delete

    belongs_to :writer, ScriptVoice.Accounts.User
    belongs_to :project, ScreenplayProject
    belongs_to :season, ScreenplaySeason
    has_many :audio_versions, ScriptVoice.Audio.AudioVersion

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating/updating a screenplay.
  """
  def changeset(screenplay, attrs) do
    screenplay
    |> cast(attrs, [
      :title, :genre, :logline, :page_count, :pdf_url, :script_content,
      :writer_id, :writer_name, :version, :version_notes, :last_updated_at,
      :project_id, :season_id, :episode_number, :episode_code,
      :screenplay_type, :is_published, :is_public, :air_date, :cold_open, :act_breaks,
      :character_ids
    ])
    |> cast_embed(:characters)
    |> validate_required([:title, :genre, :logline, :writer_id])
    |> validate_inclusion(:genre, @genres)
    |> validate_inclusion(:screenplay_type, @screenplay_types)
    |> validate_length(:title, min: 1, max: 200)
    |> validate_length(:logline, min: 10, max: 300)
    |> validate_number(:page_count, greater_than: 0, less_than: 500)
    |> validate_number(:episode_number, greater_than: 0, less_than: 1000)
    |> foreign_key_constraint(:writer_id)
    |> foreign_key_constraint(:project_id)
    |> foreign_key_constraint(:season_id)
    |> validate_episode_fields()
  end

  # Validate that episode fields are consistent
  defp validate_episode_fields(changeset) do
    screenplay_type = get_field(changeset, :screenplay_type)
    project_id = get_field(changeset, :project_id)

    cond do
      screenplay_type != "standalone" && is_nil(project_id) ->
        add_error(changeset, :project_id, "is required for episode screenplays")

      screenplay_type == "standalone" && !is_nil(project_id) ->
        # Auto-correct: if project_id is set, it's not standalone
        put_change(changeset, :screenplay_type, "episode")

      true ->
        changeset
    end
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
      |> put_change(:last_updated_at, DateTime.utc_now() |> DateTime.truncate(:second))
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

  @doc """
  List of available screenplay types.
  """
  def screenplay_types, do: @screenplay_types

  @doc """
  Generate episode code based on season and episode number.
  """
  def generate_episode_code(season_number, episode_number) when is_integer(season_number) and is_integer(episode_number) do
    "S#{String.pad_leading(Integer.to_string(season_number), 2, "0")}E#{String.pad_leading(Integer.to_string(episode_number), 2, "0")}"
  end

  def generate_episode_code(nil, episode_number) when is_integer(episode_number) do
    "E#{String.pad_leading(Integer.to_string(episode_number), 3, "0")}"
  end

  def generate_episode_code(_, _), do: nil
end
