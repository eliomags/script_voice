defmodule ScriptVoice.Uploads do
  @moduledoc """
  Handles file uploads to Cloudflare R2 (S3-compatible storage).

  ## Configuration

  Set the following environment variables:
  - R2_ACCOUNT_ID: Your Cloudflare account ID
  - R2_ACCESS_KEY_ID: R2 API token access key
  - R2_SECRET_ACCESS_KEY: R2 API token secret key
  - R2_BUCKET: Your R2 bucket name
  - R2_PUBLIC_URL: Public URL for the bucket (custom domain or r2.dev)

  ## Usage

      # Upload an audio file
      {:ok, url} = Uploads.upload_audio(temp_path, "my-audio.mp3", user_id)

      # Upload a PDF
      {:ok, url} = Uploads.upload_pdf(temp_path, "script.pdf", user_id)

      # Delete a file
      :ok = Uploads.delete("audio/abc123/my-audio.mp3")
  """

  require Logger

  @doc """
  Uploads an audio file to R2 storage.

  Returns {:ok, public_url} on success, {:error, reason} on failure.
  """
  def upload_audio(source_path, filename, user_id) do
    key = generate_key("audio", user_id, filename)
    content_type = get_content_type(filename)

    upload_file(source_path, key, content_type)
  end

  @doc """
  Uploads a PDF file to R2 storage.

  Returns {:ok, public_url} on success, {:error, reason} on failure.
  """
  def upload_pdf(source_path, filename, user_id) do
    key = generate_key("pdf", user_id, filename)

    upload_file(source_path, key, "application/pdf")
  end

  @doc """
  Uploads a PDF file locally when R2 is not configured.
  Saves to priv/static/uploads directory.
  """
  def upload_pdf_local(source_path, filename, user_id) do
    key = generate_key("pdf", user_id, filename)
    upload_file_local(source_path, key)
  end

  @doc """
  Uploads an audio file locally when R2 is not configured.
  """
  def upload_audio_local(source_path, filename, user_id) do
    key = generate_key("audio", user_id, filename)
    upload_file_local(source_path, key)
  end

  defp upload_file_local(source_path, key) do
    # Save to priv/static/uploads
    uploads_dir = Path.join([:code.priv_dir(:script_voice), "static", "uploads"])
    dest_dir = Path.join(uploads_dir, Path.dirname(key))
    dest_path = Path.join(uploads_dir, key)

    # Create directory if needed
    File.mkdir_p!(dest_dir)

    case File.cp(source_path, dest_path) do
      :ok ->
        file_size = File.stat!(dest_path).size
        url = "/uploads/#{key}"
        Logger.info("Uploaded file locally: #{key} (#{file_size} bytes)")
        {:ok, %{url: url, key: key, size: file_size}}

      {:error, reason} ->
        Logger.error("Failed to save file locally: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Deletes a file from R2 storage.

  Takes the full key (path) of the file.
  Returns :ok on success, {:error, reason} on failure.
  """
  def delete(key) do
    bucket = get_bucket()

    case ExAws.S3.delete_object(bucket, key) |> ExAws.request() do
      {:ok, _} ->
        Logger.info("Deleted file from R2: #{key}")
        :ok

      {:error, reason} ->
        Logger.error("Failed to delete file from R2: #{key}, reason: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Returns the public URL for a given key.
  """
  def public_url(key) do
    base_url = get_public_url()
    "#{base_url}/#{key}"
  end

  @doc """
  Checks if uploads are configured (R2 credentials are set).
  Verifies that bucket, public_url, and actual R2 credentials exist.
  """
  def configured? do
    config = Application.get_env(:script_voice, :uploads, [])
    bucket = config[:bucket]
    public_url = config[:public_url]

    # Also check that the actual R2 environment variables are set
    access_key = System.get_env("R2_ACCESS_KEY_ID")
    secret_key = System.get_env("R2_SECRET_ACCESS_KEY")

    bucket != nil and
      public_url != nil and
      access_key != nil and access_key != "" and
      secret_key != nil and secret_key != ""
  end

  # ===========================================================================
  # Private Functions
  # ===========================================================================

  defp upload_file(source_path, key, content_type) do
    bucket = get_bucket()

    case File.read(source_path) do
      {:ok, file_contents} ->
        file_size = byte_size(file_contents)

        opts = [
          content_type: content_type,
          acl: :public_read
        ]

        case ExAws.S3.put_object(bucket, key, file_contents, opts) |> ExAws.request() do
          {:ok, _} ->
            url = public_url(key)
            Logger.info("Uploaded file to R2: #{key} (#{file_size} bytes)")
            {:ok, %{url: url, key: key, size: file_size}}

          {:error, reason} ->
            Logger.error("Failed to upload to R2: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, reason} ->
        Logger.error("Failed to read source file: #{source_path}, reason: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp generate_key(type, user_id, filename) do
    # Generate a unique key with timestamp and UUID to prevent collisions
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    uuid = UUID.uuid4() |> String.slice(0, 8)
    sanitized_filename = sanitize_filename(filename)

    "#{type}/#{user_id}/#{timestamp}-#{uuid}-#{sanitized_filename}"
  end

  defp sanitize_filename(filename) do
    filename
    |> String.downcase()
    |> String.replace(~r/[^\w\.\-]/, "_")
    |> String.replace(~r/_+/, "_")
  end

  defp get_content_type(filename) do
    case Path.extname(filename) |> String.downcase() do
      ".mp3" -> "audio/mpeg"
      ".wav" -> "audio/wav"
      ".m4a" -> "audio/mp4"
      ".ogg" -> "audio/ogg"
      ".flac" -> "audio/flac"
      ".pdf" -> "application/pdf"
      _ -> "application/octet-stream"
    end
  end

  defp get_bucket do
    Application.get_env(:script_voice, :uploads, [])[:bucket] || "scriptvoice-uploads"
  end

  defp get_public_url do
    Application.get_env(:script_voice, :uploads, [])[:public_url] || ""
  end
end
