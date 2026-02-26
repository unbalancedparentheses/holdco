defmodule Holdco.Repo do
  use Ecto.Repo,
    otp_app: :holdco,
    adapter: Ecto.Adapters.SQLite3
end
