defmodule ScriptVoice.Screenplays.ProjectCharacter do
  @moduledoc """
  Schema for characters defined at the project level.

  Project characters are recurring/main characters that appear across
  multiple episodes. They can be linked to episode-specific character
  instances.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias ScriptVoice.Screenplays.ScreenplayProject

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @genders ~w(Male Female Any Unknown)
  @role_types ~w(lead supporting recurring guest)
  @age_ranges ~w(Child Teen 20s 30s 40s 50s 60s 70+ Ageless)

  schema "project_characters" do
    field :name, :string
    field :gender, :string, default: "Unknown"
    field :age_range, :string
    field :role_type, :string, default: "recurring"
    field :description, :string
    field :backstory, :string
    field :arc_notes, :string
    field :first_appearance, :string
    field :is_active, :boolean, default: true

    belongs_to :project, ScreenplayProject

    timestamps(type: :utc_datetime)
  end

  def changeset(character, attrs) do
    character
    |> cast(attrs, [
      :name, :gender, :age_range, :role_type, :description,
      :backstory, :arc_notes, :first_appearance, :is_active, :project_id
    ])
    |> validate_required([:name, :project_id])
    |> validate_inclusion(:gender, @genders)
    |> validate_inclusion(:role_type, @role_types)
    |> validate_age_range()
    |> validate_length(:name, min: 1, max: 100)
    |> validate_length(:description, max: 1000)
    |> foreign_key_constraint(:project_id)
    |> unique_constraint([:project_id, :name], name: :project_characters_name_unique)
    |> normalize_name()
  end

  defp validate_age_range(changeset) do
    case get_field(changeset, :age_range) do
      nil -> changeset
      age when age in @age_ranges -> changeset
      _ -> add_error(changeset, :age_range, "is invalid")
    end
  end

  defp normalize_name(changeset) do
    case get_change(changeset, :name) do
      nil -> changeset
      name -> put_change(changeset, :name, String.upcase(name))
    end
  end

  def genders, do: @genders
  def role_types, do: @role_types
  def age_ranges, do: @age_ranges
end
