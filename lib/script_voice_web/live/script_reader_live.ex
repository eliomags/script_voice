defmodule ScriptVoiceWeb.ScriptReaderLive do
  @moduledoc """
  Full-screen story reader page.
  Displays story content with view mode toggle:
  - Reader View: clean prose for reading
  - Script View: formatted for narration/recording
  - Legacy: raw text for old screenplays without blocks
  """
  use ScriptVoiceWeb, :live_view

  import ScriptVoiceWeb.ReaderViewComponent
  import ScriptVoiceWeb.ScriptViewComponent

  alias ScriptVoice.Screenplays
  alias ScriptVoice.Screenplays.Screenplay
  alias ScriptVoice.Accounts

  @impl true
  def mount(%{"id" => id} = params, session, socket) do
    current_user = get_current_user(session)

    back_to = case params do
      %{"from" => "commission", "commission_id" => commission_id} -> ~p"/commissions/#{commission_id}"
      _ -> nil
    end

    case Screenplays.get_screenplay(id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Story not found")
         |> push_navigate(to: ~p"/browse")}

      screenplay ->
        is_author = current_user && current_user.id == screenplay.writer_id
        has_blocks = Screenplay.has_blocks?(screenplay)

        # Default view: reader for general users, script for voice artists
        default_view = cond do
          !has_blocks -> :legacy
          current_user && current_user.user_type == "voice_artist" -> :script
          true -> :reader
        end

        stats = if has_blocks do
          Screenplays.compute_story_stats(screenplay.blocks)
        else
          nil
        end

        {:ok,
         socket
         |> assign(:current_user, current_user)
         |> assign(:screenplay, screenplay)
         |> assign(:is_author, is_author)
         |> assign(:back_to, back_to)
         |> assign(:has_blocks, has_blocks)
         |> assign(:view_mode, default_view)
         |> assign(:stats, stats)
         |> assign(:page_title, "#{screenplay.title} - Read")}
    end
  end

  @impl true
  def handle_event("switch_view", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :view_mode, String.to_atom(mode))}
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
          <.back navigate={~p"/screenplay/#{@screenplay.id}"}>Back to story</.back>
        <% end %>

        <!-- Header -->
        <div class="bg-white border rounded-xl p-4 sm:p-6 mt-4 mb-6">
          <div class="flex flex-col sm:flex-row justify-between items-start gap-4">
            <div class="flex-1">
              <div class="flex flex-wrap items-center gap-2 mb-2">
                <h1 class="text-xl sm:text-2xl font-bold"><%= @screenplay.title %></h1>
                <.genre_badge genre={@screenplay.genre} />
              </div>
              <p class="text-gray-500 text-sm sm:text-base">
                by <.link navigate={~p"/profile/#{@screenplay.writer_id}"} class="text-emerald-600 font-medium hover:underline"><%= @screenplay.writer_name %></.link>
                <%= if @stats do %>
                  · ~<%= @stats.estimated_duration_minutes %> min
                <% else %>
                  · <%= @screenplay.page_count || "?" %> pages
                <% end %>
              </p>
            </div>

            <!-- View Toggle (only for block-based stories) -->
            <%= if @has_blocks do %>
              <div class="flex rounded-lg border border-gray-200 overflow-hidden">
                <button
                  type="button"
                  phx-click="switch_view"
                  phx-value-mode="reader"
                  class={"px-4 py-2 text-sm font-medium transition #{if @view_mode == :reader, do: "bg-emerald-600 text-white", else: "bg-white text-gray-600 hover:bg-gray-50"}"}
                >
                  Reader View
                </button>
                <button
                  type="button"
                  phx-click="switch_view"
                  phx-value-mode="script"
                  class={"px-4 py-2 text-sm font-medium transition #{if @view_mode == :script, do: "bg-emerald-600 text-white", else: "bg-white text-gray-600 hover:bg-gray-50"}"}
                >
                  Script View
                </button>
              </div>
            <% end %>
          </div>

          <!-- Quick Stats -->
          <%= if @stats && map_size(@stats.characters) > 0 do %>
            <div class="flex flex-wrap gap-3 mt-3 pt-3 border-t border-gray-100 text-sm text-gray-500">
              <span><%= @stats.total_words %> words</span>
              <span>·</span>
              <span><%= @stats.scene_count %> scenes</span>
              <span>·</span>
              <span><%= map_size(@stats.characters) %> characters</span>
              <%= if @stats.sfx_count > 0 do %>
                <span>·</span>
                <span><%= @stats.sfx_count %> SFX cues</span>
              <% end %>
            </div>
          <% end %>
        </div>

        <!-- Content -->
        <%= cond do %>
          <% @has_blocks && @view_mode == :reader -> %>
            <div class="bg-white rounded-xl border p-6 sm:p-10">
              <.reader_view blocks={@screenplay.blocks} />
            </div>

          <% @has_blocks && @view_mode == :script -> %>
            <div class="bg-white rounded-xl border p-4 sm:p-6">
              <.script_view blocks={@screenplay.blocks} />
            </div>

          <% @screenplay.script_content && String.length(@screenplay.script_content) > 0 -> %>
            <!-- Legacy text content -->
            <div class="bg-white rounded-xl border p-6 sm:p-8">
              <pre class="whitespace-pre-wrap font-mono text-sm sm:text-base leading-relaxed text-gray-800"><%= @screenplay.script_content %></pre>
            </div>

          <% @screenplay.pdf_url -> %>
            <!-- PDF Viewer -->
            <div class="bg-white rounded-xl border overflow-hidden">
              <div class="bg-gray-100 px-4 py-3 border-b flex items-center justify-between">
                <span class="text-sm text-gray-600 font-medium">PDF</span>
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
                    Click here to download
                  </a>
                </p>
              </iframe>
            </div>

          <% true -> %>
            <!-- No Content -->
            <div class="bg-white rounded-xl border p-12 text-center">
              <.icon name="hero-document-text" class="w-16 h-16 text-gray-300 mx-auto mb-4" />
              <h2 class="font-semibold text-xl mb-2">Story not available</h2>
              <p class="text-gray-500 mb-6">The story content hasn't been added yet.</p>
              <.link
                navigate={@back_to || ~p"/screenplay/#{@screenplay.id}"}
                class="text-emerald-600 font-medium hover:underline"
              >
                <%= if @back_to, do: "Back to commission", else: "Back to story" %>
              </.link>
            </div>
        <% end %>
      </div>
    </div>
    """
  end
end
