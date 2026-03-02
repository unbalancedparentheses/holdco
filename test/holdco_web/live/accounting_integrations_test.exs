defmodule HoldcoWeb.AccountingIntegrationsTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  # ── Handle Info ───────────────────────────────────────

  describe "handle_info for PubSub broadcast" do
    test "handles generic broadcast without crashing", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/integrations")

      send(view.pid, :some_broadcast)

      html = render(view)
      assert html =~ "All Integrations"
    end
  end

end
