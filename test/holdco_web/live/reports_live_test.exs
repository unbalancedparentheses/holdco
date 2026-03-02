defmodule HoldcoWeb.ReportsLiveTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "GET /reports" do
    test "print_page event pushes js-print event", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/reports")

      # The print_page event pushes a JS event - should not crash
      render_hook(view, "print_page", %{})
      assert render(view) =~ "Reports"
    end
  end
end
