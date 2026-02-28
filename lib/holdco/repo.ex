defmodule Holdco.Repo do
  use Ecto.Repo,
    otp_app: :holdco,
    adapter: Ecto.Adapters.Postgres
end
