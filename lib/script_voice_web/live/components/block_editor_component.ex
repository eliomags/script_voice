defmodule ScriptVoiceWeb.BlockEditorComponent do
  @moduledoc """
  Segment-based story editor component.
  Renders a mix of text segments (editable textareas) and block segments (typed cards).
  User selects text in a textarea → parent shows popup → text becomes a block.
  """
  use ScriptVoiceWeb, :live_component

  alias ScriptVoice.Screenplays

  @block_type_labels [
    {"Narration", "narration"},
    {"Dialogue", "dialogue"},
    {"Sound Effect", "sfx"},
    {"Scene Break", "scene_break"},
    {"Chapter", "chapter"},
    {"Music", "music"},
    {"Pause / Beat", "pause"}
  ]

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:show_add_menu, false)
     |> assign(:open_type_menu, nil)
     |> assign(:block_type_labels, @block_type_labels)}
  end

  @impl true
  def update(assigns, socket) do
    segments = assigns[:segments] || []
    blocks = Enum.filter(segments, &(&1.type == :block)) |> Enum.map(& &1.block)
    characters = extract_characters(blocks)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:segments, segments)
     |> assign(:characters, characters)
     |> assign(:stats, Screenplays.compute_story_stats(blocks))}
  end

  defp extract_characters(blocks) do
    blocks
    |> Enum.filter(&(&1.type == "dialogue" && &1.character_name && &1.character_name != ""))
    |> Enum.map(& &1.character_name)
    |> Enum.uniq()
    |> Enum.sort()
  end

  # ── Events (delegated to parent via send) ──────────────────────────────────

  @impl true
  def handle_event("toggle_add_menu", _, socket) do
    {:noreply, update(socket, :show_add_menu, &(!&1))}
  end

  @impl true
  def handle_event("add_empty_block", %{"type" => type}, socket) do
    send(self(), {:add_empty_block, type})
    {:noreply, assign(socket, :show_add_menu, false)}
  end

  @impl true
  def handle_event("toggle_type_menu", %{"id" => id}, socket) do
    current = socket.assigns.open_type_menu
    {:noreply, assign(socket, :open_type_menu, if(current == id, do: nil, else: id))}
  end

  # ── Render ─────────────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-3">
      <%= if Enum.empty?(@segments) do %>
        <div class="text-center py-12 text-gray-400 border-2 border-dashed border-gray-200 rounded-xl">
          <.icon name="hero-document-text" class="w-10 h-10 mx-auto mb-3 text-gray-300" />
          <p class="text-sm">No content yet. Start typing or upload a file above.</p>
        </div>
      <% else %>
        <%= for seg <- @segments do %>
          <%= case seg.type do %>
            <% :text -> %>
              <.text_segment segment={seg} />
            <% :block -> %>
              <.block_card
                segment={seg}
                block={seg.block}
                characters={@characters}
                open_type_menu={@open_type_menu}
                block_type_labels={@block_type_labels}
                myself={@myself}
              />
          <% end %>
        <% end %>
      <% end %>

      <!-- Add Block Button -->
      <div class="relative">
        <button
          type="button"
          phx-click="toggle_add_menu"
          phx-target={@myself}
          class="w-full border-2 border-dashed border-gray-300 rounded-xl py-3 text-gray-500 hover:border-emerald-400 hover:text-emerald-600 hover:bg-emerald-50/50 text-sm font-medium transition-colors flex items-center justify-center gap-2"
        >
          <.icon name="hero-plus" class="w-4 h-4" />
          Add Block
        </button>

        <%= if @show_add_menu do %>
          <div class="absolute bottom-full left-0 right-0 mb-2 bg-white border rounded-xl shadow-lg p-2 z-10 grid grid-cols-2 sm:grid-cols-4 gap-1">
            <%= for {label, type} <- @block_type_labels do %>
              <button
                type="button"
                phx-click="add_empty_block"
                phx-value-type={type}
                phx-target={@myself}
                class={"px-3 py-2 rounded-lg text-sm font-medium transition-colors text-left " <> block_menu_class(type)}
              >
                <span class="mr-1"><%= block_icon(type) %></span>
                <%= label %>
              </button>
            <% end %>
          </div>
        <% end %>
      </div>

      <!-- Stats -->
      <% blocks = Enum.filter(@segments, &(&1.type == :block)) |> Enum.map(& &1.block) %>
      <%= if length(blocks) > 0 do %>
        <div class="bg-gray-50 border rounded-xl p-4 mt-4">
          <h3 class="text-sm font-semibold text-gray-700 mb-3">Story Stats</h3>
          <div class="grid grid-cols-2 sm:grid-cols-4 gap-3 text-sm">
            <div>
              <span class="text-gray-500">Words</span>
              <p class="font-semibold"><%= @stats.total_words %></p>
            </div>
            <div>
              <span class="text-gray-500">Duration</span>
              <p class="font-semibold"><%= @stats.estimated_duration_minutes %> min</p>
            </div>
            <div>
              <span class="text-gray-500">Scenes</span>
              <p class="font-semibold"><%= @stats.scene_count %></p>
            </div>
            <div>
              <span class="text-gray-500">SFX Cues</span>
              <p class="font-semibold"><%= @stats.sfx_count %></p>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # ── Text Segment ───────────────────────────────────────────────────────────

  defp text_segment(assigns) do
    lines = (assigns.segment.content || "") |> String.split("\n") |> length()
    rows = max(4, min(lines + 2, 30))
    assigns = assign(assigns, :rows, rows)

    ~H"""
    <div
      id={"text-seg-#{@segment.id}"}
      data-segment-id={@segment.id}
      data-segment-type="text"
      phx-hook="TextSelectionHook"
      class="relative group"
    >
      <div class="absolute -left-3 top-0 bottom-0 w-1 bg-gray-200 rounded-full group-hover:bg-emerald-300 transition-colors"></div>
      <textarea
        id={"textarea-#{@segment.id}"}
        phx-blur="update_text_segment"
        phx-value-segment-id={@segment.id}
        name={"text_segment[#{@segment.id}]"}
        rows={@rows}
        class="w-full px-4 py-3 text-sm text-gray-700 leading-relaxed bg-transparent border border-gray-200 rounded-lg focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 resize-y font-serif"
        placeholder="Plain text — select any portion and choose a block type..."
      ><%= @segment.content %></textarea>
      <p class="text-xs text-gray-400 mt-1 opacity-0 group-hover:opacity-100 transition-opacity">
        Highlight text and pick a block type from the toolbar that appears
      </p>
    </div>
    """
  end

  # ── Block Card ─────────────────────────────────────────────────────────────

  defp block_card(assigns) do
    ~H"""
    <div class={"border-l-4 rounded-xl p-4 " <> block_style(@block.type)}>
      <%!-- Header: type badge + controls --%>
      <div class="flex items-center justify-between gap-2 mb-2">
        <%!-- Type badge (clickable dropdown) --%>
        <div class="relative">
          <button
            type="button"
            phx-click="toggle_type_menu"
            phx-value-id={@segment.id}
            phx-target={@myself}
            class={"inline-flex items-center gap-1 px-2.5 py-1 rounded text-xs font-bold uppercase cursor-pointer hover:ring-2 hover:ring-offset-1 transition " <> block_badge_style(@block.type)}
            title="Change block type"
          >
            <span><%= block_icon(@block.type) %></span>
            <span><%= block_label(@block.type) %></span>
            <.icon name="hero-chevron-down" class="w-3 h-3 opacity-60" />
          </button>

          <%= if @open_type_menu == @segment.id do %>
            <div class="absolute top-full left-0 mt-1 bg-white border rounded-lg shadow-lg py-1 z-20 min-w-[160px]">
              <%= for {label, type} <- @block_type_labels do %>
                <button
                  type="button"
                  phx-click="change_block_type"
                  phx-value-id={@block.id}
                  phx-value-type={type}
                  class={"w-full text-left px-3 py-1.5 text-sm flex items-center gap-2 transition-colors " <>
                    if(type == @block.type, do: "bg-emerald-50 text-emerald-700 font-semibold", else: "hover:bg-gray-50 text-gray-700")}
                >
                  <span><%= block_icon(type) %></span>
                  <span><%= label %></span>
                  <%= if type == @block.type do %>
                    <.icon name="hero-check" class="w-3.5 h-3.5 ml-auto text-emerald-600" />
                  <% end %>
                </button>
              <% end %>
            </div>
          <% end %>
        </div>

        <%!-- Controls --%>
        <div class="flex items-center gap-0.5">
          <button type="button" phx-click="move_segment_up" phx-value-id={@segment.id}
            class="p-1.5 text-gray-400 hover:text-gray-600 hover:bg-white rounded transition" title="Move up">
            <.icon name="hero-chevron-up" class="w-4 h-4" />
          </button>
          <button type="button" phx-click="move_segment_down" phx-value-id={@segment.id}
            class="p-1.5 text-gray-400 hover:text-gray-600 hover:bg-white rounded transition" title="Move down">
            <.icon name="hero-chevron-down" class="w-4 h-4" />
          </button>
          <div class="w-px h-4 bg-gray-300 mx-1"></div>
          <button type="button" phx-click="unassign_block" phx-value-id={@segment.id}
            class="p-1.5 text-gray-400 hover:text-amber-500 hover:bg-amber-50 rounded transition" title="Convert back to text">
            <.icon name="hero-arrow-uturn-left" class="w-4 h-4" />
          </button>
          <button type="button" phx-click="delete_block" phx-value-id={@segment.id}
            class="p-1.5 text-gray-400 hover:text-red-500 hover:bg-red-50 rounded transition" title="Delete block"
            data-confirm="Delete this block?">
            <.icon name="hero-trash" class="w-4 h-4" />
          </button>
        </div>
      </div>

      <%!-- Content fields based on type --%>
      <%= case @block.type do %>
        <% "chapter" -> %>
          <input type="text" value={@block.title || ""} phx-blur="update_block_field"
            phx-value-id={@block.id} phx-value-field="title"
            placeholder="Chapter title..."
            class="w-full px-3 py-2 bg-white border border-gray-200 rounded-lg text-lg font-bold focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500" />

        <% "scene_break" -> %>
          <input type="text" value={@block.title || ""} phx-blur="update_block_field"
            phx-value-id={@block.id} phx-value-field="title"
            placeholder="Scene / location..."
            class="w-full px-3 py-2 bg-white border border-gray-200 rounded-lg text-sm focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500" />

        <% "narration" -> %>
          <textarea phx-blur="update_block_field" phx-value-id={@block.id} phx-value-field="text"
            placeholder="Narration text..." rows="3"
            class="w-full px-3 py-2 bg-white border border-gray-200 rounded-lg text-sm focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 resize-y"
          ><%= @block.text || "" %></textarea>

        <% "dialogue" -> %>
          <div class="space-y-2">
            <div class="flex gap-2">
              <div class="flex-1">
                <label class="block text-xs text-gray-500 mb-1">Character</label>
                <input type="text" value={@block.character_name || ""} phx-blur="update_block_field"
                  phx-value-id={@block.id} phx-value-field="character_name"
                  list={"chars-#{@block.id}"} placeholder="Character name"
                  class="w-full px-3 py-2 bg-white border border-gray-200 rounded-lg text-sm font-semibold uppercase focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500" />
                <datalist id={"chars-#{@block.id}"}>
                  <%= for name <- @characters do %><option value={name} /><% end %>
                </datalist>
              </div>
              <div class="w-36">
                <label class="block text-xs text-gray-500 mb-1">Tone / Emotion</label>
                <input type="text" value={@block.parenthetical || ""} phx-blur="update_block_field"
                  phx-value-id={@block.id} phx-value-field="parenthetical"
                  placeholder="e.g. softly"
                  class="w-full px-3 py-2 bg-white border border-gray-200 rounded-lg text-sm italic focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500" />
              </div>
            </div>
            <textarea phx-blur="update_block_field" phx-value-id={@block.id} phx-value-field="text"
              placeholder="Dialogue text..." rows="2"
              class="w-full px-3 py-2 bg-white border border-gray-200 rounded-lg text-sm focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500 resize-y"
            ><%= @block.text || "" %></textarea>
          </div>

        <% "sfx" -> %>
          <input type="text" value={@block.description || ""} phx-blur="update_block_field"
            phx-value-id={@block.id} phx-value-field="description"
            placeholder="Sound effect..."
            class="w-full px-3 py-2 bg-white border border-gray-200 rounded-lg text-sm focus:ring-2 focus:ring-orange-500/20 focus:border-orange-500" />

        <% "music" -> %>
          <input type="text" value={@block.description || ""} phx-blur="update_block_field"
            phx-value-id={@block.id} phx-value-field="description"
            placeholder="Music cue..."
            class="w-full px-3 py-2 bg-white border border-gray-200 rounded-lg text-sm focus:ring-2 focus:ring-purple-500/20 focus:border-purple-500" />

        <% "pause" -> %>
          <input type="text" value={@block.description || ""} phx-blur="update_block_field"
            phx-value-id={@block.id} phx-value-field="description"
            placeholder="e.g. long pause, beat..."
            class="w-full px-3 py-2 bg-white border border-gray-200 rounded-lg text-sm focus:ring-2 focus:ring-zinc-500/20 focus:border-zinc-500" />

        <% _ -> %>
          <p class="text-sm text-gray-500 italic">Unknown block type</p>
      <% end %>
    </div>
    """
  end

  # ── Styling ────────────────────────────────────────────────────────────────

  defp block_style("narration"), do: "bg-gray-50 border-l-gray-400"
  defp block_style("dialogue"), do: "bg-blue-50 border-l-blue-400"
  defp block_style("sfx"), do: "bg-orange-50 border-l-orange-400"
  defp block_style("music"), do: "bg-purple-50 border-l-purple-400"
  defp block_style("pause"), do: "bg-zinc-100 border-l-zinc-400"
  defp block_style("scene_break"), do: "bg-emerald-50 border-l-emerald-400"
  defp block_style("chapter"), do: "bg-zinc-800 border-l-zinc-900"
  defp block_style(_), do: "bg-white border-l-gray-300"

  defp block_badge_style("narration"), do: "bg-gray-200 text-gray-700 hover:ring-gray-400"
  defp block_badge_style("dialogue"), do: "bg-blue-200 text-blue-800 hover:ring-blue-400"
  defp block_badge_style("sfx"), do: "bg-orange-200 text-orange-800 hover:ring-orange-400"
  defp block_badge_style("music"), do: "bg-purple-200 text-purple-800 hover:ring-purple-400"
  defp block_badge_style("pause"), do: "bg-zinc-300 text-zinc-700 hover:ring-zinc-400"
  defp block_badge_style("scene_break"), do: "bg-emerald-200 text-emerald-800 hover:ring-emerald-400"
  defp block_badge_style("chapter"), do: "bg-white/20 text-white hover:ring-white/50"
  defp block_badge_style(_), do: "bg-gray-200 text-gray-700 hover:ring-gray-400"

  defp block_label("narration"), do: "Narration"
  defp block_label("dialogue"), do: "Dialogue"
  defp block_label("sfx"), do: "SFX"
  defp block_label("music"), do: "Music"
  defp block_label("pause"), do: "Pause"
  defp block_label("scene_break"), do: "Scene"
  defp block_label("chapter"), do: "Chapter"
  defp block_label(_), do: "Block"

  defp block_icon("narration"), do: "📝"
  defp block_icon("dialogue"), do: "💬"
  defp block_icon("sfx"), do: "🔊"
  defp block_icon("music"), do: "🎵"
  defp block_icon("pause"), do: "⏸"
  defp block_icon("scene_break"), do: "🎬"
  defp block_icon("chapter"), do: "📖"
  defp block_icon(_), do: "▪"

  defp block_menu_class("narration"), do: "hover:bg-gray-100"
  defp block_menu_class("dialogue"), do: "hover:bg-blue-50"
  defp block_menu_class("sfx"), do: "hover:bg-orange-50"
  defp block_menu_class("music"), do: "hover:bg-purple-50"
  defp block_menu_class("pause"), do: "hover:bg-zinc-100"
  defp block_menu_class("scene_break"), do: "hover:bg-emerald-50"
  defp block_menu_class("chapter"), do: "hover:bg-zinc-100"
  defp block_menu_class(_), do: "hover:bg-gray-50"
end
