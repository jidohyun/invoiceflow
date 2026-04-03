# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

config :auto_my_invoice,
  ecto_repos: [AutoMyInvoice.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configure the endpoint
config :auto_my_invoice, AutoMyInvoiceWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: AutoMyInvoiceWeb.ErrorHTML, json: AutoMyInvoiceWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: AutoMyInvoice.PubSub,
  live_view: [signing_salt: "SLKLpXoW"]

# Configure the mailer
config :auto_my_invoice, AutoMyInvoice.Mailer, adapter: Swoosh.Adapters.Local

# Configure Oban
config :auto_my_invoice, Oban,
  repo: AutoMyInvoice.Repo,
  queues: [
    default: 10,
    reminders: 5,
    extraction: 3,
    pdf: 3,
    email_tracking: 5
  ],
  plugins: [
    Oban.Plugins.Pruner,
    {Oban.Plugins.Cron,
     crontab: [
       {"0 * * * *", AutoMyInvoice.Workers.ReminderScheduler},
       {"0 9 * * *", AutoMyInvoice.Workers.OverdueScanner}
     ]}
  ]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  auto_my_invoice: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  auto_my_invoice: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Sentry
config :sentry,
  dsn: System.get_env("SENTRY_DSN"),
  environment_name: config_env(),
  enable_source_code_context: true,
  root_source_code_paths: [File.cwd!()],
  client: Sentry.FinchClient

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Paddle Billing (for payments)
config :auto_my_invoice, :paddle_webhook_secret, System.get_env("PADDLE_WEBHOOK_SECRET")
config :auto_my_invoice, :paddle_api_key, System.get_env("PADDLE_API_KEY")
config :auto_my_invoice, :paddle_price_id_starter, System.get_env("PADDLE_PRICE_ID_STARTER")
config :auto_my_invoice, :paddle_price_id_pro, System.get_env("PADDLE_PRICE_ID_PRO")

# OpenAI API (for OCR extraction)
config :auto_my_invoice, :openai_api_key, System.get_env("OPENAI_API_KEY")

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
