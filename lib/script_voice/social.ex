defmodule ScriptVoice.Social do
  @moduledoc """
  The Social context manages likes and social interactions.
  """

  import Ecto.Query, warn: false
  alias ScriptVoice.Repo
  alias ScriptVoice.Social.Like
  alias ScriptVoice.Screenplays
  alias ScriptVoice.Audio

  # ============================================================================
  # LIKES
  # ============================================================================

  @doc """
  Toggles a like for a target (screenplay or audio_version).
  Returns {:ok, :liked} or {:ok, :unliked}
  """
  def toggle_like(user_id, target_type, target_id)
      when target_type in ["screenplay", "audio_version"] do
    existing_like =
      Repo.get_by(Like, user_id: user_id, target_type: target_type, target_id: target_id)

    if existing_like do
      # Unlike
      {:ok, _} = Repo.delete(existing_like)
      update_like_count(target_type, target_id, -1)
      {:ok, :unliked}
    else
      # Like
      %Like{}
      |> Like.changeset(%{
        user_id: user_id,
        target_type: target_type,
        target_id: target_id
      })
      |> Repo.insert()
      |> case do
        {:ok, _like} ->
          update_like_count(target_type, target_id, 1)
          {:ok, :liked}

        {:error, _} ->
          {:error, :failed}
      end
    end
  end

  defp update_like_count("screenplay", id, change) do
    case Screenplays.get_screenplay(id) do
      nil -> :ok
      screenplay when change > 0 -> Screenplays.increment_likes(screenplay)
      screenplay when change < 0 -> Screenplays.decrement_likes(screenplay)
      _ -> :ok
    end
  end

  defp update_like_count("audio_version", id, change) do
    case Audio.get_audio_version(id) do
      nil -> :ok
      audio when change > 0 -> Audio.increment_likes(audio)
      audio when change < 0 -> Audio.decrement_likes(audio)
      _ -> :ok
    end
  end

  @doc """
  Checks if a user has liked a target.
  """
  def liked?(user_id, target_type, target_id) when is_binary(user_id) do
    Repo.exists?(
      from(l in Like,
        where:
          l.user_id == ^user_id and
            l.target_type == ^target_type and
            l.target_id == ^target_id
      )
    )
  end

  def liked?(_, _, _), do: false

  @doc """
  Gets all liked screenplay IDs for a user.
  """
  def get_liked_screenplay_ids(user_id) when is_binary(user_id) do
    from(l in Like,
      where: l.user_id == ^user_id and l.target_type == "screenplay",
      select: l.target_id
    )
    |> Repo.all()
  end

  def get_liked_screenplay_ids(_), do: []

  @doc """
  Gets all liked audio version IDs for a user.
  """
  def get_liked_audio_ids(user_id) when is_binary(user_id) do
    from(l in Like,
      where: l.user_id == ^user_id and l.target_type == "audio_version",
      select: l.target_id
    )
    |> Repo.all()
  end

  def get_liked_audio_ids(_), do: []

  @doc """
  Gets all likes for a user (both screenplays and audio versions).
  """
  def get_user_likes(user_id) when is_binary(user_id) do
    %{
      screenplay_ids: get_liked_screenplay_ids(user_id),
      audio_ids: get_liked_audio_ids(user_id)
    }
  end

  def get_user_likes(_), do: %{screenplay_ids: [], audio_ids: []}

  @doc """
  Gets the total like count for a user's content (screenplays and audio versions).
  """
  def get_user_total_received_likes(user_id) do
    # This would need to aggregate likes across the user's screenplays and audio versions
    # For now, return a placeholder
    0
  end
end
