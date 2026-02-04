defmodule ScriptVoice.Screenplays.SeriesBible do
  @moduledoc """
  Schema for professional series bible documents.

  A series bible contains comprehensive documentation for a TV series, limited series,
  or film project including world-building, character guides, tone/style information,
  thematic pillars, and production notes following industry standards.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias ScriptVoice.Screenplays.ScreenplayProject

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "series_bibles" do
    field :title, :string

    # Core content (original fields)
    field :content, :string
    field :pdf_url, :string
    field :world_building, :string
    field :tone_style, :string
    field :themes, {:array, :string}, default: []

    # Pitch essentials
    field :logline, :string
    field :comparable_shows, :string  # "Breaking Bad meets Modern Family"
    field :target_audience, :string
    field :why_now, :string  # Cultural relevance

    # Format details
    field :format_details, :string  # Episode count, runtime, structure
    field :episode_structure, :string  # Act breakdown, cold open, etc.

    # Visual and style
    field :visual_style, :string  # Cinematography, color palette

    # Themes as structured data
    field :thematic_pillars, {:array, :map}, default: []  # [{name: "", description: ""}]

    # Tone formula (percentages)
    field :tone_formula, :map  # %{drama: 60, comedy: 25, action: 15}
    field :comedy_guidelines, :string  # What's funny, what's not
    field :handling_serious_topics, :string

    # Production
    field :production_notes, :string
    field :consultant_needs, :string
    field :location_requirements, :string
    field :vfx_requirements, :string

    # File uploads
    field :uploaded_file_url, :string
    field :uploaded_file_name, :string

    # Season arcs
    field :season_arcs, {:array, :map}, default: []  # [{season: 1, title: "", theme: "", throughline: ""}]

    # Recurring elements
    field :visual_motifs, :string
    field :recurring_elements, :string

    # Versioning
    field :version, :integer, default: 1
    field :last_updated_at, :utc_datetime

    belongs_to :project, ScreenplayProject

    timestamps(type: :utc_datetime)
  end

  @all_fields [
    :title, :content, :pdf_url, :world_building, :tone_style, :themes, :project_id,
    :logline, :comparable_shows, :target_audience, :why_now,
    :format_details, :episode_structure, :visual_style,
    :thematic_pillars, :tone_formula, :comedy_guidelines, :handling_serious_topics,
    :production_notes, :consultant_needs, :location_requirements, :vfx_requirements,
    :uploaded_file_url, :uploaded_file_name,
    :season_arcs, :visual_motifs, :recurring_elements
  ]

  @content_fields [
    :content, :pdf_url, :world_building, :tone_style, :themes,
    :logline, :comparable_shows, :target_audience, :why_now,
    :format_details, :episode_structure, :visual_style,
    :thematic_pillars, :tone_formula, :comedy_guidelines, :handling_serious_topics,
    :production_notes, :consultant_needs, :location_requirements, :vfx_requirements,
    :uploaded_file_url, :season_arcs, :visual_motifs, :recurring_elements
  ]

  def changeset(bible, attrs) do
    bible
    |> cast(attrs, @all_fields)
    |> validate_required([:title, :project_id])
    |> validate_length(:title, min: 1, max: 200)
    |> foreign_key_constraint(:project_id)
    |> unique_constraint(:project_id)
  end

  def update_changeset(bible, attrs) do
    changeset = changeset(bible, attrs)

    content_changing = Enum.any?(@content_fields, fn field ->
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

  @doc """
  Returns the list of section groups for organizing the bible editor.
  """
  def section_groups do
    [
      %{
        id: "overview",
        title: "Series Overview",
        icon: "hero-document-text",
        fields: [:title, :logline, :comparable_shows, :target_audience, :why_now]
      },
      %{
        id: "content",
        title: "Main Content",
        icon: "hero-book-open",
        fields: [:content]
      },
      %{
        id: "world",
        title: "World Building",
        icon: "hero-globe-alt",
        fields: [:world_building, :visual_style, :visual_motifs, :recurring_elements]
      },
      %{
        id: "tone",
        title: "Tone & Style",
        icon: "hero-paint-brush",
        fields: [:tone_style, :tone_formula, :comedy_guidelines, :handling_serious_topics]
      },
      %{
        id: "themes",
        title: "Themes",
        icon: "hero-light-bulb",
        fields: [:themes, :thematic_pillars]
      },
      %{
        id: "format",
        title: "Format & Structure",
        icon: "hero-rectangle-stack",
        fields: [:format_details, :episode_structure, :season_arcs]
      },
      %{
        id: "production",
        title: "Production Notes",
        icon: "hero-film",
        fields: [:production_notes, :consultant_needs, :location_requirements, :vfx_requirements]
      }
    ]
  end

  @doc """
  Returns field metadata for rendering the editor.
  """
  def field_metadata do
    %{
      title: %{label: "Bible Title", type: :text, placeholder: "Series Bible"},
      logline: %{label: "Logline", type: :textarea, rows: 2, placeholder: "One sentence that captures the essence of your series..."},
      comparable_shows: %{label: "Comparable Shows", type: :text, placeholder: "Breaking Bad meets Modern Family"},
      target_audience: %{label: "Target Audience", type: :textarea, rows: 2, placeholder: "Who is this show for? Demographics, interests..."},
      why_now: %{label: "Why Now?", type: :textarea, rows: 2, placeholder: "What makes this culturally relevant today?"},
      content: %{label: "Main Bible Content", type: :textarea, rows: 12, placeholder: "The complete series bible content..."},
      world_building: %{label: "World Building", type: :textarea, rows: 6, placeholder: "Setting, rules, social context, key locations..."},
      visual_style: %{label: "Visual Style", type: :textarea, rows: 4, placeholder: "Color palette, cinematography, costume direction..."},
      visual_motifs: %{label: "Visual Motifs", type: :textarea, rows: 3, placeholder: "Recurring visual elements that appear throughout..."},
      recurring_elements: %{label: "Recurring Elements", type: :textarea, rows: 3, placeholder: "Objects, symbols, or patterns that recur..."},
      tone_style: %{label: "Tone Description", type: :textarea, rows: 4, placeholder: "How should this feel to watch?"},
      comedy_guidelines: %{label: "Comedy Guidelines", type: :textarea, rows: 4, placeholder: "What's funny? What's off-limits?"},
      handling_serious_topics: %{label: "Handling Serious Topics", type: :textarea, rows: 4, placeholder: "How to approach sensitive material..."},
      format_details: %{label: "Format Details", type: :textarea, rows: 3, placeholder: "Episode count, runtime, season structure..."},
      episode_structure: %{label: "Episode Structure", type: :textarea, rows: 3, placeholder: "Act breakdown, cold opens, typical structure..."},
      production_notes: %{label: "Production Notes", type: :textarea, rows: 4, placeholder: "General production considerations..."},
      consultant_needs: %{label: "Consultant Needs", type: :textarea, rows: 2, placeholder: "Historians, technical advisors, sensitivity readers..."},
      location_requirements: %{label: "Location Requirements", type: :textarea, rows: 2, placeholder: "Practical locations, sets needed..."},
      vfx_requirements: %{label: "VFX Requirements", type: :textarea, rows: 2, placeholder: "Special effects, CGI needs..."}
    }
  end
end
