defmodule ScriptVoice.Screenplays.ScreenplayProject do
  @moduledoc """
  Schema for screenplay projects (series, anthologies, miniseries).

  A project is a container for multiple episodes/screenplays, optionally
  organized into seasons.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias ScriptVoice.Screenplays.{Screenplay, ScreenplaySeason, SeriesBible, ProjectCharacter}
  alias ScriptVoice.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @project_types ~w(series limited_series miniseries anthology web_series feature_film documentary_series podcast_drama short_film_collection)
  @statuses ~w(active in_development completed hiatus cancelled archived)
  @genres ~w(Drama Comedy Thriller Sci-Fi Fantasy Romance Horror Action Adventure Crime Mystery Documentary Animation Musical Western Historical Family Other)
  @episode_formats ~w(15min 30min 45min 60min 90min feature short variable)

  schema "screenplay_projects" do
    field :title, :string
    field :project_type, :string, default: "series"
    field :genre, :string
    field :logline, :string
    field :description, :string
    field :cover_image_url, :string
    field :status, :string, default: "active"
    field :total_seasons, :integer
    field :total_episodes, :integer
    field :episode_format, :string
    field :likes, :integer, default: 0
    field :owner_name, :string
    field :is_public, :boolean, default: false

    belongs_to :owner, User
    has_one :series_bible, SeriesBible, foreign_key: :project_id
    has_many :seasons, ScreenplaySeason, foreign_key: :project_id
    has_many :characters, ProjectCharacter, foreign_key: :project_id
    has_many :episodes, Screenplay, foreign_key: :project_id

    timestamps(type: :utc_datetime)
  end

  def changeset(project, attrs) do
    project
    |> cast(attrs, [
      :title, :project_type, :genre, :logline, :description,
      :cover_image_url, :status, :total_seasons, :total_episodes,
      :episode_format, :owner_id, :owner_name, :is_public
    ])
    |> validate_required([:title, :genre, :logline, :owner_id])
    |> validate_inclusion(:project_type, @project_types)
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:genre, @genres)
    |> validate_episode_format()
    |> validate_length(:title, min: 1, max: 200)
    |> validate_length(:logline, min: 10, max: 500)
    |> validate_number(:total_seasons, greater_than: 0, less_than: 100)
    |> validate_number(:total_episodes, greater_than: 0, less_than: 1000)
    |> foreign_key_constraint(:owner_id)
  end

  defp validate_episode_format(changeset) do
    case get_field(changeset, :episode_format) do
      nil -> changeset
      format when format in @episode_formats -> changeset
      _ -> add_error(changeset, :episode_format, "is invalid")
    end
  end

  def project_types, do: @project_types
  def statuses, do: @statuses
  def genres, do: @genres
  def episode_formats, do: @episode_formats
end
