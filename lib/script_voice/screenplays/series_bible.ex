defmodule ScriptVoice.Screenplays.SeriesBible do
  @moduledoc """
  Schema for series bible documents.

  Each project has exactly one series bible containing world-building,
  character guides, tone/style information, and other reference material.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias ScriptVoice.Screenplays.ScreenplayProject

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "series_bibles" do
    field :title, :string
    field :content, :string
    field :pdf_url, :string
    field :world_building, :string
    field :tone_style, :string
    field :themes, {:array, :string}, default: []
    field :version, :integer, default: 1
    field :last_updated_at, :utc_datetime

    belongs_to :project, ScreenplayProject

    timestamps(type: :utc_datetime)
  end

  def changeset(bible, attrs) do
    bible
    |> cast(attrs, [:title, :content, :pdf_url, :world_building, :tone_style, :themes, :project_id])
    |> validate_required([:title, :project_id])
    |> validate_length(:title, min: 1, max: 200)
    |> foreign_key_constraint(:project_id)
    |> unique_constraint(:project_id)
  end

  def update_changeset(bible, attrs) do
    changeset = changeset(bible, attrs)

    content_fields = [:content, :pdf_url, :world_building, :tone_style, :themes]
    content_changing = Enum.any?(content_fields, fn field ->
      new_val = Map.get(attrs, to_string(field)) || Map.get(attrs, field)
      old_val = Map.get(bible, field)
      new_val != nil && new_val != old_val
    end)

    if content_changing do
      changeset
      |> put_change(:version, (bible.version || 1) + 1)
      |> put_change(:last_updated_at, DateTime.utc_now() |> DateTime.truncate(:second))
    else
      changeset
    end
  end
end
