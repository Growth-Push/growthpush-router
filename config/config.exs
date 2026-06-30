# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :growthpush_router, Oban,
  engine: Oban.Engines.Basic,
  notifier: Oban.Notifiers.PG,
  repo: GrowthPushRouter.Repo,
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7}
  ]

config :growthpush_router,
  namespace: GrowthPushRouter,
  ecto_repos: [GrowthPushRouter.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true],
  admin_emails: [],
  mode: "both"

# Configure the endpoint
config :growthpush_router, GrowthPushRouterWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: GrowthPushRouterWeb.ErrorHTML, json: GrowthPushRouterWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: GrowthPushRouter.PubSub,
  live_view: [signing_salt: "zp4B0ce/"]

# Configure LiveView
config :phoenix_live_view,
  # the attribute set on all root tags. Used for Phoenix.LiveView.ColocatedCSS.
  root_tag_attribute: "phx-r"

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  growthpush_router: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.3.0",
  growthpush_router: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :growthpush_router, GrowthPushRouterWeb.Gettext,
  default_locale: "pt",
  locales: ~w(en pt)

config :growthpush_router, GrowthPushRouter.Mailer, adapter: Swoosh.Adapters.Local

config :swoosh,
  api_client: Swoosh.ApiClient.Finch,
  finch_name: GrowthPushRouter.Finch

config :hammer,
  backend: {Hammer.Backend.ETS, [expiry_ms: 60_000 * 60 * 4, cleanup_interval_ms: 60_000 * 10]}

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
