import Config

# Load .env file in dev and test environments
if config_env() in [:dev, :test] do
  Dotenvy.source([".env", ".env.#{config_env()}", ".env.local"])
end

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# temporary application starts.

if System.get_env("PHX_SERVER") do
  config :script_voice, ScriptVoiceWeb.Endpoint, server: true
end

# Stripe configuration (all environments)
if stripe_key = System.get_env("STRIPE_SECRET_KEY") do
  config :stripity_stripe, api_key: stripe_key
end

if stripe_webhook_secret = System.get_env("STRIPE_CONNECT_WEBHOOK_SECRET") do
  config :stripity_stripe, connect_webhook_signing_secret: stripe_webhook_secret
end

config :script_voice, :stripe,
  publishable_key: System.get_env("STRIPE_PUBLISHABLE_KEY"),
  platform_fee_percent: 10

# Cloudflare R2 configuration (all environments)
# R2 is S3-compatible, so we use ex_aws_s3
if r2_account_id = System.get_env("R2_ACCOUNT_ID") do
  r2_endpoint = "#{r2_account_id}.r2.cloudflarestorage.com"

  config :ex_aws,
    access_key_id: System.get_env("R2_ACCESS_KEY_ID"),
    secret_access_key: System.get_env("R2_SECRET_ACCESS_KEY"),
    region: "auto"

  config :ex_aws, :s3,
    scheme: "https://",
    host: r2_endpoint,
    region: "auto"

  config :script_voice, :uploads,
    bucket: System.get_env("R2_BUCKET", "scriptvoice-uploads"),
    public_url: System.get_env("R2_PUBLIC_URL"),
    endpoint: r2_endpoint
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :script_voice, ScriptVoice.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :script_voice, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :script_voice, ScriptVoiceWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base
end
