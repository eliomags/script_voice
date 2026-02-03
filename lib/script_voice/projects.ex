defmodule ScriptVoice.Projects do
  @moduledoc """
  Context for managing screenplay projects (series/anthology organization).

  Projects contain episodes (screenplays) that can be organized into seasons.
  Each project can have a series bible and project-level characters.
  """

  import Ecto.Query
  alias ScriptVoice.Repo
  alias ScriptVoice.Screenplays.{ScreenplayProject, ScreenplaySeason, SeriesBible, ProjectCharacter, Screenplay}
  alias ScriptVoice.Accounts.User

  # ===========================================================================
  # PROJECT CRUD
  # ===========================================================================

  @doc """
  Lists all projects for a writer.
  """
  def list_projects_for_writer(writer_id, opts \\ []) do
    limit = Keyword.get(opts, :limit)
    status = Keyword.get(opts, :status)

    query = from p in ScreenplayProject,
      where: p.owner_id == ^writer_id,
      order_by: [desc: p.updated_at]

    query = if status, do: where(query, [p], p.status == ^status), else: query
    query = if limit, do: limit(query, ^limit), else: query

    Repo.all(query)
  end

  @doc """
  Gets a single project by ID.
  """
  def get_project(id), do: Repo.get(ScreenplayProject, id)

  @doc """
  Gets a single project by ID, raises if not found.
  """
  def get_project!(id), do: Repo.get!(ScreenplayProject, id)

  @doc """
  Gets a project with all preloads (seasons, episodes, bible, characters).
  """
  def get_project_with_preloads(id) do
    ScreenplayProject
    |> Repo.get(id)
    |> Repo.preload([
      :series_bible,
      :characters,
      seasons: [episodes: :writer],
      episodes: :writer
    ])
  end

  @doc """
  Creates a new project.
  """
  def create_project(attrs, %User{} = owner) do
    attrs = Map.merge(attrs, %{
      "owner_id" => owner.id,
      "owner_name" => owner.name
    })

    %ScreenplayProject{}
    |> ScreenplayProject.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a project.
  """
  def update_project(%ScreenplayProject{} = project, attrs) do
    project
    |> ScreenplayProject.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a project and all associated data.
  """
  def delete_project(%ScreenplayProject{} = project) do
    Repo.delete(project)
  end

  @doc """
  Returns a changeset for tracking project changes.
  """
  def change_project(%ScreenplayProject{} = project, attrs \\ %{}) do
    ScreenplayProject.changeset(project, attrs)
  end

  # ===========================================================================
  # SEASON MANAGEMENT
  # ===========================================================================

  @doc """
  Lists all seasons for a project, ordered by season number.
  """
  def list_seasons_for_project(project_id) do
    ScreenplaySeason
    |> where([s], s.project_id == ^project_id)
    |> order_by([s], s.season_number)
    |> preload([episodes: :writer])
    |> Repo.all()
  end

  @doc """
  Gets a season by ID.
  """
  def get_season(id), do: Repo.get(ScreenplaySeason, id)

  @doc """
  Gets a season by ID, raises if not found.
  """
  def get_season!(id), do: Repo.get!(ScreenplaySeason, id)

  @doc """
  Gets a season with episodes preloaded.
  """
  def get_season_with_episodes(id) do
    ScreenplaySeason
    |> Repo.get(id)
    |> Repo.preload([episodes: :writer])
  end

  @doc """
  Creates a new season for a project.
  """
  def create_season(%ScreenplayProject{} = project, attrs) do
    attrs = Map.put(attrs, "project_id", project.id)

    # Auto-set season number if not provided
    attrs = if Map.has_key?(attrs, "season_number") || Map.has_key?(attrs, :season_number) do
      attrs
    else
      next_number = get_next_season_number(project.id)
      Map.put(attrs, "season_number", next_number)
    end

    %ScreenplaySeason{}
    |> ScreenplaySeason.changeset(attrs)
    |> Repo.insert()
  end

  defp get_next_season_number(project_id) do
    query = from s in ScreenplaySeason,
      where: s.project_id == ^project_id,
      select: max(s.season_number)

    case Repo.one(query) do
      nil -> 1
      max_number -> max_number + 1
    end
  end

  @doc """
  Updates a season.
  """
  def update_season(%ScreenplaySeason{} = season, attrs) do
    season
    |> ScreenplaySeason.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a season (episodes will have season_id set to nil).
  """
  def delete_season(%ScreenplaySeason{} = season) do
    Repo.delete(season)
  end

  @doc """
  Returns a changeset for tracking season changes.
  """
  def change_season(%ScreenplaySeason{} = season, attrs \\ %{}) do
    ScreenplaySeason.changeset(season, attrs)
  end

  # ===========================================================================
  # EPISODE MANAGEMENT
  # ===========================================================================

  @doc """
  Lists all episodes for a project, ordered by season and episode number.
  """
  def list_episodes_for_project(project_id) do
    Screenplay
    |> where([s], s.project_id == ^project_id)
    |> order_by([s], [asc: s.season_id, asc: s.episode_number])
    |> preload(:writer)
    |> Repo.all()
  end

  @doc """
  Lists episodes for a specific season.
  """
  def list_episodes_for_season(season_id) do
    Screenplay
    |> where([s], s.season_id == ^season_id)
    |> order_by([s], asc: s.episode_number)
    |> preload(:writer)
    |> Repo.all()
  end

  @doc """
  Adds a screenplay as an episode to a project (flat organization).
  """
  def add_episode_to_project(%ScreenplayProject{} = project, %Screenplay{} = screenplay, attrs \\ %{}) do
    episode_number = Map.get(attrs, "episode_number") || Map.get(attrs, :episode_number) || get_next_episode_number(project.id, nil)

    episode_code = Screenplay.generate_episode_code(nil, episode_number)

    screenplay
    |> Screenplay.changeset(%{
      "project_id" => project.id,
      "episode_number" => episode_number,
      "episode_code" => episode_code,
      "screenplay_type" => Map.get(attrs, "screenplay_type", "episode")
    })
    |> Repo.update()
  end

  @doc """
  Adds a screenplay as an episode to a season.
  """
  def add_episode_to_season(%ScreenplaySeason{} = season, %Screenplay{} = screenplay, attrs \\ %{}) do
    episode_number = Map.get(attrs, "episode_number") || Map.get(attrs, :episode_number) || get_next_episode_number(season.project_id, season.id)

    episode_code = Screenplay.generate_episode_code(season.season_number, episode_number)

    screenplay
    |> Screenplay.changeset(%{
      "project_id" => season.project_id,
      "season_id" => season.id,
      "episode_number" => episode_number,
      "episode_code" => episode_code,
      "screenplay_type" => Map.get(attrs, "screenplay_type", "episode")
    })
    |> Repo.update()
  end

  defp get_next_episode_number(project_id, season_id) do
    query = from s in Screenplay,
      where: s.project_id == ^project_id,
      select: max(s.episode_number)

    query = if season_id do
      where(query, [s], s.season_id == ^season_id)
    else
      where(query, [s], is_nil(s.season_id))
    end

    case Repo.one(query) do
      nil -> 1
      max_number -> max_number + 1
    end
  end

  @doc """
  Removes a screenplay from a project (makes it standalone again).
  """
  def remove_episode(%Screenplay{} = screenplay) do
    screenplay
    |> Screenplay.changeset(%{
      "project_id" => nil,
      "season_id" => nil,
      "episode_number" => nil,
      "episode_code" => nil,
      "screenplay_type" => "standalone"
    })
    |> Repo.update()
  end

  @doc """
  Moves an episode to a different season.
  """
  def move_episode_to_season(%Screenplay{} = screenplay, %ScreenplaySeason{} = season, episode_number \\ nil) do
    episode_number = episode_number || get_next_episode_number(season.project_id, season.id)
    episode_code = Screenplay.generate_episode_code(season.season_number, episode_number)

    screenplay
    |> Screenplay.changeset(%{
      "season_id" => season.id,
      "episode_number" => episode_number,
      "episode_code" => episode_code
    })
    |> Repo.update()
  end

  # ===========================================================================
  # SERIES BIBLE
  # ===========================================================================

  @doc """
  Gets the series bible for a project.
  """
  def get_series_bible(project_id) do
    SeriesBible
    |> where([b], b.project_id == ^project_id)
    |> Repo.one()
  end

  @doc """
  Creates or updates a series bible for a project.
  """
  def create_or_update_series_bible(%ScreenplayProject{} = project, attrs) do
    attrs = Map.put(attrs, "project_id", project.id)

    case get_series_bible(project.id) do
      nil ->
        %SeriesBible{}
        |> SeriesBible.changeset(attrs)
        |> Repo.insert()

      bible ->
        bible
        |> SeriesBible.update_changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Deletes a series bible.
  """
  def delete_series_bible(%SeriesBible{} = bible) do
    Repo.delete(bible)
  end

  @doc """
  Returns a changeset for tracking series bible changes.
  """
  def change_series_bible(%SeriesBible{} = bible, attrs \\ %{}) do
    SeriesBible.changeset(bible, attrs)
  end

  # ===========================================================================
  # PROJECT CHARACTERS
  # ===========================================================================

  @doc """
  Lists all characters for a project.
  """
  def list_characters_for_project(project_id, opts \\ []) do
    role_type = Keyword.get(opts, :role_type)
    active_only = Keyword.get(opts, :active_only, true)

    query = from c in ProjectCharacter,
      where: c.project_id == ^project_id,
      order_by: [
        asc: fragment("CASE role_type WHEN 'lead' THEN 1 WHEN 'supporting' THEN 2 WHEN 'recurring' THEN 3 WHEN 'guest' THEN 4 END"),
        asc: c.name
      ]

    query = if role_type, do: where(query, [c], c.role_type == ^role_type), else: query
    query = if active_only, do: where(query, [c], c.is_active == true), else: query

    Repo.all(query)
  end

  @doc """
  Gets a character by ID.
  """
  def get_character(id), do: Repo.get(ProjectCharacter, id)

  @doc """
  Gets a character by ID, raises if not found.
  """
  def get_character!(id), do: Repo.get!(ProjectCharacter, id)

  @doc """
  Creates a character for a project.
  """
  def create_character(%ScreenplayProject{} = project, attrs) do
    attrs = Map.put(attrs, "project_id", project.id)

    %ProjectCharacter{}
    |> ProjectCharacter.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a character.
  """
  def update_character(%ProjectCharacter{} = character, attrs) do
    character
    |> ProjectCharacter.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a character.
  """
  def delete_character(%ProjectCharacter{} = character) do
    Repo.delete(character)
  end

  @doc """
  Returns a changeset for tracking character changes.
  """
  def change_character(%ProjectCharacter{} = character, attrs \\ %{}) do
    ProjectCharacter.changeset(character, attrs)
  end

  # ===========================================================================
  # QUERIES
  # ===========================================================================

  @doc """
  Gets statistics for a project.
  """
  def get_project_stats(project_id) do
    season_count = Repo.one(
      from s in ScreenplaySeason,
        where: s.project_id == ^project_id,
        select: count()
    )

    episode_count = Repo.one(
      from s in Screenplay,
        where: s.project_id == ^project_id,
        select: count()
    )

    total_pages = Repo.one(
      from s in Screenplay,
        where: s.project_id == ^project_id,
        select: sum(s.page_count)
    ) || 0

    audio_count = Repo.one(
      from s in Screenplay,
        where: s.project_id == ^project_id,
        select: sum(s.audio_version_count)
    ) || 0

    %{
      season_count: season_count,
      episode_count: episode_count,
      total_pages: total_pages,
      audio_count: audio_count
    }
  end

  @doc """
  Gets standalone screenplays for a writer (not linked to any project).
  """
  def get_standalone_screenplays_for_writer(writer_id) do
    Screenplay
    |> where([s], s.writer_id == ^writer_id)
    |> where([s], is_nil(s.project_id))
    |> order_by([s], desc: s.inserted_at)
    |> Repo.all()
  end
end
