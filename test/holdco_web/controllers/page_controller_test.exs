defmodule HoldcoWeb.PageControllerTest do
  use HoldcoWeb.ConnCase

  test "GET / redirects to login when not authenticated", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/users/log-in"
  end
end
