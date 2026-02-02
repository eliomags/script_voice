defmodule ScriptVoice.PdfExtractor do
  @moduledoc """
  Extracts text content from PDF files.

  Uses `pdftotext` from poppler-utils for reliable extraction.
  Falls back gracefully if the tool is not available.

  ## Installation

  On macOS: `brew install poppler`
  On Ubuntu/Debian: `apt-get install poppler-utils`
  On Alpine: `apk add poppler-utils`
  """

  require Logger

  @doc """
  Extracts text from a PDF file at the given path.

  Returns {:ok, text} on success, {:error, reason} on failure.
  """
  def extract_text(pdf_path) do
    if pdftotext_available?() do
      extract_with_pdftotext(pdf_path)
    else
      Logger.warning("pdftotext not available, cannot extract PDF text")
      {:error, :pdftotext_not_available}
    end
  end

  @doc """
  Checks if pdftotext is available on the system.
  """
  def pdftotext_available? do
    case System.cmd("which", ["pdftotext"], stderr_to_stdout: true) do
      {_, 0} -> true
      _ -> false
    end
  rescue
    _ -> false
  end

  defp extract_with_pdftotext(pdf_path) do
    # Use pdftotext with layout preservation for better screenplay formatting
    # -layout preserves the original physical layout
    # -enc UTF-8 ensures proper encoding
    args = ["-layout", "-enc", "UTF-8", pdf_path, "-"]

    case System.cmd("pdftotext", args, stderr_to_stdout: true) do
      {text, 0} ->
        # Clean up the text
        cleaned_text =
          text
          |> String.trim()
          |> normalize_whitespace()

        if String.length(cleaned_text) > 0 do
          Logger.info("Successfully extracted #{String.length(cleaned_text)} characters from PDF")
          {:ok, cleaned_text}
        else
          Logger.warning("PDF extraction returned empty text")
          {:error, :empty_content}
        end

      {error, _exit_code} ->
        Logger.error("pdftotext failed: #{error}")
        {:error, {:extraction_failed, error}}
    end
  rescue
    e ->
      Logger.error("PDF extraction error: #{inspect(e)}")
      {:error, {:exception, e}}
  end

  defp normalize_whitespace(text) do
    text
    # Replace multiple blank lines with double newline
    |> String.replace(~r/\n{3,}/, "\n\n")
    # Normalize line endings
    |> String.replace(~r/\r\n?/, "\n")
  end
end
