defmodule ScriptVoiceWeb.ReaderViewComponent do
  @moduledoc """
  Renders story blocks as clean, readable prose.
  Designed for general readers — no technical markup visible.
  """
  use Phoenix.Component

  attr :blocks, :list, required: true

  def reader_view(assigns) do
    sorted_blocks = Enum.sort_by(assigns.blocks, & &1.position)
    assigns = assign(assigns, :sorted_blocks, sorted_blocks)

    ~H"""
    <div class="prose prose-lg max-w-none">
      <%= for block <- @sorted_blocks do %>
        <.render_reader_block block={block} />
      <% end %>
    </div>
    """
  end

  defp render_reader_block(%{block: %{type: "chapter"}} = assigns) do
    ~H"""
    <h2 class="text-2xl font-bold text-center mt-10 mb-6 text-gray-900">
      <%= @block.title %>
    </h2>
    """
  end

  defp render_reader_block(%{block: %{type: "scene_break"}} = assigns) do
    ~H"""
    <div class="text-center my-8">
      <span class="text-gray-400 tracking-widest text-sm">* * *</span>
      <%= if @block.title && @block.title != "" do %>
        <p class="text-sm text-gray-500 italic mt-1"><%= @block.title %></p>
      <% end %>
    </div>
    """
  end

  defp render_reader_block(%{block: %{type: "narration"}} = assigns) do
    ~H"""
    <p class="text-gray-800 leading-relaxed mb-4">
      <%= @block.text %>
    </p>
    """
  end

  defp render_reader_block(%{block: %{type: "dialogue"}} = assigns) do
    ~H"""
    <p class="mb-3">
      <span class="text-xs font-semibold uppercase tracking-wide text-gray-500 mr-2"><%= @block.character_name %></span>
      <span class="text-gray-800">"<%= @block.text %>"</span>
    </p>
    """
  end

  defp render_reader_block(%{block: %{type: "sfx"}} = assigns) do
    ~H"""
    <p class="text-sm italic text-gray-400 mb-2"><%= @block.description %></p>
    """
  end

  defp render_reader_block(%{block: %{type: "music"}} = assigns) do
    # Hidden in reader view — music cues are production-only
    ~H"""
    """
  end

  defp render_reader_block(%{block: %{type: "pause"}} = assigns) do
    ~H"""
    <div class="my-6"></div>
    """
  end

  defp render_reader_block(assigns) do
    ~H"""
    """
  end
end
