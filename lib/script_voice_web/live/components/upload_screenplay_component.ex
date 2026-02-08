defmodule ScriptVoiceWeb.UploadScreenplayComponent do
  @moduledoc """
  LiveComponent for creating new stories.
  Simplified to metadata-only (title, genre, logline),
  then redirects to the unified Story Editor.
  """
  use ScriptVoiceWeb, :live_component

  alias ScriptVoice.Screenplays
  alias ScriptVoice.Screenplays.Screenplay

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:title, "")
     |> assign(:genre, "Drama")
     |> assign(:logline, "")
     |> assign(:error, nil)}
  end

  @impl true
  def handle_event("validate", params, socket) do
    title = Map.get(params, "title", socket.assigns.title)
    genre = Map.get(params, "genre", socket.assigns.genre)
    logline = Map.get(params, "logline", socket.assigns.logline)

    {:noreply,
     socket
     |> assign(:error, nil)
     |> assign(:title, title)
     |> assign(:genre, genre)
     |> assign(:logline, logline)}
  end

  @impl true
  def handle_event("create_story", _, socket) do
    cond do
      socket.assigns.title == "" ->
        {:noreply, assign(socket, :error, "Please enter a title")}

      socket.assigns.logline == "" ->
        {:noreply, assign(socket, :error, "Please enter a logline")}

      true ->
        screenplay_attrs = %{
          "title" => socket.assigns.title,
          "genre" => socket.assigns.genre,
          "logline" => socket.assigns.logline
        }

        case Screenplays.create_screenplay(screenplay_attrs, socket.assigns.current_user) do
          {:ok, screenplay} ->
            # Redirect to the unified Story Editor
            send(self(), {:navigate_to_editor, screenplay})
            {:noreply, socket}

          {:error, changeset} ->
            error = format_errors(changeset)
            {:noreply, assign(socket, :error, error)}
        end
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

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal_header id="upload-screenplay-modal">
        Create New Story
      </.modal_header>

      <%= if @error do %>
        <div class="bg-red-50 border border-red-200 rounded-xl p-3 mb-4 flex items-center gap-2 text-red-700 text-sm">
          <.icon name="hero-exclamation-circle" class="w-5 h-5" />
          <%= @error %>
        </div>
      <% end %>

      <form phx-change="validate" phx-submit="create_story" phx-target={@myself} class="space-y-5">
        <div class="grid sm:grid-cols-2 gap-4">
          <.styled_input
            name="title"
            value={@title}
            label="Title"
            placeholder="Your story title"
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

        <p class="text-sm text-gray-500">
          After creating, you'll be taken to the Story Editor where you can add content
          by writing blocks manually, pasting text, or uploading a file.
        </p>

        <button type="submit" class="w-full bg-emerald-600 text-white py-3 rounded-xl font-medium hover:bg-emerald-700 transition-colors shadow-sm flex items-center justify-center gap-2">
          <.icon name="hero-pencil-square" class="w-5 h-5" />
          Create & Edit Story
        </button>
      </form>
    </div>
    """
  end
end
