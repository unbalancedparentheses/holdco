defmodule HoldcoWeb.HealthControllerTest do
  use HoldcoWeb.ConnCase, async: true

  test "GET /health returns 200 with db and oban status", %{conn: conn} do
    conn = get(conn, "/health")
    assert json = json_response(conn, 200)
    assert json["status"] == "ok"
    assert json["db"] == "ok"
    assert json["oban"] == "ok"
  end

  test "GET /health includes all expected keys", %{conn: conn} do
    conn = get(conn, "/health")
    assert json = json_response(conn, 200)
    assert Map.has_key?(json, "status")
    assert Map.has_key?(json, "db")
    assert Map.has_key?(json, "oban")
  end
end
