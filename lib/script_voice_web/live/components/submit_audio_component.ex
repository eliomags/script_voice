defmodule ScriptVoiceWeb.SubmitAudioComponent do
  @moduledoc """
  LiveComponent for submitting audio versions of screenplays.
  Includes character assignment for ensemble performances.
  """
  use ScriptVoiceWeb, :live_component

  alias ScriptVoice.Audio

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:casting, %{})
     |> assign(:error, nil)
     |> assign(:submitting, false)
     |> allow_upload(:audio, accept: ~w(.mp3 .wav .m4a), max_entries: 1, max_file_size: 100_000_000)}
  end

  @impl true
  def update(assigns, socket) do
    # Initialize casting map with empty values for each character
    casting =
      if Map.has_key?(assigns, :screenplay) do
        assigns.screenplay.characters
        |> Enum.map(fn char -> {char.name, ""} end)
        |> Enum.into(%{})
      else
        %{}
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:casting, Map.merge(casting, socket.assigns[:casting] || %{}))}
  end

  @impl true
  def handle_event("update_casting", %{"character" => character, "performer" => performer}, socket) do
    casting = Map.put(socket.assigns.casting, character, performer)
    {:noreply, assign(socket, :casting, casting)}
  end

  @impl true
  def handle_event("submit_audio", _, socket) do
    if Enum.empty?(socket.assigns.uploads.audio.entries) do
      {:noreply, assign(socket, :error, "Please upload an audio file")}
    else
      # Determine performer type based on unique performers in casting
      unique_performers =
        socket.assigns.casting
        |> Map.values()
        |> Enum.filter(&(&1 != ""))
        |> Enum.uniq()

      performer_type =
        case length(unique_performers) do
          0 -> "solo"
          1 -> "solo"
          2 -> "duo"
          _ -> "group"
        end

      # Filter out empty casting entries
      casting =
        socket.assigns.casting
        |> Enum.filter(fn {_, v} -> v != "" end)
        |> Enum.into(%{})

      audio_attrs = %{
        "performer_type" => performer_type,
        "performers" => if(unique_performers == [], do: [socket.assigns.current_user.name], else: unique_performers),
        "casting" => casting,
        "audio_url" => "/uploads/audio/sample.mp3",  # Placeholder - would be actual upload URL
        "duration" => "00:00"  # Would be calculated from actual file
      }

      case Audio.create_audio_version(audio_attrs, socket.assigns.current_user, socket.assigns.screenplay) do
        {:ok, audio_version} ->
          send(self(), {:audio_submitted, audio_version})
          {:noreply, socket}

        {:error, changeset} ->
          error = format_errors(changeset)
          {:noreply, assign(socket, :error, error)}
      end
    end
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
      <.modal_header id="submit-audio-modal">
        Submit Audio Version
      </.modal_header>

      <%= if @error do %>
        <div class="bg-red-50 border border-red-200 rounded-lg p-3 mb-4 flex items-center gap-2 text-red-700 text-sm">
          <.icon name="hero-exclamation-circle" class="w-5 h-5" />
          <%= @error %>
        </div>
      <% end %>

      <div class="space-y-4">
        <!-- Screenplay Info -->
        <div class="bg-gray-50 p-3 rounded-lg">
          <p class="text-sm text-gray-500">Recording for:</p>
          <p class="font-medium"><%= @screenplay.title %></p>
        </div>

        <!-- Character Assignment -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">
            Assign Voices to Characters
          </label>
          <div class="space-y-2 max-h-[200px] overflow-y-auto">
            <%= for char <- @screenplay.characters do %>
              <div class="flex items-center gap-3 border rounded-lg p-2">
                <div class="flex-1 min-w-0">
                  <div class="flex items-center gap-2">
                    <span class="font-medium text-sm truncate"><%= char.name %></span>
                    <.gender_badge gender={char.gender} />
                  </div>
                  <p class="text-xs text-gray-500"><%= char.estimated_lines %> lines</p>
                </div>
                <select
                  phx-change="update_casting"
                  phx-value-character={char.name}
                  phx-target={@myself}
                  class="border rounded px-2 py-1 text-sm max-w-[140px]"
                >
                  <option value="">Select performer...</option>
                  <option value={@current_user.name}><%= @current_user.name %></option>
                  <option value="+ Add team member">+ Add team member</option>
                </select>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Audio Upload -->
        <div class="border-2 border-dashed rounded-lg p-6 text-center">
          <.live_file_input upload={@uploads.audio} class="hidden" />
          <.icon name="hero-microphone" class="w-8 h-8 mx-auto mb-2 text-gray-400" />
          <p class="text-sm text-gray-500">Drop audio file (MP3, WAV, M4A) or click to upload</p>
          <%= for entry <- @uploads.audio.entries do %>
            <p class="text-sm text-emerald-600 mt-2"><%= entry.client_name %></p>
            <progress value={entry.progress} max="100" class="w-full h-2 mt-2" />
          <% end %>
        </div>

        <!-- Reminder -->
        <div class="bg-amber-50 border border-amber-200 rounded-lg p-3">
          <p class="text-sm text-amber-800">
            <strong>Reminder:</strong> All performers must be verified.
            If you have new team members, they'll need to complete verification.
          </p>
        </div>

        <.button
          type="button"
          phx-click="submit_audio"
          phx-target={@myself}
          disabled={@submitting}
          class="w-full"
        >
          <%= if @submitting do %>
            <.spinner class="w-4 h-4" />
            Submitting...
          <% else %>
            Submit Audio Version
          <% end %>
        </.button>
      </div>
    </div>
    """
  end
end
