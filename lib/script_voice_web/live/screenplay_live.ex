defmodule ScriptVoiceWeb.ScreenplayLive do
  @moduledoc """
  Screenplay detail page LiveView.
  Shows screenplay info, characters, and audio versions.
  Mobile-first design with expandable sections.
  """
  use ScriptVoiceWeb, :live_view

  alias ScriptVoice.Screenplays
  alias ScriptVoice.Screenplays.Screenplay
  alias ScriptVoice.Audio
  alias ScriptVoice.Social
  alias ScriptVoice.Projects

  @audio_sort_options [
    {"Most Recent", "recent"},
    {"Most Popular", "popular"},
    {"Author's Picks First", "author_picks"}
  ]

  @impl true
  def mount(%{"id" => id} = params, session, socket) do
    current_user = get_current_user(session)

    # Handle back navigation based on where user came from
    {back_to, back_label} = case params do
      %{"from" => "commission", "commission_id" => commission_id} ->
        {~p"/commissions/#{commission_id}", "Back to commission"}
      %{"from" => "browse"} ->
        {~p"/browse", "Back to browse"}
      %{"from" => "dashboard"} ->
        {~p"/dashboard?tab=screenplays", "Back to my stories"}
      _ ->
        {nil, nil}
    end

    case Screenplays.get_screenplay(id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Story not found")
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

        # Load project characters if this screenplay has character_ids
        project_characters = if screenplay.project_id && screenplay.character_ids && length(screenplay.character_ids) > 0 do
          all_chars = Projects.list_characters_for_project(screenplay.project_id)
          Enum.filter(all_chars, fn c -> c.id in screenplay.character_ids end)
        else
          []
        end

        has_blocks = Screenplay.has_blocks?(screenplay)
        story_stats = if has_blocks do
          Screenplays.compute_story_stats(screenplay.blocks)
        else
          nil
        end

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
         |> assign(:back_to, back_to)
         |> assign(:back_label, back_label)
         |> assign(:page_title, screenplay.title)
         |> assign(:project_characters, project_characters)
         |> assign(:has_blocks, has_blocks)
         |> assign(:story_stats, story_stats)}
    end
  end

  @impl true
  def handle_event("change_audio_sort", %{"sort" => sort}, socket) do
    sort_atom = parse_audio_sort(sort)
    audio_versions = Audio.list_audio_versions_for_screenplay(socket.assigns.screenplay.id, sort: sort_atom)

    {:noreply,
     socket
     |> assign(:audio_sort, sort)
     |> assign(:audio_versions, audio_versions)}
  end

  defp parse_audio_sort("recent"), do: :recent
  defp parse_audio_sort("popular"), do: :popular
  defp parse_audio_sort("author_picks"), do: :author_picks
  defp parse_audio_sort(_), do: :recent

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

  defp has_content?(screenplay) do
    Screenplay.has_blocks?(screenplay) ||
    (screenplay.script_content && String.trim(screenplay.script_content) != "") ||
    (screenplay.pdf_url && String.trim(screenplay.pdf_url) != "")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="py-6 sm:py-8 px-4 sm:px-6">
      <div class="max-w-4xl mx-auto">
        <!-- Back Button -->
        <%= cond do %>
          <% @back_to && @back_label -> %>
            <.back navigate={@back_to}><%= @back_label %></.back>
          <% @is_author -> %>
            <.back navigate={~p"/dashboard?tab=screenplays"}>Back to my stories</.back>
          <% true -> %>
            <.back navigate={~p"/browse"}>Back to browse</.back>
        <% end %>

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
                <%= if @story_stats do %>
                  · ~<%= @story_stats.estimated_duration_minutes %> min · <%= @story_stats.total_words %> words
                <% else %>
                  · <%= @screenplay.page_count || "?" %> pages
                <% end %>
                <%= if @is_author do %>
                  <span class="ml-2 text-xs bg-emerald-100 text-emerald-700 px-2 py-0.5 rounded-full">
                    Your Story
                  </span>
                <% end %>
              </p>
            </div>

            <div class="flex flex-wrap items-center gap-2 sm:gap-3 w-full sm:w-auto">
              <.like_button
                liked={@screenplay.id in @liked_screenplay_ids}
                count={@screenplay.likes}
                phx-click="toggle_screenplay_like"
                phx-value-id={@screenplay.id}
              />
              <%= if @is_author do %>
                <!-- Edit Story button for authors -->
                <.link
                  navigate={~p"/screenplay/#{@screenplay.id}/edit"}
                  class="flex-1 sm:flex-none inline-flex items-center justify-center gap-2 px-4 py-2 border border-gray-300 rounded-lg font-medium text-gray-700 bg-white hover:bg-gray-50 transition"
                >
                  <.icon name="hero-pencil-square" class="w-4 h-4" />
                  <span class="hidden sm:inline"><%= if has_content?(@screenplay), do: "Edit Story", else: "Add Story" %></span>
                  <span class="sm:hidden"><%= if has_content?(@screenplay), do: "Edit", else: "Add" %></span>
                </.link>
                <.link
                  navigate={~p"/commissions/request/#{@screenplay.id}"}
                  class="flex-1 sm:flex-none inline-flex items-center justify-center gap-2 px-4 py-2 bg-purple-600 text-white rounded-lg font-medium hover:bg-purple-700 transition"
                >
                  <.icon name="hero-user-plus" class="w-4 h-4" />
                  <span class="hidden sm:inline">Commission Voice Artist</span>
                  <span class="sm:hidden">Commission</span>
                </.link>
              <% end %>
              <!-- Read Story button (for stories that have content) -->
              <%= cond do %>
                <% @has_blocks || (@screenplay.script_content && String.length(@screenplay.script_content) > 0) -> %>
                  <.link
                    navigate={~p"/screenplay/#{@screenplay.id}/read"}
                    class="flex-1 sm:flex-none inline-flex items-center justify-center gap-2 px-4 py-2 border border-gray-300 rounded-lg font-medium text-gray-700 bg-white hover:bg-gray-50"
                  >
                    <.icon name="hero-document-text" class="w-4 h-4" />
                    <span class="hidden sm:inline">Read Story</span>
                    <span class="sm:hidden">Read</span>
                  </.link>
                <% @screenplay.pdf_url -> %>
                  <a
                    href={@screenplay.pdf_url}
                    target="_blank"
                    class="flex-1 sm:flex-none inline-flex items-center justify-center gap-2 px-4 py-2 border border-gray-300 rounded-lg font-medium text-gray-700 bg-white hover:bg-gray-50"
                  >
                    <.icon name="hero-document-text" class="w-4 h-4" />
                    <span class="hidden sm:inline">View PDF</span>
                    <span class="sm:hidden">View</span>
                  </a>
                <% !@is_author -> %>
                  <!-- Non-authors see "Story coming soon" when no content -->
                  <span class="flex-1 sm:flex-none inline-flex items-center justify-center gap-2 px-4 py-2 border border-gray-200 rounded-lg font-medium text-gray-400 bg-gray-50 italic text-sm">
                    <.icon name="hero-clock" class="w-4 h-4" />
                    <span>Coming soon</span>
                  </span>
                <% true -> %>
                  <!-- Authors already have Edit/Add button above, so nothing needed here -->
              <% end %>
            </div>
          </div>

          <p class="text-gray-700 text-base sm:text-lg mb-4"><%= @screenplay.logline %></p>

          <!-- Version Info -->
          <div class="flex items-center gap-3 text-sm text-gray-500 mb-4">
            <span class="bg-gray-100 px-2 py-1 rounded">Version <%= @screenplay.version %></span>
            <%= if @screenplay.last_updated_at do %>
              <span>Updated <%= Calendar.strftime(@screenplay.last_updated_at, "%b %d, %Y") %></span>
            <% end %>
          </div>

          <!-- Version Notes (if any) -->
          <%= if @screenplay.version_notes && String.trim(@screenplay.version_notes) != "" do %>
            <div class="bg-amber-50 border border-amber-200 rounded-lg p-3 mb-4">
              <h4 class="text-sm font-medium text-amber-800 mb-1">Latest Changes (v<%= @screenplay.version %>)</h4>
              <p class="text-sm text-amber-700"><%= @screenplay.version_notes %></p>
            </div>
          <% end %>

          <!-- Story Stats (for block-based stories) -->
          <%= if @story_stats && map_size(@story_stats.characters) > 0 do %>
            <div class="flex flex-wrap gap-3 mt-4 pt-4 border-t border-gray-100 text-sm text-gray-500">
              <span><%= @story_stats.scene_count %> scenes</span>
              <span>·</span>
              <span><%= map_size(@story_stats.characters) %> characters</span>
              <%= if @story_stats.sfx_count > 0 do %>
                <span>·</span>
                <span><%= @story_stats.sfx_count %> SFX cues</span>
              <% end %>
              <%= if @story_stats.music_count > 0 do %>
                <span>·</span>
                <span><%= @story_stats.music_count %> music cues</span>
              <% end %>
              <span>·</span>
              <span><%= round(@story_stats.dialogue_ratio * 100) %>% dialogue</span>
            </div>
          <% end %>

          <!-- Character List -->
          <!-- Show project characters if linked, otherwise show embedded characters -->
          <%= if length(@project_characters) > 0 do %>
            <.project_character_list characters={@project_characters} />
          <% else %>
            <.character_list characters={@screenplay.characters} />
          <% end %>
        </div>

        <!-- Audio Versions Section -->
        <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 mb-4">
          <h2 class="text-lg sm:text-xl font-bold">
            Audio Versions (<%= length(@audio_versions) %>)
          </h2>
          <div class="flex items-center gap-3 w-full sm:w-auto">
            <div class="flex-1 sm:flex-none sm:w-40">
              <.styled_dropdown
                id="audio-sort"
                name="sort"
                value={@audio_sort}
                options={@audio_sort_options}
                phx-change="change_audio_sort"
              />
            </div>
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
            <%= if @is_author do %>
              <p class="text-gray-600 mb-4">Voice artists can submit their audio performances, or you can commission one directly.</p>
              <.link
                navigate={~p"/commissions/request/#{@screenplay.id}"}
                class="inline-flex items-center gap-2 bg-purple-600 text-white px-6 py-2 rounded-lg font-medium hover:bg-purple-700 transition"
              >
                <.icon name="hero-user-plus" class="w-4 h-4" />
                Commission Voice Artist
              </.link>
            <% else %>
              <p class="text-gray-600 mb-4">Be the first to bring this story to life!</p>
              <%= if @current_user && @current_user.user_type == "voice_artist" do %>
                <.button phx-click="show_submit_modal">
                  Submit Audio
                </.button>
              <% else %>
                <%= if !@current_user do %>
                  <.link
                    navigate={~p"/verify?type=voice_artist"}
                    class="inline-flex items-center gap-2 bg-emerald-600 text-white px-6 py-2 rounded-lg font-medium hover:bg-emerald-700"
                  >
                    Sign up as voice artist
                  </.link>
                <% end %>
              <% end %>
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
                screenplay_id={@screenplay.id}
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
