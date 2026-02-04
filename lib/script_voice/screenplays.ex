defmodule ScriptVoice.Screenplays do
  @moduledoc """
  The Screenplays context manages screenplays and their characters.
  """

  import Ecto.Query, warn: false
  alias ScriptVoice.Repo
  alias ScriptVoice.Screenplays.Screenplay
  alias ScriptVoice.Accounts.User

  # ============================================================================
  # SCREENPLAY CRUD
  # ============================================================================

  @doc """
  Returns the list of screenplays with optional sorting and filtering.

  Options:
  - `:sort` - :recent, :popular, :needs_audio
  - `:genre` - filter by genre
  - `:writer_id` - filter by writer
  - `:limit` - limit results
  """
  def list_screenplays(opts \\ []) do
    sort = Keyword.get(opts, :sort, :recent)
    genre = Keyword.get(opts, :genre)
    writer_id = Keyword.get(opts, :writer_id)
    limit = Keyword.get(opts, :limit)

    Screenplay
    |> apply_genre_filter(genre)
    |> apply_writer_filter(writer_id)
    |> apply_sort(sort)
    |> apply_limit(limit)
    |> Repo.all()
  end

  defp apply_genre_filter(query, nil), do: query
  defp apply_genre_filter(query, "All"), do: query
  defp apply_genre_filter(query, genre), do: where(query, [s], s.genre == ^genre)

  defp apply_writer_filter(query, nil), do: query
  defp apply_writer_filter(query, writer_id), do: where(query, [s], s.writer_id == ^writer_id)

  defp apply_sort(query, :recent), do: order_by(query, [s], desc: s.inserted_at)
  defp apply_sort(query, :popular), do: order_by(query, [s], desc: s.likes)
  defp apply_sort(query, :needs_audio), do: order_by(query, [s], asc: s.audio_version_count)
  defp apply_sort(query, _), do: order_by(query, [s], desc: s.inserted_at)

  defp apply_limit(query, nil), do: query
  defp apply_limit(query, limit), do: limit(query, ^limit)

  @doc """
  Returns the list of standalone screenplays (not part of any project).
  These are screenplays where project_id is nil.

  Options:
  - `:sort` - :recent, :popular, :needs_audio
  - `:genre` - filter by genre
  - `:limit` - limit results
  """
  def list_standalone_screenplays(opts \\ []) do
    sort = Keyword.get(opts, :sort, :recent)
    genre = Keyword.get(opts, :genre)
    limit = Keyword.get(opts, :limit)

    Screenplay
    |> where([s], is_nil(s.project_id))
    |> apply_genre_filter(genre)
    |> apply_sort(sort)
    |> apply_limit(limit)
    |> Repo.all()
  end

  @doc """
  Gets a single screenplay.
  """
  def get_screenplay(id) when is_binary(id) do
    Repo.get(Screenplay, id)
  end

  def get_screenplay(_), do: nil

  @doc """
  Gets a single screenplay, raises if not found.
  """
  def get_screenplay!(id) when is_binary(id) do
    Repo.get!(Screenplay, id)
  end

  @doc """
  Gets a single screenplay with preloaded associations.
  """
  def get_screenplay_with_preloads(id) do
    Screenplay
    |> Repo.get(id)
    |> Repo.preload([:writer, :audio_versions])
  end

  @doc """
  Creates a screenplay.
  """
  def create_screenplay(attrs \\ %{}, %User{} = writer) do
    attrs_with_writer =
      attrs
      |> Map.put("writer_id", writer.id)
      |> Map.put("writer_name", writer.name)

    %Screenplay{}
    |> Screenplay.changeset(attrs_with_writer)
    |> Repo.insert()
  end

  @doc """
  Updates a screenplay with version tracking.
  Content changes (title, logline, script_content, pdf_url, page_count)
  will increment the version number.
  """
  def update_screenplay(%Screenplay{} = screenplay, attrs) do
    screenplay
    |> Screenplay.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates a screenplay without incrementing version.
  Use this for metadata-only changes like genre.
  """
  def update_screenplay_metadata(%Screenplay{} = screenplay, attrs) do
    screenplay
    |> Screenplay.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a screenplay.
  """
  def delete_screenplay(%Screenplay{} = screenplay) do
    Repo.delete(screenplay)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking screenplay changes.
  """
  def change_screenplay(%Screenplay{} = screenplay, attrs \\ %{}) do
    Screenplay.changeset(screenplay, attrs)
  end

  # ============================================================================
  # LIKES
  # ============================================================================

  @doc """
  Increments the like count for a screenplay.
  """
  def increment_likes(%Screenplay{} = screenplay) do
    screenplay
    |> Screenplay.like_changeset(1)
    |> Repo.update()
  end

  @doc """
  Decrements the like count for a screenplay.
  """
  def decrement_likes(%Screenplay{} = screenplay) do
    screenplay
    |> Screenplay.like_changeset(-1)
    |> Repo.update()
  end

  # ============================================================================
  # AUDIO VERSION COUNT
  # ============================================================================

  @doc """
  Increments the audio version count for a screenplay.
  """
  def increment_audio_count(%Screenplay{} = screenplay) do
    screenplay
    |> Screenplay.audio_count_changeset(1)
    |> Repo.update()
  end

  @doc """
  Decrements the audio version count for a screenplay.
  """
  def decrement_audio_count(%Screenplay{} = screenplay) do
    screenplay
    |> Screenplay.audio_count_changeset(-1)
    |> Repo.update()
  end

  # ============================================================================
  # CHARACTER EXTRACTION (AI)
  # ============================================================================

  @doc """
  Extracts characters from screenplay text using AI.
  Returns a list of character maps.

  This is a placeholder - in production, integrate with Claude API or similar.
  """
  def extract_characters_from_text(text) when is_binary(text) do
    # Placeholder implementation
    # In production, send to Claude API with a prompt like:
    # "Extract all characters from this screenplay. For each character, provide:
    #  name (in CAPS), gender (Male/Female/Any/Unknown), estimated line count, brief description"

    # For now, return sample extracted characters
    # In production, this would parse the AI response
    {:ok,
     [
       %{name: "CHARACTER 1", gender: "Female", estimated_lines: 34, description: "Lead role"},
       %{name: "CHARACTER 2", gender: "Male", estimated_lines: 28, description: "Supporting"},
       %{name: "CHARACTER 3", gender: "Any", estimated_lines: 12, description: "Minor role"}
     ]}
  end

  @doc """
  Simple regex-based character extraction as fallback.
  Looks for patterns like "CHARACTER NAME:" or "CHARACTER NAME\n" in screenplay format.
  """
  def extract_characters_simple(text) when is_binary(text) do
    # Pattern: All-caps word(s) followed by newline or colon, typically dialogue
    pattern = ~r/^([A-Z][A-Z\s\-\'\.]+)(?:\s*\(.*?\))?\s*$/m

    characters =
      Regex.scan(pattern, text)
      |> Enum.map(fn [_, name] -> String.trim(name) end)
      |> Enum.uniq()
      |> Enum.reject(&(&1 in ["INT", "EXT", "CUT TO", "FADE IN", "FADE OUT", "THE END"]))
      |> Enum.map(fn name ->
        line_count = count_character_lines(text, name)

        %{
          name: name,
          gender: "Unknown",
          estimated_lines: line_count,
          description: nil
        }
      end)
      |> Enum.sort_by(& &1.estimated_lines, :desc)

    {:ok, characters}
  end

  defp count_character_lines(text, character_name) do
    pattern = ~r/^#{Regex.escape(character_name)}\s*(?:\(.*?\))?\s*$/m
    length(Regex.scan(pattern, text))
  end
end
