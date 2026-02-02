defmodule ScriptVoiceWeb.CommissionSubmitAudioComponent do
  @moduledoc """
  LiveComponent for performers to submit audio for a commission.
  Handles file upload to R2 storage and audio metadata extraction.
  """
  use ScriptVoiceWeb, :live_component

  alias ScriptVoice.Audio.AudioProcessor
  alias ScriptVoice.Uploads

  require Logger

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:error, nil)
     |> assign(:notes, "")
     |> assign(:submitting, false)
     |> allow_upload(:audio,
       accept: ~w(audio/*),
       max_entries: 1,
       max_file_size: 100_000_000,
       auto_upload: true
     )}
  end

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_notes", %{"notes" => notes}, socket) do
    {:noreply, assign(socket, :notes, notes)}
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

      case process_audio_upload(socket) do
        {:ok, audio_data} ->
          # Send to parent LiveView with the audio data
          send(self(), {:submit_commission_audio, %{
            audio_url: audio_data.url,
            duration_seconds: audio_data[:duration_seconds] || 0,
            file_size_bytes: audio_data[:file_size_bytes] || audio_data[:size] || 0,
            performer_notes: socket.assigns.notes
          }})

          {:noreply,
           socket
           |> assign(:submitting, false)
           |> assign(:notes, "")}

        {:error, reason} ->
          {:noreply,
           socket
           |> assign(:error, "Upload failed: #{reason}")
           |> assign(:submitting, false)}
      end
    end
  end

  defp process_audio_upload(socket) do
    user_id = socket.assigns.current_user.id

    uploaded_files =
      consume_uploaded_entries(socket, :audio, fn %{path: temp_path}, entry ->
        metadata = get_audio_metadata(temp_path)

        upload_result =
          if Uploads.configured?() do
            Uploads.upload_audio(temp_path, entry.client_name, user_id)
          else
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

  defp get_audio_metadata(file_path) do
    case AudioProcessor.get_metadata(file_path) do
      {:ok, metadata} ->
        metadata

      {:error, _reason} ->
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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-blue-50 border border-blue-200 rounded-xl p-4 sm:p-6">
      <h2 class="font-semibold text-blue-900 mb-4 flex items-center gap-2">
        <.icon name="hero-microphone" class="w-5 h-5" />
        Submit Your Recording
      </h2>

      <%= if @error do %>
        <div class="bg-red-50 border border-red-200 rounded-lg p-3 mb-4 flex items-center gap-2 text-red-700 text-sm">
          <.icon name="hero-exclamation-circle" class="w-5 h-5" />
          <%= @error %>
        </div>
      <% end %>

      <form phx-submit="submit_audio" phx-change="validate" phx-target={@myself}>
        <div class="space-y-4">
          <!-- Audio Upload -->
          <div
            class="border-2 border-dashed border-blue-300 rounded-lg p-6 text-center cursor-pointer hover:border-blue-400 transition bg-white"
            phx-drop-target={@uploads.audio.ref}
          >
            <.live_file_input upload={@uploads.audio} class="sr-only" />
            <label for={@uploads.audio.ref} class="cursor-pointer">
              <.icon name="hero-arrow-up-tray" class="w-8 h-8 mx-auto mb-2 text-blue-400" />
              <p class="text-sm text-gray-600">
                Drop your audio file here or <span class="text-blue-600 font-medium">click to browse</span>
              </p>
              <p class="text-xs text-gray-400 mt-1">MP3, WAV, M4A up to 100MB</p>
            </label>

            <%= for entry <- @uploads.audio.entries do %>
              <div class="mt-4 bg-blue-50 rounded-lg p-3">
                <div class="flex items-center justify-between mb-2">
                  <span class="text-sm font-medium text-blue-700 truncate flex-1">
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
                <div class="w-full bg-blue-200 rounded-full h-2">
                  <div
                    class="bg-blue-600 h-2 rounded-full transition-all duration-300"
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

          <!-- Notes -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">
              Notes (optional)
            </label>
            <textarea
              name="notes"
              phx-change="update_notes"
              phx-target={@myself}
              rows="2"
              placeholder="Any notes about this recording..."
              class="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 text-sm"
            ><%= @notes %></textarea>
          </div>

          <.button
            type="submit"
            disabled={@submitting or Enum.empty?(@uploads.audio.entries)}
            class="w-full bg-blue-600 hover:bg-blue-700"
          >
            <%= if @submitting do %>
              <.spinner class="w-4 h-4" />
              Uploading & Submitting...
            <% else %>
              Submit Recording
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
