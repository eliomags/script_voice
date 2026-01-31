defmodule ScriptVoice.Repo do
  use Ecto.Repo,
    otp_app: :script_voice,
    adapter: Ecto.Adapters.Postgres
end
