defmodule ScriptVoiceWeb.ProjectLive do
  @moduledoc """
  LiveView for managing screenplay projects (series, anthologies, miniseries).
  Shows project details, seasons, episodes, and series bible.
  """
  use ScriptVoiceWeb, :live_view

  alias ScriptVoice.Projects
  alias ScriptVoice.Screenplays
  alias ScriptVoice.Screenplays.{ScreenplayProject, ScreenplaySeason, SeriesBible}

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

        unless is_owner do
          {:ok,
           socket
           |> put_flash(:error, "You don't have access to this project")
           |> push_navigate(to: ~p"/dashboard")}
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
           |> assign(:selected_season_id, params["season_id"])
           |> assign(:page_title, project.title)
           |> assign(:new_season_form, to_form(%{"title" => "", "description" => ""}))
           |> assign(:new_episode_form, to_form(%{"title" => "", "genre" => "Drama", "logline" => ""}))
           |> assign(:bible_form, init_bible_form(project.series_bible))}
        end
    end
  end

  defp init_bible_form(nil) do
    to_form(%{"title" => "Series Bible", "content" => "", "world_building" => "", "tone_style" => ""})
  end

  defp init_bible_form(bible) do
    to_form(%{
      "title" => bible.title || "Series Bible",
      "content" => bible.content || "",
      "world_building" => bible.world_building || "",
      "tone_style" => bible.tone_style || ""
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
  def handle_event("delete_season", %{"id" => season_id}, socket) do
    season = Projects.get_season!(season_id)
    case Projects.delete_season(season) do
      {:ok, _} ->
        project = Projects.get_project_with_preloads(socket.assigns.project.id)
        {:noreply,
         socket
         |> assign(:project, project)
         |> put_flash(:info, "Season deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete season")}
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
  def handle_event("delete_project", _, socket) do
    case Projects.delete_project(socket.assigns.project) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Project deleted")
         |> push_navigate(to: ~p"/dashboard?tab=screenplays")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete project")}
    end
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

            <div class="flex flex-wrap items-center gap-2 w-full sm:w-auto">
              <button
                phx-click="show_edit_project"
                class="px-3 py-2 text-sm border border-gray-300 rounded-lg hover:bg-gray-50"
              >
                <.icon name="hero-pencil" class="w-4 h-4" />
              </button>
              <button
                phx-click="delete_project"
                data-confirm="Are you sure you want to delete this project? All episodes will become standalone."
                class="px-3 py-2 text-sm border border-red-300 text-red-600 rounded-lg hover:bg-red-50"
              >
                <.icon name="hero-trash" class="w-4 h-4" />
              </button>
            </div>
          </div>

          <p class="text-gray-700 text-base mb-4"><%= @project.logline %></p>

          <%= if @project.description do %>
            <p class="text-gray-600 text-sm"><%= @project.description %></p>
          <% end %>
        </div>

        <!-- Series Bible Section -->
        <div class="bg-white border rounded-xl p-4 sm:p-6 mb-6">
          <div class="flex justify-between items-center mb-4">
            <h2 class="text-lg font-bold flex items-center gap-2">
              <.icon name="hero-book-open" class="w-5 h-5 text-purple-600" />
              Series Bible
            </h2>
            <button
              phx-click="show_bible_editor"
              class="text-sm text-emerald-600 hover:text-emerald-700 font-medium"
            >
              <%= if @project.series_bible, do: "Edit", else: "Add" %>
            </button>
          </div>

          <%= if @project.series_bible do %>
            <div class="text-gray-600 text-sm">
              <p class="font-medium"><%= @project.series_bible.title %></p>
              <%= if @project.series_bible.content do %>
                <p class="mt-2 line-clamp-3"><%= @project.series_bible.content %></p>
              <% end %>
              <p class="mt-2 text-xs text-gray-400">
                Version <%= @project.series_bible.version %>
                <%= if @project.series_bible.last_updated_at do %>
                  · Updated <%= Calendar.strftime(@project.series_bible.last_updated_at, "%b %d, %Y") %>
                <% end %>
              </p>
            </div>
          <% else %>
            <p class="text-gray-500 text-sm">
              No series bible yet. Add one to document your world, characters, and tone.
            </p>
          <% end %>
        </div>

        <!-- Episodes Section -->
        <div class="mb-6">
          <div class="flex justify-between items-center mb-4">
            <h2 class="text-lg font-bold">Episodes</h2>
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
          </div>

          <!-- Add Season Form -->
          <%= if @show_add_season do %>
            <div class="bg-purple-50 border border-purple-200 rounded-xl p-4 mb-4">
              <h3 class="font-medium mb-3">Add New Season</h3>
              <form phx-submit="create_season" class="space-y-3">
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Season Title (optional)</label>
                  <input
                    type="text"
                    name="title"
                    placeholder="e.g., The Beginning"
                    class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
                  />
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Description (optional)</label>
                  <textarea
                    name="description"
                    rows="2"
                    placeholder="Season arc description..."
                    class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
                  ></textarea>
                </div>
                <div class="flex gap-2">
                  <button type="submit" class="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 text-sm font-medium">
                    Create Season
                  </button>
                  <button type="button" phx-click="cancel_add_season" class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 text-sm">
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
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Title *</label>
                    <input
                      type="text"
                      name="title"
                      required
                      placeholder="Episode title"
                      class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
                    />
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Genre</label>
                    <select name="genre" class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500">
                      <%= for genre <- ScriptVoice.Screenplays.Screenplay.genres() do %>
                        <option value={genre} selected={genre == @project.genre}><%= genre %></option>
                      <% end %>
                    </select>
                  </div>
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Logline *</label>
                  <textarea
                    name="logline"
                    required
                    rows="2"
                    minlength="10"
                    placeholder="A brief summary of the episode..."
                    class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
                  ></textarea>
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Script Content (optional)</label>
                  <textarea
                    name="content"
                    rows="6"
                    placeholder="Paste your script content here, or upload later..."
                    class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 font-mono text-sm"
                  ></textarea>
                </div>
                <div class="flex gap-2">
                  <button type="submit" class="px-4 py-2 bg-emerald-600 text-white rounded-lg hover:bg-emerald-700 text-sm font-medium">
                    Add Episode
                  </button>
                  <button type="button" phx-click="cancel_add_episode" class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 text-sm">
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
                  <button
                    phx-click="toggle_season"
                    phx-value-id={season.id}
                    class="w-full p-4 flex items-center justify-between bg-gray-50 hover:bg-gray-100 transition"
                  >
                    <div class="flex items-center gap-3">
                      <.icon
                        name={if MapSet.member?(@expanded_seasons, season.id), do: "hero-chevron-down", else: "hero-chevron-right"}
                        class="w-5 h-5 text-gray-500"
                      />
                      <div class="text-left">
                        <span class="font-medium">Season <%= season.season_number %></span>
                        <%= if season.title do %>
                          <span class="text-gray-500">: <%= season.title %></span>
                        <% end %>
                      </div>
                    </div>
                    <span class="text-sm text-gray-500">
                      <%= length(season.episodes) %> episodes
                    </span>
                  </button>

                  <!-- Season Episodes -->
                  <%= if MapSet.member?(@expanded_seasons, season.id) do %>
                    <div class="p-4 border-t space-y-2">
                      <%= if Enum.empty?(season.episodes) do %>
                        <p class="text-gray-500 text-sm text-center py-4">
                          No episodes in this season yet.
                        </p>
                      <% else %>
                        <%= for episode <- Enum.sort_by(season.episodes, & &1.episode_number) do %>
                          <.episode_card episode={episode} />
                        <% end %>
                      <% end %>
                      <div class="flex gap-2 pt-2">
                        <button
                          phx-click="show_add_episode"
                          phx-value-season_id={season.id}
                          class="text-sm text-emerald-600 hover:text-emerald-700"
                        >
                          + Add Episode to Season <%= season.season_number %>
                        </button>
                        <button
                          phx-click="delete_season"
                          phx-value-id={season.id}
                          data-confirm="Delete this season? Episodes will become unorganized."
                          class="text-sm text-red-600 hover:text-red-700 ml-auto"
                        >
                          Delete Season
                        </button>
                      </div>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% end %>

          <!-- Unorganized Episodes (Flat) -->
          <% flat_episodes = Enum.filter(@project.episodes, & is_nil(&1.season_id)) %>
          <%= if length(flat_episodes) > 0 do %>
            <div class="mt-4">
              <%= if length(@project.seasons) > 0 do %>
                <h3 class="text-sm font-medium text-gray-500 mb-2">Unorganized Episodes</h3>
              <% end %>
              <div class="space-y-2">
                <%= for episode <- Enum.sort_by(flat_episodes, & &1.episode_number || 0) do %>
                  <.episode_card episode={episode} />
                <% end %>
              </div>
            </div>
          <% end %>

          <!-- Empty State -->
          <%= if Enum.empty?(@project.seasons) && Enum.empty?(@project.episodes) do %>
            <div class="text-center py-8 bg-gray-50 rounded-xl border border-dashed border-gray-300">
              <.icon name="hero-film" class="w-10 h-10 text-gray-400 mx-auto mb-3" />
              <p class="text-gray-600 mb-4">No episodes yet. Add your first episode to get started.</p>
              <button
                phx-click="show_add_episode"
                class="inline-flex items-center gap-2 px-4 py-2 bg-emerald-600 text-white rounded-lg hover:bg-emerald-700 text-sm font-medium"
              >
                <.icon name="hero-plus" class="w-4 h-4" />
                Add First Episode
              </button>
            </div>
          <% end %>
        </div>
      </div>
    </div>

    <!-- Bible Editor Modal -->
    <%= if @show_bible_editor do %>
      <.modal id="bible-editor" show={true} on_cancel={JS.push("close_bible_editor")}>
        <div class="space-y-4">
          <h2 class="text-xl font-bold">Series Bible</h2>
          <form phx-submit="save_bible" class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Title</label>
              <input
                type="text"
                name="title"
                value={@bible_form[:title].value}
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Content</label>
              <textarea
                name="content"
                rows="8"
                placeholder="Main series bible content..."
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500"
              ><%= @bible_form[:content].value %></textarea>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">World Building</label>
              <textarea
                name="world_building"
                rows="4"
                placeholder="World, setting, rules..."
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500"
              ><%= @bible_form[:world_building].value %></textarea>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Tone & Style</label>
              <textarea
                name="tone_style"
                rows="4"
                placeholder="Tone, visual style, pacing..."
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500"
              ><%= @bible_form[:tone_style].value %></textarea>
            </div>
            <div class="flex gap-2 justify-end">
              <button type="button" phx-click="close_bible_editor" class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50">
                Cancel
              </button>
              <button type="submit" class="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700">
                Save Bible
              </button>
            </div>
          </form>
        </div>
      </.modal>
    <% end %>

    <!-- Edit Project Modal -->
    <%= if @show_edit_project do %>
      <.modal id="edit-project" show={true} on_cancel={JS.push("cancel_edit_project")}>
        <div class="space-y-4">
          <h2 class="text-xl font-bold">Edit Project</h2>
          <form phx-submit="update_project" class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Title *</label>
              <input
                type="text"
                name="title"
                value={@project.title}
                required
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-emerald-500"
              />
            </div>
            <div class="grid grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Type</label>
                <select name="project_type" class="w-full px-3 py-2 border border-gray-300 rounded-lg">
                  <%= for type <- ScriptVoice.Screenplays.ScreenplayProject.project_types() do %>
                    <option value={type} selected={type == @project.project_type}><%= String.capitalize(type) %></option>
                  <% end %>
                </select>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Genre</label>
                <select name="genre" class="w-full px-3 py-2 border border-gray-300 rounded-lg">
                  <%= for genre <- ScriptVoice.Screenplays.ScreenplayProject.genres() do %>
                    <option value={genre} selected={genre == @project.genre}><%= genre %></option>
                  <% end %>
                </select>
              </div>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Logline *</label>
              <textarea
                name="logline"
                required
                rows="2"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg"
              ><%= @project.logline %></textarea>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Description</label>
              <textarea
                name="description"
                rows="3"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg"
              ><%= @project.description %></textarea>
            </div>
            <div class="grid grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Total Episodes (planned)</label>
                <input
                  type="number"
                  name="total_episodes"
                  value={@project.total_episodes}
                  min="1"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Status</label>
                <select name="status" class="w-full px-3 py-2 border border-gray-300 rounded-lg">
                  <%= for status <- ScriptVoice.Screenplays.ScreenplayProject.statuses() do %>
                    <option value={status} selected={status == @project.status}><%= String.capitalize(status) %></option>
                  <% end %>
                </select>
              </div>
            </div>
            <div class="flex gap-2 justify-end">
              <button type="button" phx-click="cancel_edit_project" class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50">
                Cancel
              </button>
              <button type="submit" class="px-4 py-2 bg-emerald-600 text-white rounded-lg hover:bg-emerald-700">
                Save Changes
              </button>
            </div>
          </form>
        </div>
      </.modal>
    <% end %>
    """
  end

  # ===========================================================================
  # COMPONENTS
  # ===========================================================================

  defp project_type_color("series"), do: "bg-blue-100 text-blue-700"
  defp project_type_color("anthology"), do: "bg-purple-100 text-purple-700"
  defp project_type_color("miniseries"), do: "bg-amber-100 text-amber-700"
  defp project_type_color(_), do: "bg-gray-100 text-gray-700"

  attr :episode, :map, required: true

  defp episode_card(assigns) do
    ~H"""
    <div class="flex items-center justify-between p-3 bg-white border rounded-lg hover:border-emerald-300 transition">
      <div class="flex items-center gap-3">
        <span class="text-sm font-mono text-gray-500 w-16">
          <%= @episode.episode_code || "E#{String.pad_leading(to_string(@episode.episode_number || 0), 3, "0")}" %>
        </span>
        <div>
          <.link navigate={~p"/screenplay/#{@episode.id}"} class="font-medium text-gray-900 hover:text-emerald-600">
            <%= @episode.title %>
          </.link>
          <p class="text-sm text-gray-500 line-clamp-1"><%= @episode.logline %></p>
        </div>
      </div>
      <div class="flex items-center gap-2">
        <span class="text-xs text-gray-400"><%= @episode.page_count || "?" %> pg</span>
        <span class="text-xs text-gray-400">v<%= @episode.version %></span>
        <.link navigate={~p"/screenplay/#{@episode.id}"} class="text-emerald-600 hover:text-emerald-700">
          <.icon name="hero-arrow-right" class="w-4 h-4" />
        </.link>
      </div>
    </div>
    """
  end
end
