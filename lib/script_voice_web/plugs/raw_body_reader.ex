defmodule ScriptVoiceWeb.Plugs.RawBodyReader do
  @moduledoc """
  Plug that reads and caches the raw request body for webhook signature verification.
  Must be used before the JSON parser for Stripe webhooks.
  """

  @behaviour Plug

  def init(opts), do: opts

  def call(conn, _opts) do
    case Plug.Conn.read_body(conn) do
      {:ok, body, conn} ->
        Plug.Conn.assign(conn, :raw_body, body)
        |> Plug.Conn.put_private(:raw_body, body)

      {:more, _partial_body, conn} ->
        # Handle chunked/large bodies if needed
        conn

      {:error, _reason} ->
        conn
    end
  end
end
