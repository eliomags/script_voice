defmodule ScriptVoice.Screenplays.ScreenplaySeason do
  @moduledoc """
  Schema for seasons within a screenplay project.

  Seasons are optional groupings of episodes within a project.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias ScriptVoice.Screenplays.{ScreenplayProject, Screenplay}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(planned in_progress completed)

  schema "screenplay_seasons" do
    field :season_number, :integer
    field :title, :string
    field :description, :string
    field :episode_count, :integer
    field :status, :string, default: "in_progress"
    field :premiere_date, :date

    belongs_to :project, ScreenplayProject
    has_many :episodes, Screenplay, foreign_key: :season_id

    timestamps(type: :utc_datetime)
  end

  def changeset(season, attrs) do
    season
    |> cast(attrs, [:season_number, :title, :description, :episode_count, :status, :premiere_date, :project_id])
    |> validate_required([:season_number, :project_id])
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:season_number, greater_than: 0, less_than: 100)
    |> validate_number(:episode_count, greater_than: 0, less_than: 100)
    |> foreign_key_constraint(:project_id)
    |> unique_constraint([:project_id, :season_number], name: :seasons_project_number_unique)
  end

  def statuses, do: @statuses
end
