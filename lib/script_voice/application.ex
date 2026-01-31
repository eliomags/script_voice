defmodule ScriptVoice.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ScriptVoiceWeb.Telemetry,
      ScriptVoice.Repo,
      {DNSCluster, query: Application.get_env(:script_voice, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ScriptVoice.PubSub},
      {Finch, name: ScriptVoice.Finch},
      ScriptVoiceWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: ScriptVoice.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    ScriptVoiceWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
