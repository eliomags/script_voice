defmodule ScriptVoiceWeb.ScriptViewComponent do
  @moduledoc """
  Renders story blocks as a formatted audio script.
  Designed for narrators and voice artists — clear labels,
  character cues, SFX markers, and estimated timestamps.
  """
  use Phoenix.Component

  alias ScriptVoice.Screenplays.StoryBlock

  attr :blocks, :list, required: true

  def script_view(assigns) do
    sorted_blocks = Enum.sort_by(assigns.blocks, & &1.position)

    # Compute running timestamps (cumulative word count / 150 WPM)
    {blocks_with_time, _} =
      Enum.map_reduce(sorted_blocks, 0, fn block, cumulative_words ->
        words = StoryBlock.word_count(block)
        timestamp = format_timestamp(cumulative_words)
        {Map.put(block, :timestamp, timestamp), cumulative_words + words}
      end)

    assigns = assign(assigns, :blocks_with_time, blocks_with_time)

    ~H"""
    <div class="space-y-3 font-sans text-base sm:text-lg">
      <%= for block <- @blocks_with_time do %>
        <.render_script_block block={block} />
      <% end %>
    </div>
    """
  end

  defp render_script_block(%{block: %{type: "chapter"}} = assigns) do
    ~H"""
    <div class="bg-zinc-800 text-white rounded-lg px-5 py-3 mt-8 mb-4">
      <div class="flex justify-between items-center">
        <h2 class="text-lg font-bold uppercase tracking-wide"><%= @block.title %></h2>
        <span class="text-zinc-400 text-sm font-mono"><%= @block.timestamp %></span>
      </div>
    </div>
    """
  end

  defp render_script_block(%{block: %{type: "scene_break"}} = assigns) do
    ~H"""
    <div class="border-t-2 border-b-2 border-emerald-300 bg-emerald-50 px-5 py-2 my-4 flex justify-between items-center">
      <span class="text-sm font-semibold text-emerald-700 uppercase">
        Scene: <%= @block.title || "—" %>
      </span>
      <span class="text-emerald-500 text-sm font-mono"><%= @block.timestamp %></span>
    </div>
    """
  end

  defp render_script_block(%{block: %{type: "narration"}} = assigns) do
    ~H"""
    <div class="pl-4 border-l-4 border-gray-300 py-2">
      <div class="flex justify-between items-start gap-4">
        <div class="flex-1">
          <span class="text-xs font-bold uppercase text-gray-500 tracking-wider">Narrator</span>
          <p class="text-gray-800 mt-1 leading-relaxed"><%= @block.text %></p>
        </div>
        <span class="text-gray-400 text-sm font-mono whitespace-nowrap"><%= @block.timestamp %></span>
      </div>
    </div>
    """
  end

  defp render_script_block(%{block: %{type: "dialogue"}} = assigns) do
    ~H"""
    <div class="pl-4 border-l-4 border-blue-400 bg-blue-50/50 py-2 rounded-r-lg">
      <div class="flex justify-between items-start gap-4">
        <div class="flex-1">
          <span class="font-bold text-blue-700 uppercase">
            <%= @block.character_name %>
          </span>
          <%= if @block.parenthetical && @block.parenthetical != "" do %>
            <span class="text-blue-500 italic text-sm ml-2">(<%= @block.parenthetical %>)</span>
          <% end %>
          <p class="text-gray-800 mt-1 leading-relaxed"><%= @block.text %></p>
        </div>
        <span class="text-gray-400 text-sm font-mono whitespace-nowrap"><%= @block.timestamp %></span>
      </div>
    </div>
    """
  end

  defp render_script_block(%{block: %{type: "sfx"}} = assigns) do
    ~H"""
    <div class="flex items-center gap-3 bg-orange-50 border border-orange-200 rounded-lg px-4 py-2 my-2">
      <span class="text-orange-500 text-lg">🔊</span>
      <span class="font-bold text-orange-700 uppercase text-sm flex-1">
        SFX: <%= @block.description %>
      </span>
      <span class="text-orange-400 text-sm font-mono"><%= @block.timestamp %></span>
    </div>
    """
  end

  defp render_script_block(%{block: %{type: "music"}} = assigns) do
    ~H"""
    <div class="flex items-center gap-3 bg-purple-50 border border-purple-200 rounded-lg px-4 py-2 my-2">
      <span class="text-purple-500 text-lg">🎵</span>
      <span class="font-bold text-purple-700 uppercase text-sm flex-1">
        MUSIC: <%= @block.description %>
      </span>
      <span class="text-purple-400 text-sm font-mono"><%= @block.timestamp %></span>
    </div>
    """
  end

  defp render_script_block(%{block: %{type: "pause"}} = assigns) do
    ~H"""
    <div class="flex items-center justify-center gap-3 py-2 my-1">
      <span class="text-zinc-400">⏸</span>
      <span class="text-sm font-medium text-zinc-500 uppercase">
        <%= if @block.description && @block.description != "", do: @block.description, else: "BEAT" %>
      </span>
      <span class="text-zinc-400 text-sm font-mono"><%= @block.timestamp %></span>
    </div>
    """
  end

  defp render_script_block(assigns) do
    ~H"""
    """
  end

  defp format_timestamp(total_words) do
    total_seconds = round(total_words / 150 * 60)
    minutes = div(total_seconds, 60)
    seconds = rem(total_seconds, 60)
    "#{String.pad_leading(Integer.to_string(minutes), 2, "0")}:#{String.pad_leading(Integer.to_string(seconds), 2, "0")}"
  end
end
