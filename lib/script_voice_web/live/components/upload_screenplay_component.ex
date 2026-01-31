defmodule ScriptVoiceWeb.UploadScreenplayComponent do
  @moduledoc """
  LiveComponent for uploading screenplays with AI character extraction.
  Two-step process: 1) Upload & metadata, 2) Review extracted characters.
  """
  use ScriptVoiceWeb, :live_component

  alias ScriptVoice.Screenplays
  alias ScriptVoice.Screenplays.{Screenplay, Character}

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:step, 1)
     |> assign(:extracting, false)
     |> assign(:title, "")
     |> assign(:genre, "Drama")
     |> assign(:logline, "")
     |> assign(:characters, [])
     |> assign(:error, nil)
     |> allow_upload(:pdf, accept: ~w(.pdf), max_entries: 1, max_file_size: 10_000_000)}
  end

  @impl true
  def handle_event("validate", %{"title" => title, "genre" => genre, "logline" => logline}, socket) do
    {:noreply,
     socket
     |> assign(:title, title)
     |> assign(:genre, genre)
     |> assign(:logline, logline)
     |> assign(:error, nil)}
  end

  @impl true
  def handle_event("upload_and_extract", _, socket) do
    if socket.assigns.title == "" do
      {:noreply, assign(socket, :error, "Please enter a title")}
    else
      # Start extraction (simulated)
      send(self(), {:extract_characters, socket.assigns.id})
      {:noreply, assign(socket, :extracting, true)}
    end
  end

  @impl true
  def handle_event("update_character", %{"index" => index, "field" => field, "value" => value}, socket) do
    index = String.to_integer(index)

    characters =
      socket.assigns.characters
      |> List.update_at(index, fn char ->
        Map.put(char, String.to_atom(field), value)
      end)

    {:noreply, assign(socket, :characters, characters)}
  end

  @impl true
  def handle_event("add_character", _, socket) do
    new_char = %{
      name: "NEW CHARACTER",
      gender: "Unknown",
      estimated_lines: 0,
      description: ""
    }

    {:noreply, update(socket, :characters, &(&1 ++ [new_char]))}
  end

  @impl true
  def handle_event("remove_character", %{"index" => index}, socket) do
    index = String.to_integer(index)
    characters = List.delete_at(socket.assigns.characters, index)
    {:noreply, assign(socket, :characters, characters)}
  end

  @impl true
  def handle_event("publish", _, socket) do
    screenplay_attrs = %{
      "title" => socket.assigns.title,
      "genre" => socket.assigns.genre,
      "logline" => socket.assigns.logline,
      "characters" => socket.assigns.characters
    }

    case Screenplays.create_screenplay(screenplay_attrs, socket.assigns.current_user) do
      {:ok, screenplay} ->
        send(self(), {:screenplay_created, screenplay})
        {:noreply, socket}

      {:error, changeset} ->
        error = format_errors(changeset)
        {:noreply, assign(socket, :error, error)}
    end
  end

  @impl true
  def handle_event("back_to_step_1", _, socket) do
    {:noreply, assign(socket, :step, 1)}
  end

  # Handle the simulated character extraction
  @impl true
  def update(%{extract_complete: true, characters: characters}, socket) do
    {:ok,
     socket
     |> assign(:extracting, false)
     |> assign(:characters, characters)
     |> assign(:step, 2)}
  end

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

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal_header id="upload-screenplay-modal">
        <%= if @step == 1, do: "Upload Screenplay", else: "Review Characters" %>
      </.modal_header>

      <%= if @error do %>
        <div class="bg-red-50 border border-red-200 rounded-lg p-3 mb-4 flex items-center gap-2 text-red-700 text-sm">
          <.icon name="hero-exclamation-circle" class="w-5 h-5" />
          <%= @error %>
        </div>
      <% end %>

      <%= if @step == 1 do %>
        <!-- Step 1: Upload & Metadata -->
        <form phx-change="validate" phx-target={@myself} class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Title *</label>
            <input
              type="text"
              name="title"
              value={@title}
              class="w-full border rounded-lg px-3 py-2.5 focus:border-emerald-500 focus:ring-emerald-500"
              placeholder="Your screenplay title"
            />
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Genre *</label>
            <select
              name="genre"
              class="w-full border rounded-lg px-3 py-2.5 focus:border-emerald-500 focus:ring-emerald-500"
            >
              <%= for genre <- Screenplay.genres() do %>
                <option value={genre} selected={genre == @genre}><%= genre %></option>
              <% end %>
            </select>
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Logline *</label>
            <textarea
              name="logline"
              class="w-full border rounded-lg px-3 py-2.5 min-h-[80px] focus:border-emerald-500 focus:ring-emerald-500"
              placeholder="One sentence that captures your story..."
            ><%= @logline %></textarea>
          </div>

          <div class="border-2 border-dashed rounded-lg p-6 sm:p-8 text-center">
            <.live_file_input upload={@uploads.pdf} class="hidden" />
            <.icon name="hero-document-text" class="w-8 h-8 mx-auto mb-2 text-gray-400" />
            <p class="text-sm text-gray-500">Drop PDF here or click to upload</p>
            <%= for entry <- @uploads.pdf.entries do %>
              <p class="text-sm text-emerald-600 mt-2"><%= entry.client_name %></p>
            <% end %>
          </div>

          <div class="bg-purple-50 border border-purple-200 rounded-lg p-3">
            <div class="flex items-center gap-2 text-purple-800">
              <.icon name="hero-sparkles" class="w-4 h-4" />
              <span class="text-sm font-medium">AI Character Extraction</span>
            </div>
            <p class="text-xs text-purple-600 mt-1">
              We'll automatically detect characters, gender, and line counts from your script
            </p>
          </div>

          <.button
            type="button"
            phx-click="upload_and_extract"
            phx-target={@myself}
            disabled={@extracting}
            class="w-full"
          >
            <%= if @extracting do %>
              <.spinner class="w-4 h-4" />
              Extracting Characters...
            <% else %>
              Upload & Extract Characters
            <% end %>
          </.button>
        </form>
      <% else %>
        <!-- Step 2: Review Characters -->
        <div class="space-y-4">
          <p class="text-sm text-gray-600">
            Review the characters we detected. Voice artists will see this when choosing scripts to perform.
          </p>

          <div class="space-y-3 max-h-[300px] overflow-y-auto">
            <%= for {char, index} <- Enum.with_index(@characters) do %>
              <div class="border rounded-lg p-3">
                <div class="flex items-center justify-between mb-2">
                  <input
                    type="text"
                    value={char.name}
                    phx-blur="update_character"
                    phx-value-index={index}
                    phx-value-field="name"
                    phx-target={@myself}
                    class="font-medium bg-transparent border-b border-transparent hover:border-gray-300 focus:border-emerald-500 focus:outline-none w-32"
                  />
                  <div class="flex items-center gap-2">
                    <select
                      phx-change="update_character"
                      phx-value-index={index}
                      phx-value-field="gender"
                      phx-target={@myself}
                      class="text-sm border rounded px-2 py-1"
                    >
                      <%= for gender <- Character.genders() do %>
                        <option value={gender} selected={gender == char.gender}><%= gender %></option>
                      <% end %>
                    </select>
                    <button
                      type="button"
                      phx-click="remove_character"
                      phx-value-index={index}
                      phx-target={@myself}
                      class="text-gray-400 hover:text-red-500 p-1"
                    >
                      <.icon name="hero-x-mark" class="w-4 h-4" />
                    </button>
                  </div>
                </div>
                <div class="flex items-center justify-between text-sm text-gray-500">
                  <input
                    type="text"
                    value={char.description || ""}
                    phx-blur="update_character"
                    phx-value-index={index}
                    phx-value-field="description"
                    phx-target={@myself}
                    placeholder="Character description..."
                    class="flex-1 bg-transparent border-b border-transparent hover:border-gray-300 focus:border-emerald-500 focus:outline-none text-sm"
                  />
                  <span class="ml-2 whitespace-nowrap">~<%= char.estimated_lines %> lines</span>
                </div>
              </div>
            <% end %>

            <button
              type="button"
              phx-click="add_character"
              phx-target={@myself}
              class="w-full border-2 border-dashed rounded-lg py-3 text-gray-500 hover:border-gray-400 hover:text-gray-600 text-sm"
            >
              + Add Character Manually
            </button>
          </div>

          <div class="flex gap-3">
            <.button
              type="button"
              variant="secondary"
              phx-click="back_to_step_1"
              phx-target={@myself}
              class="flex-1"
            >
              Back
            </.button>
            <.button
              type="button"
              phx-click="publish"
              phx-target={@myself}
              class="flex-1"
            >
              Publish Screenplay
            </.button>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
