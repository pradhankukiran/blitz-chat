# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :blitz_chat,
  ecto_repos: [BlitzChat.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

# Configure the endpoint
config :blitz_chat, BlitzChatWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: BlitzChatWeb.ErrorHTML, json: BlitzChatWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: BlitzChat.PubSub,
  live_view: [signing_salt: "8nY35xNH"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  blitz_chat: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  blitz_chat: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Rate limiter backend (in-memory ETS; swap for Redis backend to scale horizontally)
config :hammer,
  backend:
    {Hammer.Backend.ETS,
     [expiry_ms: 60_000 * 60, cleanup_interval_ms: 60_000 * 10]}

# Sentry logger handler (only captures when DSN is configured at runtime)
config :logger, :sentry, level: :error

config :sentry,
  dsn: nil,
  environment_name: Mix.env()

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
