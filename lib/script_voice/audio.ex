defmodule ScriptVoice.Audio do
  @moduledoc """
  The Audio context manages audio versions of screenplays.
  """

  import Ecto.Query, warn: false
  alias ScriptVoice.Repo
  alias ScriptVoice.Audio.AudioVersion
  alias ScriptVoice.Screenplays
  alias ScriptVoice.Accounts.User

  # ============================================================================
  # AUDIO VERSION CRUD
  # ============================================================================

  @doc """
  Returns audio versions for a screenplay with optional sorting.

  Options:
  - `:sort` - :recent, :popular, :author_picks
  """
  def list_audio_versions_for_screenplay(screenplay_id, opts \\ []) do
    sort = Keyword.get(opts, :sort, :recent)

    AudioVersion
    |> where([av], av.screenplay_id == ^screenplay_id)
    |> apply_audio_sort(sort)
    |> Repo.all()
    |> Repo.preload([:collective, :submitted_by])
  end

  defp apply_audio_sort(query, :recent), do: order_by(query, [av], desc: av.inserted_at)
  defp apply_audio_sort(query, :popular), do: order_by(query, [av], desc: av.likes)

  defp apply_audio_sort(query, :author_picks) do
    order_by(query, [av], [desc: av.author_pick, desc: av.inserted_at])
  end

  defp apply_audio_sort(query, _), do: order_by(query, [av], desc: av.inserted_at)

  @doc """
  Gets a single audio version.
  """
  def get_audio_version(id) when is_binary(id) do
    Repo.get(AudioVersion, id)
  end

  def get_audio_version(_), do: nil

  @doc """
  Gets a single audio version with preloaded associations.
  """
  def get_audio_version_with_preloads(id) do
    AudioVersion
    |> Repo.get(id)
    |> Repo.preload([:screenplay, :submitted_by, :collective])
  end

  @doc """
  Creates an audio version.
  """
  def create_audio_version(attrs \\ %{}, %User{} = submitter, screenplay) do
    # Determine if all performers are verified
    verified = submitter.verification_status == "verified"

    # Track which script version this audio is recorded for
    script_version = screenplay.version || 1

    attrs_with_associations =
      attrs
      |> Map.put("submitted_by_id", submitter.id)
      |> Map.put("screenplay_id", screenplay.id)
      |> Map.put("verified", verified)
      |> Map.put("script_version", script_version)

    result =
      %AudioVersion{}
      |> AudioVersion.changeset(attrs_with_associations)
      |> Repo.insert()

    case result do
      {:ok, audio_version} ->
        # Increment screenplay's audio count
        Screenplays.increment_audio_count(screenplay)
        {:ok, audio_version}

      error ->
        error
    end
  end

  @doc """
  Updates an audio version.
  """
  def update_audio_version(%AudioVersion{} = audio_version, attrs) do
    audio_version
    |> AudioVersion.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes an audio version.
  """
  def delete_audio_version(%AudioVersion{} = audio_version) do
    screenplay = Screenplays.get_screenplay(audio_version.screenplay_id)

    result = Repo.delete(audio_version)

    case result do
      {:ok, _} ->
        if screenplay, do: Screenplays.decrement_audio_count(screenplay)
        result

      error ->
        error
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking audio version changes.
  """
  def change_audio_version(%AudioVersion{} = audio_version, attrs \\ %{}) do
    AudioVersion.changeset(audio_version, attrs)
  end

  # ============================================================================
  # LIKES
  # ============================================================================

  @doc """
  Increments the like count for an audio version.
  """
  def increment_likes(%AudioVersion{} = audio_version) do
    audio_version
    |> AudioVersion.like_changeset(1)
    |> Repo.update()
  end

  @doc """
  Decrements the like count for an audio version.
  """
  def decrement_likes(%AudioVersion{} = audio_version) do
    audio_version
    |> AudioVersion.like_changeset(-1)
    |> Repo.update()
  end

  # ============================================================================
  # AUTHOR PICKS
  # ============================================================================

  @doc """
  Toggles the author pick status for an audio version.
  """
  def toggle_author_pick(%AudioVersion{} = audio_version) do
    audio_version
    |> AudioVersion.author_pick_changeset(!audio_version.author_pick)
    |> Repo.update()
  end

  @doc """
  Sets the author pick status for an audio version.
  """
  def set_author_pick(%AudioVersion{} = audio_version, is_picked) when is_boolean(is_picked) do
    audio_version
    |> AudioVersion.author_pick_changeset(is_picked)
    |> Repo.update()
  end

  @doc """
  Gets all author picks for a screenplay.
  """
  def get_author_picks(screenplay_id) do
    AudioVersion
    |> where([av], av.screenplay_id == ^screenplay_id and av.author_pick == true)
    |> order_by([av], desc: av.inserted_at)
    |> Repo.all()
  end

  # ============================================================================
  # USER'S AUDIO VERSIONS
  # ============================================================================

  @doc """
  Gets all audio versions submitted by a user.
  """
  def list_audio_versions_by_user(user_id) do
    # Get collective IDs where the user is a member
    collective_ids = get_user_collective_ids(user_id)

    # Get audio versions where user submitted them OR they're from user's collectives
    AudioVersion
    |> where([av], av.submitted_by_id == ^user_id or av.collective_id in ^collective_ids)
    |> order_by([av], desc: av.inserted_at)
    |> Repo.all()
    |> Repo.preload([:screenplay, :collective])
    |> Enum.uniq_by(& &1.id)  # Remove duplicates (if user both submitted and is in collective)
  end

  defp get_user_collective_ids(user_id) do
    import Ecto.Query

    from(m in ScriptVoice.Collectives.CollectiveMembership,
      where: m.user_id == ^user_id,
      select: m.collective_id
    )
    |> Repo.all()
  end

  @doc """
  Gets all audio versions by a collective.
  """
  def list_audio_versions_by_collective(collective_id) do
    AudioVersion
    |> where([av], av.collective_id == ^collective_id)
    |> order_by([av], desc: av.inserted_at)
    |> Repo.all()
    |> Repo.preload([:screenplay, :submitted_by])
  end
end
