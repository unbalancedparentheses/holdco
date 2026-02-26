defmodule HoldcoWeb.Api.HealthController do
  use HoldcoWeb, :controller

  def index(conn, _params) do
    json(conn, %{status: "ok"})
  end
end
