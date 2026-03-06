import Config

# This file contains secrets that can't live in the database.
# It is gitignored. Copy secrets.example.exs and fill in your values.
#
# All service credentials (Gmail, Xero, QuickBooks, Plaid, S3) are
# managed via Settings > Services in the web UI.

# ── Database ──────────────────────────────────────────────
config :holdco, Holdco.Repo,
  url: "ecto://postgres:postgres@localhost/holdco_prod",
  pool_size: 10

# ── Phoenix ───────────────────────────────────────────────
config :holdco, HoldcoWeb.Endpoint,
  secret_key_base: "CHANGE_ME_run_mix_phx_gen_secret"

config :holdco, :host, "localhost"
