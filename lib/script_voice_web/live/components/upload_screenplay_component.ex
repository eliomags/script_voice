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
     |> assign(:title, "")
     |> assign(:genre, "Drama")
     |> assign(:logline, "")
     |> assign(:characters, [])
     |> assign(:error, nil)
     |> allow_upload(:pdf, accept: ~w(.pdf), max_entries: 1, max_file_size: 10_000_000, auto_upload: true)}
  end

  @impl true
  def handle_event("validate", params, socket) do
    socket =
      socket
      |> assign(:error, nil)
      |> then(fn s -> if params["title"], do: assign(s, :title, params["title"]), else: s end)
      |> then(fn s -> if params["genre"], do: assign(s, :genre, params["genre"]), else: s end)
      |> then(fn s -> if params["logline"], do: assign(s, :logline, params["logline"]), else: s end)

    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :pdf, ref)}
  end

  @impl true
  def handle_event("upload_and_extract", _, socket) do
    cond do
      socket.assigns.title == "" ->
        {:noreply, assign(socket, :error, "Please enter a title")}

      socket.assigns.logline == "" ->
        {:noreply, assign(socket, :error, "Please enter a logline")}

      true ->
        # Go directly to step 2 for manual character entry
        # AI extraction can be added later as an optional feature
        {:noreply, assign(socket, :step, 2)}
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
        <%= if @step == 1, do: "Upload Screenplay", else: "Add Characters" %>
      </.modal_header>

      <%= if @error do %>
        <div class="bg-red-50 border border-red-200 rounded-lg p-3 mb-4 flex items-center gap-2 text-red-700 text-sm">
          <.icon name="hero-exclamation-circle" class="w-5 h-5" />
          <%= @error %>
        </div>
      <% end %>

      <%= if @step == 1 do %>
        <!-- Step 1: Upload & Metadata -->
        <form phx-change="validate" phx-submit="upload_and_extract" phx-target={@myself} class="space-y-4">
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

          <div
            class="border-2 border-dashed rounded-lg p-6 sm:p-8 text-center cursor-pointer hover:border-emerald-400 transition"
            phx-drop-target={@uploads.pdf.ref}
          >
            <.live_file_input upload={@uploads.pdf} class="sr-only" />
            <label for={@uploads.pdf.ref} class="cursor-pointer block">
              <.icon name="hero-document-text" class="w-8 h-8 mx-auto mb-2 text-gray-400" />
              <p class="text-sm text-gray-500">Drop PDF here or <span class="text-emerald-600 font-medium">click to upload</span></p>
            </label>
            <%= for entry <- @uploads.pdf.entries do %>
              <div class="mt-3 bg-emerald-50 rounded-lg p-2">
                <p class="text-sm text-emerald-600 font-medium"><%= entry.client_name %></p>
                <div class="w-full bg-emerald-200 rounded-full h-1.5 mt-1">
                  <div class="bg-emerald-600 h-1.5 rounded-full transition-all" style={"width: #{entry.progress}%"}></div>
                </div>
              </div>
            <% end %>
            <%= for err <- upload_errors(@uploads.pdf) do %>
              <p class="text-red-500 text-sm mt-2"><%= error_to_string(err) %></p>
            <% end %>
          </div>

          <div class="bg-gray-50 border border-gray-200 rounded-lg p-3">
            <div class="flex items-center gap-2 text-gray-700">
              <.icon name="hero-users" class="w-4 h-4" />
              <span class="text-sm font-medium">Add Characters</span>
            </div>
            <p class="text-xs text-gray-500 mt-1">
              You'll add your screenplay's characters in the next step. Voice artists will see this when browsing.
            </p>
          </div>

          <.button
            type="submit"
            class="w-full"
          >
            Continue to Add Characters
          </.button>
        </form>
      <% else %>
        <!-- Step 2: Add Characters -->
        <div class="space-y-4">
          <p class="text-sm text-gray-600">
            Add your screenplay's characters below. Voice artists will see this when choosing scripts to perform.
          </p>

          <div class="space-y-3 max-h-[300px] overflow-y-auto">
            <%= for {char, index} <- Enum.with_index(@characters) do %>
              <div class="border rounded-lg p-3">
                <div class="flex items-center justify-between mb-2">
                  <input
                    type="text"
                    name="value"
                    value={char.name}
                    phx-blur="update_character"
                    phx-debounce="blur"
                    phx-value-index={index}
                    phx-value-field="name"
                    phx-target={@myself}
                    class="font-medium bg-transparent border-b border-transparent hover:border-gray-300 focus:border-emerald-500 focus:outline-none w-32"
                  />
                  <div class="flex items-center gap-2">
                    <select
                      name="value"
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
                    name="value"
                    value={char.description || ""}
                    phx-blur="update_character"
                    phx-debounce="blur"
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
