defmodule ScriptVoiceWeb.ProfileLive do
  @moduledoc """
  Profile page LiveView - Shows user profile with their screenplays or audio versions.
  """
  use ScriptVoiceWeb, :live_view

  alias ScriptVoice.Accounts
  alias ScriptVoice.Screenplays
  alias ScriptVoice.Audio
  alias ScriptVoice.Social

  @impl true
  def mount(%{"id" => id}, session, socket) do
    current_user = get_current_user(session)

    case Accounts.get_user(id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "User not found")
         |> push_navigate(to: ~p"/browse")}

      profile_user ->
        # Load user's content
        {screenplays, audio_versions} =
          case profile_user.user_type do
            "writer" ->
              {Screenplays.list_screenplays(writer_id: profile_user.id), []}

            "voice_artist" ->
              {[], Audio.list_audio_versions_by_user(profile_user.id)}

            _ ->
              {[], []}
          end

        is_own_profile = current_user && current_user.id == profile_user.id

        liked_ids =
          if current_user do
            Social.get_liked_screenplay_ids(current_user.id)
          else
            []
          end

        {:ok,
         socket
         |> assign(:current_user, current_user)
         |> assign(:profile_user, profile_user)
         |> assign(:screenplays, screenplays)
         |> assign(:audio_versions, audio_versions)
         |> assign(:is_own_profile, is_own_profile)
         |> assign(:liked_screenplay_ids, liked_ids)
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
        {:noreply, push_navigate(socket, to: ~p"/verify")}

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
