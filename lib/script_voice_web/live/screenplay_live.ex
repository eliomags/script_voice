defmodule ScriptVoiceWeb.ScreenplayLive do
  @moduledoc """
  Screenplay detail page LiveView.
  Shows screenplay info, characters, and audio versions.
  Mobile-first design with expandable sections.
  """
  use ScriptVoiceWeb, :live_view

  alias ScriptVoice.Screenplays
  alias ScriptVoice.Audio
  alias ScriptVoice.Social

  @audio_sort_options [
    {"Most Recent", "recent"},
    {"Most Popular", "popular"},
    {"Author's Picks First", "author_picks"}
  ]

  @impl true
  def mount(%{"id" => id}, session, socket) do
    current_user = get_current_user(session)

    case Screenplays.get_screenplay(id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Screenplay not found")
         |> push_navigate(to: ~p"/browse")}

      screenplay ->
        audio_versions = Audio.list_audio_versions_for_screenplay(id, sort: :recent)

        {liked_screenplay_ids, liked_audio_ids} =
          if current_user do
            {Social.get_liked_screenplay_ids(current_user.id),
             Social.get_liked_audio_ids(current_user.id)}
          else
            {[], []}
          end

        is_author = current_user && current_user.id == screenplay.writer_id

        {:ok,
         socket
         |> assign(:current_user, current_user)
         |> assign(:screenplay, screenplay)
         |> assign(:audio_versions, audio_versions)
         |> assign(:audio_sort, "recent")
         |> assign(:audio_sort_options, @audio_sort_options)
         |> assign(:liked_screenplay_ids, liked_screenplay_ids)
         |> assign(:liked_audio_ids, liked_audio_ids)
         |> assign(:is_author, is_author)
         |> assign(:playing_id, nil)
         |> assign(:show_submit_modal, false)
         |> assign(:page_title, screenplay.title)}
    end
  end

  @impl true
  def handle_event("change_audio_sort", %{"sort" => sort}, socket) do
    sort_atom = String.to_existing_atom(sort)
    audio_versions = Audio.list_audio_versions_for_screenplay(socket.assigns.screenplay.id, sort: sort_atom)

    {:noreply,
     socket
     |> assign(:audio_sort, sort)
     |> assign(:audio_versions, audio_versions)}
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
             |> update(:screenplay, &%{&1 | likes: &1.likes + 1})}

          {:ok, :unliked} ->
            {:noreply,
             socket
             |> update(:liked_screenplay_ids, &List.delete(&1, id))
             |> update(:screenplay, &%{&1 | likes: max(0, &1.likes - 1)})}

          _ ->
            {:noreply, socket}
        end
    end
  end

  @impl true
  def handle_event("toggle_audio_like", %{"id" => id}, socket) do
    case socket.assigns.current_user do
      nil ->
        {:noreply, push_navigate(socket, to: ~p"/verify?type=visitor")}

      user ->
        case Social.toggle_like(user.id, "audio_version", id) do
          {:ok, :liked} ->
            {:noreply,
             socket
             |> update(:liked_audio_ids, &[id | &1])
             |> update_audio_likes(id, 1)}

          {:ok, :unliked} ->
            {:noreply,
             socket
             |> update(:liked_audio_ids, &List.delete(&1, id))
             |> update_audio_likes(id, -1)}

          _ ->
            {:noreply, socket}
        end
    end
  end

  @impl true
  def handle_event("toggle_author_pick", %{"id" => id}, socket) do
    if socket.assigns.is_author do
      case Audio.get_audio_version(id) do
        nil ->
          {:noreply, socket}

        audio_version ->
          case Audio.toggle_author_pick(audio_version) do
            {:ok, updated} ->
              {:noreply, update_audio_version(socket, updated)}

            _ ->
              {:noreply, socket}
          end
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_play", %{"id" => id}, socket) do
    new_playing_id = if socket.assigns.playing_id == id, do: nil, else: id
    {:noreply, assign(socket, :playing_id, new_playing_id)}
  end

  @impl true
  def handle_event("show_submit_modal", _, socket) do
    if socket.assigns.current_user do
      {:noreply, assign(socket, :show_submit_modal, true)}
    else
      {:noreply, push_navigate(socket, to: ~p"/verify?type=voice_artist")}
    end
  end

  @impl true
  def handle_event("close_submit_modal", _, socket) do
    {:noreply, assign(socket, :show_submit_modal, false)}
  end

  defp update_audio_likes(socket, id, change) do
    update(socket, :audio_versions, fn versions ->
      Enum.map(versions, fn av ->
        if av.id == id do
          %{av | likes: max(0, av.likes + change)}
        else
          av
        end
      end)
    end)
  end

  defp update_audio_version(socket, updated_av) do
    update(socket, :audio_versions, fn versions ->
      Enum.map(versions, fn av ->
        if av.id == updated_av.id, do: updated_av, else: av
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
        <!-- Back Button -->
        <.back navigate={~p"/browse"}>Back to browse</.back>

        <!-- Screenplay Header -->
        <div class="bg-white border rounded-xl p-4 sm:p-6 mt-4 mb-6">
          <div class="flex flex-col sm:flex-row justify-between items-start gap-4 mb-4">
            <div class="flex-1">
              <div class="flex flex-wrap items-center gap-2 mb-2">
                <h1 class="text-xl sm:text-2xl font-bold"><%= @screenplay.title %></h1>
                <.genre_badge genre={@screenplay.genre} />
              </div>
              <p class="text-gray-500 text-sm sm:text-base">
                by <.link navigate={~p"/profile/#{@screenplay.writer_id}"} class="text-emerald-600 font-medium hover:underline"><%= @screenplay.writer_name %></.link>
                · <%= @screenplay.page_count || "?" %> pages
                <%= if @is_author do %>
                  <span class="ml-2 text-xs bg-emerald-100 text-emerald-700 px-2 py-0.5 rounded-full">
                    Your Script
                  </span>
                <% end %>
              </p>
            </div>

            <div class="flex items-center gap-2 sm:gap-3 w-full sm:w-auto">
              <.like_button
                liked={@screenplay.id in @liked_screenplay_ids}
                count={@screenplay.likes}
                phx-click="toggle_screenplay_like"
                phx-value-id={@screenplay.id}
              />
              <.button variant="secondary" class="flex-1 sm:flex-none">
                <.icon name="hero-document-text" class="w-4 h-4" />
                <span class="hidden sm:inline">Read Script</span>
                <span class="sm:hidden">Read</span>
              </.button>
            </div>
          </div>

          <p class="text-gray-700 text-base sm:text-lg mb-4"><%= @screenplay.logline %></p>

          <!-- Character List -->
          <.character_list characters={@screenplay.characters} />
        </div>

        <!-- Audio Versions Section -->
        <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 mb-4">
          <h2 class="text-lg sm:text-xl font-bold">
            Audio Versions (<%= length(@audio_versions) %>)
          </h2>
          <div class="flex items-center gap-3 w-full sm:w-auto">
            <select
              name="sort"
              phx-change="change_audio_sort"
              class="flex-1 sm:flex-none border rounded-lg px-3 py-2 text-sm font-medium bg-white focus:border-emerald-500 focus:ring-emerald-500"
            >
              <%= for {label, value} <- @audio_sort_options do %>
                <option value={value} selected={value == @audio_sort}><%= label %></option>
              <% end %>
            </select>
            <%= if @current_user && @current_user.user_type == "voice_artist" do %>
              <.button phx-click="show_submit_modal" class="whitespace-nowrap">
                <.icon name="hero-microphone" class="w-4 h-4" />
                <span class="hidden sm:inline">Submit Version</span>
                <span class="sm:hidden">Submit</span>
              </.button>
            <% end %>
          </div>
        </div>

        <!-- Audio Versions List -->
        <%= if Enum.empty?(@audio_versions) do %>
          <div class="bg-amber-50 border border-amber-200 rounded-xl p-6 sm:p-8 text-center">
            <.icon name="hero-microphone" class="w-10 h-10 text-amber-500 mx-auto mb-3" />
            <h3 class="font-semibold text-lg mb-2">No audio versions yet</h3>
            <p class="text-gray-600 mb-4">Be the first to bring this screenplay to life!</p>
            <%= if @current_user do %>
              <.button phx-click="show_submit_modal">
                Record This Script
              </.button>
            <% else %>
              <.link
                navigate={~p"/verify?type=voice_artist"}
                class="inline-flex items-center gap-2 bg-emerald-600 text-white px-6 py-2 rounded-lg font-medium hover:bg-emerald-700"
              >
                Sign up to record
              </.link>
            <% end %>
          </div>
        <% else %>
          <div class="space-y-3">
            <%= for av <- @audio_versions do %>
              <.audio_version_card
                audio_version={av}
                playing={@playing_id == av.id}
                liked={av.id in @liked_audio_ids}
                is_author={@is_author}
              />
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <!-- Submit Audio Modal -->
    <%= if @show_submit_modal do %>
      <.modal id="submit-audio-modal" show={true} on_cancel={JS.push("close_submit_modal")}>
        <.live_component
          module={ScriptVoiceWeb.SubmitAudioComponent}
          id="submit-audio"
          screenplay={@screenplay}
          current_user={@current_user}
        />
      </.modal>
    <% end %>
    """
  end
end
