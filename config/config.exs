# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :holdco, :scopes,
  user: [
    default: true,
    module: Holdco.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :id,
    schema_table: :users,
    test_data_fixture: Holdco.AccountsFixtures,
    test_setup_helper: :register_and_log_in_user
  ]

config :holdco,
  ecto_repos: [Holdco.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configure the endpoint
config :holdco, HoldcoWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: HoldcoWeb.ErrorHTML, json: HoldcoWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Holdco.PubSub,
  live_view: [signing_salt: "iyGNXsYY"]

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :holdco, Holdco.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  holdco: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  holdco: [
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

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Oban background jobs
config :holdco, Oban,
  engine: Oban.Engines.Basic,
  notifier: Oban.Notifiers.PG,
  repo: Holdco.Repo,
  queues: [default: 10, prices: 5, snapshots: 2],
  plugins: [
    {Oban.Plugins.Cron,
     crontab: [
       {"0 2 * * *", Holdco.Workers.PortfolioSnapshotWorker},
       {"0 3 * * *", Holdco.Workers.SnapshotPricesWorker},
       {"0 6 * * *", Holdco.Workers.TaxReminderWorker},
       {"0 4 * * *", Holdco.Workers.BackupWorker},
       {"0 5 * * 0", Holdco.Workers.SanctionsCheckWorker},
       {"0 7 * * 1", Holdco.Workers.EmailDigestWorker},
       {"0 6 * * *", Holdco.Workers.ScheduledReportWorker}
     ]}
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
