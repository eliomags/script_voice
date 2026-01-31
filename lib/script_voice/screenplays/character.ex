defmodule ScriptVoice.Screenplays.Character do
  @moduledoc """
  Embedded schema for screenplay characters.

  Characters are extracted from the screenplay (via AI or manually)
  and include name, gender, estimated lines, and description.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  @genders ~w(Male Female Any Unknown)

  embedded_schema do
    field :name, :string
    field :gender, :string, default: "Unknown"
    field :estimated_lines, :integer, default: 0
    field :description, :string
  end

  @doc """
  Changeset for creating/updating a character.
  """
  def changeset(character, attrs) do
    character
    |> cast(attrs, [:name, :gender, :estimated_lines, :description])
    |> validate_required([:name])
    |> validate_inclusion(:gender, @genders)
    |> validate_length(:name, min: 1, max: 100)
    |> validate_length(:description, max: 500)
    |> validate_number(:estimated_lines, greater_than_or_equal_to: 0)
    |> normalize_name()
  end

  # Normalize character name to uppercase (screenplay convention)
  defp normalize_name(changeset) do
    case get_change(changeset, :name) do
      nil -> changeset
      name -> put_change(changeset, :name, String.upcase(name))
    end
  end

  @doc """
  List of available genders.
  """
  def genders, do: @genders
end
