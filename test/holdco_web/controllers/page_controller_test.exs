defmodule HoldcoWeb.PageControllerTest do
  use HoldcoWeb.ConnCase, async: true

  describe "PageController.home/2" do
    test "renders the home template with Welcome to Holdco", %{conn: conn} do
      # PageController.home is not routed (DashboardLive handles /), so invoke directly
      conn =
        conn
        |> bypass_through(HoldcoWeb.Router, [:browser])
        |> get("/")
        |> Phoenix.Controller.put_view(HoldcoWeb.PageHTML)
        |> Phoenix.Controller.put_format("html")
        |> HoldcoWeb.PageController.home(%{})

      assert html_response(conn, 200) =~ "Welcome to Holdco"
    end

    test "renders a link to the dashboard", %{conn: conn} do
      conn =
        conn
        |> bypass_through(HoldcoWeb.Router, [:browser])
        |> get("/")
        |> Phoenix.Controller.put_view(HoldcoWeb.PageHTML)
        |> Phoenix.Controller.put_format("html")
        |> HoldcoWeb.PageController.home(%{})

      assert html_response(conn, 200) =~ "Go to Dashboard"
    end
  end
end
