defmodule ScriptVoiceWeb.BrowseLive do
  @moduledoc """
  Browse page LiveView - Browse stories with filters and sorting.
  Mobile-first design with horizontal scrolling filters.
  Includes simplified inline create form for writers that redirects to editor.
  Organizes content into Projects and Standalone Stories.
  """
  use ScriptVoiceWeb, :live_view

  alias ScriptVoice.Screenplays
  alias ScriptVoice.Screenplays.Screenplay
  alias ScriptVoice.Social

  @genres ["All" | Screenplay.genres()]
  @sort_options [
    {"Most Recent", "recent"},
    {"Most Popular", "popular"},
    {"Needs Audio", "needs_audio"}
  ]

  @impl true
  def mount(_params, session, socket) do
    current_user = get_current_user(session)

    liked_ids =
      if current_user do
        Social.get_liked_screenplay_ids(current_user.id)
      else
        []
      end

    {:ok,
     socket
     |> assign(:current_user, current_user)
     |> assign(:genres, @genres)
     |> assign(:sort_options, @sort_options)
     |> assign(:selected_genre, "All")
     |> assign(:selected_sort, "recent")
     |> assign(:liked_screenplay_ids, liked_ids)
     |> assign(:show_upload_form, false)
     |> assign(:page_title, "Browse Stories")
     |> assign(:view_mode, "all")
     |> init_upload_form()
     |> load_content()}
  end

  defp init_upload_form(socket) do
    socket
    |> assign(:upload_title, "")
    |> assign(:upload_genre, "Drama")
    |> assign(:upload_logline, "")
    |> assign(:upload_error, nil)
  end

  @impl true
  def handle_params(params, _uri, socket) do
    genre = Map.get(params, "genre", "All")
    sort = Map.get(params, "sort", "recent")
    view_mode = Map.get(params, "view", "all")

    {:noreply,
     socket
     |> assign(:selected_genre, genre)
     |> assign(:selected_sort, sort)
     |> assign(:view_mode, view_mode)
     |> load_content()}
  end

  defp load_content(socket) do
    genre = socket.assigns.selected_genre
    sort = parse_sort(socket.assigns.selected_sort)

    # Load all projects with their episodes
    projects = list_all_projects_with_episodes(genre)

    # Load standalone screenplays (not part of any project)
    standalone_screenplays = Screenplays.list_standalone_screenplays(sort: sort, genre: genre)

    socket
    |> assign(:projects, projects)
    |> assign(:standalone_screenplays, standalone_screenplays)
  end

  defp list_all_projects_with_episodes(genre) do
    import Ecto.Query
    alias ScriptVoice.Repo
    alias ScriptVoice.Screenplays.ScreenplayProject

    query = from p in ScreenplayProject,
      where: p.is_public == true,
      left_join: e in assoc(p, :episodes),
      left_join: w in assoc(p, :owner),
      preload: [episodes: e, owner: w],
      order_by: [desc: p.updated_at]

    query = if genre != "All" do
      where(query, [p], p.genre == ^genre)
    else
      query
    end

    Repo.all(query)
  end

  defp parse_sort("recent"), do: :recent
  defp parse_sort("popular"), do: :popular
  defp parse_sort("needs_audio"), do: :needs_audio
  defp parse_sort(_), do: :recent

  @impl true
  def handle_event("filter_genre", %{"genre" => genre}, socket) do
    {:noreply,
     push_patch(socket,
       to: ~p"/browse?#{%{genre: genre, sort: socket.assigns.selected_sort}}"
     )}
  end

  @impl true
  def handle_event("change_sort", %{"sort" => sort}, socket) do
    {:noreply,
     push_patch(socket,
       to: ~p"/browse?#{%{genre: socket.assigns.selected_genre, sort: sort}}"
     )}
  end

  @impl true
  def handle_event("toggle_screenplay_like", %{"id" => id}, socket) do
    case socket.assigns.current_user do
      nil ->
        {:noreply, push_navigate(socket, to: ~p"/verify?type=visitor")}

      user ->
        case Social.toggle_like(user.id, "screenplay", id) do
          {:ok, :liked} ->
            {:noreply,
             socket
             |> update(:liked_screenplay_ids, &[id | &1])
             |> update_screenplay_likes(id, 1)}

          {:ok, :unliked} ->
            {:noreply,
             socket
             |> update(:liked_screenplay_ids, &List.delete(&1, id))
             |> update_screenplay_likes(id, -1)}

          _ ->
            {:noreply, socket}
        end
    end
  end

  # Upload form toggle
  @impl true
  def handle_event("toggle_upload_form", _, socket) do
    {:noreply,
     socket
     |> assign(:show_upload_form, !socket.assigns.show_upload_form)
     |> assign(:upload_title, "")
     |> assign(:upload_genre, "Drama")
     |> assign(:upload_logline, "")
     |> assign(:upload_error, nil)}
  end

  @impl true
  def handle_event("validate_upload", params, socket) do
    title = Map.get(params, "title", socket.assigns.upload_title)
    genre = Map.get(params, "genre", socket.assigns.upload_genre)
    logline = Map.get(params, "logline", socket.assigns.upload_logline)

    {:noreply,
     socket
     |> assign(:upload_error, nil)
     |> assign(:upload_title, title)
     |> assign(:upload_genre, genre)
     |> assign(:upload_logline, logline)}
  end

  @impl true
  def handle_event("create_story", _, socket) do
    cond do
      String.trim(socket.assigns.upload_title) == "" ->
        {:noreply, assign(socket, :upload_error, "Please enter a title")}

      String.trim(socket.assigns.upload_logline) == "" ->
        {:noreply, assign(socket, :upload_error, "Please enter a logline")}

      true ->
        screenplay_attrs = %{
          "title" => socket.assigns.upload_title,
          "genre" => socket.assigns.upload_genre,
          "logline" => socket.assigns.upload_logline
        }

        case Screenplays.create_screenplay(screenplay_attrs, socket.assigns.current_user) do
          {:ok, screenplay} ->
            {:noreply,
             socket
             |> put_flash(:info, "Story \"#{screenplay.title}\" created! Add your content in the editor.")
             |> push_navigate(to: ~p"/screenplay/#{screenplay.id}/edit")}

          {:error, changeset} ->
            error = format_errors(changeset)
            {:noreply, assign(socket, :upload_error, error)}
        end
    end
  end

  defp update_screenplay_likes(socket, id, change) do
    update(socket, :standalone_screenplays, fn screenplays ->
      Enum.map(screenplays, fn sp ->
        if sp.id == id do
          %{sp | likes: max(0, sp.likes + change)}
        else
          sp
        end
      end)
    end)
  end

  defp get_current_user(session) do
    case session["user_id"] do
      nil -> nil
      user_id -> ScriptVoice.Accounts.get_user(user_id)
    end
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {field, errors} -> "#{field}: #{Enum.join(errors, ", ")}" end)
    |> Enum.join("; ")
  end

  # Project card for browse page
  attr :project, :map, required: true

  defp project_browse_card(assigns) do
    ~H"""
    <div class="bg-white border rounded-xl overflow-hidden hover:border-purple-300 hover:shadow-md transition">
      <.link navigate={~p"/project/#{@project.id}"} class="block p-4 sm:p-5">
        <div class="flex flex-col sm:flex-row sm:items-start gap-3">
          <!-- Project Info -->
          <div class="flex-1 min-w-0">
            <div class="flex flex-wrap items-center gap-2 mb-1">
              <h3 class="font-semibold text-gray-900 truncate"><%= @project.title %></h3>
              <span class={"px-2 py-0.5 text-xs font-medium rounded-full #{project_type_color(@project.project_type)}"}>
                <%= format_project_type(@project.project_type) %>
              </span>
              <.genre_badge genre={@project.genre} />
            </div>

            <p class="text-sm text-gray-500 mb-2">
              by <%= @project.owner_name || "Unknown" %>
            </p>

            <p class="text-gray-600 text-sm line-clamp-2 mb-3"><%= @project.logline %></p>

            <!-- Episodes Preview -->
            <div class="flex flex-wrap items-center gap-2">
              <span class="text-xs text-gray-500">
                <.icon name="hero-document-text" class="w-3.5 h-3.5 inline" />
                <%= length(@project.episodes) %> episodes
              </span>
              <%= if @project.total_seasons && @project.total_seasons > 0 do %>
                <span class="text-xs text-gray-500">
                  <.icon name="hero-folder" class="w-3.5 h-3.5 inline" />
                  <%= @project.total_seasons %> seasons planned
                </span>
              <% end %>
              <%= if length(@project.episodes) > 0 do %>
                <div class="flex items-center gap-1 ml-auto">
                  <%= for ep <- Enum.take(@project.episodes, 3) do %>
                    <span class="px-2 py-0.5 text-xs bg-gray-100 text-gray-600 rounded">
                      <%= ep.episode_code || "E#{ep.episode_number}" %>
                    </span>
                  <% end %>
                  <%= if length(@project.episodes) > 3 do %>
                    <span class="text-xs text-gray-400">+<%= length(@project.episodes) - 3 %> more</span>
                  <% end %>
                </div>
              <% end %>
            </div>
          </div>

          <!-- Arrow -->
          <div class="hidden sm:flex items-center">
            <.icon name="hero-chevron-right" class="w-5 h-5 text-gray-400" />
          </div>
        </div>
      </.link>
    </div>
    """
  end

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

  defp format_project_type(type) do
    type
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="py-6 sm:py-8 px-4 sm:px-6">
      <div class="max-w-4xl mx-auto">
        <!-- Header -->
        <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 mb-6">
          <h1 class="text-xl sm:text-2xl font-bold">Browse Stories</h1>
          <%= if @current_user && @current_user.user_type == "writer" do %>
            <button
              phx-click="toggle_upload_form"
              class={[
                "w-full sm:w-auto inline-flex items-center justify-center gap-2 px-4 py-2 rounded-lg font-medium transition",
                !@show_upload_form && "bg-emerald-600 text-white hover:bg-emerald-700",
                @show_upload_form && "bg-gray-200 text-gray-700 hover:bg-gray-300"
              ]}
            >
              <%= if @show_upload_form do %>
                <.icon name="hero-x-mark" class="w-4 h-4" />
                Cancel
              <% else %>
                <.icon name="hero-plus" class="w-4 h-4" />
                Create Story
              <% end %>
            </button>
          <% end %>
        </div>

        <!-- Create Story Form (Inline - metadata only) -->
        <%= if @show_upload_form do %>
          <div class="bg-white rounded-xl border p-4 sm:p-6 mb-6">
            <%= if @upload_error do %>
              <div class="bg-red-50 border border-red-200 rounded-xl p-3 mb-4 flex items-center gap-2 text-red-700 text-sm">
                <.icon name="hero-exclamation-circle" class="w-5 h-5" />
                <%= @upload_error %>
              </div>
            <% end %>

            <h3 class="font-semibold text-gray-900 mb-6">Create New Story</h3>
            <form phx-change="validate_upload" phx-submit="create_story" class="space-y-5">
              <div class="grid sm:grid-cols-2 gap-4">
                <.styled_input
                  name="title"
                  value={@upload_title}
                  label="Title"
                  placeholder="Your story title"
                  required={true}
                />
                <.styled_dropdown
                  name="genre"
                  value={@upload_genre}
                  options={Screenplay.genres()}
                  label="Genre"
                  required={true}
                />
              </div>

              <.styled_textarea
                name="logline"
                value={@upload_logline}
                label="Logline"
                placeholder="One sentence that captures your story..."
                rows={2}
                required={true}
              />

              <p class="text-sm text-gray-500">
                After creating, you'll be taken to the Story Editor where you can add content
                by writing blocks manually, pasting text, or uploading a file.
              </p>

              <button type="submit" class="w-full bg-emerald-600 text-white py-3 rounded-xl font-medium hover:bg-emerald-700 transition-colors shadow-sm flex items-center justify-center gap-2">
                <.icon name="hero-pencil-square" class="w-5 h-5" />
                Create & Edit Story
              </button>
            </form>
          </div>
        <% end %>

        <!-- Filters -->
        <div class="flex flex-col sm:flex-row gap-4 mb-6">
          <!-- Genre Pills (horizontal scroll on mobile) -->
          <div class="flex gap-2 overflow-x-auto pb-2 -mx-4 px-4 sm:mx-0 sm:px-0 sm:flex-wrap scrollbar-hide">
            <%= for genre <- @genres do %>
              <button
                phx-click="filter_genre"
                phx-value-genre={genre}
                class={[
                  "px-4 py-2 rounded-full text-sm font-medium whitespace-nowrap transition touch-manipulation",
                  genre == @selected_genre && "bg-emerald-600 text-white",
                  genre != @selected_genre && "bg-gray-100 text-gray-700 hover:bg-gray-200 active:bg-gray-300"
                ]}
              >
                <%= genre %>
              </button>
            <% end %>
          </div>

          <!-- Sort Dropdown -->
          <div class="sm:ml-auto w-full sm:w-48">
            <.styled_dropdown
              id="browse-sort"
              name="sort"
              value={@selected_sort}
              options={@sort_options}
              phx-change="change_sort"
            />
          </div>
        </div>

        <!-- Projects Section -->
        <%= if length(@projects) > 0 do %>
          <div class="mb-8">
            <h2 class="text-lg font-bold text-gray-900 mb-4 flex items-center gap-2">
              <.icon name="hero-folder" class="w-5 h-5 text-purple-600" />
              Projects
              <span class="text-sm font-normal text-gray-500">(<%= length(@projects) %>)</span>
            </h2>
            <div class="grid gap-4">
              <%= for project <- @projects do %>
                <.project_browse_card project={project} />
              <% end %>
            </div>
          </div>
        <% end %>

        <!-- Standalone Stories Section -->
        <div>
          <h2 class="text-lg font-bold text-gray-900 mb-4 flex items-center gap-2">
            <.icon name="hero-document-text" class="w-5 h-5 text-emerald-600" />
            Standalone Stories
            <span class="text-sm font-normal text-gray-500">(<%= length(@standalone_screenplays) %>)</span>
          </h2>

          <%= if Enum.empty?(@standalone_screenplays) do %>
            <div class="bg-white border rounded-xl p-8 text-center">
              <.icon name="hero-document-magnifying-glass" class="w-12 h-12 text-gray-300 mx-auto mb-4" />
              <h3 class="font-semibold text-lg mb-2">No standalone stories found</h3>
              <p class="text-gray-600 mb-4">
                <%= if @selected_genre != "All" do %>
                  Try selecting a different genre or clearing your filters.
                <% else %>
                  Be the first to publish a story!
                <% end %>
              </p>
              <%= if @selected_genre != "All" do %>
                <button
                  phx-click="filter_genre"
                  phx-value-genre="All"
                  class="text-emerald-600 font-medium hover:underline"
                >
                  Clear filters
                </button>
              <% end %>
            </div>
          <% else %>
            <div class="grid gap-4">
              <%= for sp <- @standalone_screenplays do %>
                <.screenplay_card
                  screenplay={sp}
                  liked={sp.id in @liked_screenplay_ids}
                  phx-click={JS.navigate(~p"/screenplay/#{sp.id}?from=browse")}
                />
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
