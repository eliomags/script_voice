defmodule ScriptVoiceWeb.ScriptReaderLive do
  @moduledoc """
  Full-screen script reader page.
  Displays the screenplay content in a clean, readable format.
  """
  use ScriptVoiceWeb, :live_view

  alias ScriptVoice.Screenplays
  alias ScriptVoice.Accounts

  @impl true
  def mount(%{"id" => id} = params, session, socket) do
    current_user = get_current_user(session)

    # Handle back navigation from commissions
    back_to = case params do
      %{"from" => "commission", "commission_id" => commission_id} -> ~p"/commissions/#{commission_id}"
      _ -> nil
    end

    case Screenplays.get_screenplay(id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Screenplay not found")
         |> push_navigate(to: ~p"/browse")}

      screenplay ->
        is_author = current_user && current_user.id == screenplay.writer_id

        {:ok,
         socket
         |> assign(:current_user, current_user)
         |> assign(:screenplay, screenplay)
         |> assign(:is_author, is_author)
         |> assign(:back_to, back_to)
         |> assign(:page_title, "#{screenplay.title} - Read Script")}
    end
  end

  defp get_current_user(session) do
    case session["user_id"] do
      nil -> nil
      user_id -> Accounts.get_user(user_id)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="py-6 sm:py-8 px-4 sm:px-6">
      <div class="max-w-4xl mx-auto">
        <!-- Back Button -->
        <%= if @back_to do %>
          <.back navigate={@back_to}>Back to commission</.back>
        <% else %>
          <.back navigate={~p"/screenplay/#{@screenplay.id}"}>Back to screenplay</.back>
        <% end %>

        <!-- Script Header -->
        <div class="bg-white border rounded-xl p-4 sm:p-6 mt-4 mb-6">
          <div class="flex flex-col sm:flex-row justify-between items-start gap-4">
            <div class="flex-1">
              <div class="flex flex-wrap items-center gap-2 mb-2">
                <h1 class="text-xl sm:text-2xl font-bold"><%= @screenplay.title %></h1>
                <.genre_badge genre={@screenplay.genre} />
              </div>
              <p class="text-gray-500 text-sm sm:text-base">
                by <.link navigate={~p"/profile/#{@screenplay.writer_id}"} class="text-emerald-600 font-medium hover:underline"><%= @screenplay.writer_name %></.link>
                · <%= @screenplay.page_count || "?" %> pages
              </p>
            </div>
          </div>
        </div>

        <!-- Script Content -->
        <%= cond do %>
          <% @screenplay.script_content && String.length(@screenplay.script_content) > 0 -> %>
            <!-- Text Content -->
            <div class="bg-white rounded-xl border p-6 sm:p-8">
              <pre class="whitespace-pre-wrap font-mono text-sm sm:text-base leading-relaxed text-gray-800"><%= @screenplay.script_content %></pre>
            </div>

          <% @screenplay.pdf_url -> %>
            <!-- PDF Viewer -->
            <div class="bg-white rounded-xl border overflow-hidden">
              <div class="bg-gray-100 px-4 py-3 border-b flex items-center justify-between">
                <span class="text-sm text-gray-600 font-medium">PDF Script</span>
                <a
                  href={@screenplay.pdf_url}
                  target="_blank"
                  download
                  class="text-sm text-emerald-600 hover:underline flex items-center gap-1"
                >
                  <.icon name="hero-arrow-down-tray" class="w-4 h-4" />
                  Download
                </a>
              </div>
              <iframe
                src={@screenplay.pdf_url}
                class="w-full"
                style="height: calc(100vh - 200px); min-height: 600px;"
              >
                <p class="p-6 text-center text-gray-500">
                  Your browser doesn't support embedded PDFs.
                  <a href={@screenplay.pdf_url} target="_blank" class="text-emerald-600 underline">
                    Click here to download the PDF
                  </a>
                </p>
              </iframe>
            </div>

          <% true -> %>
            <!-- No Content -->
            <div class="bg-white rounded-xl border p-12 text-center">
              <.icon name="hero-document-text" class="w-16 h-16 text-gray-300 mx-auto mb-4" />
              <h2 class="font-semibold text-xl mb-2">Script not available</h2>
              <p class="text-gray-500 mb-6">The full script content hasn't been uploaded yet.</p>
              <.link
                navigate={@back_to || ~p"/screenplay/#{@screenplay.id}"}
                class="text-emerald-600 font-medium hover:underline"
              >
                <%= if @back_to, do: "Back to commission", else: "Back to screenplay" %>
              </.link>
            </div>
        <% end %>
      </div>
    </div>
    """
  end
end
