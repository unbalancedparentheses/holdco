import Config

if System.get_env("PHX_SERVER") do
  config :holdco, HoldcoWeb.Endpoint, server: true
end

if config_env() != :test do
  config :holdco, HoldcoWeb.Endpoint,
    http: [port: String.to_integer(System.get_env("PORT", "4000"))]
end

if config_env() == :prod do
  # Load secrets from config/secrets.exs (gitignored)
  secrets_path = Path.expand("secrets.exs", __DIR__)

  if File.exists?(secrets_path) do
    import_config(secrets_path)
  else
    raise "config/secrets.exs is missing. Copy config/secrets.example.exs and fill in your values."
  end

  # These can be overridden via secrets.exs, but we set sane prod defaults here
  host = Application.get_env(:holdco, :host, "example.com")

  config :holdco, HoldcoWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [ip: {0, 0, 0, 0, 0, 0, 0, 0}]
end
