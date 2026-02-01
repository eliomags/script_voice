# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
import Config

config :script_voice,
  ecto_repos: [ScriptVoice.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :script_voice, ScriptVoiceWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: ScriptVoiceWeb.ErrorHTML, json: ScriptVoiceWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: ScriptVoice.PubSub,
  live_view: [signing_salt: "scriptvoice_salt"]

# Configures the mailer
config :script_voice, ScriptVoice.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild
config :esbuild,
  version: "0.17.11",
  script_voice: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind
config :tailwind,
  version: "3.4.0",
  script_voice: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Stripe configuration
# Set these in runtime.exs or environment variables
config :stripity_stripe,
  api_key: System.get_env("STRIPE_SECRET_KEY"),
  connect_webhook_signing_secret: System.get_env("STRIPE_CONNECT_WEBHOOK_SECRET")

# ScriptVoice Stripe settings
config :script_voice, :stripe,
  platform_fee_percent: 10,
  publishable_key: System.get_env("STRIPE_PUBLISHABLE_KEY")

# Import environment specific config
import_config "#{config_env()}.exs"
