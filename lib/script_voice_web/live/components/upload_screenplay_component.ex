defmodule ScriptVoiceWeb.UploadScreenplayComponent do
  @moduledoc """
  LiveComponent for uploading screenplays.
  Uses the same styled form components as the dashboard.
  """
  use ScriptVoiceWeb, :live_component

  alias ScriptVoice.Screenplays
  alias ScriptVoice.Screenplays.{Screenplay, Character}

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:title, "")
     |> assign(:genre, "Drama")
     |> assign(:logline, "")
     |> assign(:page_count, nil)
     |> assign(:characters, [])
     |> assign(:error, nil)
     |> allow_upload(:pdf, accept: ~w(.pdf), max_entries: 1, max_file_size: 10_000_000, auto_upload: true)}
  end

  @impl true
  def handle_event("validate", params, socket) do
    title = Map.get(params, "title", socket.assigns.title)
    genre = Map.get(params, "genre", socket.assigns.genre)
    logline = Map.get(params, "logline", socket.assigns.logline)

    page_count = case Map.get(params, "page_count") do
      nil -> socket.assigns.page_count
      "" -> socket.assigns.page_count
      val ->
        case Integer.parse(val) do
          {num, _} -> num
          :error -> socket.assigns.page_count
        end
    end

    {:noreply,
     socket
     |> assign(:error, nil)
     |> assign(:title, title)
     |> assign(:genre, genre)
     |> assign(:logline, logline)
     |> assign(:page_count, page_count)}
  end

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :pdf, ref)}
  end

  @impl true
  def handle_event("add_character", _, socket) do
    new_char = %{
      name: "",
      gender: "Any",
      estimated_lines: nil,
      description: ""
    }

    {:noreply, update(socket, :characters, &(&1 ++ [new_char]))}
  end

  @impl true
  def handle_event("update_character", %{"index" => index, "field" => field} = params, socket) do
    index_int = String.to_integer(index)

    # Get value from phx-value-* attributes or dynamic input names
    value = cond do
      Map.has_key?(params, "gender") && params["gender"] != "" -> params["gender"]
      Map.has_key?(params, "value") && params["value"] != "" -> params["value"]
      Map.has_key?(params, "char_name_#{index}") -> params["char_name_#{index}"]
      Map.has_key?(params, "char_lines_#{index}") -> params["char_lines_#{index}"]
      true -> nil
    end

    # Convert estimated_lines to integer
    value = if field == "estimated_lines" do
      case value do
        nil -> nil
        "" -> nil
        val when is_binary(val) -> String.to_integer(val)
        val -> val
      end
    else
      value
    end

    characters =
      socket.assigns.characters
      |> List.update_at(index_int, fn char ->
        Map.put(char, String.to_atom(field), value)
      end)

    {:noreply, assign(socket, :characters, characters)}
  end

  @impl true
  def handle_event("remove_character", %{"index" => index}, socket) do
    index = String.to_integer(index)
    characters = List.delete_at(socket.assigns.characters, index)
    {:noreply, assign(socket, :characters, characters)}
  end

  @impl true
  def handle_event("publish", _, socket) do
    cond do
      socket.assigns.title == "" ->
        {:noreply, assign(socket, :error, "Please enter a title")}

      socket.assigns.logline == "" ->
        {:noreply, assign(socket, :error, "Please enter a logline")}

      true ->
        # Process uploaded PDF if any
        pdf_result = process_pdf_upload(socket)

        screenplay_attrs = %{
          "title" => socket.assigns.title,
          "genre" => socket.assigns.genre,
          "logline" => socket.assigns.logline,
          "page_count" => socket.assigns.page_count,
          "characters" => socket.assigns.characters
        }

        # Add PDF URL and extracted text if upload succeeded
        screenplay_attrs = case pdf_result do
          %{url: url, extracted_text: text} when not is_nil(text) and text != "" ->
            screenplay_attrs
            |> Map.put("pdf_url", url)
            |> Map.put("script_content", text)
          %{url: url} ->
            Map.put(screenplay_attrs, "pdf_url", url)
          _ ->
            screenplay_attrs
        end

        case Screenplays.create_screenplay(screenplay_attrs, socket.assigns.current_user) do
          {:ok, screenplay} ->
            send(self(), {:screenplay_created, screenplay})
            {:noreply, socket}

          {:error, changeset} ->
            error = format_errors(changeset)
            {:noreply, assign(socket, :error, error)}
        end
    end
  end

  defp process_pdf_upload(socket) do
    alias ScriptVoice.Uploads
    alias ScriptVoice.PdfExtractor

    user_id = socket.assigns.current_user.id

    uploaded_files =
      consume_uploaded_entries(socket, :pdf, fn %{path: temp_path}, entry ->
        # First extract text from PDF
        extracted_text = case PdfExtractor.extract_text(temp_path) do
          {:ok, text} -> text
          _ -> nil
        end

        # Then upload the PDF file
        upload_result = if Uploads.configured?() do
          Uploads.upload_pdf(temp_path, entry.client_name, user_id)
        else
          Uploads.upload_pdf_local(temp_path, entry.client_name, user_id)
        end

        # Return both the upload result and extracted text
        case upload_result do
          {:ok, result} -> {:ok, Map.put(result, :extracted_text, extracted_text)}
          error -> error
        end
      end)

    case uploaded_files do
      [result | _] -> result
      [] -> {:error, :no_file}
    end
  end

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {field, errors} -> "#{field}: #{Enum.join(errors, ", ")}" end)
    |> Enum.join("; ")
  end

  defp error_to_string(:too_large), do: "File is too large (max 10MB)"
  defp error_to_string(:too_many_files), do: "Only one file allowed"
  defp error_to_string(:not_accepted), do: "Only PDF files are accepted"
  defp error_to_string(err), do: "Error: #{inspect(err)}"

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal_header id="upload-screenplay-modal">
        Upload New Screenplay
      </.modal_header>

      <%= if @error do %>
        <div class="bg-red-50 border border-red-200 rounded-xl p-3 mb-4 flex items-center gap-2 text-red-700 text-sm">
          <.icon name="hero-exclamation-circle" class="w-5 h-5" />
          <%= @error %>
        </div>
      <% end %>

      <form phx-change="validate" phx-submit="publish" phx-target={@myself} class="space-y-5">
        <div class="grid sm:grid-cols-2 gap-4">
          <.styled_input
            name="title"
            value={@title}
            label="Title"
            placeholder="Your screenplay title"
            required={true}
          />
          <.styled_dropdown
            name="genre"
            value={@genre}
            options={Screenplay.genres()}
            label="Genre"
            required={true}
          />
        </div>

        <.styled_textarea
          name="logline"
          value={@logline}
          label="Logline"
          placeholder="One sentence that captures your story..."
          rows={2}
          required={true}
        />

        <div class="grid sm:grid-cols-2 gap-4">
          <.styled_number
            name="page_count"
            value={@page_count}
            label="Page Count"
            placeholder="Number of pages"
            min={1}
            max={500}
          />

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1.5">Script PDF</label>
            <div
              class="border-2 border-dashed border-gray-200 rounded-xl p-4 text-center cursor-pointer hover:border-emerald-400 hover:bg-emerald-50/50 transition-colors"
              phx-drop-target={@uploads.pdf.ref}
            >
              <.live_file_input upload={@uploads.pdf} class="sr-only" />
              <label for={@uploads.pdf.ref} class="cursor-pointer block">
                <%= if Enum.empty?(@uploads.pdf.entries) do %>
                  <.icon name="hero-document-text" class="w-8 h-8 text-gray-300 mx-auto mb-2" />
                  <p class="text-sm text-gray-500">Drop PDF or <span class="text-emerald-600 font-medium">browse</span></p>
                <% else %>
                  <%= for entry <- @uploads.pdf.entries do %>
                    <div class="flex items-center justify-center gap-2">
                      <.icon name="hero-check-circle" class="w-5 h-5 text-emerald-500" />
                      <p class="text-sm text-emerald-600 font-medium truncate"><%= entry.client_name %></p>
                    </div>
                  <% end %>
                <% end %>
              </label>
              <%= for err <- upload_errors(@uploads.pdf) do %>
                <p class="text-red-500 text-sm mt-2"><%= error_to_string(err) %></p>
              <% end %>
            </div>
          </div>
        </div>

        <!-- Characters Section -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-3">Characters (optional)</label>
          <div class="space-y-3">
            <%= for {char, index} <- Enum.with_index(@characters) do %>
              <div class="flex flex-col sm:flex-row sm:items-center gap-3 p-3 bg-gray-50 rounded-xl">
                <div class="flex-1">
                  <input
                    type="text"
                    name={"char_name_#{index}"}
                    value={char.name}
                    phx-blur="update_character"
                    phx-value-index={index}
                    phx-value-field="name"
                    phx-target={@myself}
                    placeholder="Character name"
                    class="w-full px-3 py-2 bg-white border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500"
                  />
                </div>
                <div class="flex items-center gap-2">
                  <div class="flex rounded-lg border border-gray-200 overflow-hidden">
                    <%= for gender <- Character.genders() do %>
                      <button
                        type="button"
                        phx-click="update_character"
                        phx-value-index={index}
                        phx-value-field="gender"
                        phx-value-gender={gender}
                        phx-target={@myself}
                        class={[
                          "px-3 py-2 text-sm font-medium transition-colors",
                          gender == char.gender && "bg-emerald-500 text-white",
                          gender != char.gender && "bg-white text-gray-600 hover:bg-gray-50"
                        ]}
                      >
                        <%= gender %>
                      </button>
                    <% end %>
                  </div>
                  <input
                    type="number"
                    name={"char_lines_#{index}"}
                    value={char.estimated_lines}
                    phx-blur="update_character"
                    phx-value-index={index}
                    phx-value-field="estimated_lines"
                    phx-target={@myself}
                    placeholder="Lines"
                    min="0"
                    class="w-20 px-3 py-2 bg-white border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 [appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none"
                  />
                  <button
                    type="button"
                    phx-click="remove_character"
                    phx-value-index={index}
                    phx-target={@myself}
                    class="p-2 text-gray-400 hover:text-red-500 hover:bg-red-50 rounded-lg transition-colors"
                  >
                    <.icon name="hero-x-mark" class="w-4 h-4" />
                  </button>
                </div>
              </div>
            <% end %>

            <button
              type="button"
              phx-click="add_character"
              phx-target={@myself}
              class="w-full border-2 border-dashed border-gray-200 rounded-xl py-3 text-gray-500 hover:border-emerald-400 hover:text-emerald-600 hover:bg-emerald-50/50 text-sm font-medium transition-colors"
            >
              + Add Character
            </button>
          </div>
        </div>

        <button type="submit" class="w-full bg-emerald-600 text-white py-3 rounded-xl font-medium hover:bg-emerald-700 transition-colors shadow-sm">
          Publish Screenplay
        </button>
      </form>
    </div>
    """
  end
end
