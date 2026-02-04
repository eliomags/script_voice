defmodule ScriptVoice.Repo.Migrations.ExpandSeriesBiblesWithProfessionalFields do
  use Ecto.Migration

  def change do
    alter table(:series_bibles) do
      # Pitch essentials
      add :logline, :text
      add :comparable_shows, :text  # "Breaking Bad meets Modern Family"
      add :target_audience, :text
      add :why_now, :text  # Cultural relevance

      # Format details
      add :format_details, :text  # Episode count, runtime, structure
      add :episode_structure, :text  # Act breakdown, cold open, etc.

      # Visual and style
      add :visual_style, :text  # Cinematography, color palette

      # Themes (stored as JSONB for flexibility)
      add :thematic_pillars, {:array, :map}, default: []  # [{name: "", description: ""}]

      # Tone formula
      add :tone_formula, :map  # %{drama: 60, comedy: 25, action: 15}
      add :comedy_guidelines, :text  # What's funny, what's not
      add :handling_serious_topics, :text

      # Production
      add :production_notes, :text
      add :consultant_needs, :text
      add :location_requirements, :text
      add :vfx_requirements, :text

      # File uploads
      add :uploaded_file_url, :string  # Additional uploaded file (PDF/txt)
      add :uploaded_file_name, :string

      # Season arcs (JSONB for flexible storage)
      add :season_arcs, {:array, :map}, default: []  # [{season: 1, title: "", theme: "", throughline: ""}]

      # Recurring elements
      add :visual_motifs, :text
      add :recurring_elements, :text
    end
  end
end
