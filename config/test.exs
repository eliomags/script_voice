import Config

# Configure your database
config :script_voice, ScriptVoice.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "script_voice_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test
config :script_voice, ScriptVoiceWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test_secret_key_base_that_is_at_least_64_bytes_long_for_security",
  server: false

# In test we don't send emails
config :script_voice, ScriptVoice.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
