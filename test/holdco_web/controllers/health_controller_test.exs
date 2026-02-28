defmodule HoldcoWeb.HealthControllerTest do
  use HoldcoWeb.ConnCase, async: true

  test "GET /health returns 200", %{conn: conn} do
    conn = get(conn, "/health")
    assert response(conn, 200)
  end
end
