defmodule ScriptVoiceWeb.ScriptReaderLive do
  @moduledoc """
  Full-screen script reader page.
  Displays the screenplay content in a clean, readable format.
  """
  use ScriptVoiceWeb, :live_view

  alias ScriptVoice.Screenplays

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Screenplays.get_screenplay(id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Screenplay not found")
         |> push_navigate(to: ~p"/browse")}

      screenplay ->
        {:ok,
         socket
         |> assign(:screenplay, screenplay)
         |> assign(:page_title, "#{screenplay.title} - Read Script")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <!-- Sticky Header -->
      <div class="sticky top-0 z-10 bg-white border-b shadow-sm">
        <div class="max-w-4xl mx-auto px-4 py-3 flex items-center justify-between">
          <div class="flex items-center gap-4">
            <.link
              navigate={~p"/screenplay/#{@screenplay.id}"}
              class="text-gray-500 hover:text-gray-700 p-2 -ml-2 rounded-lg hover:bg-gray-100"
            >
              <.icon name="hero-x-mark" class="w-6 h-6" />
            </.link>
            <div>
              <h1 class="font-bold text-lg truncate max-w-[200px] sm:max-w-none"><%= @screenplay.title %></h1>
              <p class="text-sm text-gray-500">by <%= @screenplay.writer_name %></p>
            </div>
          </div>
          <div class="flex items-center gap-2">
            <.genre_badge genre={@screenplay.genre} />
            <span class="text-sm text-gray-500 hidden sm:inline">
              <%= @screenplay.page_count || "?" %> pages
            </span>
          </div>
        </div>
      </div>

      <!-- Script Content -->
      <div class="max-w-4xl mx-auto px-4 py-6 sm:py-8">
        <%= if @screenplay.script_content do %>
          <div class="bg-white rounded-xl shadow-sm border p-6 sm:p-8">
            <pre class="whitespace-pre-wrap font-mono text-sm sm:text-base leading-relaxed text-gray-800"><%= @screenplay.script_content %></pre>
          </div>
        <% else %>
          <div class="bg-white rounded-xl shadow-sm border p-12 text-center">
            <.icon name="hero-document-text" class="w-16 h-16 text-gray-300 mx-auto mb-4" />
            <h2 class="font-semibold text-xl mb-2">Script not available</h2>
            <p class="text-gray-500 mb-6">The full script content hasn't been uploaded yet.</p>
            <.link
              navigate={~p"/screenplay/#{@screenplay.id}"}
              class="text-emerald-600 font-medium hover:underline"
            >
              Back to screenplay
            </.link>
          </div>
        <% end %>
      </div>

      <!-- Bottom Navigation (mobile) -->
      <div class="fixed bottom-0 left-0 right-0 bg-white border-t p-3 sm:hidden">
        <.link
          navigate={~p"/screenplay/#{@screenplay.id}"}
          class="block w-full text-center bg-gray-100 text-gray-700 py-3 rounded-lg font-medium"
        >
          Close Reader
        </.link>
      </div>
    </div>
    """
  end
end
