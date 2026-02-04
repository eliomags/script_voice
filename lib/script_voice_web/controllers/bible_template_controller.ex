defmodule ScriptVoiceWeb.BibleTemplateController do
  @moduledoc """
  Generates dynamic bible templates based on project type and genre.
  """
  use ScriptVoiceWeb, :controller

  alias ScriptVoice.Projects

  def show(conn, %{"project_id" => project_id}) do
    case Projects.get_project(project_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> text("Project not found")

      project ->
        template = generate_template(project)

        conn
        |> put_resp_content_type("text/plain")
        |> put_resp_header("content-disposition", "attachment; filename=\"#{safe_filename(project.title)}_bible_template.txt\"")
        |> send_resp(200, template)
    end
  end

  defp safe_filename(title) do
    title
    |> String.replace(~r/[^a-zA-Z0-9\s]/, "")
    |> String.replace(~r/\s+/, "_")
    |> String.slice(0..50)
  end

  defp generate_template(project) do
    case project.project_type do
      "feature_film" -> feature_film_template(project)
      "short_film_collection" -> feature_film_template(project)
      "podcast_drama" -> audio_drama_template(project)
      "documentary_series" -> documentary_template(project)
      _ -> series_template(project)
    end
  end

  # ============================================================================
  # TV STORY BIBLE TEMPLATE
  # ============================================================================
  defp series_template(project) do
    """
================================================================================
                           STORY BIBLE
                    #{String.upcase(project.title)}
================================================================================
Project Type: #{humanize_type(project.project_type)}
Genre: #{project.genre || "Not specified"}

Instructions: Fill in each section below with your series information.
After completing, upload this file to ScriptVoice to import your Bible.
Delete these instruction lines before uploading.

================================================================================

TITLE:
#{project.title}

LOGLINE:
#{project.logline || "[One to two sentence summary of your series premise]"}

COMPARABLE SHOWS:
[List 2-3 existing shows that share similar tone, genre, or format]
[Example: "Breaking Bad meets Modern Family" or "The Wire meets The Office"]

TARGET AUDIENCE:
[Who is this show for? Demographics, age range, interests]
[Example: "Adults 25-54 who enjoy prestige drama with dark humor"]

WHY NOW:
[Why is this the right time for this story? Cultural relevance, timeliness]
[What conversation is happening in society that this show speaks to?]

MAIN CONTENT:
[Overview of your series - the big picture concept, what makes it unique]
[This is the heart of your bible - explain your show's premise, central conflict,
and what audiences will experience episode to episode]




WORLD BUILDING:
[Describe the world of your series]
- Setting (time period, location, social context)
- Rules of your world (what's possible, what's forbidden)
- Key locations that recur throughout the series
- Social dynamics and power structures




VISUAL STYLE:
[How should the series look?]
- Color palette and lighting approach
- Cinematography style (handheld, steady, specific lenses)
- Production design aesthetic
- Costume and makeup direction




VISUAL MOTIFS:
[Recurring visual elements, symbols, or imagery throughout the series]
[These create visual continuity and thematic depth]

RECURRING ELEMENTS:
[Story elements, locations, or situations that appear regularly]
[Running gags, catchphrases, ritual scenes that audiences look forward to]

TONE & STYLE:
[The emotional feel of the series]
- Overall mood (dark, comedic, hopeful, unsettling, warm)
- How does humor function in the show?
- How does drama function?
- What should viewers FEEL while watching?




COMEDY GUIDELINES:
[If applicable - what kind of humor, boundaries, comedic timing]
- What's funny in this world?
- What's off-limits for jokes?
- Character-specific humor styles




HANDLING SERIOUS TOPICS:
[How the series approaches sensitive or heavy subject matter]
- What serious themes does this show explore?
- What's the approach to violence, trauma, social issues?
- Tone when dealing with difficult material




FORMAT DETAILS:
[Episode length, number of episodes per season, streaming vs broadcast]
- Target runtime per episode
- Planned episodes per season
- Act structure (network breaks vs streaming)
- Season arc vs episodic balance




EPISODE STRUCTURE:
[Typical episode format]
- Cold open conventions
- Act breaks and cliffhangers
- A/B/C storyline balance
- Typical resolution patterns




PRODUCTION NOTES:
[Practical production considerations]
- Budget level expectations
- Any special production requirements
- Scheduling considerations




CONSULTANT NEEDS:
[Subject matter experts or consultants needed for accuracy]
[Medical, legal, historical, cultural consultants]

LOCATION REQUIREMENTS:
[Key shooting locations]
- Primary standing sets
- Recurring exterior locations
- Practical vs studio considerations

VFX REQUIREMENTS:
[Visual effects needs]
- Minimal / Moderate / Heavy VFX show
- Specific VFX sequences or requirements
- Any CGI characters or environments

================================================================================
                              END OF TEMPLATE
================================================================================
"""
  end

  # ============================================================================
  # FEATURE FILM STORY BIBLE TEMPLATE
  # ============================================================================
  defp feature_film_template(project) do
    """
================================================================================
                           STORY BIBLE
                    #{String.upcase(project.title)}
================================================================================
Project Type: #{humanize_type(project.project_type)}
Genre: #{project.genre || "Not specified"}

Instructions: Fill in each section below with your story information.
For feature films, this document serves as a creative reference for the entire
production team to maintain consistency in world, tone, and character.

================================================================================

TITLE:
#{project.title}

LOGLINE:
#{project.logline || "[One sentence that captures your film's premise and hook]"}

COMPARABLE SHOWS:
[List 2-3 films that share similar tone, genre, or style]
[Example: "Parasite meets Get Out" or "The Grand Budapest Hotel meets Knives Out"]

TARGET AUDIENCE:
[Who is this film for? MPAA rating target, demographics]
[Example: "R-rated adult audiences who enjoy elevated genre films"]

WHY NOW:
[Why is this the right time for this story?]
[What makes this culturally relevant today?]

MAIN CONTENT:
[Synopsis of your film - the complete story arc]
[This is a detailed treatment covering beginning, middle, and end]




WORLD BUILDING:
[The world of your film]
- Setting (time, place, social context)
- Rules and logic of this world
- Key locations in the story




THEMES:
[Central themes your film explores]
- Primary theme
- Secondary themes
- How these themes manifest in the story




VISUAL STYLE:
[The look and feel of the film]
- Visual references and influences
- Color palette and lighting approach
- Camera language and movement
- Production design aesthetic




TONE & STYLE:
[The emotional experience of watching this film]
- Overall mood and atmosphere
- Balance of genre elements
- Pacing and rhythm




CHARACTER ARCS:
[Protagonist journey and transformation]
[Antagonist role and motivation]
[Key supporting character functions]




PRODUCTION NOTES:
[Practical production considerations]
- Budget range
- Key locations needed
- Special requirements

VFX REQUIREMENTS:
[Visual effects needs]
- Level of VFX work required
- Specific sequences requiring VFX

================================================================================
                              END OF TEMPLATE
================================================================================
"""
  end

  # ============================================================================
  # AUDIO DRAMA / PODCAST BIBLE TEMPLATE
  # ============================================================================
  defp audio_drama_template(project) do
    """
================================================================================
                         AUDIO DRAMA BIBLE
                    #{String.upcase(project.title)}
================================================================================
Project Type: #{humanize_type(project.project_type)}
Genre: #{project.genre || "Not specified"}

Instructions: Fill in each section below with your series information.
Audio dramas require special attention to sonic identity and voice casting.

================================================================================

TITLE:
#{project.title}

LOGLINE:
#{project.logline || "[One to two sentence summary of your audio drama premise]"}

COMPARABLE SHOWS:
[List 2-3 existing audio dramas or podcasts that share similar tone]
[Example: "Welcome to Night Vale meets Serial" or "The Black Tapes meets Limetown"]

TARGET AUDIENCE:
[Who is this show for? Podcast listener demographics]
[Example: "True crime podcast listeners who enjoy supernatural elements"]

WHY NOW:
[Why is this the right time for this story in audio format?]
[What makes audio the ideal medium for this narrative?]

MAIN CONTENT:
[Overview of your audio drama - premise, format, episode structure]




WORLD BUILDING:
[The world of your audio drama]
- Setting and time period
- Rules of your world
- How the world is revealed through sound




SONIC IDENTITY:
[The audio signature of your show - THIS IS CRUCIAL FOR AUDIO DRAMA]
- Theme music style and mood
- Signature sounds that recur
- Sound design aesthetic (realistic, stylized, otherworldly)
- Audio transitions between scenes
- Use of silence and space




SOUNDSCAPE DESIGN:
[How sound creates your world]
- Environmental audio (locations, weather, ambient sound)
- Era-specific sounds
- Supernatural or genre-specific audio elements
- Sound effects palette




VOICE CASTING PROFILES:
[Character voice descriptions for casting]
- Protagonist: Age range, vocal quality, accent, energy
- Antagonist: Contrast with protagonist, distinctive quality
- Supporting cast: Diversity of voices for clarity
- Narrator (if applicable): Style, relationship to story




NARRATION STYLE:
[If using narration]
- First person / Third person / Mixed
- Past tense / Present tense
- Narrator reliability
- Narrator's emotional distance




TONE & STYLE:
[The listening experience]
- Overall mood and atmosphere
- Pacing and rhythm
- Use of music to enhance emotion
- Moments of silence and impact




FORMAT DETAILS:
[Episode structure]
- Target episode length
- Release schedule
- Season structure
- Cold opens and hooks




PRODUCTION NOTES:
[Recording and post-production considerations]
- Recording environment needs
- Post-production workflow
- Music licensing needs
- Any celebrity voice talent targets

================================================================================
                              END OF TEMPLATE
================================================================================
"""
  end

  # ============================================================================
  # DOCUMENTARY BIBLE TEMPLATE
  # ============================================================================
  defp documentary_template(project) do
    """
================================================================================
                         DOCUMENTARY BIBLE
                    #{String.upcase(project.title)}
================================================================================
Project Type: #{humanize_type(project.project_type)}
Genre: #{project.genre || "Not specified"}

Instructions: Fill in each section below with your documentary series information.

================================================================================

TITLE:
#{project.title}

LOGLINE:
#{project.logline || "[One to two sentence summary of your documentary subject and angle]"}

COMPARABLE SHOWS:
[List 2-3 existing documentaries that share similar approach]
[Example: "The Jinx meets Making a Murderer" or "Planet Earth meets Our Planet"]

TARGET AUDIENCE:
[Who is this documentary for?]
[Example: "True crime enthusiasts interested in investigative journalism"]

WHY NOW:
[Why is this the right time to tell this story?]
[Is there breaking news, anniversary, new evidence, cultural moment?]

MAIN CONTENT:
[Overview of your documentary - subject, angle, narrative approach]




SUBJECT MATTER:
[Deep dive into what this documentary explores]
- Central subject/story
- Historical context
- Current relevance
- Unique access or angle




INTERVIEW SUBJECTS:
[Key people to interview]
- Primary subjects (who carries the story)
- Expert voices (context and authority)
- Witnesses/participants
- Any adversarial interviews




ARCHIVAL MATERIAL:
[Historical footage and documents needed]
- News footage
- Personal archives
- Documents and evidence
- Photographs




RESEARCH STATUS:
[Current state of research]
- What is known
- What needs investigation
- Access secured
- Access needed




VISUAL STYLE:
[Documentary visual approach]
- Verité vs staged interviews
- Reenactment approach (if any)
- Graphics and animation style
- Archival treatment




TONE & STYLE:
[The viewing experience]
- Investigative vs observational
- Emotional register
- Use of music
- Narrator approach (if any)




ETHICAL CONSIDERATIONS:
[Responsible documentary making]
- Subject consent and participation
- Sensitive material handling
- Fact-checking process
- Legal clearances needed




FORMAT DETAILS:
[Episode structure]
- Target episode length
- Number of episodes
- Chronological vs thematic structure




PRODUCTION NOTES:
[Practical considerations]
- Location shooting needs
- International travel
- Security considerations
- Legal review needs

================================================================================
                              END OF TEMPLATE
================================================================================
"""
  end

  defp humanize_type(type) do
    type
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
end
