defmodule ScriptVoiceWeb.BrowseLive do
  @moduledoc """
  Browse page LiveView - Browse screenplays with filters and sorting.
  Mobile-first design with horizontal scrolling filters.
  Includes inline upload form for writers.
  Organizes content into Projects and Standalone Scripts.
  """
  use ScriptVoiceWeb, :live_view

  alias ScriptVoice.Screenplays
  alias ScriptVoice.Screenplays.{Screenplay, Character}
  alias ScriptVoice.Projects
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
     |> assign(:page_title, "Browse Screenplays")
     |> assign(:view_mode, "all")  # "all", "projects", "standalone"
     |> init_upload_form()
     |> load_content()}
  end

  defp init_upload_form(socket) do
    socket
    |> assign(:upload_title, "")
    |> assign(:upload_genre, "Drama")
    |> assign(:upload_logline, "")
    |> assign(:upload_page_count, nil)
    |> assign(:upload_characters, [])
    |> assign(:upload_error, nil)
    |> allow_upload(:pdf, accept: ~w(.pdf), max_entries: 1, max_file_size: 10_000_000, auto_upload: true)
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
    # Get all PUBLIC projects and filter by genre if needed
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
     |> assign(:upload_page_count, nil)
     |> assign(:upload_characters, [])
     |> assign(:upload_error, nil)}
  end

  @impl true
  def handle_event("validate_upload", params, socket) do
    title = Map.get(params, "title", socket.assigns.upload_title)
    genre = Map.get(params, "genre", socket.assigns.upload_genre)
    logline = Map.get(params, "logline", socket.assigns.upload_logline)

    page_count = case Map.get(params, "page_count") do
      nil -> socket.assigns.upload_page_count
      "" -> socket.assigns.upload_page_count
      val ->
        case Integer.parse(val) do
          {num, _} -> num
          :error -> socket.assigns.upload_page_count
        end
    end

    {:noreply,
     socket
     |> assign(:upload_error, nil)
     |> assign(:upload_title, title)
     |> assign(:upload_genre, genre)
     |> assign(:upload_logline, logline)
     |> assign(:upload_page_count, page_count)}
  end

  @impl true
  def handle_event("add_character", _, socket) do
    new_char = %{
      name: "",
      gender: "Any",
      estimated_lines: nil,
      description: ""
    }

    {:noreply, update(socket, :upload_characters, &(&1 ++ [new_char]))}
  end

  @impl true
  def handle_event("update_character", %{"index" => index, "field" => field} = params, socket) do
    index_int = String.to_integer(index)

    value = cond do
      Map.has_key?(params, "gender") && params["gender"] != "" -> params["gender"]
      Map.has_key?(params, "value") && params["value"] != "" -> params["value"]
      Map.has_key?(params, "char_name_#{index}") -> params["char_name_#{index}"]
      Map.has_key?(params, "char_lines_#{index}") -> params["char_lines_#{index}"]
      true -> nil
    end

    value = if field == "estimated_lines" do
      case value do
        nil -> nil
        "" -> nil
        val when is_binary(val) -> String.to_integer(val)
        val -> val
      end
    else
      value
    end

    characters =
      socket.assigns.upload_characters
      |> List.update_at(index_int, fn char ->
        Map.put(char, String.to_atom(field), value)
      end)

    {:noreply, assign(socket, :upload_characters, characters)}
  end

  @impl true
  def handle_event("remove_character", %{"index" => index}, socket) do
    index = String.to_integer(index)
    characters = List.delete_at(socket.assigns.upload_characters, index)
    {:noreply, assign(socket, :upload_characters, characters)}
  end

  @impl true
  def handle_event("publish_screenplay", _, socket) do
    user_id = socket.assigns.current_user.id

    pdf_result = process_pdf_upload(socket, user_id)

    screenplay_attrs = %{
      "title" => socket.assigns.upload_title,
      "genre" => socket.assigns.upload_genre,
      "logline" => socket.assigns.upload_logline,
      "page_count" => socket.assigns.upload_page_count,
      "characters" => socket.assigns.upload_characters
    }

    screenplay_attrs = case pdf_result do
      %{url: url, extracted_text: text} when not is_nil(text) and text != "" ->
        screenplay_attrs
        |> Map.put("pdf_url", url)
        |> Map.put("script_content", text)
      %{url: url} ->
        Map.put(screenplay_attrs, "pdf_url", url)
      _ ->
        screenplay_attrs
    end

    case Screenplays.create_screenplay(screenplay_attrs, socket.assigns.current_user) do
      {:ok, screenplay} ->
        {:noreply,
         socket
         |> put_flash(:info, "Screenplay \"#{screenplay.title}\" published successfully!")
         |> assign(:show_upload_form, false)
         |> assign(:upload_title, "")
         |> assign(:upload_genre, "Drama")
         |> assign(:upload_logline, "")
         |> assign(:upload_page_count, nil)
         |> assign(:upload_characters, [])
         |> push_navigate(to: ~p"/screenplay/#{screenplay.id}")}

      {:error, changeset} ->
        error = format_errors(changeset)
        {:noreply, assign(socket, :upload_error, error)}
    end
  end

  defp process_pdf_upload(socket, user_id) do
    alias ScriptVoice.Uploads
    alias ScriptVoice.PdfExtractor

    uploaded_files =
      consume_uploaded_entries(socket, :pdf, fn %{path: temp_path}, entry ->
        extracted_text = case PdfExtractor.extract_text(temp_path) do
          {:ok, text} -> text
          _ -> nil
        end

        upload_result = if Uploads.configured?() do
          Uploads.upload_pdf(temp_path, entry.client_name, user_id)
        else
          Uploads.upload_pdf_local(temp_path, entry.client_name, user_id)
        end

        case upload_result do
          {:ok, result} -> {:ok, Map.put(result, :extracted_text, extracted_text)}
          error -> error
        end
      end)

    case uploaded_files do
      [result | _] -> result
      [] -> {:error, :no_file}
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
          <h1 class="text-xl sm:text-2xl font-bold">Browse Screenplays</h1>
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
                Upload
              <% end %>
            </button>
          <% end %>
        </div>

        <!-- Upload Form (Inline) -->
        <%= if @show_upload_form do %>
          <div class="bg-white rounded-xl border p-4 sm:p-6 mb-6">
            <%= if @upload_error do %>
              <div class="bg-red-50 border border-red-200 rounded-xl p-3 mb-4 flex items-center gap-2 text-red-700 text-sm">
                <.icon name="hero-exclamation-circle" class="w-5 h-5" />
                <%= @upload_error %>
              </div>
            <% end %>

            <h3 class="font-semibold text-gray-900 mb-6">Upload New Screenplay</h3>
            <form phx-change="validate_upload" phx-submit="publish_screenplay" class="space-y-5">
              <div class="grid sm:grid-cols-2 gap-4">
                <.styled_input
                  name="title"
                  value={@upload_title}
                  label="Title"
                  placeholder="Your screenplay title"
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

              <div class="grid sm:grid-cols-2 gap-4">
                <.styled_number
                  name="page_count"
                  value={@upload_page_count}
                  label="Page Count"
                  placeholder="Number of pages"
                  min={1}
                  max={500}
                />

                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1.5">Script PDF</label>
                  <div
                    class="border-2 border-dashed border-gray-200 rounded-xl p-4 text-center cursor-pointer hover:border-emerald-400 hover:bg-emerald-50/50 transition-colors"
                    phx-drop-target={@uploads.pdf.ref}
                  >
                    <.live_file_input upload={@uploads.pdf} class="sr-only" />
                    <label for={@uploads.pdf.ref} class="cursor-pointer block">
                      <%= if Enum.empty?(@uploads.pdf.entries) do %>
                        <.icon name="hero-document-text" class="w-8 h-8 text-gray-300 mx-auto mb-2" />
                        <p class="text-sm text-gray-500">Drop PDF or <span class="text-emerald-600 font-medium">browse</span></p>
                      <% else %>
                        <%= for entry <- @uploads.pdf.entries do %>
                          <div class="flex items-center justify-center gap-2">
                            <.icon name="hero-check-circle" class="w-5 h-5 text-emerald-500" />
                            <p class="text-sm text-emerald-600 font-medium truncate"><%= entry.client_name %></p>
                          </div>
                        <% end %>
                      <% end %>
                    </label>
                  </div>
                </div>
              </div>

              <!-- Characters Section -->
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-3">Characters (optional)</label>
                <div class="space-y-3">
                  <%= for {char, index} <- Enum.with_index(@upload_characters) do %>
                    <div class="flex flex-col sm:flex-row sm:items-center gap-3 p-3 bg-gray-50 rounded-xl">
                      <div class="flex-1">
                        <input
                          type="text"
                          name={"char_name_#{index}"}
                          value={char.name}
                          phx-blur="update_character"
                          phx-value-index={index}
                          phx-value-field="name"
                          placeholder="Character name"
                          class="w-full px-3 py-2 bg-white border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500"
                        />
                      </div>
                      <div class="flex items-center gap-2">
                        <div class="flex rounded-lg border border-gray-200 overflow-hidden">
                          <%= for gender <- Character.genders() do %>
                            <button
                              type="button"
                              phx-click="update_character"
                              phx-value-index={index}
                              phx-value-field="gender"
                              phx-value-gender={gender}
                              class={[
                                "px-3 py-2 text-sm font-medium transition-colors",
                                gender == char.gender && "bg-emerald-500 text-white",
                                gender != char.gender && "bg-white text-gray-600 hover:bg-gray-50"
                              ]}
                            >
                              <%= gender %>
                            </button>
                          <% end %>
                        </div>
                        <input
                          type="number"
                          name={"char_lines_#{index}"}
                          value={char.estimated_lines}
                          phx-blur="update_character"
                          phx-value-index={index}
                          phx-value-field="estimated_lines"
                          placeholder="Lines"
                          min="0"
                          class="w-20 px-3 py-2 bg-white border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 [appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none"
                        />
                        <button
                          type="button"
                          phx-click="remove_character"
                          phx-value-index={index}
                          class="p-2 text-gray-400 hover:text-red-500 hover:bg-red-50 rounded-lg transition-colors"
                        >
                          <.icon name="hero-x-mark" class="w-4 h-4" />
                        </button>
                      </div>
                    </div>
                  <% end %>

                  <button
                    type="button"
                    phx-click="add_character"
                    class="w-full border-2 border-dashed border-gray-200 rounded-xl py-3 text-gray-500 hover:border-emerald-400 hover:text-emerald-600 hover:bg-emerald-50/50 text-sm font-medium transition-colors"
                  >
                    + Add Character
                  </button>
                </div>
              </div>

              <button type="submit" class="w-full bg-emerald-600 text-white py-3 rounded-xl font-medium hover:bg-emerald-700 transition-colors shadow-sm">
                Publish Screenplay
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

        <!-- Standalone Scripts Section -->
        <div>
          <h2 class="text-lg font-bold text-gray-900 mb-4 flex items-center gap-2">
            <.icon name="hero-document-text" class="w-5 h-5 text-emerald-600" />
            Standalone Scripts
            <span class="text-sm font-normal text-gray-500">(<%= length(@standalone_screenplays) %>)</span>
          </h2>

          <%= if Enum.empty?(@standalone_screenplays) do %>
            <div class="bg-white border rounded-xl p-8 text-center">
              <.icon name="hero-document-magnifying-glass" class="w-12 h-12 text-gray-300 mx-auto mb-4" />
              <h3 class="font-semibold text-lg mb-2">No standalone scripts found</h3>
              <p class="text-gray-600 mb-4">
                <%= if @selected_genre != "All" do %>
                  Try selecting a different genre or clearing your filters.
                <% else %>
                  Be the first to upload a screenplay!
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
