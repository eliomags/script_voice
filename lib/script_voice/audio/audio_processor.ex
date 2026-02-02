defmodule ScriptVoice.Audio.AudioProcessor do
  @moduledoc """
  Processes audio files to extract metadata like duration and file size.

  Uses FFprobe (part of FFmpeg) to analyze audio files. FFprobe must be
  installed on the system for this to work.

  ## Installation

  On macOS: `brew install ffmpeg`
  On Ubuntu: `sudo apt install ffmpeg`
  On Alpine: `apk add ffmpeg`

  ## Usage

      # Get audio duration in seconds
      {:ok, duration_seconds} = AudioProcessor.get_duration("/path/to/audio.mp3")

      # Get full metadata
      {:ok, metadata} = AudioProcessor.get_metadata("/path/to/audio.mp3")
  """

  require Logger

  @doc """
  Extracts the duration of an audio file in seconds.

  Returns {:ok, seconds} on success, {:error, reason} on failure.

  ## Examples

      iex> AudioProcessor.get_duration("/path/to/audio.mp3")
      {:ok, 184}  # 3 minutes 4 seconds

      iex> AudioProcessor.get_duration("/nonexistent.mp3")
      {:error, :file_not_found}
  """
  def get_duration(file_path) do
    case get_metadata(file_path) do
      {:ok, metadata} -> {:ok, metadata.duration_seconds}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Extracts metadata from an audio file.

  Returns {:ok, metadata} on success where metadata contains:
  - duration_seconds: integer duration in seconds
  - duration_raw: float duration from FFprobe
  - format: audio format (e.g., "mp3", "wav")
  - bit_rate: bit rate in bits/s
  - sample_rate: sample rate in Hz
  - channels: number of audio channels
  - file_size_bytes: file size in bytes

  Returns {:error, reason} on failure.
  """
  def get_metadata(file_path) do
    unless File.exists?(file_path) do
      {:error, :file_not_found}
    else
      case run_ffprobe(file_path) do
        {:ok, output} -> parse_ffprobe_output(output, file_path)
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Checks if FFprobe is available on the system.
  """
  def ffprobe_available? do
    case System.find_executable("ffprobe") do
      nil -> false
      _path -> true
    end
  end

  # ===========================================================================
  # Private Functions
  # ===========================================================================

  defp run_ffprobe(file_path) do
    args = [
      "-v", "quiet",
      "-print_format", "json",
      "-show_format",
      "-show_streams",
      file_path
    ]

    case System.cmd("ffprobe", args, stderr_to_stdout: true) do
      {output, 0} ->
        {:ok, output}

      {error_output, _code} ->
        Logger.error("FFprobe error: #{error_output}")
        {:error, :ffprobe_failed}
    end
  rescue
    e in ErlangError ->
      Logger.error("FFprobe not found or execution error: #{inspect(e)}")
      {:error, :ffprobe_not_available}
  end

  defp parse_ffprobe_output(json_output, file_path) do
    case Jason.decode(json_output) do
      {:ok, data} ->
        format = data["format"] || %{}

        # Get duration from format
        duration_raw =
          case format["duration"] do
            nil -> 0.0
            val when is_binary(val) -> String.to_float(val)
            val when is_float(val) -> val
            val when is_integer(val) -> val / 1.0
          end

        # Get file size
        file_size =
          case File.stat(file_path) do
            {:ok, %{size: size}} -> size
            _ -> format["size"] |> parse_int_or_nil() || 0
          end

        # Get audio stream info
        audio_stream =
          (data["streams"] || [])
          |> Enum.find(fn s -> s["codec_type"] == "audio" end)
          || %{}

        metadata = %{
          duration_seconds: round(duration_raw),
          duration_raw: duration_raw,
          format: format["format_name"],
          bit_rate: parse_int_or_nil(format["bit_rate"]),
          sample_rate: parse_int_or_nil(audio_stream["sample_rate"]),
          channels: audio_stream["channels"],
          file_size_bytes: file_size
        }

        {:ok, metadata}

      {:error, _} ->
        Logger.error("Failed to parse FFprobe JSON output")
        {:error, :parse_failed}
    end
  end

  defp parse_int_or_nil(nil), do: nil
  defp parse_int_or_nil(val) when is_binary(val) do
    case Integer.parse(val) do
      {int, _} -> int
      :error -> nil
    end
  end
  defp parse_int_or_nil(val) when is_integer(val), do: val
  defp parse_int_or_nil(_), do: nil
end
