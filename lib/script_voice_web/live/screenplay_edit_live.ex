defmodule ScriptVoiceWeb.ScreenplayEditLive do
  @moduledoc """
  LiveView for editing screenplay content.
  Allows writers to add/edit script text or upload PDF.
  """
  use ScriptVoiceWeb, :live_view

  alias ScriptVoice.Screenplays
  alias ScriptVoice.Screenplays.Screenplay
  alias ScriptVoice.Projects

  @impl true
  def mount(%{"id" => id}, session, socket) do
    current_user = get_current_user(session)

    case Screenplays.get_screenplay(id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Screenplay not found")
         |> push_navigate(to: ~p"/dashboard")}

      screenplay ->
        # Only the author can edit
        if current_user && current_user.id == screenplay.writer_id do
          # Load project characters if this screenplay belongs to a project
          {project_characters, selected_character_ids} = if screenplay.project_id do
            chars = Projects.list_characters_for_project(screenplay.project_id)
            selected = screenplay.character_ids || []
            {chars, selected}
          else
            {[], []}
          end

          {:ok,
           socket
           |> assign(:current_user, current_user)
           |> assign(:screenplay, screenplay)
           |> assign(:page_title, "Edit: #{screenplay.title}")
           |> assign(:content_mode, determine_content_mode(screenplay))
           |> assign(:form, init_form(screenplay))
           |> assign(:saving, false)
           |> assign(:upload_progress, nil)
           |> assign(:project_characters, project_characters)
           |> assign(:selected_character_ids, selected_character_ids)
           |> allow_upload(:pdf,
               accept: ~w(.pdf),
               max_entries: 1,
               max_file_size: 25_000_000,
               auto_upload: true,
               progress: &handle_progress/3
             )
           |> allow_upload(:text_file,
               accept: ~w(.txt),
               max_entries: 1,
               max_file_size: 5_000_000,
               auto_upload: true,
               progress: &handle_text_progress/3
             )}
        else
          {:ok,
           socket
           |> put_flash(:error, "You can only edit your own screenplays")
           |> push_navigate(to: ~p"/screenplay/#{id}")}
        end
    end
  end

  defp determine_content_mode(screenplay) do
    cond do
      screenplay.script_content && String.trim(screenplay.script_content) != "" -> :text
      screenplay.pdf_url && String.trim(screenplay.pdf_url) != "" -> :pdf
      true -> :text  # Default to text mode for new content
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

  defp handle_progress(:pdf, entry, socket) do
    {:noreply, assign(socket, :upload_progress, entry.progress)}
  end

  defp handle_text_progress(:text_file, entry, socket) do
    {:noreply, assign(socket, :upload_progress, entry.progress)}
  end

  @impl true
  def handle_event("switch_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :content_mode, String.to_atom(mode))}
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
  def handle_event("process_text_file", _, socket) do
    case consume_uploaded_entries(socket, :text_file, &process_text_upload/2) do
      [content | _] ->
        form = socket.assigns.form
        updated_form = to_form(Map.put(form.source, "script_content", content))
        {:noreply,
         socket
         |> assign(:form, updated_form)
         |> assign(:content_mode, :text)
         |> put_flash(:info, "Text file loaded successfully!")}
      [] ->
        {:noreply, socket}
    end
  end

  defp process_text_upload(meta, _entry) do
    File.read!(meta.path)
  end

  @impl true
  def handle_event("validate", %{"screenplay" => params}, socket) do
    {:noreply, assign(socket, :form, to_form(params))}
  end

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :pdf, ref)}
  end

  @impl true
  def handle_event("cancel_text_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :text_file, ref)}
  end

  @impl true
  def handle_event("save", %{"screenplay" => params}, socket) do
    socket = assign(socket, :saving, true)
    screenplay = socket.assigns.screenplay

    # Handle PDF upload if present
    params = case consume_uploaded_entries(socket, :pdf, &process_pdf_upload/2) do
      [pdf_url | _] ->
        params
        |> Map.put("pdf_url", pdf_url)
        |> Map.put("script_content", nil)  # Clear text content when uploading PDF
      [] ->
        params
    end

    # If we're in text mode and have content, calculate page count
    params = if socket.assigns.content_mode == :text do
      content = Map.get(params, "script_content", "")
      page_count = estimate_page_count(content)
      Map.put(params, "page_count", page_count)
    else
      params
    end

    # Add selected character IDs
    params = Map.put(params, "character_ids", socket.assigns.selected_character_ids)

    case Screenplays.update_screenplay(screenplay, params) do
      {:ok, updated} ->
        # Navigate back to the screenplay view
        back_path = if updated.project_id do
          ~p"/project/#{updated.project_id}"
        else
          ~p"/screenplay/#{updated.id}"
        end

        {:noreply,
         socket
         |> put_flash(:info, "Script saved successfully!")
         |> push_navigate(to: back_path)}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:saving, false)
         |> assign(:form, to_form(Ecto.Changeset.apply_action(changeset, :validate) |> elem(1) |> Map.from_struct()))
         |> put_flash(:error, "Failed to save. Please check the form.")}
    end
  end

  defp process_pdf_upload(meta, entry) do
    # For now, store locally. In production, upload to R2/S3
    dest_dir = Path.join(["priv", "static", "uploads", "screenplays"])
    File.mkdir_p!(dest_dir)

    filename = "#{entry.uuid}-#{entry.client_name}"
    dest = Path.join(dest_dir, filename)

    File.cp!(meta.path, dest)
    "/uploads/screenplays/#{filename}"
  end

  # Rough estimate: ~55 lines per page (industry standard for screenplays)
  defp estimate_page_count(nil), do: nil
  defp estimate_page_count(""), do: nil
  defp estimate_page_count(content) do
    lines = content
    |> String.split("\n")
    |> length()

    max(1, div(lines, 55))
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
    <div class="py-6 px-4 sm:px-6 max-w-4xl mx-auto">
      <!-- Header -->
      <div class="flex items-center justify-between mb-6">
        <div>
          <.back navigate={back_path(@screenplay)}>Back</.back>
          <h1 class="text-2xl font-bold text-gray-900 mt-2">
            <%= if has_content?(@screenplay), do: "Edit Script", else: "Add Script" %>
          </h1>
          <p class="text-gray-600"><%= @screenplay.title %></p>
        </div>
      </div>

      <!-- Mode Switcher -->
      <div class="bg-white border rounded-xl p-4 mb-6">
        <label class="block text-sm font-medium text-gray-700 mb-3">Content Type</label>
        <div class="flex flex-wrap gap-3">
          <button
            type="button"
            phx-click="switch_mode"
            phx-value-mode="text"
            class={"px-4 py-2 rounded-lg font-medium transition #{if @content_mode == :text, do: "bg-emerald-600 text-white", else: "bg-gray-100 text-gray-700 hover:bg-gray-200"}"}
          >
            <.icon name="hero-document-text" class="w-4 h-4 inline mr-1" />
            Write Script
          </button>
          <button
            type="button"
            phx-click="switch_mode"
            phx-value-mode="text_upload"
            class={"px-4 py-2 rounded-lg font-medium transition #{if @content_mode == :text_upload, do: "bg-emerald-600 text-white", else: "bg-gray-100 text-gray-700 hover:bg-gray-200"}"}
          >
            <.icon name="hero-arrow-up-tray" class="w-4 h-4 inline mr-1" />
            Upload Text
          </button>
          <button
            type="button"
            phx-click="switch_mode"
            phx-value-mode="pdf"
            class={"px-4 py-2 rounded-lg font-medium transition #{if @content_mode == :pdf, do: "bg-emerald-600 text-white", else: "bg-gray-100 text-gray-700 hover:bg-gray-200"}"}
          >
            <.icon name="hero-document" class="w-4 h-4 inline mr-1" />
            Upload PDF
          </button>
        </div>
      </div>

      <!-- Characters Section (only if episode belongs to a project with characters) -->
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
                  <span class="ml-1">✓</span>
                <% end %>
              </button>
            <% end %>
          </div>
        </div>
      <% end %>

      <!-- Edit Form -->
      <.form for={@form} phx-submit="save" phx-change="validate" class="space-y-6">
        <!-- Metadata Section -->
        <div class="bg-white border rounded-xl p-6">
          <h2 class="text-lg font-semibold mb-4">Episode Details</h2>
          <div class="grid gap-4 sm:grid-cols-2">
            <div class="sm:col-span-2">
              <.styled_input
                name="screenplay[title]"
                value={@form[:title].value}
                label="Title"
                placeholder="Episode title"
                required
              />
            </div>
            <div>
              <.styled_dropdown
                id="genre"
                name="screenplay[genre]"
                label="Genre"
                value={@form[:genre].value}
                options={Screenplay.genres() |> Enum.map(&{&1, &1})}
              />
            </div>
            <div>
              <.styled_input
                name="screenplay[page_count]"
                value={@form[:page_count].value}
                type="number"
                label="Page Count"
                placeholder="Auto-calculated for text"
                disabled={@content_mode == :text}
              />
            </div>
            <div class="sm:col-span-2">
              <.styled_textarea
                name="screenplay[logline]"
                value={@form[:logline].value}
                label="Logline"
                placeholder="One-sentence summary of this episode"
                rows={2}
              />
            </div>
          </div>
        </div>

        <!-- Content Section -->
        <div class="bg-white border rounded-xl p-6">
          <h2 class="text-lg font-semibold mb-4">
            <%= cond do %>
              <% @content_mode == :text -> %>Script Content
              <% @content_mode == :text_upload -> %>Upload Text File
              <% true -> %>PDF Upload
            <% end %>
          </h2>

          <%= if @content_mode == :text do %>
            <!-- Text Editor -->
            <div>
              <textarea
                name="screenplay[script_content]"
                rows="25"
                class="w-full font-mono text-sm border border-gray-300 rounded-lg p-4 focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
                placeholder="INT. LOCATION - DAY&#10;&#10;Character enters...&#10;&#10;CHARACTER&#10;Dialogue goes here.&#10;&#10;ACTION DESCRIPTION continues..."
              ><%= @form[:script_content].value %></textarea>
              <p class="text-xs text-gray-500 mt-2">
                Use standard screenplay format. Page count will be estimated automatically (~55 lines per page).
              </p>
            </div>
          <% end %>

          <%= if @content_mode == :text_upload do %>
            <!-- Text File Upload -->
            <div class="space-y-4">
              <div
                class="border-2 border-dashed border-gray-300 rounded-xl p-8 text-center hover:border-emerald-400 transition-colors"
                phx-drop-target={@uploads.text_file.ref}
              >
                <.live_file_input upload={@uploads.text_file} class="hidden" />

                <%= for entry <- @uploads.text_file.entries do %>
                  <div class="flex items-center gap-3 p-4 bg-emerald-50 rounded-lg mb-4">
                    <.icon name="hero-document-text" class="w-8 h-8 text-emerald-600" />
                    <div class="flex-1">
                      <p class="font-medium"><%= entry.client_name %></p>
                      <div class="w-full bg-gray-200 rounded-full h-2 mt-2">
                        <div class="bg-emerald-600 h-2 rounded-full transition-all" style={"width: #{entry.progress}%"}></div>
                      </div>
                    </div>
                    <button type="button" phx-click="cancel_text_upload" phx-value-ref={entry.ref} class="text-red-500 hover:text-red-700">
                      <.icon name="hero-x-mark" class="w-5 h-5" />
                    </button>
                  </div>
                  <%= if entry.progress == 100 do %>
                    <button
                      type="button"
                      phx-click="process_text_file"
                      class="px-4 py-2 bg-emerald-600 text-white rounded-lg font-medium hover:bg-emerald-700 transition"
                    >
                      Load into Editor
                    </button>
                  <% end %>
                <% end %>

                <%= for err <- upload_errors(@uploads.text_file) do %>
                  <p class="text-red-500 text-sm mb-2"><%= text_upload_error_to_string(err) %></p>
                <% end %>

                <%= if Enum.empty?(@uploads.text_file.entries) do %>
                  <.icon name="hero-document-text" class="w-12 h-12 text-gray-400 mx-auto mb-3" />
                  <p class="text-gray-600 mb-2">Drag and drop your script file here, or</p>
                  <label class="inline-flex items-center gap-2 px-4 py-2 bg-emerald-600 text-white rounded-lg font-medium hover:bg-emerald-700 cursor-pointer transition">
                    <.icon name="hero-folder-open" class="w-4 h-4" />
                    Browse Files
                    <.live_file_input upload={@uploads.text_file} class="hidden" />
                  </label>
                  <p class="text-xs text-gray-500 mt-3">Plain text files (.txt) up to 5MB</p>
                <% end %>
              </div>
            </div>
          <% end %>

          <%= if @content_mode == :pdf do %>
            <!-- PDF Upload -->
            <div class="space-y-4">
              <%= if @screenplay.pdf_url do %>
                <div class="flex items-center gap-3 p-4 bg-gray-50 rounded-lg">
                  <.icon name="hero-document" class="w-8 h-8 text-red-500" />
                  <div class="flex-1">
                    <p class="font-medium">Current PDF</p>
                    <a href={@screenplay.pdf_url} target="_blank" class="text-sm text-emerald-600 hover:underline">
                      View current file
                    </a>
                  </div>
                </div>
              <% end %>

              <div
                class="border-2 border-dashed border-gray-300 rounded-xl p-8 text-center hover:border-emerald-400 transition-colors"
                phx-drop-target={@uploads.pdf.ref}
              >
                <.live_file_input upload={@uploads.pdf} class="hidden" />

                <%= for entry <- @uploads.pdf.entries do %>
                  <div class="flex items-center gap-3 p-4 bg-emerald-50 rounded-lg mb-4">
                    <.icon name="hero-document" class="w-8 h-8 text-emerald-600" />
                    <div class="flex-1">
                      <p class="font-medium"><%= entry.client_name %></p>
                      <div class="w-full bg-gray-200 rounded-full h-2 mt-2">
                        <div class="bg-emerald-600 h-2 rounded-full transition-all" style={"width: #{entry.progress}%"}></div>
                      </div>
                    </div>
                    <button type="button" phx-click="cancel_upload" phx-value-ref={entry.ref} class="text-red-500 hover:text-red-700">
                      <.icon name="hero-x-mark" class="w-5 h-5" />
                    </button>
                  </div>
                <% end %>

                <%= for err <- upload_errors(@uploads.pdf) do %>
                  <p class="text-red-500 text-sm mb-2"><%= upload_error_to_string(err) %></p>
                <% end %>

                <%= if Enum.empty?(@uploads.pdf.entries) do %>
                  <.icon name="hero-cloud-arrow-up" class="w-12 h-12 text-gray-400 mx-auto mb-3" />
                  <p class="text-gray-600 mb-2">Drag and drop your PDF here, or</p>
                  <label class="inline-flex items-center gap-2 px-4 py-2 bg-emerald-600 text-white rounded-lg font-medium hover:bg-emerald-700 cursor-pointer transition">
                    <.icon name="hero-folder-open" class="w-4 h-4" />
                    Browse Files
                    <.live_file_input upload={@uploads.pdf} class="hidden" />
                  </label>
                  <p class="text-xs text-gray-500 mt-3">PDF files up to 25MB</p>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>

        <!-- Version Notes (optional) -->
        <div class="bg-white border rounded-xl p-6">
          <h2 class="text-lg font-semibold mb-4">Version Notes (optional)</h2>
          <.styled_textarea
            name="screenplay[version_notes]"
            value={@form[:version_notes].value}
            placeholder="Describe what changed in this version..."
            rows={3}
          />
        </div>

        <!-- Submit -->
        <div class="flex justify-end gap-3">
          <.link
            navigate={back_path(@screenplay)}
            class="px-6 py-2.5 border border-gray-300 rounded-lg font-medium text-gray-700 hover:bg-gray-50 transition"
          >
            Cancel
          </.link>
          <button
            type="submit"
            disabled={@saving}
            class="px-6 py-2.5 bg-emerald-600 text-white rounded-lg font-medium hover:bg-emerald-700 disabled:opacity-50 disabled:cursor-not-allowed transition flex items-center gap-2"
          >
            <%= if @saving do %>
              <.icon name="hero-arrow-path" class="w-4 h-4 animate-spin" />
              Saving...
            <% else %>
              <.icon name="hero-check" class="w-4 h-4" />
              Save Script
            <% end %>
          </button>
        </div>
      </.form>
    </div>
    """
  end

  defp back_path(screenplay) do
    if screenplay.project_id do
      ~p"/project/#{screenplay.project_id}"
    else
      ~p"/screenplay/#{screenplay.id}"
    end
  end

  defp has_content?(screenplay) do
    (screenplay.script_content && String.trim(screenplay.script_content) != "") ||
    (screenplay.pdf_url && String.trim(screenplay.pdf_url) != "")
  end

  defp upload_error_to_string(:too_large), do: "File is too large (max 25MB)"
  defp upload_error_to_string(:not_accepted), do: "Only PDF files are accepted"
  defp upload_error_to_string(:too_many_files), do: "Only one file allowed"
  defp upload_error_to_string(_), do: "Upload error"

  defp text_upload_error_to_string(:too_large), do: "File is too large (max 5MB)"
  defp text_upload_error_to_string(:not_accepted), do: "Only .txt files are accepted"
  defp text_upload_error_to_string(:too_many_files), do: "Only one file allowed"
  defp text_upload_error_to_string(_), do: "Upload error"
end
