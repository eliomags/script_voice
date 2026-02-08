defmodule ScriptVoice.Screenplays.StoryBlock do
  @moduledoc """
  Embedded schema for story blocks.

  Each block represents a unit of content in a story:
  narration, dialogue, sound effects, music cues, pauses,
  scene breaks, or chapter headings.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  @block_types ~w(chapter scene_break narration dialogue sfx music pause)

  embedded_schema do
    field :type, :string
    field :text, :string
    field :character_name, :string
    field :parenthetical, :string
    field :description, :string
    field :title, :string
    field :position, :integer, default: 0
  end

  def changeset(block, attrs) do
    block
    |> cast(attrs, [:type, :text, :character_name, :parenthetical, :description, :title, :position])
    |> validate_required([:type, :position])
    |> validate_inclusion(:type, @block_types)
    |> validate_by_type()
  end

  defp validate_by_type(changeset) do
    case get_field(changeset, :type) do
      "narration" ->
        validate_required(changeset, [:text])

      "dialogue" ->
        changeset
        |> validate_required([:text, :character_name])
        |> normalize_character_name()

      "sfx" ->
        validate_required(changeset, [:description])

      "music" ->
        validate_required(changeset, [:description])

      "chapter" ->
        validate_required(changeset, [:title])

      "scene_break" ->
        changeset

      "pause" ->
        changeset

      _ ->
        changeset
    end
  end

  defp normalize_character_name(changeset) do
    case get_change(changeset, :character_name) do
      nil -> changeset
      name -> put_change(changeset, :character_name, String.upcase(String.trim(name)))
    end
  end

  def block_types, do: @block_types

  @doc """
  Returns the word count for a block (text or description content).
  """
  def word_count(%{type: "dialogue", text: text}) when is_binary(text), do: count_words(text)
  def word_count(%{type: "narration", text: text}) when is_binary(text), do: count_words(text)
  def word_count(_), do: 0

  defp count_words(nil), do: 0
  defp count_words(""), do: 0
  defp count_words(text), do: text |> String.split(~r/\s+/, trim: true) |> length()
end
