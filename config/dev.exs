import Config

# Configure your database
config :script_voice, ScriptVoice.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "script_voice_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# For development, we disable any cache and enable debugging
config :script_voice, ScriptVoiceWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "K8mGTJ7qL+nXzYPvW2gRfHsNdJkVuE1xCyA9QiO3oM5bF4hUp6wS0ctBeIjDlXaZ",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:script_voice, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:script_voice, ~w(--watch)]}
  ]

# Watch static and templates for browser reloading.
config :script_voice, ScriptVoiceWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/script_voice_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

# Enable dev routes for dashboard and mailbox
config :script_voice, dev_routes: true

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  debug_heex_annotations: true,
  enable_expensive_runtime_checks: true

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false
