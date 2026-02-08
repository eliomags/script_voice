defmodule ScriptVoiceWeb.ScreenplayEditLive do
  @moduledoc """
  LiveView for editing story content.
  Text-first editor: import text, then select portions to assign as blocks.
  """
  use ScriptVoiceWeb, :live_view

  alias ScriptVoice.Screenplays
  alias ScriptVoice.Screenplays.{Screenplay, StoryBlock}
  alias ScriptVoice.Projects

  @impl true
  def mount(%{"id" => id}, session, socket) do
    current_user = get_current_user(session)

    case Screenplays.get_screenplay(id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Story not found")
         |> push_navigate(to: ~p"/dashboard")}

      screenplay ->
        if current_user && current_user.id == screenplay.writer_id do
          {project_characters, selected_character_ids} = if screenplay.project_id do
            chars = Projects.list_characters_for_project(screenplay.project_id)
            selected = screenplay.character_ids || []
            {chars, selected}
          else
            {[], []}
          end

          blocks = screenplay.blocks || []

          # Convert existing blocks to segments for editing
          # If no blocks exist, start with one empty text segment (the editor itself)
          segments = if Enum.empty?(blocks) do
            [%{type: :text, id: Ecto.UUID.generate(), content: ""}]
          else
            blocks_to_segments(blocks)
          end

          {:ok,
           socket
           |> assign(:current_user, current_user)
           |> assign(:screenplay, screenplay)
           |> assign(:page_title, "Edit: #{screenplay.title}")
           |> assign(:form, init_form(screenplay))
           |> assign(:segments, segments)
           |> assign(:selection, nil)
           |> assign(:saving, false)
           |> assign(:project_characters, project_characters)
           |> assign(:selected_character_ids, selected_character_ids)
           |> allow_upload(:import_file,
               accept: ~w(.txt .pdf),
               max_entries: 1,
               max_file_size: 25_000_000,
               auto_upload: true,
               progress: &handle_upload_progress/3
             )}
        else
          {:ok,
           socket
           |> put_flash(:error, "You can only edit your own stories")
           |> push_navigate(to: ~p"/screenplay/#{id}")}
        end
    end
  end

  defp init_form(screenplay) do
    to_form(%{
      "title" => screenplay.title,
      "genre" => screenplay.genre,
      "logline" => screenplay.logline,
      "script_content" => screenplay.script_content || "",
      "page_count" => screenplay.page_count,
      "version_notes" => ""
    })
  end

  # ── Segment Conversion ───────────────────────────────────────────────────

  # Convert DB blocks → editor segments
  defp blocks_to_segments(blocks) when is_list(blocks) and length(blocks) > 0 do
    blocks
    |> Enum.sort_by(& &1.position)
    |> Enum.map(fn block -> %{type: :block, id: block.id, block: block} end)
  end
  defp blocks_to_segments(_), do: []

  # Convert editor segments → DB blocks for saving
  defp segments_to_blocks(segments) do
    segments
    |> Enum.with_index()
    |> Enum.flat_map(fn {seg, idx} ->
      case seg.type do
        :block ->
          [%{seg.block | position: idx}]

        :text ->
          text = String.trim(seg.content || "")
          if text != "" do
            [%StoryBlock{
              id: Ecto.UUID.generate(),
              type: "narration",
              text: text,
              position: idx
            }]
          else
            []
          end
      end
    end)
  end

  # ── Upload Progress ────────────────────────────────────────────────────────

  defp handle_upload_progress(:import_file, entry, socket) do
    if entry.done? do
      {:noreply, push_event(socket, "upload-complete", %{name: entry.client_name})}
    else
      {:noreply, socket}
    end
  end

  # ── Events ─────────────────────────────────────────────────────────────────

  # Process uploaded file — extract text and load as ONE text segment
  @impl true
  def handle_event("process_upload", _params, socket) do
    results =
      consume_uploaded_entries(socket, :import_file, fn %{path: path}, entry ->
        {:ok, extract_file_text(path, entry.client_name)}
      end)

    case results do
      [text | _] when is_binary(text) and text != "" ->
        segments = [%{type: :text, id: Ecto.UUID.generate(), content: String.trim(text)}]

        {:noreply,
         socket
         |> assign(:segments, segments)
         |> put_flash(:info, "Text loaded! Select any text and choose a block type to assign it.")}

      _ ->
        {:noreply, put_flash(socket, :error, "Could not extract text from file.")}
    end
  end

  @impl true
  def handle_event("cancel_import_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :import_file, ref)}
  end

  # ── Text Selection & Block Assignment ──────────────────────────────────────

  # JS hook sends selection data when user highlights text in a textarea
  @impl true
  def handle_event("text_selected", params, socket) do
    selection = %{
      segment_id: params["segment_id"],
      start_offset: params["start_offset"],
      end_offset: params["end_offset"],
      selected_text: params["selected_text"],
      rect_top: params["rect_top"],
      rect_left: params["rect_left"],
      rect_bottom: params["rect_bottom"]
    }

    {:noreply, assign(socket, :selection, selection)}
  end

  @impl true
  def handle_event("clear_selection", _, socket) do
    {:noreply, assign(socket, :selection, nil)}
  end

  # User picked a block type for the selected text
  @impl true
  def handle_event("assign_block_type", %{"type" => block_type}, socket) do
    sel = socket.assigns.selection
    if is_nil(sel) do
      {:noreply, socket}
    else
      segments = socket.assigns.segments
      idx = Enum.find_index(segments, &(&1.id == sel.segment_id))

      if is_nil(idx) do
        {:noreply, assign(socket, :selection, nil)}
      else
        seg = Enum.at(segments, idx)

        if seg.type != :text do
          {:noreply, assign(socket, :selection, nil)}
        else
          before_text = String.slice(seg.content, 0, sel.start_offset)
          selected_text = String.slice(seg.content, sel.start_offset, sel.end_offset - sel.start_offset)
          after_text = String.slice(seg.content, sel.end_offset..-1//1)

          new_block = build_block(block_type, selected_text)

          new_parts =
            maybe_text_seg(before_text) ++
            [%{type: :block, id: new_block.id, block: new_block}] ++
            maybe_text_seg(after_text)

          updated =
            segments
            |> List.replace_at(idx, new_parts)
            |> List.flatten()

          {:noreply,
           socket
           |> assign(:segments, updated)
           |> assign(:selection, nil)}
        end
      end
    end
  end

  # Convert a block back to text (unassign)
  @impl true
  def handle_event("unassign_block", %{"id" => id}, socket) do
    segments = socket.assigns.segments
    idx = Enum.find_index(segments, &(&1.id == id))

    if idx do
      seg = Enum.at(segments, idx)
      text = get_block_text(seg.block)
      text_seg = %{type: :text, id: Ecto.UUID.generate(), content: text}

      # Merge with adjacent text segments
      updated = List.replace_at(segments, idx, text_seg) |> merge_adjacent_text()
      {:noreply, assign(socket, :segments, updated)}
    else
      {:noreply, socket}
    end
  end

  # Update a text segment's content
  @impl true
  def handle_event("update_text_segment", %{"segment-id" => id, "value" => value}, socket) do
    updated =
      Enum.map(socket.assigns.segments, fn seg ->
        if seg.id == id && seg.type == :text, do: %{seg | content: value}, else: seg
      end)

    {:noreply, assign(socket, :segments, updated)}
  end

  # Update a block field
  @impl true
  def handle_event("update_block_field", %{"id" => id, "field" => field, "value" => value}, socket) do
    updated =
      Enum.map(socket.assigns.segments, fn seg ->
        if seg.type == :block && seg.block.id == id do
          block = Map.put(seg.block, String.to_existing_atom(field), value)
          %{seg | block: block}
        else
          seg
        end
      end)

    {:noreply, assign(socket, :segments, updated)}
  end

  # Change block type
  @impl true
  def handle_event("change_block_type", %{"id" => id, "type" => new_type}, socket) do
    updated =
      Enum.map(socket.assigns.segments, fn seg ->
        if seg.type == :block && seg.block.id == id do
          block = seg.block
          text = block.text || block.description || block.title || ""

          new_block = %{block |
            type: new_type,
            text: if(new_type in ["narration", "dialogue"], do: text, else: nil),
            description: if(new_type in ["sfx", "music", "pause"], do: text, else: nil),
            title: if(new_type in ["chapter", "scene_break"], do: text, else: nil),
            character_name: if(new_type == "dialogue", do: block.character_name, else: nil),
            parenthetical: if(new_type == "dialogue", do: block.parenthetical, else: nil)
          }

          %{seg | block: new_block}
        else
          seg
        end
      end)

    {:noreply, assign(socket, :segments, updated)}
  end

  # Delete block entirely (remove from segments)
  @impl true
  def handle_event("delete_block", %{"id" => id}, socket) do
    updated = Enum.reject(socket.assigns.segments, &(&1.id == id))
    {:noreply, assign(socket, :segments, updated)}
  end

  # Move segment up/down
  @impl true
  def handle_event("move_segment_up", %{"id" => id}, socket) do
    {:noreply, move_segment(socket, id, :up)}
  end

  @impl true
  def handle_event("move_segment_down", %{"id" => id}, socket) do
    {:noreply, move_segment(socket, id, :down)}
  end

  # Add empty block at end
  @impl true
  def handle_event("add_empty_block", %{"type" => type}, socket) do
    new_block = build_block(type, "")
    new_seg = %{type: :block, id: new_block.id, block: new_block}
    updated = socket.assigns.segments ++ [new_seg]
    {:noreply, assign(socket, :segments, updated)}
  end

  @impl true
  def handle_event("toggle_character", %{"id" => char_id}, socket) do
    selected = socket.assigns.selected_character_ids
    new_selected = if char_id in selected do
      List.delete(selected, char_id)
    else
      [char_id | selected]
    end
    {:noreply, assign(socket, :selected_character_ids, new_selected)}
  end

  @impl true
  def handle_event("validate", %{"screenplay" => params}, socket) do
    {:noreply, assign(socket, :form, to_form(params))}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  # ── Save ───────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("save", %{"screenplay" => params}, socket) do
    socket = assign(socket, :saving, true)
    screenplay = socket.assigns.screenplay

    # Convert segments to blocks for DB
    blocks = segments_to_blocks(socket.assigns.segments)
    script_content = Screenplays.blocks_to_script_content(blocks)
    page_count = Screenplays.estimate_page_count_from_blocks(blocks)

    block_maps = Enum.map(blocks, fn block ->
      %{
        "id" => block.id,
        "type" => block.type,
        "text" => block.text,
        "character_name" => block.character_name,
        "parenthetical" => block.parenthetical,
        "description" => block.description,
        "title" => block.title,
        "position" => block.position
      }
    end)

    params =
      params
      |> Map.put("blocks", block_maps)
      |> Map.put("script_content", script_content)
      |> Map.put("page_count", page_count)
      |> Map.put("character_ids", socket.assigns.selected_character_ids)

    case Screenplays.update_screenplay(screenplay, params) do
      {:ok, updated} ->
        back = if updated.project_id, do: ~p"/project/#{updated.project_id}", else: ~p"/screenplay/#{updated.id}"
        {:noreply, socket |> put_flash(:info, "Story saved!") |> push_navigate(to: back)}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:saving, false)
         |> assign(:form, to_form(Ecto.Changeset.apply_action(changeset, :validate) |> elem(1) |> Map.from_struct()))
         |> put_flash(:error, "Failed to save. Please check the form.")}
    end
  end

  # Handle blocks_updated message (backward compat from live_component)
  @impl true
  def handle_info({:blocks_updated, blocks}, socket) do
    {:noreply, assign(socket, :segments, blocks_to_segments(blocks))}
  end

  # Handle add_empty_block from BlockEditorComponent
  @impl true
  def handle_info({:add_empty_block, type}, socket) do
    handle_event("add_empty_block", %{"type" => type}, socket)
  end

  # ── Helpers ────────────────────────────────────────────────────────────────

  defp build_block(type, text) do
    %StoryBlock{
      id: Ecto.UUID.generate(),
      type: type,
      text: if(type in ["narration", "dialogue"], do: text, else: nil),
      description: if(type in ["sfx", "music", "pause"], do: text, else: nil),
      title: if(type in ["chapter", "scene_break"], do: text, else: nil),
      character_name: nil,
      parenthetical: nil,
      position: 0
    }
  end

  defp get_block_text(block) do
    block.text || block.description || block.title || ""
  end

  defp maybe_text_seg(text) do
    if String.trim(text || "") != "" do
      [%{type: :text, id: Ecto.UUID.generate(), content: text}]
    else
      []
    end
  end

  defp merge_adjacent_text(segments) do
    Enum.reduce(segments, [], fn seg, acc ->
      case {List.last(acc), seg} do
        {%{type: :text} = prev, %{type: :text}} ->
          merged = %{prev | content: prev.content <> "\n" <> seg.content}
          List.replace_at(acc, -1, merged)
        _ ->
          acc ++ [seg]
      end
    end)
  end

  defp move_segment(socket, id, direction) do
    segments = socket.assigns.segments
    idx = Enum.find_index(segments, &(&1.id == id))

    swap_idx = case direction do
      :up -> max(0, idx - 1)
      :down -> min(length(segments) - 1, idx + 1)
    end

    if idx == swap_idx do
      socket
    else
      updated =
        segments
        |> List.replace_at(idx, Enum.at(segments, swap_idx))
        |> List.replace_at(swap_idx, Enum.at(segments, idx))

      assign(socket, :segments, updated)
    end
  end

  defp extract_file_text(path, client_name) do
    cond do
      String.ends_with?(client_name, ".pdf") ->
        case ScriptVoice.PdfExtractor.extract_text(path) do
          {:ok, text} -> text
          {:error, _} -> ""
        end

      String.ends_with?(client_name, ".txt") ->
        case File.read(path) do
          {:ok, content} -> content
          {:error, _} -> ""
        end

      true -> ""
    end
  rescue
    _ -> ""
  end

  defp get_current_user(session) do
    case session["user_id"] do
      nil -> nil
      user_id -> ScriptVoice.Accounts.get_user(user_id)
    end
  end

  # ── Render ─────────────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <div class="py-6 px-4 sm:px-6 max-w-4xl mx-auto">
      <!-- Header -->
      <div class="flex items-center justify-between mb-6">
        <div>
          <.back navigate={back_path(@screenplay)}>Back</.back>
          <h1 class="text-2xl font-bold text-gray-900 mt-2">
            <%= if has_content?(@screenplay), do: "Edit Story", else: "Add Story" %>
          </h1>
          <p class="text-gray-600"><%= @screenplay.title %></p>
        </div>
      </div>

      <!-- Characters Section -->
      <%= if length(@project_characters) > 0 do %>
        <div class="bg-white border rounded-xl p-6 mb-6">
          <h2 class="text-lg font-semibold mb-2">Characters in this Episode</h2>
          <p class="text-sm text-gray-500 mb-4">Select which series characters appear in this episode</p>
          <div class="flex flex-wrap gap-2">
            <%= for char <- @project_characters do %>
              <button
                type="button"
                phx-click="toggle_character"
                phx-value-id={char.id}
                class={"px-3 py-1.5 rounded-full text-sm font-medium border transition-colors " <>
                  if(char.id in @selected_character_ids,
                    do: "bg-emerald-100 border-emerald-400 text-emerald-700",
                    else: "bg-white border-gray-300 text-gray-600 hover:border-gray-400")}
              >
                <%= char.name %>
                <%= if char.id in @selected_character_ids do %>
                  <span class="ml-1">&#10003;</span>
                <% end %>
              </button>
            <% end %>
          </div>
        </div>
      <% end %>

      <.form for={@form} phx-submit="save" phx-change="validate" id="story-form" class="space-y-6">

        <!-- Metadata Section -->
        <div class="bg-white border rounded-xl p-6">
          <h2 class="text-lg font-semibold mb-4">Story Details</h2>
          <div class="grid gap-4 sm:grid-cols-2">
            <div class="sm:col-span-2">
              <.styled_input name="screenplay[title]" value={@form[:title].value} label="Title" placeholder="Story title" required />
            </div>
            <div>
              <.styled_dropdown id="genre" name="screenplay[genre]" label="Genre" value={@form[:genre].value} options={Screenplay.genres() |> Enum.map(&{&1, &1})} />
            </div>
            <div>
              <.styled_input name="screenplay[page_count]" value={@form[:page_count].value} type="number" label="Page Count" placeholder="Auto-calculated" disabled />
            </div>
            <div class="sm:col-span-2">
              <.styled_textarea name="screenplay[logline]" value={@form[:logline].value} label="Logline" placeholder="One-sentence summary" rows={2} />
            </div>
          </div>
        </div>

        <!-- Story Content — ONE unified section: upload + editor -->
        <div class="bg-white border rounded-xl p-6">
          <div class="flex items-center justify-between mb-4">
            <h2 class="text-lg font-semibold">Story Content</h2>
            <p class="text-xs text-gray-400">Type, paste, or upload text — then select portions to assign block types</p>
          </div>

          <%!-- Compact upload bar --%>
          <div
            id="upload-drop-zone"
            class="border border-dashed border-gray-200 rounded-lg p-3 mb-4 hover:border-emerald-400 hover:bg-emerald-50/30 transition-colors"
            phx-drop-target={@uploads.import_file.ref}
            phx-hook="AutoSubmitUpload"
            data-upload-done={to_string(Enum.any?(@uploads.import_file.entries, & &1.done?))}
          >
            <%= for entry <- @uploads.import_file.entries do %>
              <div class="flex items-center gap-3 p-2 bg-emerald-50 rounded-lg">
                <.icon name="hero-document-text" class="w-5 h-5 text-emerald-600" />
                <div class="flex-1">
                  <p class="text-sm font-medium text-emerald-700"><%= entry.client_name %></p>
                  <div class="w-full bg-gray-200 rounded-full h-1.5 mt-1">
                    <div class="bg-emerald-600 h-1.5 rounded-full transition-all" style={"width: #{entry.progress}%"}></div>
                  </div>
                </div>
                <button type="button" phx-click="cancel_import_upload" phx-value-ref={entry.ref} class="text-gray-400 hover:text-red-500">
                  <.icon name="hero-x-mark" class="w-4 h-4" />
                </button>
              </div>
            <% end %>

            <label class="cursor-pointer flex items-center gap-3">
              <div class={if not Enum.empty?(@uploads.import_file.entries), do: "hidden", else: "flex items-center gap-3 w-full"}>
                <.icon name="hero-arrow-up-tray" class="w-5 h-5 text-gray-400" />
                <span class="text-sm text-gray-500">
                  Drop a <strong>.txt</strong> or <strong>.pdf</strong> here, or <span class="text-emerald-600 font-medium">browse</span>
                </span>
                <span class="text-xs text-gray-400 ml-auto">Up to 25MB</span>
              </div>
              <.live_file_input upload={@uploads.import_file} class="hidden" />
            </label>

            <%= for err <- upload_errors(@uploads.import_file) do %>
              <p class="text-red-500 text-sm mt-2"><%= import_error_to_string(err) %></p>
            <% end %>
          </div>

          <%!-- Editor (segments: text areas + block cards) --%>
          <.live_component
            module={ScriptVoiceWeb.BlockEditorComponent}
            id="block-editor"
            segments={@segments}
            selection={@selection}
          />
        </div>

        <!-- Version Notes -->
        <div class="bg-white border rounded-xl p-6">
          <h2 class="text-lg font-semibold mb-4">Version Notes (optional)</h2>
          <.styled_textarea name="screenplay[version_notes]" value={@form[:version_notes].value} placeholder="Describe what changed..." rows={3} />
        </div>

        <!-- Submit -->
        <div class="flex justify-end gap-3">
          <.link navigate={back_path(@screenplay)}
            class="px-6 py-2.5 border border-gray-300 rounded-lg font-medium text-gray-700 hover:bg-gray-50 transition">
            Cancel
          </.link>
          <button type="submit" disabled={@saving}
            class="px-6 py-2.5 bg-emerald-600 text-white rounded-lg font-medium hover:bg-emerald-700 disabled:opacity-50 disabled:cursor-not-allowed transition flex items-center gap-2">
            <%= if @saving do %>
              <.icon name="hero-arrow-path" class="w-4 h-4 animate-spin" /> Saving...
            <% else %>
              <.icon name="hero-check" class="w-4 h-4" /> Save Story
            <% end %>
          </button>
        </div>
      </.form>
    </div>

    <%!-- Block type selection popup (floating bottom, shown when text is selected) --%>
    <%= if @selection do %>
      <div
        id="block-type-popup"
        phx-click-away="clear_selection"
        class="fixed z-50 bg-white border border-gray-200 rounded-xl shadow-2xl p-2 transition-all"
        style={"bottom: 0; left: 0; right: 0;"}
      >
        <div class="px-3 py-2 border-b border-gray-100 mb-1">
          <p class="text-xs text-gray-500 font-medium">Assign selected text as:</p>
        </div>
        <div class="grid grid-cols-2 sm:grid-cols-4 gap-1">
          <.block_type_btn type="narration" icon="hero-pencil" label="Narration" />
          <.block_type_btn type="dialogue" icon="hero-chat-bubble-left-right" label="Dialogue" />
          <.block_type_btn type="sfx" icon="hero-speaker-wave" label="SFX" />
          <.block_type_btn type="scene_break" icon="hero-film" label="Scene" />
          <.block_type_btn type="chapter" icon="hero-bookmark" label="Chapter" />
          <.block_type_btn type="music" icon="hero-musical-note" label="Music" />
          <.block_type_btn type="pause" icon="hero-pause" label="Pause" />
        </div>
      </div>
    <% end %>
    """
  end

  defp block_type_btn(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="assign_block_type"
      phx-value-type={@type}
      class="flex items-center gap-2 px-3 py-2 rounded-lg text-sm font-medium hover:bg-gray-100 text-gray-700 transition-colors"
    >
      <.icon name={@icon} class="w-4 h-4" />
      <%= @label %>
    </button>
    """
  end

  defp back_path(screenplay) do
    if screenplay.project_id, do: ~p"/project/#{screenplay.project_id}", else: ~p"/screenplay/#{screenplay.id}"
  end

  defp has_content?(screenplay) do
    Screenplay.has_blocks?(screenplay) ||
    (screenplay.script_content && String.trim(screenplay.script_content) != "") ||
    (screenplay.pdf_url && String.trim(screenplay.pdf_url) != "")
  end

  defp import_error_to_string(:too_large), do: "File is too large (max 25MB)"
  defp import_error_to_string(:not_accepted), do: "Only .txt and .pdf files are accepted"
  defp import_error_to_string(:too_many_files), do: "Only one file allowed"
  defp import_error_to_string(_), do: "Upload error"
end
