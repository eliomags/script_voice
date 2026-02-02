defmodule ScriptVoiceWeb.SubmitAudioComponent do
  @moduledoc """
  LiveComponent for submitting audio versions of screenplays.
  Handles file upload to R2 storage and audio metadata extraction.
  Includes character assignment for ensemble performances.
  """
  use ScriptVoiceWeb, :live_component

  alias ScriptVoice.Audio
  alias ScriptVoice.Audio.AudioProcessor
  alias ScriptVoice.Uploads

  require Logger

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:casting, %{})
     |> assign(:error, nil)
     |> assign(:submitting, false)
     |> assign(:upload_progress, 0)
     |> allow_upload(:audio,
       accept: ~w(.mp3 .wav .m4a .ogg .flac),
       max_entries: 1,
       max_file_size: 100_000_000,
       auto_upload: true,
       progress: &handle_progress/3
     )}
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

  # Handle upload progress
  defp handle_progress(:audio, entry, socket) do
    if entry.done? do
      {:noreply, assign(socket, :upload_progress, 100)}
    else
      {:noreply, assign(socket, :upload_progress, entry.progress)}
    end
  end

  @impl true
  def handle_event("update_casting", %{"character" => character, "performer" => performer}, socket) do
    casting = Map.put(socket.assigns.casting, character, performer)
    {:noreply, assign(socket, :casting, casting)}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :audio, ref)}
  end

  @impl true
  def handle_event("submit_audio", _, socket) do
    if Enum.empty?(socket.assigns.uploads.audio.entries) do
      {:noreply, assign(socket, :error, "Please upload an audio file")}
    else
      socket = assign(socket, :submitting, true)

      # Process the upload
      case process_audio_upload(socket) do
        {:ok, audio_data} ->
          # Create audio version with real data
          audio_attrs = build_audio_attrs(socket, audio_data)

          case Audio.create_audio_version(audio_attrs, socket.assigns.current_user, socket.assigns.screenplay) do
            {:ok, audio_version} ->
              send(self(), {:audio_submitted, audio_version})
              {:noreply, assign(socket, :submitting, false)}

            {:error, changeset} ->
              error = format_errors(changeset)
              {:noreply, socket |> assign(:error, error) |> assign(:submitting, false)}
          end

        {:error, reason} ->
          {:noreply, socket |> assign(:error, "Upload failed: #{reason}") |> assign(:submitting, false)}
      end
    end
  end

  # Process uploaded audio file
  defp process_audio_upload(socket) do
    user_id = socket.assigns.current_user.id

    # Consume the uploaded file
    uploaded_files =
      consume_uploaded_entries(socket, :audio, fn %{path: temp_path}, entry ->
        # Get audio metadata using FFprobe
        metadata = get_audio_metadata(temp_path)

        # Upload to R2 if configured, otherwise use local path
        upload_result =
          if Uploads.configured?() do
            Uploads.upload_audio(temp_path, entry.client_name, user_id)
          else
            # Fallback for development without R2
            {:ok, %{url: "/uploads/audio/#{entry.client_name}", key: nil, size: metadata.file_size_bytes}}
          end

        case upload_result do
          {:ok, upload_data} ->
            {:ok, Map.merge(metadata, upload_data)}

          {:error, reason} ->
            {:error, reason}
        end
      end)

    case uploaded_files do
      [{:ok, data}] -> {:ok, data}
      [{:error, reason}] -> {:error, reason}
      [data] when is_map(data) -> {:ok, data}
      [] -> {:error, "No file uploaded"}
      _ -> {:error, "Upload processing failed"}
    end
  end

  # Get audio metadata using FFprobe
  defp get_audio_metadata(file_path) do
    case AudioProcessor.get_metadata(file_path) do
      {:ok, metadata} ->
        metadata

      {:error, _reason} ->
        # Fallback if FFprobe is not available
        Logger.warning("FFprobe not available, using fallback metadata")
        %{
          duration_seconds: 0,
          file_size_bytes: get_file_size(file_path)
        }
    end
  end

  defp get_file_size(file_path) do
    case File.stat(file_path) do
      {:ok, %{size: size}} -> size
      _ -> 0
    end
  end

  # Build audio attributes from upload data and socket assigns
  defp build_audio_attrs(socket, audio_data) do
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

    %{
      "performer_type" => performer_type,
      "performers" => if(unique_performers == [], do: [socket.assigns.current_user.name], else: unique_performers),
      "casting" => casting,
      "audio_url" => audio_data.url,
      "duration_seconds" => audio_data[:duration_seconds] || 0,
      "file_size_bytes" => audio_data[:file_size_bytes] || audio_data[:size] || 0
    }
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

      <form phx-submit="submit_audio" phx-change="validate" phx-target={@myself}>
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
          <div
            class="border-2 border-dashed rounded-lg p-6 text-center cursor-pointer hover:border-emerald-400 transition"
            phx-drop-target={@uploads.audio.ref}
          >
            <.live_file_input upload={@uploads.audio} class="sr-only" />
            <label for={@uploads.audio.ref} class="cursor-pointer">
              <.icon name="hero-microphone" class="w-8 h-8 mx-auto mb-2 text-gray-400" />
              <p class="text-sm text-gray-500">
                Drop audio file here or <span class="text-emerald-600 font-medium">click to browse</span>
              </p>
              <p class="text-xs text-gray-400 mt-1">MP3, WAV, M4A, OGG, FLAC up to 100MB</p>
            </label>

            <%= for entry <- @uploads.audio.entries do %>
              <div class="mt-4 bg-gray-50 rounded-lg p-3">
                <div class="flex items-center justify-between mb-2">
                  <span class="text-sm font-medium text-gray-700 truncate flex-1">
                    <%= entry.client_name %>
                  </span>
                  <button
                    type="button"
                    phx-click="cancel_upload"
                    phx-value-ref={entry.ref}
                    phx-target={@myself}
                    class="text-gray-400 hover:text-red-500 ml-2"
                  >
                    <.icon name="hero-x-mark" class="w-4 h-4" />
                  </button>
                </div>
                <div class="w-full bg-gray-200 rounded-full h-2">
                  <div
                    class="bg-emerald-500 h-2 rounded-full transition-all duration-300"
                    style={"width: #{entry.progress}%"}
                  ></div>
                </div>
                <%= for err <- upload_errors(@uploads.audio, entry) do %>
                  <p class="text-red-500 text-xs mt-1"><%= error_to_string(err) %></p>
                <% end %>
              </div>
            <% end %>

            <%= for err <- upload_errors(@uploads.audio) do %>
              <p class="text-red-500 text-sm mt-2"><%= error_to_string(err) %></p>
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
            type="submit"
            disabled={@submitting or Enum.empty?(@uploads.audio.entries)}
            class="w-full"
          >
            <%= if @submitting do %>
              <.spinner class="w-4 h-4" />
              Uploading & Processing...
            <% else %>
              Submit Audio Version
            <% end %>
          </.button>
        </div>
      </form>
    </div>
    """
  end

  defp error_to_string(:too_large), do: "File is too large (max 100MB)"
  defp error_to_string(:too_many_files), do: "Only one file allowed"
  defp error_to_string(:not_accepted), do: "Invalid file type"
  defp error_to_string(err), do: "Error: #{inspect(err)}"
end
