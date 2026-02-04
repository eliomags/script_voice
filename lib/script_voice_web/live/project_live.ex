defmodule ScriptVoiceWeb.ProjectLive do
  @moduledoc """
  LiveView for managing screenplay projects (series, anthologies, miniseries).
  Shows project details, seasons, episodes, and series bible.
  """
  use ScriptVoiceWeb, :live_view

  alias ScriptVoice.Projects
  alias ScriptVoice.Screenplays
  alias ScriptVoice.Screenplays.{ScreenplayProject, ScreenplaySeason, SeriesBible, ProjectCharacter}

  @impl true
  def mount(%{"id" => project_id} = params, session, socket) do
    current_user = get_current_user(session)

    case Projects.get_project_with_preloads(project_id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Project not found")
         |> push_navigate(to: ~p"/dashboard")}

      project ->
        # Check if user is the owner
        is_owner = current_user && current_user.id == project.owner_id
        # Allow access if owner OR if project is public
        can_view = is_owner || project.is_public

        unless can_view do
          {:ok,
           socket
           |> put_flash(:error, "This project is private")
           |> push_navigate(to: ~p"/browse")}
        else
          stats = Projects.get_project_stats(project.id)

          {:ok,
           socket
           |> assign(:current_user, current_user)
           |> assign(:project, project)
           |> assign(:stats, stats)
           |> assign(:is_owner, is_owner)
           |> assign(:expanded_seasons, MapSet.new())
           |> assign(:show_add_season, false)
           |> assign(:show_add_episode, false)
           |> assign(:show_edit_project, false)
           |> assign(:show_bible_editor, false)
           |> assign(:bible_edit_mode, false)
           |> assign(:bible_expanded, false)
           |> assign(:bible_expanded_section, "overview")
           |> assign(:selected_season_id, params["season_id"])
           |> assign(:page_title, project.title)
           |> assign(:new_season_form, to_form(%{"title" => "", "description" => ""}))
           |> assign(:new_episode_form, to_form(%{"title" => "", "genre" => "Drama", "logline" => ""}))
           |> assign(:bible_form, init_bible_form(project.series_bible))
           # Episode/Season editing states
           |> assign(:editing_episode, nil)
           |> assign(:editing_season, nil)
           |> assign(:moving_episode, nil)
           |> assign(:confirm_delete_season, nil)
           |> assign(:confirm_delete_episode, nil)
           |> assign(:confirm_delete_project, false)
           |> assign(:upload_error, nil)
           # Character management
           |> assign(:characters, Projects.list_characters_for_project(project.id))
           |> assign(:show_add_character, false)
           |> assign(:editing_character, nil)
           |> assign(:confirm_delete_character, nil)
           |> assign(:character_form, to_form(%{"name" => "", "gender" => "Unknown", "role_type" => "recurring", "age_range" => "", "description" => ""}))
}
        end
    end
  end

  @impl true
  def handle_event("toggle_bible_section", %{"section" => section}, socket) do
    current = socket.assigns.bible_expanded_section
    new_section = if current == section, do: nil, else: section
    {:noreply, assign(socket, :bible_expanded_section, new_section)}
  end

  @impl true
  def handle_event("toggle_bible_expanded", _, socket) do
    {:noreply, assign(socket, :bible_expanded, !socket.assigns.bible_expanded)}
  end

  defp init_bible_form(nil) do
    to_form(%{
      "title" => "Story Bible",
      "content" => "",
      "world_building" => "",
      "tone_style" => "",
      "logline" => "",
      "comparable_shows" => "",
      "target_audience" => "",
      "why_now" => "",
      "format_details" => "",
      "episode_structure" => "",
      "visual_style" => "",
      "comedy_guidelines" => "",
      "handling_serious_topics" => "",
      "production_notes" => "",
      "consultant_needs" => "",
      "location_requirements" => "",
      "vfx_requirements" => "",
      "visual_motifs" => "",
      "recurring_elements" => ""
    })
  end

  defp init_bible_form(bible) do
    to_form(%{
      "title" => bible.title || "Story Bible",
      "content" => bible.content || "",
      "world_building" => bible.world_building || "",
      "tone_style" => bible.tone_style || "",
      "logline" => bible.logline || "",
      "comparable_shows" => bible.comparable_shows || "",
      "target_audience" => bible.target_audience || "",
      "why_now" => bible.why_now || "",
      "format_details" => bible.format_details || "",
      "episode_structure" => bible.episode_structure || "",
      "visual_style" => bible.visual_style || "",
      "comedy_guidelines" => bible.comedy_guidelines || "",
      "handling_serious_topics" => bible.handling_serious_topics || "",
      "production_notes" => bible.production_notes || "",
      "consultant_needs" => bible.consultant_needs || "",
      "location_requirements" => bible.location_requirements || "",
      "vfx_requirements" => bible.vfx_requirements || "",
      "visual_motifs" => bible.visual_motifs || "",
      "recurring_elements" => bible.recurring_elements || ""
    })
  end

  defp bible_template_form do
    to_form(%{
      "title" => "Story Bible",
      "logline" => "[One sentence that captures the heart of your series. What's the central conflict? Who's the protagonist? What makes this story unique?]",
      "comparable_shows" => "[Two to three shows that share your tone or audience. Example: \"Breaking Bad meets Modern Family\" or \"The Office meets Black Mirror\"]",
      "target_audience" => "[Who is this show for? Consider demographics, interests, and what draws them to this type of content.]",
      "why_now" => "[What makes this story timely? Why should audiences care about this topic today?]",
      "content" => """
[OVERVIEW]
This is the heart of your series bible. Include:

1. THE HOOK
What makes this show different from everything else? What's the unique angle?

2. PREMISE
Expand on your logline. What's the world? What's the central conflict?

3. THEMES
What deeper ideas does the show explore? What questions does it ask?

4. SEASON ARC (if applicable)
Where does Season 1 begin and end? What's the journey?

[CHARACTER BREAKDOWN]
List your main characters here:
- Character Name: Role, key traits, arc, relationships
- Character Name: Role, key traits, arc, relationships

[PILOT SUMMARY]
Brief description of your pilot episode and how it sets up the series.
""",
      "world_building" => """
[SETTING]
Where and when does this story take place?

[RULES OF THE WORLD]
What are the unique rules, constraints, or elements of your world?

[KEY LOCATIONS]
Important recurring locations and their significance:
- Location 1: Description and role in the story
- Location 2: Description and role in the story

[SOCIAL CONTEXT]
What's the social/political landscape of your world?
""",
      "visual_style" => "[Describe the look and feel. Color palette, camera work, lighting, costume direction. What films or shows have a similar visual language?]",
      "visual_motifs" => "[Recurring visual elements that carry meaning. Examples: mirrors reflecting truth, windows as barriers, specific colors for specific characters.]",
      "recurring_elements" => "[Objects, symbols, or patterns that appear throughout. The coffee cup in Twin Peaks. The blue meth in Breaking Bad.]",
      "tone_style" => "[How should this feel to watch? Describe the emotional experience. Is it dark and brooding? Light and hopeful? Satirical? Intimate?]",
      "comedy_guidelines" => "[If applicable: What kind of humor works in this world? What's off-limits? Character comedy vs. situational comedy vs. dark humor?]",
      "handling_serious_topics" => "[How do you approach sensitive material? What's the line between drama and exploitation? Any specific approaches or consultants needed?]",
      "format_details" => "[Episode count per season, episode runtime, number of planned seasons, streaming vs. broadcast considerations.]",
      "episode_structure" => """
[TYPICAL EPISODE STRUCTURE]
- Cold Open: What happens before titles?
- Act 1: Setup and inciting incident
- Act 2: Complications and escalation
- Act 3: Climax and resolution
- Tag/Stinger: How do episodes typically end?

[A-STORY vs B-STORY]
How do you balance main plot with subplots?
""",
      "production_notes" => "[Budget considerations, filming requirements, practical vs. CGI, season filming schedule, any special requirements.]",
      "consultant_needs" => "[Experts needed: historical advisors, technical consultants, sensitivity readers, cultural consultants.]",
      "location_requirements" => "[Practical locations needed vs. sets to build. Any specific geographic requirements?]",
      "vfx_requirements" => "[Special effects needs: CGI, practical effects, makeup/prosthetics, post-production requirements.]"
    })
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :show, _params) do
    socket
    |> assign(:show_bible_editor, false)
    |> assign(:show_add_episode, false)
  end

  defp apply_action(socket, :show_season, %{"season_id" => season_id}) do
    socket
    |> assign(:selected_season_id, season_id)
    |> assign(:expanded_seasons, MapSet.put(socket.assigns.expanded_seasons, season_id))
  end

  defp apply_action(socket, :new_episode, _params) do
    socket
    |> assign(:show_add_episode, true)
  end

  defp apply_action(socket, :bible, _params) do
    socket
    |> assign(:show_bible_editor, true)
    |> assign(:bible_edit_mode, true)  # Enable edit mode when navigating to bible
  end

  # ===========================================================================
  # SEASON EVENTS
  # ===========================================================================

  @impl true
  def handle_event("toggle_season", %{"id" => season_id}, socket) do
    expanded = socket.assigns.expanded_seasons
    expanded = if MapSet.member?(expanded, season_id) do
      MapSet.delete(expanded, season_id)
    else
      MapSet.put(expanded, season_id)
    end
    {:noreply, assign(socket, :expanded_seasons, expanded)}
  end

  @impl true
  def handle_event("show_add_season", _, socket) do
    {:noreply, assign(socket, :show_add_season, true)}
  end

  @impl true
  def handle_event("cancel_add_season", _, socket) do
    {:noreply, assign(socket, :show_add_season, false)}
  end

  @impl true
  def handle_event("create_season", %{"title" => title, "description" => description}, socket) do
    case Projects.create_season(socket.assigns.project, %{
      "title" => if(title == "", do: nil, else: title),
      "description" => if(description == "", do: nil, else: description)
    }) do
      {:ok, _season} ->
        project = Projects.get_project_with_preloads(socket.assigns.project.id)
        {:noreply,
         socket
         |> assign(:project, project)
         |> assign(:show_add_season, false)
         |> put_flash(:info, "Season created successfully")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create season")}
    end
  end

  @impl true
  def handle_event("confirm_delete_season", %{"id" => season_id}, socket) do
    season = Projects.get_season!(season_id)
    episode_count = length(season.episodes)
    {:noreply, assign(socket, :confirm_delete_season, %{id: season_id, episode_count: episode_count})}
  end

  @impl true
  def handle_event("cancel_delete_season", _, socket) do
    {:noreply, assign(socket, :confirm_delete_season, nil)}
  end

  @impl true
  def handle_event("delete_season", %{"keep_episodes" => keep_episodes}, socket) do
    season_id = socket.assigns.confirm_delete_season.id
    season = Projects.get_season!(season_id)
    keep = keep_episodes == "true"

    result = if keep do
      # Move episodes to unorganized before deleting season
      Projects.delete_season_keep_episodes(season)
    else
      Projects.delete_season_with_episodes(season)
    end

    case result do
      {:ok, _} ->
        project = Projects.get_project_with_preloads(socket.assigns.project.id)
        stats = Projects.get_project_stats(project.id)
        msg = if keep, do: "Season deleted, episodes moved to unorganized", else: "Season and episodes deleted"
        {:noreply,
         socket
         |> assign(:project, project)
         |> assign(:stats, stats)
         |> assign(:confirm_delete_season, nil)
         |> put_flash(:info, msg)}

      {:error, _} ->
        {:noreply,
         socket
         |> assign(:confirm_delete_season, nil)
         |> put_flash(:error, "Failed to delete season")}
    end
  end

  @impl true
  def handle_event("show_edit_season", %{"id" => season_id}, socket) do
    season = Projects.get_season!(season_id)
    {:noreply, assign(socket, :editing_season, season)}
  end

  @impl true
  def handle_event("cancel_edit_season", _, socket) do
    {:noreply, assign(socket, :editing_season, nil)}
  end

  @impl true
  def handle_event("update_season", params, socket) do
    season = socket.assigns.editing_season
    case Projects.update_season(season, params) do
      {:ok, _} ->
        project = Projects.get_project_with_preloads(socket.assigns.project.id)
        {:noreply,
         socket
         |> assign(:project, project)
         |> assign(:editing_season, nil)
         |> put_flash(:info, "Season updated")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update season")}
    end
  end

  # ===========================================================================
  # EPISODE EVENTS
  # ===========================================================================

  @impl true
  def handle_event("show_add_episode", params, socket) do
    {:noreply,
     socket
     |> assign(:show_add_episode, true)
     |> assign(:target_season_id, params["season_id"])}
  end

  @impl true
  def handle_event("cancel_add_episode", _, socket) do
    {:noreply, assign(socket, :show_add_episode, false)}
  end

  @impl true
  def handle_event("create_episode", params, socket) do
    user = socket.assigns.current_user
    project = socket.assigns.project
    target_season_id = socket.assigns[:target_season_id]

    # Create the screenplay first
    screenplay_attrs = %{
      "title" => params["title"],
      "genre" => params["genre"],
      "logline" => params["logline"],
      "script_content" => params["content"]
    }

    with {:ok, screenplay} <- Screenplays.create_screenplay(screenplay_attrs, user) do
      # Link to project/season
      result = if target_season_id do
        season = Projects.get_season!(target_season_id)
        Projects.add_episode_to_season(season, screenplay, %{
          "screenplay_type" => params["screenplay_type"] || "episode"
        })
      else
        Projects.add_episode_to_project(project, screenplay, %{
          "screenplay_type" => params["screenplay_type"] || "episode"
        })
      end

      case result do
        {:ok, _updated_screenplay} ->
          project = Projects.get_project_with_preloads(project.id)
          stats = Projects.get_project_stats(project.id)
          {:noreply,
           socket
           |> assign(:project, project)
           |> assign(:stats, stats)
           |> assign(:show_add_episode, false)
           |> put_flash(:info, "Episode added successfully")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to link episode to project")}
      end
    else
      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create episode")}
    end
  end

  @impl true
  def handle_event("confirm_delete_episode", %{"id" => episode_id}, socket) do
    {:noreply, assign(socket, :confirm_delete_episode, episode_id)}
  end

  @impl true
  def handle_event("cancel_delete_episode", _, socket) do
    {:noreply, assign(socket, :confirm_delete_episode, nil)}
  end

  @impl true
  def handle_event("delete_episode", _, socket) do
    episode_id = socket.assigns.confirm_delete_episode
    screenplay = Screenplays.get_screenplay!(episode_id)

    case Screenplays.delete_screenplay(screenplay) do
      {:ok, _} ->
        project = Projects.get_project_with_preloads(socket.assigns.project.id)
        stats = Projects.get_project_stats(project.id)
        {:noreply,
         socket
         |> assign(:project, project)
         |> assign(:stats, stats)
         |> assign(:confirm_delete_episode, nil)
         |> put_flash(:info, "Episode deleted")}

      {:error, _} ->
        {:noreply,
         socket
         |> assign(:confirm_delete_episode, nil)
         |> put_flash(:error, "Failed to delete episode")}
    end
  end

  @impl true
  def handle_event("remove_episode", %{"id" => screenplay_id}, socket) do
    screenplay = Screenplays.get_screenplay!(screenplay_id)
    case Projects.remove_episode(screenplay) do
      {:ok, _} ->
        project = Projects.get_project_with_preloads(socket.assigns.project.id)
        stats = Projects.get_project_stats(project.id)
        {:noreply,
         socket
         |> assign(:project, project)
         |> assign(:stats, stats)
         |> put_flash(:info, "Episode removed from project")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to remove episode")}
    end
  end

  @impl true
  def handle_event("show_edit_episode", %{"id" => episode_id}, socket) do
    episode = Screenplays.get_screenplay!(episode_id)
    {:noreply, assign(socket, :editing_episode, episode)}
  end

  @impl true
  def handle_event("cancel_edit_episode", _, socket) do
    {:noreply, assign(socket, :editing_episode, nil)}
  end

  @impl true
  def handle_event("update_episode", params, socket) do
    episode = socket.assigns.editing_episode
    case Screenplays.update_screenplay(episode, params) do
      {:ok, _} ->
        project = Projects.get_project_with_preloads(socket.assigns.project.id)
        stats = Projects.get_project_stats(project.id)
        {:noreply,
         socket
         |> assign(:project, project)
         |> assign(:stats, stats)
         |> assign(:editing_episode, nil)
         |> put_flash(:info, "Episode updated")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update episode")}
    end
  end

  @impl true
  def handle_event("show_move_episode", %{"id" => episode_id}, socket) do
    episode = Screenplays.get_screenplay!(episode_id)
    {:noreply, assign(socket, :moving_episode, episode)}
  end

  @impl true
  def handle_event("cancel_move_episode", _, socket) do
    {:noreply, assign(socket, :moving_episode, nil)}
  end

  @impl true
  def handle_event("move_episode", %{"season_id" => season_id}, socket) do
    episode = socket.assigns.moving_episode
    target_season_id = if season_id == "none", do: nil, else: season_id

    case Projects.move_episode_to_season(episode, target_season_id) do
      {:ok, _} ->
        project = Projects.get_project_with_preloads(socket.assigns.project.id)
        {:noreply,
         socket
         |> assign(:project, project)
         |> assign(:moving_episode, nil)
         |> put_flash(:info, "Episode moved")}

      {:error, _} ->
        {:noreply,
         socket
         |> assign(:moving_episode, nil)
         |> put_flash(:error, "Failed to move episode")}
    end
  end

  # ===========================================================================
  # BIBLE EVENTS
  # ===========================================================================

  @impl true
  def handle_event("show_bible_editor", _, socket) do
    {:noreply, push_patch(socket, to: ~p"/project/#{socket.assigns.project.id}/bible")}
  end

  @impl true
  def handle_event("close_bible_editor", _, socket) do
    {:noreply, push_patch(socket, to: ~p"/project/#{socket.assigns.project.id}")}
  end

  @impl true
  def handle_event("save_bible", params, socket) do
    case Projects.create_or_update_series_bible(socket.assigns.project, params) do
      {:ok, bible} ->
        project = %{socket.assigns.project | series_bible: bible}
        {:noreply,
         socket
         |> assign(:project, project)
         |> assign(:bible_form, init_bible_form(bible))
         |> assign(:bible_edit_mode, false)
         |> put_flash(:info, "Series bible saved")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to save series bible")}
    end
  end

  # ===========================================================================
  # PROJECT EVENTS
  # ===========================================================================

  @impl true
  def handle_event("show_edit_project", _, socket) do
    {:noreply, assign(socket, :show_edit_project, true)}
  end

  @impl true
  def handle_event("cancel_edit_project", _, socket) do
    {:noreply, assign(socket, :show_edit_project, false)}
  end

  @impl true
  def handle_event("update_project", params, socket) do
    case Projects.update_project(socket.assigns.project, params) do
      {:ok, project} ->
        project = Projects.get_project_with_preloads(project.id)
        {:noreply,
         socket
         |> assign(:project, project)
         |> assign(:show_edit_project, false)
         |> assign(:page_title, project.title)
         |> put_flash(:info, "Project updated")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update project")}
    end
  end

  @impl true
  def handle_event("confirm_delete_project", _, socket) do
    {:noreply, assign(socket, :confirm_delete_project, true)}
  end

  @impl true
  def handle_event("cancel_delete_project", _, socket) do
    {:noreply, assign(socket, :confirm_delete_project, false)}
  end

  @impl true
  def handle_event("delete_project", _, socket) do
    case Projects.delete_project(socket.assigns.project) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Project deleted")
         |> push_navigate(to: ~p"/dashboard?tab=screenplays")}

      {:error, _} ->
        {:noreply,
         socket
         |> assign(:confirm_delete_project, false)
         |> put_flash(:error, "Failed to delete project")}
    end
  end

  # ===========================================================================
  # VISIBILITY TOGGLES
  # ===========================================================================

  @impl true
  def handle_event("toggle_project_visibility", _, socket) do
    project = socket.assigns.project
    new_visibility = !project.is_public

    case Projects.update_project(project, %{"is_public" => new_visibility}) do
      {:ok, updated} ->
        project = Projects.get_project_with_preloads(updated.id)
        {:noreply,
         socket
         |> assign(:project, project)
         |> put_flash(:info, if(new_visibility, do: "Project is now public", else: "Project is now private"))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update visibility")}
    end
  end

  @impl true
  def handle_event("toggle_episode_visibility", %{"id" => episode_id}, socket) do
    alias ScriptVoice.Screenplays

    case Screenplays.get_screenplay(episode_id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Episode not found")}

      episode ->
        new_visibility = !episode.is_public

        case Screenplays.update_screenplay(episode, %{"is_public" => new_visibility}) do
          {:ok, _} ->
            project = Projects.get_project_with_preloads(socket.assigns.project.id)
            {:noreply,
             socket
             |> assign(:project, project)
             |> put_flash(:info, if(new_visibility, do: "Episode is now visible", else: "Episode is now hidden"))}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to update episode visibility")}
        end
    end
  end

  # ===========================================================================
  # BIBLE EDIT MODE
  # ===========================================================================

  @impl true
  def handle_event("toggle_bible_edit_mode", _, socket) do
    {:noreply, assign(socket, :bible_edit_mode, !socket.assigns.bible_edit_mode)}
  end

  @impl true
  def handle_event("start_bible_edit", _, socket) do
    {:noreply, assign(socket, :bible_edit_mode, true)}
  end

  @impl true
  def handle_event("cancel_bible_edit", _, socket) do
    # Reset to initial form state and exit edit mode
    {:noreply,
     socket
     |> assign(:bible_edit_mode, false)
     |> assign(:bible_form, init_bible_form(socket.assigns.project.series_bible))}
  end

  @impl true
  def handle_event("import_bible_content", %{"content" => content, "filename" => filename}, socket) do
    # Parse the file content
    parsed_content = if String.ends_with?(filename, ".pdf") do
      %{
        "title" => "Story Bible",
        "content" => content,
        "logline" => "",
        "comparable_shows" => "",
        "target_audience" => "",
        "world_building" => "",
        "tone_style" => ""
      }
    else
      parse_bible_text_file(content)
    end

    bible_form = to_form(parsed_content)

    {:noreply,
     socket
     |> assign(:bible_form, bible_form)
     |> assign(:bible_edit_mode, true)
     |> put_flash(:info, "Content imported from #{filename}! Review and save.")}
  end

  defp parse_bible_text_file(content) do
    # Parse sections from template format
    sections = %{
      "title" => extract_section(content, "TITLE:", "Story Bible"),
      "logline" => extract_section(content, "LOGLINE:", ""),
      "comparable_shows" => extract_section(content, "COMPARABLE SHOWS:", ""),
      "target_audience" => extract_section(content, "TARGET AUDIENCE:", ""),
      "why_now" => extract_section(content, "WHY NOW:", ""),
      "content" => extract_section(content, "MAIN CONTENT:", ""),
      "world_building" => extract_section(content, "WORLD BUILDING:", ""),
      "visual_style" => extract_section(content, "VISUAL STYLE:", ""),
      "visual_motifs" => extract_section(content, "VISUAL MOTIFS:", ""),
      "recurring_elements" => extract_section(content, "RECURRING ELEMENTS:", ""),
      "tone_style" => extract_section(content, "TONE & STYLE:", ""),
      "comedy_guidelines" => extract_section(content, "COMEDY GUIDELINES:", ""),
      "handling_serious_topics" => extract_section(content, "HANDLING SERIOUS TOPICS:", ""),
      "format_details" => extract_section(content, "FORMAT DETAILS:", ""),
      "episode_structure" => extract_section(content, "EPISODE STRUCTURE:", ""),
      "production_notes" => extract_section(content, "PRODUCTION NOTES:", ""),
      "consultant_needs" => extract_section(content, "CONSULTANT NEEDS:", ""),
      "location_requirements" => extract_section(content, "LOCATION REQUIREMENTS:", ""),
      "vfx_requirements" => extract_section(content, "VFX REQUIREMENTS:", "")
    }

    # If no sections found, put all content in main content
    if Enum.all?(Map.values(sections), &(&1 == "" || &1 == "Story Bible")) do
      %{sections | "content" => content}
    else
      sections
    end
  end

  defp extract_section(content, marker, default) do
    # Find content between this marker and the next marker (or end)
    markers = ["TITLE:", "LOGLINE:", "COMPARABLE SHOWS:", "TARGET AUDIENCE:", "WHY NOW:",
               "MAIN CONTENT:", "WORLD BUILDING:", "VISUAL STYLE:", "VISUAL MOTIFS:",
               "RECURRING ELEMENTS:", "TONE & STYLE:", "COMEDY GUIDELINES:",
               "HANDLING SERIOUS TOPICS:", "FORMAT DETAILS:", "EPISODE STRUCTURE:",
               "PRODUCTION NOTES:", "CONSULTANT NEEDS:", "LOCATION REQUIREMENTS:", "VFX REQUIREMENTS:"]

    case String.split(content, marker, parts: 2) do
      [_, rest] ->
        # Find the next section marker
        next_marker_pos = markers
        |> Enum.filter(&(&1 != marker))
        |> Enum.map(&String.split(rest, &1, parts: 2))
        |> Enum.filter(&(length(&1) > 1))
        |> Enum.map(fn [before, _] -> String.length(before) end)
        |> Enum.min(fn -> String.length(rest) end)

        rest
        |> String.slice(0, next_marker_pos)
        |> String.trim()
      _ ->
        default
    end
  end

  @impl true
  def handle_event("use_bible_template", _, socket) do
    {:noreply,
     socket
     |> assign(:bible_form, bible_template_form())
     |> assign(:show_bible_editor, true)
     |> assign(:bible_edit_mode, true)
     |> put_flash(:info, "Template loaded! Edit the bracketed text to customize your Story Bible.")}
  end

  # ===========================================================================
  # CHARACTER MANAGEMENT
  # ===========================================================================

  @impl true
  def handle_event("show_add_character", _, socket) do
    {:noreply,
     socket
     |> assign(:show_add_character, true)
     |> assign(:character_form, to_form(%{"name" => "", "gender" => "Unknown", "role_type" => "recurring", "age_range" => "", "description" => ""}))}
  end

  @impl true
  def handle_event("cancel_add_character", _, socket) do
    {:noreply, assign(socket, :show_add_character, false)}
  end

  @impl true
  def handle_event("create_character", params, socket) do
    case Projects.create_character(socket.assigns.project, params) do
      {:ok, _character} ->
        characters = Projects.list_characters_for_project(socket.assigns.project.id)
        {:noreply,
         socket
         |> assign(:characters, characters)
         |> assign(:show_add_character, false)
         |> put_flash(:info, "Character added successfully")}

      {:error, changeset} ->
        errors = format_changeset_errors(changeset)
        {:noreply, put_flash(socket, :error, "Failed to add character: #{errors}")}
    end
  end

  @impl true
  def handle_event("show_edit_character", %{"id" => id}, socket) do
    character = Projects.get_character!(id)
    form = to_form(%{
      "name" => character.name,
      "gender" => character.gender,
      "role_type" => character.role_type,
      "age_range" => character.age_range || "",
      "description" => character.description || "",
      "backstory" => character.backstory || "",
      "arc_notes" => character.arc_notes || "",
      "first_appearance" => character.first_appearance || ""
    })
    {:noreply,
     socket
     |> assign(:editing_character, character)
     |> assign(:character_form, form)}
  end

  @impl true
  def handle_event("cancel_edit_character", _, socket) do
    {:noreply, assign(socket, :editing_character, nil)}
  end

  @impl true
  def handle_event("update_character", params, socket) do
    character = socket.assigns.editing_character
    case Projects.update_character(character, params) do
      {:ok, _} ->
        characters = Projects.list_characters_for_project(socket.assigns.project.id)
        {:noreply,
         socket
         |> assign(:characters, characters)
         |> assign(:editing_character, nil)
         |> put_flash(:info, "Character updated")}

      {:error, changeset} ->
        errors = format_changeset_errors(changeset)
        {:noreply, put_flash(socket, :error, "Failed to update: #{errors}")}
    end
  end

  @impl true
  def handle_event("confirm_delete_character", %{"id" => id}, socket) do
    {:noreply, assign(socket, :confirm_delete_character, id)}
  end

  @impl true
  def handle_event("cancel_delete_character", _, socket) do
    {:noreply, assign(socket, :confirm_delete_character, nil)}
  end

  @impl true
  def handle_event("delete_character", _, socket) do
    character = Projects.get_character!(socket.assigns.confirm_delete_character)
    case Projects.delete_character(character) do
      {:ok, _} ->
        characters = Projects.list_characters_for_project(socket.assigns.project.id)
        {:noreply,
         socket
         |> assign(:characters, characters)
         |> assign(:confirm_delete_character, nil)
         |> put_flash(:info, "Character deleted")}

      {:error, _} ->
        {:noreply,
         socket
         |> assign(:confirm_delete_character, nil)
         |> put_flash(:error, "Failed to delete character")}
    end
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {field, errors} -> "#{field}: #{Enum.join(errors, ", ")}" end)
    |> Enum.join("; ")
  end

  # ===========================================================================
  # HELPERS
  # ===========================================================================

  defp get_current_user(session) do
    case session["user_id"] do
      nil -> nil
      user_id -> ScriptVoice.Accounts.get_user(user_id)
    end
  end

  # ===========================================================================
  # RENDER
  # ===========================================================================

  @impl true
  def render(assigns) do
    ~H"""
    <div class="py-6 sm:py-8 px-4 sm:px-6">
      <div class="max-w-4xl mx-auto">
        <!-- Back Button -->
        <.back navigate={~p"/dashboard?tab=screenplays"}>Back to My Work</.back>

        <!-- Project Header -->
        <div class="bg-white border rounded-xl p-4 sm:p-6 mt-4 mb-6">
          <div class="flex flex-col sm:flex-row justify-between items-start gap-4 mb-4">
            <div class="flex-1">
              <div class="flex flex-wrap items-center gap-2 mb-2">
                <h1 class="text-xl sm:text-2xl font-bold"><%= @project.title %></h1>
                <span class={"px-2 py-0.5 rounded-full text-xs font-medium #{project_type_color(@project.project_type)}"}>
                  <%= String.capitalize(@project.project_type) %>
                </span>
                <.genre_badge genre={@project.genre} />
              </div>
              <p class="text-gray-500 text-sm sm:text-base">
                by <%= @project.owner_name %>
                · <%= @stats.episode_count %> episodes
                <%= if @stats.season_count > 0 do %>
                  · <%= @stats.season_count %> seasons
                <% end %>
                · <%= @stats.total_pages %> total pages
              </p>
            </div>

            <%= if @is_owner do %>
              <div class="flex flex-wrap items-center gap-2 w-full sm:w-auto">
                <!-- Visibility Toggle -->
                <button
                  phx-click="toggle_project_visibility"
                  class={"flex items-center gap-2 px-3 py-1.5 text-sm font-medium rounded-lg transition-colors " <>
                    if(@project.is_public, do: "bg-emerald-100 text-emerald-700 hover:bg-emerald-200", else: "bg-gray-100 text-gray-600 hover:bg-gray-200")}
                >
                  <.icon name={if @project.is_public, do: "hero-eye", else: "hero-eye-slash"} class="w-4 h-4" />
                  <%= if @project.is_public, do: "Public", else: "Private" %>
                </button>
                <button
                  phx-click="show_edit_project"
                  class="px-3 py-1.5 text-sm font-medium border border-gray-300 rounded-lg hover:bg-gray-50 text-gray-700 transition-colors"
                >
                  Edit Project
                </button>
                <button
                  phx-click="confirm_delete_project"
                  class="px-3 py-1.5 text-sm font-medium border border-red-300 text-red-600 rounded-lg hover:bg-red-50 transition-colors"
                >
                  Delete
                </button>
              </div>
            <% end %>
          </div>

          <p class="text-gray-700 text-base mb-4"><%= @project.logline %></p>

          <%= if @project.description do %>
            <p class="text-gray-600 text-sm"><%= @project.description %></p>
          <% end %>

          <!-- Inline Edit Project Form -->
          <%= if @show_edit_project do %>
            <div class="mt-4 pt-4 border-t border-gray-200">
              <form phx-submit="update_project" class="space-y-4">
                <h3 class="text-sm font-semibold text-gray-700 mb-3">Edit Project Details</h3>
                <.styled_input name="title" label="Title" value={@project.title} required={true} />
                <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <.styled_dropdown
                    name="project_type"
                    label="Type"
                    value={@project.project_type}
                    options={Enum.map(ScriptVoice.Screenplays.ScreenplayProject.project_types(), &{format_project_type(&1), &1})}
                  />
                  <.styled_dropdown
                    name="genre"
                    label="Genre"
                    value={@project.genre}
                    options={ScriptVoice.Screenplays.ScreenplayProject.genres()}
                  />
                </div>
                <.styled_textarea name="logline" label="Logline" value={@project.logline} required={true} rows={2} />
                <.styled_textarea name="description" label="Description" value={@project.description} rows={3} />
                <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <.styled_number name="total_episodes" label="Total Episodes (planned)" value={@project.total_episodes} min={1} />
                  <.styled_dropdown
                    name="status"
                    label="Status"
                    value={@project.status}
                    options={Enum.map(ScriptVoice.Screenplays.ScreenplayProject.statuses(), &{format_status(&1), &1})}
                  />
                </div>
                <div class="flex gap-2 justify-end">
                  <button type="button" phx-click="cancel_edit_project" class="px-4 py-2 text-sm border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors">
                    Cancel
                  </button>
                  <button type="submit" class="px-4 py-2 text-sm bg-emerald-600 text-white rounded-lg hover:bg-emerald-700 transition-colors">
                    Save Changes
                  </button>
                </div>
              </form>
            </div>
          <% end %>
        </div>

        <!-- Story Bible Section -->
        <div class="bg-white border rounded-xl mb-6 overflow-hidden">
          <!-- Header -->
          <div class="flex justify-between items-center p-4 sm:p-6 border-b border-gray-100">
            <h2 class="text-lg font-bold flex items-center gap-2">
              <.icon name="hero-book-open" class="w-5 h-5 text-purple-600" />
              Story Bible
              <%= if @project.series_bible do %>
                <span class="text-xs font-normal text-gray-400">v<%= @project.series_bible.version %></span>
              <% end %>
            </h2>
            <div class="flex items-center gap-2">
              <%= cond do %>
                <% @bible_edit_mode && @is_owner -> %>
                  <!-- Editing: show Cancel -->
                  <button
                    type="button"
                    phx-click="cancel_bible_edit"
                    class="px-3 py-1.5 text-sm text-gray-600 hover:text-gray-800 font-medium"
                  >
                    Cancel
                  </button>
                <% @project.series_bible && @is_owner -> %>
                  <!-- Has bible, not editing: show Edit button -->
                  <button
                    type="button"
                    phx-click="start_bible_edit"
                    class="flex items-center gap-1 px-3 py-1.5 text-sm bg-purple-600 text-white rounded-lg hover:bg-purple-700 font-medium"
                  >
                    <.icon name="hero-pencil" class="w-4 h-4" />
                    Edit
                  </button>
                <% true -> %>
                  <!-- No bible yet: no header buttons needed -->
              <% end %>
            </div>
          </div>

          <%= cond do %>
            <% @bible_edit_mode && @is_owner -> %>
              <!-- EDIT MODE: Show the form only -->
              <form phx-submit="save_bible" phx-change="validate_bible_upload" class="divide-y divide-gray-100">
                <.bible_edit_section title="Series Overview" icon="hero-document-text">
                  <.styled_input name="title" label="Bible Title" value={@bible_form[:title].value} placeholder="Story Bible" />
                  <.styled_textarea name="logline" label="Logline" value={@bible_form[:logline].value} rows={2} placeholder="One sentence that captures the essence of your series..." />
                  <.styled_input name="comparable_shows" label="Comparable Shows" value={@bible_form[:comparable_shows].value} placeholder="Breaking Bad meets Modern Family" />
                  <.styled_textarea name="target_audience" label="Target Audience" value={@bible_form[:target_audience].value} rows={2} placeholder="Who is this show for?" />
                  <.styled_textarea name="why_now" label="Why Now?" value={@bible_form[:why_now].value} rows={2} placeholder="What makes this culturally relevant today?" />
                </.bible_edit_section>

                <.bible_edit_section title="Main Content" icon="hero-book-open">
                  <.styled_textarea name="content" label="Main Bible Content" value={@bible_form[:content].value} rows={10} placeholder="The complete series bible content..." />
                </.bible_edit_section>

                <.bible_edit_section title="World Building" icon="hero-globe-alt">
                  <.styled_textarea name="world_building" label="World Building" value={@bible_form[:world_building].value} rows={5} placeholder="Setting, rules, social context, key locations..." />
                  <.styled_textarea name="visual_style" label="Visual Style" value={@bible_form[:visual_style].value} rows={3} placeholder="Color palette, cinematography, costume direction..." />
                  <.styled_textarea name="visual_motifs" label="Visual Motifs" value={@bible_form[:visual_motifs].value} rows={2} placeholder="Recurring visual symbols, imagery..." />
                  <.styled_textarea name="recurring_elements" label="Recurring Elements" value={@bible_form[:recurring_elements].value} rows={2} placeholder="Story elements, running gags, callbacks..." />
                </.bible_edit_section>

                <.bible_edit_section title="Tone & Style" icon="hero-paint-brush">
                  <.styled_textarea name="tone_style" label="Overall Tone" value={@bible_form[:tone_style].value} rows={3} placeholder="The emotional and stylistic feel of the series..." />
                  <.styled_textarea name="comedy_guidelines" label="Comedy Guidelines" value={@bible_form[:comedy_guidelines].value} rows={2} placeholder="Types of humor, what to avoid..." />
                  <.styled_textarea name="handling_serious_topics" label="Handling Serious Topics" value={@bible_form[:handling_serious_topics].value} rows={2} placeholder="Approach to sensitive material..." />
                </.bible_edit_section>

                <.bible_edit_section title="Format & Production" icon="hero-film">
                  <.styled_textarea name="format_details" label="Format Details" value={@bible_form[:format_details].value} rows={2} placeholder="Episode length, episodes per season..." />
                  <.styled_textarea name="episode_structure" label="Episode Structure" value={@bible_form[:episode_structure].value} rows={3} placeholder="Typical episode format, cold opens, act breaks..." />
                  <.styled_textarea name="production_notes" label="Production Notes" value={@bible_form[:production_notes].value} rows={3} placeholder="Budget considerations, special requirements..." />
                  <.styled_input name="consultant_needs" label="Consultant Needs" value={@bible_form[:consultant_needs].value} placeholder="Subject matter experts needed..." />
                  <.styled_input name="location_requirements" label="Location Requirements" value={@bible_form[:location_requirements].value} placeholder="Key shooting locations..." />
                  <.styled_input name="vfx_requirements" label="VFX Requirements" value={@bible_form[:vfx_requirements].value} placeholder="Visual effects needs..." />
                </.bible_edit_section>

                <!-- Save buttons -->
                <div class="p-4 sm:p-6 bg-gray-50">
                  <div class="flex items-center justify-end gap-2">
                    <button type="button" phx-click="cancel_bible_edit" class="px-4 py-2 text-sm border border-gray-200 rounded-lg bg-white hover:bg-gray-50 transition-colors">
                      Cancel
                    </button>
                    <button type="submit" class="px-4 py-2 text-sm bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors">
                      Save Bible
                    </button>
                  </div>
                </div>
              </form>

              <!-- Import from file (using JS file reader) -->
              <div class="px-4 sm:px-6 pb-4">
                <div id="bible-file-upload-edit" class="flex items-center gap-3 text-sm" phx-hook="BibleFileReader">
                  <span class="text-gray-500">Or import from file:</span>
                  <label class="text-purple-600 hover:text-purple-700 font-medium cursor-pointer">
                    Choose .txt/.pdf
                    <input type="file" accept=".txt,.pdf" class="hidden" id="bible-file-input-edit" />
                  </label>
                </div>
              </div>

            <% !@project.series_bible && @is_owner -> %>
              <!-- NO BIBLE YET: Show create options -->
              <div class="p-6 sm:p-8">
                <div class="max-w-md mx-auto text-center">
                  <.icon name="hero-book-open" class="w-12 h-12 text-gray-300 mx-auto mb-4" />
                  <h3 class="text-lg font-medium text-gray-900 mb-2">Create Your <%= bible_type_label(@project.project_type) %></h3>
                  <p class="text-gray-500 text-sm mb-6">
                    <%= bible_description(@project.project_type) %>
                  </p>

                  <div class="space-y-4">
                    <!-- Primary: Write manually -->
                    <button
                      phx-click="start_bible_edit"
                      class="w-full inline-flex items-center justify-center gap-2 px-4 py-3 bg-purple-600 text-white rounded-xl hover:bg-purple-700 font-medium transition-colors"
                    >
                      <.icon name="hero-pencil" class="w-5 h-5" />
                      Start Writing
                    </button>

                    <!-- Secondary: Upload file (using JS file reader) -->
                    <div
                      id="bible-file-upload"
                      class="border-2 border-dashed border-gray-200 rounded-xl p-4 hover:border-purple-300 transition-colors cursor-pointer"
                      phx-hook="BibleFileReader"
                    >
                      <label class="flex flex-col items-center cursor-pointer py-2">
                        <.icon name="hero-arrow-up-tray" class="w-6 h-6 text-gray-400 mb-1" />
                        <span class="text-sm text-gray-600">Upload existing <%= bible_type_label(@project.project_type) |> String.downcase() %></span>
                        <span class="text-xs text-gray-400">.txt or .pdf (click or drag)</span>
                        <input type="file" accept=".txt,.pdf" class="hidden" id="bible-file-input" />
                      </label>
                    </div>

                    <!-- Tertiary: Download template -->
                    <a
                      href={~p"/api/bible-template/#{@project.id}"}
                      download={"#{@project.title |> String.replace(~r/[^a-zA-Z0-9]/, "_")}_bible_template.txt"}
                      class="inline-flex items-center gap-1 text-sm text-gray-500 hover:text-purple-600"
                    >
                      <.icon name="hero-arrow-down-tray" class="w-4 h-4" />
                      Download template for <%= @project.project_type |> String.replace("_", " ") %>
                    </a>
                  </div>
                </div>
              </div>

            <% !@project.series_bible -> %>
              <!-- NO BIBLE, NOT OWNER: Just show message -->
              <div class="p-6 text-center">
                <p class="text-gray-500 text-sm">No series bible has been created yet.</p>
              </div>

            <% @project.series_bible -> %>
              <!-- HAS BIBLE: Show preview/full view -->
              <div class="p-4 sm:p-6">
                <%= if @project.series_bible.logline do %>
                  <p class="text-gray-700 italic mb-4 text-lg">"<%= @project.series_bible.logline %>"</p>
                <% end %>

                <div class="grid grid-cols-1 sm:grid-cols-2 gap-4 text-sm">
                  <%= if @project.series_bible.comparable_shows do %>
                    <div>
                      <span class="font-medium text-gray-500">Comparable Shows:</span>
                      <span class="text-gray-700 ml-1"><%= @project.series_bible.comparable_shows %></span>
                    </div>
                  <% end %>
                  <%= if @project.series_bible.target_audience do %>
                    <div>
                      <span class="font-medium text-gray-500">Target Audience:</span>
                      <span class="text-gray-700 ml-1"><%= @project.series_bible.target_audience %></span>
                    </div>
                  <% end %>
                  <%= if @project.series_bible.format_details do %>
                    <div>
                      <span class="font-medium text-gray-500">Format:</span>
                      <span class="text-gray-700 ml-1"><%= @project.series_bible.format_details %></span>
                    </div>
                  <% end %>
                </div>

                <%= if @bible_expanded do %>
                  <!-- EXPANDED VIEW: Show all sections -->
                  <%= if @project.series_bible.why_now && String.trim(@project.series_bible.why_now) != "" do %>
                    <div class="mt-4 pt-4 border-t">
                      <h4 class="font-medium text-gray-700 mb-2">Why Now?</h4>
                      <p class="text-sm text-gray-600 whitespace-pre-wrap"><%= @project.series_bible.why_now %></p>
                    </div>
                  <% end %>

                  <%= if @project.series_bible.content && String.trim(@project.series_bible.content) != "" do %>
                    <div class="mt-4 pt-4 border-t">
                      <h4 class="font-medium text-gray-700 mb-2">Overview</h4>
                      <p class="text-sm text-gray-600 whitespace-pre-wrap"><%= @project.series_bible.content %></p>
                    </div>
                  <% end %>

                  <%= if @project.series_bible.world_building && String.trim(@project.series_bible.world_building) != "" do %>
                    <div class="mt-4 pt-4 border-t">
                      <h4 class="font-medium text-gray-700 mb-2">World Building</h4>
                      <p class="text-sm text-gray-600 whitespace-pre-wrap"><%= @project.series_bible.world_building %></p>
                    </div>
                  <% end %>

                  <%= if @project.series_bible.tone_style && String.trim(@project.series_bible.tone_style) != "" do %>
                    <div class="mt-4 pt-4 border-t">
                      <h4 class="font-medium text-gray-700 mb-2">Tone & Style</h4>
                      <p class="text-sm text-gray-600 whitespace-pre-wrap"><%= @project.series_bible.tone_style %></p>
                    </div>
                  <% end %>

                  <%= if @project.series_bible.visual_style && String.trim(@project.series_bible.visual_style) != "" do %>
                    <div class="mt-4 pt-4 border-t">
                      <h4 class="font-medium text-gray-700 mb-2">Visual Style</h4>
                      <p class="text-sm text-gray-600 whitespace-pre-wrap"><%= @project.series_bible.visual_style %></p>
                    </div>
                  <% end %>

                  <%= if @project.series_bible.episode_structure && String.trim(@project.series_bible.episode_structure) != "" do %>
                    <div class="mt-4 pt-4 border-t">
                      <h4 class="font-medium text-gray-700 mb-2">Episode Structure</h4>
                      <p class="text-sm text-gray-600 whitespace-pre-wrap"><%= @project.series_bible.episode_structure %></p>
                    </div>
                  <% end %>

                  <%= if @project.series_bible.production_notes && String.trim(@project.series_bible.production_notes) != "" do %>
                    <div class="mt-4 pt-4 border-t">
                      <h4 class="font-medium text-gray-700 mb-2">Production Notes</h4>
                      <p class="text-sm text-gray-600 whitespace-pre-wrap"><%= @project.series_bible.production_notes %></p>
                    </div>
                  <% end %>

                  <div class="mt-4 pt-4 text-center">
                    <button
                      phx-click="toggle_bible_expanded"
                      class="text-sm text-purple-600 hover:text-purple-700 font-medium"
                    >
                      <.icon name="hero-chevron-up" class="w-4 h-4 inline" /> Show Less
                    </button>
                  </div>
                <% else %>
                  <!-- COLLAPSED VIEW: Show preview with expand button -->
                  <%= if @project.series_bible.content && String.trim(@project.series_bible.content) != "" do %>
                    <div class="mt-4 pt-4 border-t">
                      <p class="text-sm text-gray-700 whitespace-pre-wrap"><%= String.slice(@project.series_bible.content, 0..300) %><%= if String.length(@project.series_bible.content || "") > 300, do: "..." %></p>
                    </div>
                  <% end %>

                  <div class="mt-4 text-center">
                    <button
                      phx-click="toggle_bible_expanded"
                      class="text-sm text-purple-600 hover:text-purple-700 font-medium"
                    >
                      <.icon name="hero-chevron-down" class="w-4 h-4 inline" /> Read Full Story Bible
                    </button>
                  </div>
                <% end %>
              </div>
          <% end %>
        </div>

        <!-- Characters Section -->
        <div class="bg-white border rounded-xl mb-6 overflow-hidden">
          <div class="flex justify-between items-center p-4 sm:p-6 border-b border-gray-100">
            <h2 class="text-lg font-bold flex items-center gap-2">
              <.icon name="hero-users" class="w-5 h-5 text-blue-600" />
              Characters
              <span class="text-sm font-normal text-gray-400">(<%= length(@characters) %>)</span>
            </h2>
            <%= if @is_owner do %>
              <button
                phx-click="show_add_character"
                class="flex items-center gap-1 px-3 py-1.5 text-sm bg-blue-600 text-white rounded-lg hover:bg-blue-700 font-medium transition-colors"
              >
                <.icon name="hero-plus" class="w-4 h-4" />
                Add Character
              </button>
            <% end %>
          </div>

          <!-- Add Character Form -->
          <%= if @show_add_character do %>
            <div class="p-4 sm:p-6 bg-blue-50 border-b border-blue-100">
              <h3 class="font-medium mb-3">Add New Character</h3>
              <form phx-submit="create_character" class="space-y-4">
                <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
                  <.styled_input name="name" label="Name" placeholder="CHARACTER NAME" required />
                  <.styled_dropdown
                    name="gender"
                    label="Gender"
                    value="Unknown"
                    options={ProjectCharacter.genders() |> Enum.map(&{&1, &1})}
                  />
                  <.styled_dropdown
                    name="role_type"
                    label="Role Type"
                    value="recurring"
                    options={ProjectCharacter.role_types() |> Enum.map(&{String.capitalize(&1), &1})}
                  />
                </div>
                <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <.styled_dropdown
                    name="age_range"
                    label="Age Range"
                    value=""
                    options={[{"Not specified", ""} | Enum.map(ProjectCharacter.age_ranges(), &{&1, &1})]}
                  />
                  <.styled_input name="first_appearance" label="First Appearance" placeholder="e.g., S01E01 or Pilot" />
                </div>
                <.styled_textarea name="description" label="Description" rows={2} placeholder="Brief character description..." />
                <div class="flex gap-2">
                  <button type="submit" class="px-4 py-2 bg-blue-600 text-white rounded-xl hover:bg-blue-700 text-sm font-medium transition-colors">
                    Add Character
                  </button>
                  <button type="button" phx-click="cancel_add_character" class="px-4 py-2 border border-gray-200 rounded-xl hover:bg-white text-sm transition-colors">
                    Cancel
                  </button>
                </div>
              </form>
            </div>
          <% end %>

          <!-- Character List -->
          <div class="divide-y divide-gray-100">
            <%= if Enum.empty?(@characters) do %>
              <div class="p-8 text-center">
                <.icon name="hero-users" class="w-10 h-10 text-gray-300 mx-auto mb-3" />
                <p class="text-gray-500 text-sm mb-2">No characters defined yet.</p>
                <%= if @is_owner do %>
                  <p class="text-gray-400 text-xs">Add recurring characters that appear across multiple episodes.</p>
                <% end %>
              </div>
            <% else %>
              <%= for character <- @characters do %>
                <div class="hover:bg-gray-50 transition-colors">
                  <%= if @editing_character && @editing_character.id == character.id do %>
                    <!-- Inline Edit Form -->
                    <div class="p-4 bg-blue-50 border-l-4 border-blue-400">
                      <form phx-submit="update_character" class="space-y-3">
                        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                          <.styled_input name="name" label="Name" value={@character_form[:name].value} required />
                          <.styled_dropdown
                            name="gender"
                            label="Gender"
                            value={@character_form[:gender].value}
                            options={ProjectCharacter.genders() |> Enum.map(&{&1, &1})}
                          />
                        </div>
                        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                          <.styled_dropdown
                            name="role_type"
                            label="Role Type"
                            value={@character_form[:role_type].value}
                            options={ProjectCharacter.role_types() |> Enum.map(&{String.capitalize(&1), &1})}
                          />
                          <.styled_dropdown
                            name="age_range"
                            label="Age Range"
                            value={@character_form[:age_range].value}
                            options={[{"Not specified", ""} | Enum.map(ProjectCharacter.age_ranges(), &{&1, &1})]}
                          />
                        </div>
                        <.styled_input name="first_appearance" label="First Appearance" value={@character_form[:first_appearance].value} placeholder="e.g., S01E01" />
                        <.styled_textarea name="description" label="Description" value={@character_form[:description].value} rows={2} placeholder="Brief character description..." />
                        <.styled_textarea name="backstory" label="Backstory" value={@character_form[:backstory].value} rows={2} placeholder="Character background..." />
                        <.styled_textarea name="arc_notes" label="Arc Notes" value={@character_form[:arc_notes].value} rows={2} placeholder="Character arc notes..." />
                        <div class="flex gap-2 justify-end">
                          <button type="button" phx-click="cancel_edit_character" class="px-4 py-2 text-sm border border-gray-200 rounded-lg bg-white hover:bg-gray-50 transition-colors">
                            Cancel
                          </button>
                          <button type="submit" class="px-4 py-2 text-sm bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors">
                            Save Changes
                          </button>
                        </div>
                      </form>
                    </div>
                  <% else %>
                    <!-- Character Display -->
                    <div class="p-4">
                      <div class="flex items-start justify-between gap-4">
                        <div class="flex-1 min-w-0">
                          <div class="flex items-center gap-2 flex-wrap">
                            <span class="font-semibold text-gray-900"><%= character.name %></span>
                            <span class={"text-xs px-2 py-0.5 rounded-full " <> role_type_color(character.role_type)}>
                              <%= String.capitalize(character.role_type) %>
                            </span>
                            <%= if character.gender && character.gender != "Unknown" do %>
                              <span class="text-xs text-gray-500"><%= character.gender %></span>
                            <% end %>
                            <%= if character.age_range do %>
                              <span class="text-xs text-gray-500">· <%= character.age_range %></span>
                            <% end %>
                          </div>
                          <%= if character.description do %>
                            <p class="text-sm text-gray-600 mt-1"><%= character.description %></p>
                          <% end %>
                          <%= if character.first_appearance do %>
                            <p class="text-xs text-gray-400 mt-1">First appears: <%= character.first_appearance %></p>
                          <% end %>
                        </div>
                        <%= if @is_owner do %>
                          <div class="flex items-center gap-1 shrink-0">
                            <button
                              type="button"
                              phx-click="show_edit_character"
                              phx-value-id={character.id}
                              class="p-1.5 text-gray-400 hover:text-gray-600 hover:bg-gray-100 rounded-lg transition-colors"
                              title="Edit character"
                            >
                              <.icon name="hero-pencil" class="w-4 h-4" />
                            </button>
                            <button
                              type="button"
                              phx-click="confirm_delete_character"
                              phx-value-id={character.id}
                              class="p-1.5 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                              title="Delete character"
                            >
                              <.icon name="hero-trash" class="w-4 h-4" />
                            </button>
                          </div>
                        <% end %>
                      </div>
                    </div>
                  <% end %>
                </div>
              <% end %>
            <% end %>
          </div>
        </div>

        <!-- Episodes Section -->
        <div class="mb-6">
          <div class="flex justify-between items-center mb-4">
            <h2 class="text-lg font-bold">Episodes</h2>
            <%= if @is_owner do %>
              <div class="flex gap-2">
                <%= if length(@project.seasons) > 0 || @project.project_type != "anthology" do %>
                  <button
                    phx-click="show_add_season"
                    class="text-sm text-purple-600 hover:text-purple-700 font-medium"
                  >
                    + Add Season
                  </button>
                <% end %>
                <button
                  phx-click="show_add_episode"
                  class="text-sm text-emerald-600 hover:text-emerald-700 font-medium"
                >
                  + Add Episode
                </button>
              </div>
            <% end %>
          </div>

          <!-- Add Season Form -->
          <%= if @show_add_season do %>
            <div class="bg-purple-50 border border-purple-200 rounded-xl p-4 mb-4">
              <h3 class="font-medium mb-3">Add New Season</h3>
              <form phx-submit="create_season" class="space-y-3">
                <.styled_input
                  name="title"
                  label="Season Title (optional)"
                  placeholder="e.g., The Beginning"
                />
                <.styled_textarea
                  name="description"
                  label="Description (optional)"
                  rows={2}
                  placeholder="Season arc description..."
                />
                <div class="flex gap-2">
                  <button type="submit" class="px-4 py-2 bg-purple-600 text-white rounded-xl hover:bg-purple-700 text-sm font-medium transition-colors">
                    Create Season
                  </button>
                  <button type="button" phx-click="cancel_add_season" class="px-4 py-2 border border-gray-200 rounded-xl hover:bg-gray-50 text-sm transition-colors">
                    Cancel
                  </button>
                </div>
              </form>
            </div>
          <% end %>

          <!-- Add Episode Form -->
          <%= if @show_add_episode do %>
            <div class="bg-emerald-50 border border-emerald-200 rounded-xl p-4 mb-4">
              <h3 class="font-medium mb-3">Add New Episode</h3>
              <form phx-submit="create_episode" class="space-y-3">
                <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <.styled_input
                    name="title"
                    label="Title"
                    required={true}
                    placeholder="Episode title"
                  />
                  <.styled_dropdown
                    name="genre"
                    label="Genre"
                    value={@project.genre}
                    options={ScriptVoice.Screenplays.Screenplay.genres()}
                  />
                </div>
                <.styled_textarea
                  name="logline"
                  label="Logline"
                  required={true}
                  rows={2}
                  placeholder="A brief summary of the episode..."
                />
                <.styled_textarea
                  name="content"
                  label="Script Content (optional)"
                  rows={6}
                  placeholder="Paste your script content here, or upload later..."
                  class="font-mono"
                />
                <div class="flex gap-2">
                  <button type="submit" class="px-4 py-2 bg-emerald-600 text-white rounded-xl hover:bg-emerald-700 text-sm font-medium transition-colors">
                    Add Episode
                  </button>
                  <button type="button" phx-click="cancel_add_episode" class="px-4 py-2 border border-gray-200 rounded-xl hover:bg-gray-50 text-sm transition-colors">
                    Cancel
                  </button>
                </div>
              </form>
            </div>
          <% end %>

          <!-- Seasons with Episodes (Hierarchical) -->
          <%= if length(@project.seasons) > 0 do %>
            <div class="space-y-4">
              <%= for season <- @project.seasons do %>
                <div class="border rounded-xl overflow-hidden">
                  <!-- Season Header -->
                  <%= if @editing_season && @editing_season.id == season.id do %>
                    <!-- Inline Edit Form for Season -->
                    <div class="p-4 bg-purple-50 border-b">
                      <form phx-submit="update_season" class="space-y-3">
                        <div class="flex items-center gap-2 mb-2">
                          <span class="font-semibold text-purple-800">Edit Season <%= season.season_number %></span>
                        </div>
                        <.styled_input name="title" label="Season Title (optional)" value={@editing_season.title} placeholder="e.g., The Beginning" />
                        <.styled_textarea name="description" label="Description (optional)" value={@editing_season.description} rows={2} placeholder="Season arc description..." />
                        <div class="flex gap-2 justify-end">
                          <button type="button" phx-click="cancel_edit_season" class="px-4 py-2 text-sm border border-gray-200 rounded-lg bg-white hover:bg-gray-50 transition-colors">
                            Cancel
                          </button>
                          <button type="submit" class="px-4 py-2 text-sm bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors">
                            Save Changes
                          </button>
                        </div>
                      </form>
                    </div>
                  <% else %>
                    <!-- Normal Season Header -->
                    <div class="flex items-center bg-gray-50 border-b">
                      <button
                        phx-click="toggle_season"
                        phx-value-id={season.id}
                        class="flex-1 p-4 flex items-center gap-3 hover:bg-gray-100 transition text-left"
                      >
                        <.icon
                          name={if MapSet.member?(@expanded_seasons, season.id), do: "hero-chevron-down", else: "hero-chevron-right"}
                          class="w-5 h-5 text-gray-500"
                        />
                        <div>
                          <span class="font-semibold text-gray-900">Season <%= season.season_number %></span>
                          <%= if season.title do %>
                            <span class="text-gray-600 font-normal">: <%= season.title %></span>
                          <% end %>
                        </div>
                      </button>
                      <div class="flex items-center gap-2 pr-4">
                        <span class="text-sm text-gray-500 bg-gray-100 px-2 py-1 rounded-full"><%= length(season.episodes) %> episodes</span>
                        <%= if @is_owner do %>
                          <div class="flex items-center gap-1.5">
                            <button
                              phx-click="show_edit_season"
                              phx-value-id={season.id}
                              class="px-2.5 py-1.5 text-xs font-medium rounded-md border border-gray-300 bg-white text-gray-700 hover:bg-gray-100 transition-colors"
                            >
                              Edit
                            </button>
                            <button
                              phx-click="confirm_delete_season"
                              phx-value-id={season.id}
                              class="px-2.5 py-1.5 text-xs font-medium rounded-md border border-red-300 bg-white text-red-600 hover:bg-red-50 transition-colors"
                            >
                              Delete
                            </button>
                          </div>
                        <% end %>
                      </div>
                    </div>
                  <% end %>

                  <!-- Season Episodes -->
                  <%= if MapSet.member?(@expanded_seasons, season.id) do %>
                    <%
                      # Filter episodes: owners see all, viewers only see public episodes with content
                      visible_episodes = if @is_owner do
                        season.episodes
                      else
                        Enum.filter(season.episodes, fn ep ->
                          ep.is_public && has_script_content?(ep)
                        end)
                      end
                    %>
                    <div class="p-4 border-t space-y-2">
                      <%= if Enum.empty?(visible_episodes) do %>
                        <p class="text-gray-500 text-sm text-center py-4">
                          <%= if @is_owner, do: "No episodes in this season yet.", else: "No public episodes available yet." %>
                        </p>
                      <% else %>
                        <%= for episode <- Enum.sort_by(visible_episodes, & &1.episode_number) do %>
                          <.episode_card episode={episode} seasons={@project.seasons} moving_episode={@moving_episode} editing_episode={@editing_episode} confirm_delete={@confirm_delete_episode} is_owner={@is_owner} />
                        <% end %>
                      <% end %>
                      <%= if @is_owner do %>
                        <div class="flex gap-2 pt-2">
                          <button
                            phx-click="show_add_episode"
                            phx-value-season_id={season.id}
                            class="text-sm text-emerald-600 hover:text-emerald-700 font-medium"
                          >
                            + Add Episode to Season <%= season.season_number %>
                          </button>
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% end %>

          <!-- No Season Episodes (Flat) -->
          <%
            # Filter flat episodes: owners see all, viewers only see public episodes with content
            all_flat_episodes = Enum.filter(@project.episodes, & is_nil(&1.season_id))
            visible_flat_episodes = if @is_owner do
              all_flat_episodes
            else
              Enum.filter(all_flat_episodes, fn ep ->
                ep.is_public && has_script_content?(ep)
              end)
            end
          %>
          <%= if length(visible_flat_episodes) > 0 do %>
            <div class="mt-4">
              <%= if length(@project.seasons) > 0 do %>
                <h3 class="text-sm font-medium text-gray-500 mb-2"><%= if @is_owner, do: "No Season Episodes", else: "Episodes" %></h3>
              <% end %>
              <div class="space-y-2">
                <%= for episode <- Enum.sort_by(visible_flat_episodes, & &1.episode_number || 0) do %>
                  <.episode_card episode={episode} seasons={@project.seasons} moving_episode={@moving_episode} editing_episode={@editing_episode} confirm_delete={@confirm_delete_episode} is_owner={@is_owner} />
                <% end %>
              </div>
            </div>
          <% end %>

          <!-- Empty State -->
          <%
            # Count visible episodes for empty state check
            all_season_episodes = Enum.flat_map(@project.seasons, & &1.episodes)
            total_visible = if @is_owner do
              length(@project.episodes)
            else
              Enum.count(@project.episodes, fn ep -> ep.is_public && has_script_content?(ep) end)
            end
          %>
          <%= if Enum.empty?(@project.seasons) && total_visible == 0 do %>
            <div class="text-center py-8 bg-gray-50 rounded-xl border border-dashed border-gray-300">
              <.icon name="hero-film" class="w-10 h-10 text-gray-400 mx-auto mb-3" />
              <%= if @is_owner do %>
                <p class="text-gray-600 mb-4">No episodes yet. Add your first episode to get started.</p>
                <button
                  phx-click="show_add_episode"
                  class="inline-flex items-center gap-2 px-4 py-2 bg-emerald-600 text-white rounded-lg hover:bg-emerald-700 text-sm font-medium"
                >
                  <.icon name="hero-plus" class="w-4 h-4" />
                  Add First Episode
                </button>
              <% else %>
                <p class="text-gray-600">No public episodes available yet. Check back later!</p>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </div>

    <!-- Delete Season Confirmation Modal -->
    <%= if @confirm_delete_season do %>
      <.modal id="confirm-delete-season" show={true} on_cancel={JS.push("cancel_delete_season")}>
        <div class="space-y-4">
          <div class="flex items-center gap-3 text-red-600">
            <.icon name="hero-exclamation-triangle" class="w-6 h-6" />
            <h2 class="text-xl font-bold">Delete Season?</h2>
          </div>
          <%= if @confirm_delete_season.episode_count > 0 do %>
            <p class="text-gray-600">
              This season has <strong><%= @confirm_delete_season.episode_count %> episode(s)</strong>. What would you like to do with them?
            </p>
            <div class="space-y-2">
              <button
                type="button"
                phx-click="delete_season"
                phx-value-keep_episodes="true"
                class="w-full px-4 py-3 text-left border border-gray-200 rounded-xl hover:border-amber-500 hover:bg-amber-50 transition-colors"
              >
                <div class="font-medium text-gray-900">Keep Episodes</div>
                <div class="text-sm text-gray-500">Move episodes to unorganized, delete only the season</div>
              </button>
              <button
                type="button"
                phx-click="delete_season"
                phx-value-keep_episodes="false"
                class="w-full px-4 py-3 text-left border border-gray-200 rounded-xl hover:border-red-500 hover:bg-red-50 transition-colors"
              >
                <div class="font-medium text-red-600">Delete Everything</div>
                <div class="text-sm text-gray-500">Delete the season and all its episodes</div>
              </button>
            </div>
          <% else %>
            <p class="text-gray-600">This season has no episodes. Are you sure you want to delete it?</p>
            <div class="flex gap-2 justify-end">
              <button type="button" phx-click="cancel_delete_season" class="px-4 py-2 border border-gray-200 rounded-xl hover:bg-gray-50 transition-colors">
                Cancel
              </button>
              <button type="button" phx-click="delete_season" phx-value-keep_episodes="true" class="px-4 py-2 bg-red-600 text-white rounded-xl hover:bg-red-700 transition-colors">
                Delete Season
              </button>
            </div>
          <% end %>
        </div>
      </.modal>
    <% end %>

    <!-- Delete Episode Confirmation Modal -->
    <%= if @confirm_delete_episode do %>
      <.modal id="confirm-delete-episode" show={true} on_cancel={JS.push("cancel_delete_episode")}>
        <div class="space-y-4">
          <div class="flex items-center gap-3 text-red-600">
            <.icon name="hero-exclamation-triangle" class="w-6 h-6" />
            <h2 class="text-xl font-bold">Delete Episode?</h2>
          </div>
          <p class="text-gray-600">
            Are you sure you want to permanently delete this episode? This action cannot be undone.
          </p>
          <div class="flex gap-2 justify-end">
            <button type="button" phx-click="cancel_delete_episode" class="px-4 py-2 border border-gray-200 rounded-xl hover:bg-gray-50 transition-colors">
              Cancel
            </button>
            <button type="button" phx-click="delete_episode" class="px-4 py-2 bg-red-600 text-white rounded-xl hover:bg-red-700 transition-colors">
              Delete Episode
            </button>
          </div>
        </div>
      </.modal>
    <% end %>

    <!-- Delete Project Confirmation Modal -->
    <%= if @confirm_delete_project do %>
      <.modal id="confirm-delete-project" show={true} on_cancel={JS.push("cancel_delete_project")}>
        <div class="space-y-4">
          <div class="flex items-center gap-3 text-red-600">
            <.icon name="hero-exclamation-triangle" class="w-6 h-6" />
            <h2 class="text-xl font-bold">Delete Project?</h2>
          </div>
          <p class="text-gray-600">
            Are you sure you want to delete <strong>"<%= @project.title %>"</strong>?
          </p>
          <p class="text-sm text-gray-500">
            All episodes will become standalone screenplays. This action cannot be undone.
          </p>
          <div class="flex gap-2 justify-end">
            <button type="button" phx-click="cancel_delete_project" class="px-4 py-2 border border-gray-200 rounded-xl hover:bg-gray-50 transition-colors">
              Cancel
            </button>
            <button type="button" phx-click="delete_project" class="px-4 py-2 bg-red-600 text-white rounded-xl hover:bg-red-700 transition-colors">
              Delete Project
            </button>
          </div>
        </div>
      </.modal>
    <% end %>

    <!-- Delete Character Confirmation Modal -->
    <%= if @confirm_delete_character do %>
      <.modal id="confirm-delete-character" show={true} on_cancel={JS.push("cancel_delete_character")}>
        <div class="space-y-4">
          <div class="flex items-center gap-3 text-red-600">
            <.icon name="hero-exclamation-triangle" class="w-6 h-6" />
            <h2 class="text-xl font-bold">Delete Character?</h2>
          </div>
          <p class="text-gray-600">
            Are you sure you want to permanently delete this character? This action cannot be undone.
          </p>
          <div class="flex gap-2 justify-end">
            <button type="button" phx-click="cancel_delete_character" class="px-4 py-2 border border-gray-200 rounded-xl hover:bg-gray-50 transition-colors">
              Cancel
            </button>
            <button type="button" phx-click="delete_character" class="px-4 py-2 bg-red-600 text-white rounded-xl hover:bg-red-700 transition-colors">
              Delete Character
            </button>
          </div>
        </div>
      </.modal>
    <% end %>
    """
  end

  # ===========================================================================
  # COMPONENTS
  # ===========================================================================

  defp project_type_color("series"), do: "bg-blue-100 text-blue-700"
  defp project_type_color("limited_series"), do: "bg-indigo-100 text-indigo-700"
  defp project_type_color("anthology"), do: "bg-purple-100 text-purple-700"
  defp project_type_color("miniseries"), do: "bg-amber-100 text-amber-700"
  defp project_type_color("web_series"), do: "bg-cyan-100 text-cyan-700"
  defp project_type_color("feature_film"), do: "bg-rose-100 text-rose-700"
  defp project_type_color("documentary_series"), do: "bg-teal-100 text-teal-700"
  defp project_type_color("podcast_drama"), do: "bg-orange-100 text-orange-700"
  defp project_type_color("short_film_collection"), do: "bg-pink-100 text-pink-700"
  defp project_type_color(_), do: "bg-gray-100 text-gray-700"

  defp role_type_color("lead"), do: "bg-purple-100 text-purple-700"
  defp role_type_color("supporting"), do: "bg-blue-100 text-blue-700"
  defp role_type_color("recurring"), do: "bg-green-100 text-green-700"
  defp role_type_color("guest"), do: "bg-gray-100 text-gray-700"
  defp role_type_color(_), do: "bg-gray-100 text-gray-700"

  defp format_project_type(type) do
    type
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp format_status(status) do
    status
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp bible_sections do
    [
      %{id: "overview", title: "Overview", icon: "hero-document-text"},
      %{id: "content", title: "Content", icon: "hero-book-open"},
      %{id: "world", title: "World", icon: "hero-globe-alt"},
      %{id: "tone", title: "Tone", icon: "hero-paint-brush"},
      %{id: "format", title: "Format", icon: "hero-rectangle-stack"},
      %{id: "production", title: "Production", icon: "hero-film"}
    ]
  end

  attr :episode, :map, required: true
  attr :seasons, :list, default: []
  attr :moving_episode, :any, default: nil
  attr :editing_episode, :any, default: nil
  attr :confirm_delete, :any, default: nil
  attr :is_owner, :boolean, default: false

  # Helper to check if an episode has actual script content
  defp has_script_content?(episode) do
    (episode.script_content && String.trim(episode.script_content) != "") ||
    (episode.pdf_url && String.trim(episode.pdf_url) != "")
  end

  defp episode_card(assigns) do
    has_content = has_script_content?(assigns.episode)
    is_editing = assigns.editing_episode && assigns.editing_episode.id == assigns.episode.id
    is_moving = assigns.moving_episode && assigns.moving_episode.id == assigns.episode.id
    assigns = assigns
      |> assign(:has_content, has_content)
      |> assign(:is_editing, is_editing)
      |> assign(:is_moving, is_moving)

    ~H"""
    <div class="bg-white border rounded-xl hover:border-emerald-300 hover:shadow-sm transition">
      <!-- Episode Row -->
      <div class="flex items-center justify-between p-3">
        <div class="flex items-center gap-3 flex-1 min-w-0">
          <span class="text-sm font-mono text-gray-500 w-16 shrink-0">
            <%= @episode.episode_code || "E#{String.pad_leading(to_string(@episode.episode_number || 0), 3, "0")}" %>
          </span>
          <div class="min-w-0 flex-1">
            <div class="flex items-center gap-2">
              <.link navigate={~p"/screenplay/#{@episode.id}"} class="font-medium text-gray-900 hover:text-emerald-600 block truncate">
                <%= @episode.title %>
              </.link>
              <%= if @is_owner do %>
                <%= if @has_content do %>
                  <%= if @episode.is_public do %>
                    <span class="text-xs px-1.5 py-0.5 bg-emerald-100 text-emerald-700 rounded">Public</span>
                  <% else %>
                    <span class="text-xs px-1.5 py-0.5 bg-gray-100 text-gray-600 rounded">Private</span>
                  <% end %>
                <% else %>
                  <span class="text-xs px-1.5 py-0.5 bg-amber-100 text-amber-700 rounded">No Script</span>
                <% end %>
              <% end %>
            </div>
            <p class="text-sm text-gray-500 line-clamp-1"><%= @episode.logline %></p>
          </div>
        </div>

        <!-- Right side: metadata + actions -->
        <div class="flex items-center gap-2 shrink-0 ml-4">
          <%= if @has_content do %>
            <span class="text-xs text-gray-400 hidden sm:inline"><%= @episode.page_count || "?" %> pg · v<%= @episode.version %></span>
          <% else %>
            <span class="text-xs text-gray-400 hidden sm:inline">v<%= @episode.version %></span>
          <% end %>

          <!-- View Script button (only when content exists) -->
          <%= if @has_content do %>
            <.link
              navigate={~p"/screenplay/#{@episode.id}"}
              class="px-3 py-1.5 text-xs font-medium rounded-lg bg-emerald-600 text-white hover:bg-emerald-700 transition-colors"
            >
              View
            </.link>
          <% end %>

          <!-- 3-dot menu for owners -->
          <%= if @is_owner do %>
            <div class="relative inline-flex">
              <button
                type="button"
                phx-click={JS.toggle(to: "#episode-menu-#{@episode.id}", in: "fade-in-scale", out: "fade-out-scale")}
                class="inline-flex items-center justify-center w-8 h-8 text-gray-400 hover:text-gray-600 hover:bg-gray-100 rounded-full transition-colors"
                title="More options"
              >
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor" class="w-5 h-5">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M12 6.75a.75.75 0 110-1.5.75.75 0 010 1.5zM12 12.75a.75.75 0 110-1.5.75.75 0 010 1.5zM12 18.75a.75.75 0 110-1.5.75.75 0 010 1.5z" />
                </svg>
              </button>

              <!-- Dropdown menu -->
              <div
                id={"episode-menu-#{@episode.id}"}
                phx-click-away={JS.hide(to: "#episode-menu-#{@episode.id}")}
                class="hidden absolute right-0 top-full mt-1 w-48 bg-white rounded-lg shadow-lg border border-gray-200 py-1 z-50"
              >
                <!-- Add Script / Edit Script (conditional) -->
                <.link
                  navigate={~p"/screenplay/#{@episode.id}/edit"}
                  class="flex items-center gap-2 px-4 py-2 text-sm text-gray-700 hover:bg-gray-50"
                >
                  <.icon name="hero-pencil-square" class="w-4 h-4" />
                  <%= if @has_content, do: "Edit Script", else: "Add Script" %>
                </.link>

                <!-- Edit Details (inline) -->
                <button
                  type="button"
                  phx-click={JS.push("show_edit_episode", value: %{id: @episode.id}) |> JS.hide(to: "#episode-menu-#{@episode.id}")}
                  class="w-full flex items-center gap-2 px-4 py-2 text-sm text-gray-700 hover:bg-gray-50 text-left"
                >
                  <.icon name="hero-cog-6-tooth" class="w-4 h-4" />
                  Edit Details
                </button>

                <!-- Move to Season (inline) -->
                <%= if length(@seasons) > 0 do %>
                  <button
                    type="button"
                    phx-click={JS.push("show_move_episode", value: %{id: @episode.id}) |> JS.hide(to: "#episode-menu-#{@episode.id}")}
                    class="w-full flex items-center gap-2 px-4 py-2 text-sm text-gray-700 hover:bg-gray-50 text-left"
                  >
                    <.icon name="hero-arrows-right-left" class="w-4 h-4" />
                    Move to Season
                  </button>
                <% end %>

                <div class="border-t border-gray-100 my-1"></div>

                <!-- Visibility Toggle (disabled if no content) -->
                <%= if @has_content do %>
                  <button
                    type="button"
                    phx-click={JS.push("toggle_episode_visibility", value: %{id: @episode.id}) |> JS.hide(to: "#episode-menu-#{@episode.id}")}
                    class="w-full flex items-center gap-2 px-4 py-2 text-sm text-gray-700 hover:bg-gray-50 text-left"
                  >
                    <%= if @episode.is_public do %>
                      <.icon name="hero-eye-slash" class="w-4 h-4" />
                      Make Private
                    <% else %>
                      <.icon name="hero-eye" class="w-4 h-4" />
                      Make Public
                    <% end %>
                  </button>
                <% else %>
                  <div class="flex items-center gap-2 px-4 py-2 text-sm text-gray-400 cursor-not-allowed">
                    <.icon name="hero-eye-slash" class="w-4 h-4" />
                    Make Public
                    <span class="text-xs">(add script first)</span>
                  </div>
                <% end %>

                <div class="border-t border-gray-100 my-1"></div>

                <!-- Delete -->
                <button
                  type="button"
                  phx-click={JS.push("confirm_delete_episode", value: %{id: @episode.id}) |> JS.hide(to: "#episode-menu-#{@episode.id}")}
                  class="w-full flex items-center gap-2 px-4 py-2 text-sm text-red-600 hover:bg-red-50 text-left"
                >
                  <.icon name="hero-trash" class="w-4 h-4" />
                  Delete Episode
                </button>
              </div>
            </div>
          <% else %>
            <!-- Non-owners see "Coming soon" if no content -->
            <%= if !@has_content do %>
              <span class="text-xs text-gray-400 italic">Coming soon</span>
            <% end %>
          <% end %>
        </div>
      </div>

      <!-- Inline Edit Form -->
      <%= if @is_editing do %>
        <div class="border-t border-gray-100 p-4 bg-gray-50">
          <form phx-submit="update_episode" class="space-y-3">
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <.styled_input name="title" label="Title" value={@editing_episode.title} required />
              <.styled_dropdown
                name="genre"
                label="Genre"
                value={@editing_episode.genre}
                options={ScriptVoice.Screenplays.Screenplay.genres()}
              />
            </div>
            <.styled_textarea name="logline" label="Logline" value={@editing_episode.logline} required rows={2} />
            <div class="flex gap-2 justify-end">
              <button type="button" phx-click="cancel_edit_episode" class="px-4 py-2 text-sm border border-gray-200 rounded-lg hover:bg-white transition-colors">
                Cancel
              </button>
              <button type="submit" class="px-4 py-2 text-sm bg-emerald-600 text-white rounded-lg hover:bg-emerald-700 transition-colors">
                Save Changes
              </button>
            </div>
          </form>
        </div>
      <% end %>

      <!-- Inline Move Form -->
      <%= if @is_moving do %>
        <div class="border-t border-gray-100 p-4 bg-blue-50">
          <p class="text-sm font-medium mb-3">Move to:</p>
          <div class="flex flex-wrap gap-2">
            <button
              type="button"
              phx-click="move_episode"
              phx-value-season_id="none"
              class={"px-3 py-1.5 text-sm rounded-lg border transition-colors " <>
                if(is_nil(@episode.season_id), do: "border-emerald-500 bg-emerald-100 text-emerald-700", else: "border-gray-200 hover:border-gray-300 bg-white")}
            >
              No Season
            </button>
            <%= for season <- @seasons do %>
              <button
                type="button"
                phx-click="move_episode"
                phx-value-season_id={season.id}
                class={"px-3 py-1.5 text-sm rounded-lg border transition-colors " <>
                  if(@episode.season_id == season.id, do: "border-emerald-500 bg-emerald-100 text-emerald-700", else: "border-gray-200 hover:border-gray-300 bg-white")}
              >
                Season <%= season.season_number %>
              </button>
            <% end %>
            <button type="button" phx-click="cancel_move_episode" class="px-3 py-1.5 text-sm text-gray-500 hover:text-gray-700">
              Cancel
            </button>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # ===========================================================================
  # BIBLE SECTION COMPONENTS
  # ===========================================================================

  attr :title, :string, required: true
  attr :icon, :string, required: true
  slot :inner_block, required: true

  defp bible_edit_section(assigns) do
    ~H"""
    <div class="p-4 sm:p-6">
      <h3 class="flex items-center gap-2 text-sm font-semibold text-gray-900 mb-4">
        <.icon name={@icon} class="w-4 h-4 text-purple-600" />
        <%= @title %>
      </h3>
      <div class="space-y-4">
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :icon, :string, required: true
  attr :bible, :map, required: true
  slot :inner_block, required: true

  defp bible_read_section(assigns) do
    ~H"""
    <div class="p-4 sm:p-6">
      <h3 class="flex items-center gap-2 text-sm font-semibold text-gray-900 mb-4">
        <.icon name={@icon} class="w-4 h-4 text-purple-600" />
        <%= @title %>
      </h3>
      <div class="space-y-3">
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, default: nil
  attr :italic, :boolean, default: false

  defp bible_field(assigns) do
    ~H"""
    <%= if @value && String.trim(@value || "") != "" do %>
      <div>
        <dt class="text-xs font-medium text-gray-500 uppercase tracking-wide mb-1"><%= @label %></dt>
        <dd class={["text-sm text-gray-700 whitespace-pre-wrap", @italic && "italic"]}>
          <%= @value %>
        </dd>
      </div>
    <% end %>
    """
  end

  # Upload error messages for bible file uploads
  defp bible_upload_error(:too_large), do: "File is too large (max 10MB)"
  defp bible_upload_error(:not_accepted), do: "Only .txt or .pdf files are accepted"
  defp bible_upload_error(:too_many_files), do: "Only one file allowed"
  defp bible_upload_error(_), do: "Upload error"

  # Bible type labels based on project type
  # Universal term for all project types
  defp bible_type_label(_), do: "Story Bible"

  # Bible descriptions based on project type
  defp bible_description("feature_film") do
    "Document your story world, characters, themes, and visual style for consistent filmmaking."
  end
  defp bible_description("short_film_collection") do
    "Document the connecting threads, themes, and style that unite your short films."
  end
  defp bible_description("podcast_drama") do
    "Document your world, characters, tone, and sonic identity for consistent audio production."
  end
  defp bible_description("documentary_series") do
    "Document your subject, research, interview subjects, and visual approach."
  end
  defp bible_description(_) do
    "Document your world, characters, tone, and production notes."
  end
end
