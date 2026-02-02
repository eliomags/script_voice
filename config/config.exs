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

# Cloudflare R2 Storage Configuration (S3-compatible)
# R2 uses the same API as S3 but with Cloudflare endpoints
# Set these environment variables:
#   R2_ACCOUNT_ID - Your Cloudflare account ID
#   R2_ACCESS_KEY_ID - R2 API token access key
#   R2_SECRET_ACCESS_KEY - R2 API token secret key
#   R2_BUCKET - Your R2 bucket name
#   R2_PUBLIC_URL - Public URL for the bucket (custom domain or r2.dev)
config :ex_aws,
  access_key_id: [{:system, "R2_ACCESS_KEY_ID"}, :instance_role],
  secret_access_key: [{:system, "R2_SECRET_ACCESS_KEY"}, :instance_role],
  region: "auto",
  json_codec: Jason

config :ex_aws, :s3,
  scheme: "https://",
  host: {:system, "R2_ENDPOINT_HOST"},
  region: "auto"

# ScriptVoice upload settings
config :script_voice, :uploads,
  bucket: System.get_env("R2_BUCKET", "scriptvoice-uploads"),
  public_url: System.get_env("R2_PUBLIC_URL", "https://uploads.scriptvoice.com"),
  max_file_size: 100_000_000,  # 100 MB
  allowed_audio_types: ~w(.mp3 .wav .m4a .ogg .flac),
  allowed_pdf_types: ~w(.pdf)

# Import environment specific config
import_config "#{config_env()}.exs"
