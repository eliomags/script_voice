defmodule ScriptVoiceWeb.HomeLive do
  @moduledoc """
  Home page LiveView - Landing page with hero section and popular screenplays.
  Mobile-first design with touch-friendly interactions.
  """
  use ScriptVoiceWeb, :live_view

  alias ScriptVoice.Screenplays
  alias ScriptVoice.Social

  @impl true
  def mount(_params, session, socket) do
    current_user = get_current_user(session)
    popular_screenplays = Screenplays.list_screenplays(sort: :popular, limit: 3)

    liked_ids =
      if current_user do
        Social.get_liked_screenplay_ids(current_user.id)
      else
        []
      end

    {:ok,
     socket
     |> assign(:current_user, current_user)
     |> assign(:popular_screenplays, popular_screenplays)
     |> assign(:liked_screenplay_ids, liked_ids)
     |> assign(:page_title, "Scripts Meet Voices")}
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
    update(socket, :popular_screenplays, fn screenplays ->
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
    <div>
      <!-- Hero Section -->
      <div class="bg-gradient-to-br from-emerald-600 to-teal-700 text-white py-12 sm:py-16 px-4 sm:px-6">
        <div class="max-w-4xl mx-auto text-center">
          <h1 class="text-3xl sm:text-4xl font-bold mb-4">Scripts Meet Voices</h1>
          <p class="text-lg sm:text-xl text-emerald-100 mb-8 px-4">
            Writers publish screenplays. Voice artists bring them to life. Everyone builds their portfolio.
          </p>

          <%= if @current_user do %>
            <div class="flex flex-col sm:flex-row gap-3 sm:gap-4 justify-center px-4">
              <%= if @current_user.user_type == "writer" do %>
                <.link
                  navigate={~p"/browse"}
                  phx-click={show_modal("upload-screenplay-modal")}
                  class="bg-white text-emerald-700 px-6 sm:px-8 py-3 rounded-lg font-semibold hover:bg-emerald-50 flex items-center justify-center gap-2 touch-manipulation"
                >
                  <.icon name="hero-plus" class="w-5 h-5" />
                  Upload Screenplay
                </.link>
              <% end %>
              <.link
                navigate={~p"/browse"}
                class="bg-emerald-500 text-white px-6 sm:px-8 py-3 rounded-lg font-semibold hover:bg-emerald-400 flex items-center justify-center gap-2 touch-manipulation"
              >
                <.icon name="hero-book-open" class="w-5 h-5" />
                Browse Scripts
              </.link>
            </div>
          <% else %>
            <div class="flex flex-col sm:flex-row gap-3 sm:gap-4 justify-center px-4">
              <.link
                navigate={~p"/verify?type=writer"}
                class="bg-white text-emerald-700 px-6 sm:px-8 py-3 rounded-lg font-semibold hover:bg-emerald-50 flex items-center justify-center gap-2 touch-manipulation"
              >
                <.icon name="hero-document-text" class="w-5 h-5" />
                I'm a Writer
              </.link>
              <.link
                navigate={~p"/verify?type=voice"}
                class="bg-emerald-500 text-white px-6 sm:px-8 py-3 rounded-lg font-semibold hover:bg-emerald-400 flex items-center justify-center gap-2 touch-manipulation"
              >
                <.icon name="hero-microphone" class="w-5 h-5" />
                I'm a Voice Artist
              </.link>
            </div>
          <% end %>
        </div>
      </div>

      <!-- How It Works -->
      <div class="py-10 sm:py-12 px-4 sm:px-6 bg-gray-50">
        <div class="max-w-4xl mx-auto">
          <h2 class="text-xl sm:text-2xl font-bold text-center mb-8">How It Works</h2>
          <div class="grid grid-cols-2 md:grid-cols-4 gap-4 sm:gap-6">
            <div class="bg-white p-4 sm:p-6 rounded-xl shadow-sm text-center">
              <div class="w-10 h-10 sm:w-12 sm:h-12 bg-emerald-100 rounded-full flex items-center justify-center mx-auto mb-3 sm:mb-4">
                <.icon name="hero-shield-check" class="w-5 h-5 sm:w-6 sm:h-6 text-emerald-600" />
              </div>
              <h3 class="font-semibold text-sm sm:text-base mb-1 sm:mb-2">Get Verified</h3>
              <p class="text-xs sm:text-sm text-gray-600">Quick verification keeps the platform authentic</p>
            </div>
            <div class="bg-white p-4 sm:p-6 rounded-xl shadow-sm text-center">
              <div class="w-10 h-10 sm:w-12 sm:h-12 bg-purple-100 rounded-full flex items-center justify-center mx-auto mb-3 sm:mb-4">
                <.icon name="hero-document-text" class="w-5 h-5 sm:w-6 sm:h-6 text-purple-600" />
              </div>
              <h3 class="font-semibold text-sm sm:text-base mb-1 sm:mb-2">Upload Script</h3>
              <p class="text-xs sm:text-sm text-gray-600">AI extracts characters and line counts</p>
            </div>
            <div class="bg-white p-4 sm:p-6 rounded-xl shadow-sm text-center">
              <div class="w-10 h-10 sm:w-12 sm:h-12 bg-pink-100 rounded-full flex items-center justify-center mx-auto mb-3 sm:mb-4">
                <.icon name="hero-microphone" class="w-5 h-5 sm:w-6 sm:h-6 text-pink-600" />
              </div>
              <h3 class="font-semibold text-sm sm:text-base mb-1 sm:mb-2">Record Audio</h3>
              <p class="text-xs sm:text-sm text-gray-600">Solo or ensemble, bring scripts to life</p>
            </div>
            <div class="bg-white p-4 sm:p-6 rounded-xl shadow-sm text-center">
              <div class="w-10 h-10 sm:w-12 sm:h-12 bg-blue-100 rounded-full flex items-center justify-center mx-auto mb-3 sm:mb-4">
                <.icon name="hero-heart" class="w-5 h-5 sm:w-6 sm:h-6 text-blue-600" />
              </div>
              <h3 class="font-semibold text-sm sm:text-base mb-1 sm:mb-2">Get Recognized</h3>
              <p class="text-xs sm:text-sm text-gray-600">Community votes, authors pick favorites</p>
            </div>
          </div>
        </div>
      </div>

      <!-- Popular Screenplays -->
      <div class="py-10 sm:py-12 px-4 sm:px-6">
        <div class="max-w-4xl mx-auto">
          <div class="flex justify-between items-center mb-6">
            <h2 class="text-xl sm:text-2xl font-bold">Popular Screenplays</h2>
            <.link navigate={~p"/browse"} class="text-emerald-600 font-medium flex items-center gap-1 hover:underline text-sm sm:text-base">
              View all <.icon name="hero-chevron-right" class="w-4 h-4" />
            </.link>
          </div>

          <%= if Enum.empty?(@popular_screenplays) do %>
            <div class="bg-white border rounded-xl p-8 text-center">
              <.icon name="hero-document-text" class="w-12 h-12 text-gray-300 mx-auto mb-4" />
              <h3 class="font-semibold text-lg mb-2">No screenplays yet</h3>
              <p class="text-gray-600 mb-4">Be the first to share your screenplay!</p>
              <.link navigate={~p"/verify?type=writer"} class="text-emerald-600 font-medium hover:underline">
                Get started as a writer →
              </.link>
            </div>
          <% else %>
            <div class="grid gap-4">
              <%= for sp <- @popular_screenplays do %>
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

      <!-- CTA Section -->
      <div class="bg-emerald-50 py-10 sm:py-12 px-4 sm:px-6">
        <div class="max-w-4xl mx-auto text-center">
          <h2 class="text-xl sm:text-2xl font-bold mb-4">Ready to get started?</h2>
          <p class="text-gray-600 mb-6 px-4">
            Join our community of writers and voice artists building their portfolios together.
          </p>
          <.link
            navigate={~p"/verify"}
            class="inline-flex items-center gap-2 bg-emerald-600 text-white px-6 sm:px-8 py-3 rounded-lg font-semibold hover:bg-emerald-700 touch-manipulation"
          >
            <.icon name="hero-user-plus" class="w-5 h-5" />
            Join ScriptVoice
          </.link>
        </div>
      </div>
    </div>
    """
  end
end
