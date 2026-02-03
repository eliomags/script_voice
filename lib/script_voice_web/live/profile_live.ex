defmodule ScriptVoiceWeb.ProfileLive do
  @moduledoc """
  Profile page LiveView - Shows user profile with their screenplays or audio versions.
  """
  use ScriptVoiceWeb, :live_view

  alias ScriptVoice.Accounts
  alias ScriptVoice.Screenplays
  alias ScriptVoice.Audio
  alias ScriptVoice.Social
  alias ScriptVoice.Collectives

  @impl true
  def mount(%{"id" => id} = params, session, socket) do
    current_user = get_current_user(session)

    case Accounts.get_user(id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "User not found")
         |> push_navigate(to: ~p"/browse")}

      profile_user ->
        # Load user's content
        {screenplays, audio_versions, collectives} =
          case profile_user.user_type do
            "writer" ->
              {Screenplays.list_screenplays(writer_id: profile_user.id), [], []}

            "voice_artist" ->
              {[], Audio.list_audio_versions_by_user(profile_user.id),
               Collectives.list_collectives_for_user(profile_user.id)}

            _ ->
              {[], [], []}
          end

        is_own_profile = current_user && current_user.id == profile_user.id

        liked_ids =
          if current_user do
            Social.get_liked_screenplay_ids(current_user.id)
          else
            []
          end

        # Determine back URL from referer param or default to browse
        back_url = case params["from"] do
          "screenplay:" <> screenplay_id -> ~p"/screenplay/#{screenplay_id}"
          "collective:" <> collective_slug -> ~p"/collective/#{collective_slug}"
          "collectives" -> ~p"/collectives"
          "dashboard" -> ~p"/dashboard?tab=collectives"
          _ -> ~p"/browse"
        end

        {:ok,
         socket
         |> assign(:current_user, current_user)
         |> assign(:profile_user, profile_user)
         |> assign(:screenplays, screenplays)
         |> assign(:audio_versions, audio_versions)
         |> assign(:collectives, collectives)
         |> assign(:is_own_profile, is_own_profile)
         |> assign(:liked_screenplay_ids, liked_ids)
         |> assign(:back_url, back_url)
         |> assign(:page_title, profile_user.name)}
    end
  end

  defp get_current_user(session) do
    case session["user_id"] do
      nil -> nil
      user_id -> Accounts.get_user(user_id)
    end
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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="py-6 sm:py-8 px-4 sm:px-6">
      <div class="max-w-4xl mx-auto">
        <!-- Back Button -->
        <div class="mb-4">
          <.link navigate={@back_url} class="text-sm text-emerald-600 hover:underline flex items-center gap-1">
            <.icon name="hero-arrow-left" class="w-4 h-4" />
            Back
          </.link>
        </div>

        <!-- Profile Header -->
        <div class="bg-white border rounded-xl p-6 mb-6">
          <div class="flex items-start gap-4">
            <!-- Avatar -->
            <div class="w-16 h-16 sm:w-20 sm:h-20 bg-emerald-100 rounded-full flex items-center justify-center flex-shrink-0">
              <span class="text-2xl sm:text-3xl font-bold text-emerald-600">
                <%= String.first(@profile_user.name) |> String.upcase() %>
              </span>
            </div>

            <!-- Info -->
            <div class="flex-1 min-w-0">
              <div class="flex flex-wrap items-center gap-2 mb-1">
                <h1 class="text-xl sm:text-2xl font-bold truncate"><%= @profile_user.name %></h1>
                <%= if @profile_user.verification_status == "verified" do %>
                  <.verified_badge />
                <% end %>
              </div>

              <p class="text-gray-500 mb-2">
                <%= case @profile_user.user_type do
                  "writer" -> "Writer"
                  "voice_artist" -> "Voice Artist"
                  _ -> "Member"
                end %>
                <%= if @profile_user.performer_type == "group" do %>
                  <span class="text-xs bg-purple-100 text-purple-700 px-2 py-0.5 rounded-full ml-1">
                    Group/Ensemble
                  </span>
                <% end %>
              </p>

              <!-- Stats -->
              <div class="flex gap-4 text-sm">
                <%= if @profile_user.user_type == "writer" do %>
                  <div>
                    <span class="font-semibold"><%= length(@screenplays) %></span>
                    <span class="text-gray-500">scripts</span>
                  </div>
                <% end %>
                <%= if @profile_user.user_type == "voice_artist" do %>
                  <div>
                    <span class="font-semibold"><%= length(@audio_versions) %></span>
                    <span class="text-gray-500">recordings</span>
                  </div>
                <% end %>
              </div>

              <!-- Bio -->
              <%= if @profile_user.bio do %>
                <p class="text-gray-600 text-sm mt-3"><%= @profile_user.bio %></p>
              <% end %>

              <!-- Social Links -->
              <%= if @profile_user.social_links != [] do %>
                <div class="flex gap-2 mt-3">
                  <%= for link <- @profile_user.social_links do %>
                    <a
                      href={link}
                      target="_blank"
                      rel="noopener noreferrer"
                      class="text-xs bg-gray-100 px-2 py-1 rounded hover:bg-gray-200"
                    >
                      <%= get_social_name(link) %>
                    </a>
                  <% end %>
                </div>
              <% end %>
            </div>
          </div>
        </div>

        <!-- Profile Intro Video (30-sec intro, separate from verification) -->
        <%= if @profile_user.profile_video_url do %>
          <div class="bg-white border rounded-xl p-4 sm:p-6 mb-6">
            <h2 class="font-semibold mb-3 flex items-center gap-2">
              <.icon name="hero-video-camera" class="w-5 h-5 text-emerald-600" />
              About Me
            </h2>
            <div class="aspect-video bg-gray-900 rounded-lg overflow-hidden">
              <video
                controls
                playsinline
                class="w-full h-full object-contain"
                src={@profile_user.profile_video_url}
              >
                Your browser does not support the video tag.
              </video>
            </div>
          </div>
        <% end %>

        <!-- Verification Video (for writers and voice artists) -->
        <%= if @profile_user.user_type in ["writer", "voice_artist"] and @profile_user.verification_video_url do %>
          <div class="bg-white border rounded-xl p-4 sm:p-6 mb-6">
            <h2 class="font-semibold mb-3 flex items-center gap-2">
              <.icon name="hero-check-badge" class="w-5 h-5 text-emerald-600" />
              Identity Verified
            </h2>
            <p class="text-sm text-gray-500 mb-3">
              This user verified their identity by reading a phrase aloud on video.
            </p>

            <%= if @profile_user.verification_phrase do %>
              <div class="bg-gray-50 rounded-lg p-3 mb-3">
                <p class="text-xs text-gray-500 mb-1">Verification phrase:</p>
                <p class="font-mono text-sm">"<%= @profile_user.verification_phrase %>"</p>
              </div>
            <% end %>

            <!-- Video Player -->
            <div class="aspect-video bg-gray-900 rounded-lg overflow-hidden">
              <video
                controls
                playsinline
                class="w-full h-full object-contain"
                src={@profile_user.verification_video_url}
              >
                Your browser does not support the video tag.
              </video>
            </div>
          </div>
        <% end %>

        <!-- Collectives Section (for voice artists) -->
        <%= if @profile_user.user_type == "voice_artist" and @collectives != [] do %>
          <div class="bg-white border rounded-xl p-4 sm:p-6 mb-6">
            <h2 class="font-semibold mb-3 flex items-center gap-2">
              <.icon name="hero-user-group" class="w-5 h-5 text-purple-600" />
              Member of
            </h2>
            <div class="flex flex-wrap gap-2">
              <%= for collective <- @collectives do %>
                <.link
                  navigate={~p"/collective/#{collective.slug}"}
                  class="flex items-center gap-2 bg-purple-50 hover:bg-purple-100 rounded-lg px-3 py-2 transition"
                >
                  <span class="font-medium text-purple-700"><%= collective.name %></span>
                  <.icon name="hero-chevron-right" class="w-4 h-4 text-purple-400" />
                </.link>
              <% end %>
            </div>
          </div>
        <% end %>

        <!-- Content -->
        <%= if @profile_user.user_type == "writer" do %>
          <h2 class="text-lg font-bold mb-4">Screenplays</h2>

          <%= if Enum.empty?(@screenplays) do %>
            <div class="bg-white border rounded-xl p-8 text-center">
              <.icon name="hero-document-text" class="w-12 h-12 text-gray-300 mx-auto mb-4" />
              <p class="text-gray-500">No screenplays uploaded yet</p>
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
        <% end %>

        <%= if @profile_user.user_type == "voice_artist" do %>
          <h2 class="text-lg font-bold mb-4">Audio Recordings</h2>

          <%= if Enum.empty?(@audio_versions) do %>
            <div class="bg-white border rounded-xl p-8 text-center">
              <.icon name="hero-microphone" class="w-12 h-12 text-gray-300 mx-auto mb-4" />
              <p class="text-gray-500">No recordings yet</p>
            </div>
          <% else %>
            <div class="space-y-3">
              <%= for av <- @audio_versions do %>
                <div class="bg-white border rounded-xl p-4">
                  <!-- Solo vs Collective Label -->
                  <div class="flex items-center gap-2 mb-2">
                    <%= if av.collective do %>
                      <.link
                        navigate={~p"/collective/#{av.collective.slug}"}
                        class="text-xs bg-purple-100 text-purple-700 px-2 py-0.5 rounded-full hover:bg-purple-200 flex items-center gap-1"
                      >
                        <.icon name="hero-user-group" class="w-3 h-3" />
                        By <%= av.collective.name %>
                      </.link>
                    <% else %>
                      <span class="text-xs bg-gray-100 text-gray-600 px-2 py-0.5 rounded-full flex items-center gap-1">
                        <.icon name="hero-user" class="w-3 h-3" />
                        Solo
                      </span>
                    <% end %>
                  </div>
                  <.link navigate={~p"/screenplay/#{av.screenplay_id}"} class="text-sm text-emerald-600 font-medium hover:underline mb-2 block">
                    <%= if av.screenplay, do: av.screenplay.title, else: "Unknown Screenplay" %>
                  </.link>
                  <.audio_version_card
                    audio_version={av}
                    playing={false}
                    liked={false}
                    is_author={false}
                  />
                </div>
              <% end %>
            </div>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  defp get_social_name(url) do
    cond do
      String.contains?(url, "linkedin") -> "LinkedIn"
      String.contains?(url, "twitter") or String.contains?(url, "x.com") -> "Twitter/X"
      String.contains?(url, "imdb") -> "IMDb"
      String.contains?(url, "stage32") -> "Stage32"
      true -> "Website"
    end
  end
end
