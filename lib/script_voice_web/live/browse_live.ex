defmodule ScriptVoiceWeb.BrowseLive do
  @moduledoc """
  Browse page LiveView - Browse screenplays with filters and sorting.
  Mobile-first design with horizontal scrolling filters.
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
     |> assign(:show_upload_modal, false)
     |> assign(:page_title, "Browse Screenplays")
     |> load_screenplays()}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    genre = Map.get(params, "genre", "All")
    sort = Map.get(params, "sort", "recent")

    {:noreply,
     socket
     |> assign(:selected_genre, genre)
     |> assign(:selected_sort, sort)
     |> load_screenplays()}
  end

  defp load_screenplays(socket) do
    genre = socket.assigns.selected_genre
    sort = String.to_existing_atom(socket.assigns.selected_sort)

    screenplays = Screenplays.list_screenplays(sort: sort, genre: genre)
    assign(socket, :screenplays, screenplays)
  end

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

  @impl true
  def handle_event("show_upload_modal", _, socket) do
    {:noreply, assign(socket, :show_upload_modal, true)}
  end

  @impl true
  def handle_event("close_upload_modal", _, socket) do
    {:noreply, assign(socket, :show_upload_modal, false)}
  end

  defp update_screenplay_likes(socket, id, change) do
    update(socket, :screenplays, fn screenplays ->
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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="py-6 sm:py-8 px-4 sm:px-6">
      <div class="max-w-4xl mx-auto">
        <!-- Header -->
        <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 mb-6">
          <h1 class="text-xl sm:text-2xl font-bold">Browse Screenplays</h1>
          <%= if @current_user && @current_user.user_type == "writer" do %>
            <.button phx-click="show_upload_modal" class="w-full sm:w-auto">
              <.icon name="hero-plus" class="w-4 h-4" />
              Upload
            </.button>
          <% end %>
        </div>

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
          <div class="sm:ml-auto">
            <select
              name="sort"
              phx-change="change_sort"
              class="w-full sm:w-auto border rounded-lg px-3 py-2 text-sm font-medium bg-white focus:border-emerald-500 focus:ring-emerald-500"
            >
              <%= for {label, value} <- @sort_options do %>
                <option value={value} selected={value == @selected_sort}><%= label %></option>
              <% end %>
            </select>
          </div>
        </div>

        <!-- Screenplay List -->
        <%= if Enum.empty?(@screenplays) do %>
          <div class="bg-white border rounded-xl p-8 text-center">
            <.icon name="hero-document-magnifying-glass" class="w-12 h-12 text-gray-300 mx-auto mb-4" />
            <h3 class="font-semibold text-lg mb-2">No screenplays found</h3>
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
            <%= for sp <- @screenplays do %>
              <.screenplay_card
                screenplay={sp}
                liked={sp.id in @liked_screenplay_ids}
                phx-click={JS.navigate(~p"/screenplay/#{sp.id}")}
              />
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <!-- Upload Screenplay Modal -->
    <%= if @show_upload_modal do %>
      <.modal id="upload-screenplay-modal" show={true} on_cancel={JS.push("close_upload_modal")}>
        <.live_component
          module={ScriptVoiceWeb.UploadScreenplayComponent}
          id="upload-screenplay"
          current_user={@current_user}
        />
      </.modal>
    <% end %>
    """
  end
end
