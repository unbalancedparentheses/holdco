import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
# E2E mode: real pool + server enabled for Playwright browser tests.
# Unit tests: sandbox pool + no server.
if System.get_env("E2E") do
  config :holdco, Holdco.Repo,
    username: "postgres",
    password: "postgres",
    hostname: "localhost",
    database: "holdco_test#{System.get_env("MIX_TEST_PARTITION")}",
    pool_size: 10

  config :holdco, HoldcoWeb.Endpoint,
    http: [ip: {127, 0, 0, 1}, port: 4002],
    secret_key_base: "nLxXq4onP+KaQ8D4VsO66lj584U3Nmgkrgtx3kpu1780DEgNZvjIuBwVYEA4JXMI",
    server: true
else
  config :holdco, Holdco.Repo,
    username: "postgres",
    password: "postgres",
    hostname: "localhost",
    database: "holdco_test#{System.get_env("MIX_TEST_PARTITION")}",
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: 10

  config :holdco, HoldcoWeb.Endpoint,
    http: [ip: {127, 0, 0, 1}, port: 4002],
    secret_key_base: "nLxXq4onP+KaQ8D4VsO66lj584U3Nmgkrgtx3kpu1780DEgNZvjIuBwVYEA4JXMI",
    server: false
end

# In test we don't send emails
config :holdco, Holdco.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Disable Oban in tests
config :holdco, Oban, testing: :inline

# Skip async webhook delivery to avoid sandbox connection issues
config :holdco, :skip_async_webhooks, true

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
