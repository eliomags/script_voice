defmodule ScriptVoice.Screenplays do
  @moduledoc """
  The Screenplays context manages screenplays and their characters.
  """

  import Ecto.Query, warn: false
  alias ScriptVoice.Repo
  alias ScriptVoice.Screenplays.{Screenplay, StoryBlock}
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

  # ============================================================================
  # BLOCK UTILITIES
  # ============================================================================

  @doc """
  Generates plain text from story blocks for backwards compatibility,
  search indexing, and legacy display.
  """
  def blocks_to_script_content(blocks) when is_list(blocks) do
    blocks
    |> Enum.sort_by(& &1.position)
    |> Enum.map(&block_to_text/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n\n")
  end

  def blocks_to_script_content(_), do: ""

  defp block_to_text(%{type: "chapter", title: title}) when is_binary(title) do
    String.upcase(title)
  end

  defp block_to_text(%{type: "scene_break", title: title, description: desc}) do
    parts = [title, desc] |> Enum.reject(&is_nil/1) |> Enum.reject(&(&1 == ""))
    if Enum.empty?(parts), do: "---", else: Enum.join(parts, " — ")
  end

  defp block_to_text(%{type: "narration", text: text}) when is_binary(text), do: text

  defp block_to_text(%{type: "dialogue", character_name: name, text: text, parenthetical: paren}) do
    header = if paren && String.trim(paren) != "", do: "#{name} (#{paren})", else: name
    "#{header}\n#{text}"
  end

  defp block_to_text(%{type: "sfx", description: desc}) when is_binary(desc) do
    "SFX: #{String.upcase(desc)}"
  end

  defp block_to_text(%{type: "music", description: desc}) when is_binary(desc) do
    "MUSIC: #{String.upcase(desc)}"
  end

  defp block_to_text(%{type: "pause", description: desc}) do
    if desc && String.trim(desc) != "", do: "(#{desc})", else: "(BEAT)"
  end

  defp block_to_text(_), do: nil

  @doc """
  Computes story statistics from blocks.

  Returns a map with:
  - :total_words - total word count
  - :estimated_duration_minutes - estimated recording time at 150 WPM
  - :scene_count - number of scenes
  - :sfx_count - number of SFX cues
  - :music_count - number of music cues
  - :dialogue_words - word count from dialogue blocks
  - :narration_words - word count from narration blocks
  - :dialogue_ratio - ratio of dialogue words to total words
  - :characters - map of character_name => %{line_count, word_count}
  """
  def compute_story_stats(blocks) when is_list(blocks) do
    sorted = Enum.sort_by(blocks, & &1.position)

    characters =
      sorted
      |> Enum.filter(&(&1.type == "dialogue"))
      |> Enum.group_by(& &1.character_name)
      |> Enum.map(fn {name, dialogue_blocks} ->
        word_count = dialogue_blocks |> Enum.map(&StoryBlock.word_count/1) |> Enum.sum()
        {name, %{line_count: length(dialogue_blocks), word_count: word_count}}
      end)
      |> Enum.sort_by(fn {_, %{line_count: lc}} -> lc end, :desc)
      |> Map.new()

    dialogue_words = sorted |> Enum.filter(&(&1.type == "dialogue")) |> Enum.map(&StoryBlock.word_count/1) |> Enum.sum()
    narration_words = sorted |> Enum.filter(&(&1.type == "narration")) |> Enum.map(&StoryBlock.word_count/1) |> Enum.sum()
    total_words = dialogue_words + narration_words
    sfx_count = sorted |> Enum.count(&(&1.type == "sfx"))
    music_count = sorted |> Enum.count(&(&1.type == "music"))
    scene_count = max(1, sorted |> Enum.count(&(&1.type == "scene_break")) |> Kernel.+(1))

    dialogue_ratio = if total_words > 0, do: Float.round(dialogue_words / total_words, 2), else: 0.0

    %{
      total_words: total_words,
      estimated_duration_minutes: Float.round(total_words / 150, 1),
      scene_count: scene_count,
      sfx_count: sfx_count,
      music_count: music_count,
      dialogue_words: dialogue_words,
      narration_words: narration_words,
      dialogue_ratio: dialogue_ratio,
      characters: characters
    }
  end

  def compute_story_stats(_), do: %{total_words: 0, estimated_duration_minutes: 0.0, scene_count: 0, sfx_count: 0, music_count: 0, dialogue_words: 0, narration_words: 0, dialogue_ratio: 0.0, characters: %{}}

  @doc """
  Estimates page count from blocks based on word count (~250 words per page).
  """
  def estimate_page_count_from_blocks(blocks) when is_list(blocks) do
    total_words = blocks |> Enum.map(&StoryBlock.word_count/1) |> Enum.sum()
    max(1, div(total_words, 250))
  end

  def estimate_page_count_from_blocks(_), do: nil
end
