import Config

config :growthpush_router, Oban,
  repo: GrowthPushRouter.Repo,
  testing: :manual,
  queues: false,
  plugins: false

config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :growthpush_router, GrowthPushRouter.Repo,
  username: System.get_env("DB_USERNAME", "postgres"),
  password: System.get_env("DB_PASSWORD", "postgres"),
  hostname: System.get_env("DB_HOSTNAME", "localhost"),
  port: String.to_integer(System.get_env("DB_PORT", "5432")),
  database: "growthpush_router_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :growthpush_router, GrowthPushRouterWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "PQSPeYwp0sjkQdGjryJF+rH0BxUvTHTdWAe0WoXkI7cjoSCY/n+M8schXPRfHpe1",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

config :growthpush_router, GrowthPushRouter.Mailer, adapter: Swoosh.Adapters.Test

config :swoosh, :api_client, false

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
