defmodule HoldcoWeb.HealthController do
  use HoldcoWeb, :controller

  def index(conn, _params) do
    db = check_db()
    oban = check_oban()

    status = if db == "ok" and oban == "ok", do: "ok", else: "degraded"
    http_status = if status == "ok", do: 200, else: 503

    conn
    |> put_status(http_status)
    |> json(%{status: status, db: db, oban: oban})
  end

  defp check_db do
    Holdco.Repo.query!("SELECT 1")
    "ok"
  rescue
    _ -> "error"
  end

  defp check_oban do
    oban_config = Application.get_env(:holdco, Oban, [])

    if oban_config[:testing] do
      # In test/inline mode, Oban is healthy by definition
      "ok"
    else
      case Oban.check_queue(queue: :default) do
        %{paused: false} -> "ok"
        %{paused: true} -> "paused"
        _ -> "error"
      end
    end
  rescue
    _ -> "error"
  end
end
