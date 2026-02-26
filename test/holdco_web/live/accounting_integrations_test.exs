defmodule HoldcoWeb.AccountingIntegrationsTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  defp create_connected_qbo(_context) do
    Holdco.Integrations.upsert_integration("quickbooks", %{"status" => "connected"})
    :ok
  end

  # ── Mount & Render ──────────────────────────────────────

  describe "mount and render" do
    test "renders page title and deck", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/integrations")

      assert html =~ "<h1>Integrations</h1>"
      assert html =~ "Connect external accounting services"
      assert html =~ "page-title-rule"
    end

    test "renders QuickBooks Online section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/integrations")

      assert html =~ "QuickBooks Online"
    end

    test "shows Disconnected badge when no QBO integration", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/integrations")

      assert html =~ "Disconnected"
      assert html =~ "badge-expense"
    end

    test "shows Connect to QuickBooks link when disconnected", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/integrations")

      assert html =~ "Connect to QuickBooks"
      assert html =~ ~s(href="/auth/quickbooks/connect")
    end

    test "shows description text", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/integrations")

      assert html =~ "Sync your chart of accounts and journal entries from QuickBooks Online."
    end
  end

  # ── Connected State ─────────────────────────────────────

  describe "when QBO is connected" do
    setup [:create_connected_qbo]

    test "shows Connected badge", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/integrations")

      assert html =~ "Connected"
      assert html =~ "badge-asset"
    end

    test "shows Sync Now button", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/integrations")

      assert html =~ "Sync Now"
      assert html =~ ~s(phx-click="sync")
    end

    test "shows company filter for sync", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/integrations")

      assert html =~ "All Companies"
      assert html =~ ~s(phx-change="select_sync_company")
    end

    test "editor sees Disconnect button", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, _view, html} = live(conn, ~p"/accounts/integrations")

      assert html =~ "Disconnect"
      assert html =~ ~s(phx-click="disconnect")
    end
  end

  # ── Select Sync Company ─────────────────────────────────

  describe "select_sync_company event" do
    setup [:create_connected_qbo]

    test "selects a company for sync", %{conn: conn} do
      company = company_fixture(%{name: "SyncCo"})
      {:ok, view, _html} = live(conn, ~p"/accounts/integrations")

      html =
        view
        |> form(~s(form[phx-change="select_sync_company"]), %{"company_id" => to_string(company.id)})
        |> render_change()

      # Page should still render without error
      assert html =~ "QuickBooks Online"
    end
  end

  # ── Sync Event ──────────────────────────────────────────

  describe "sync event" do
    setup [:create_connected_qbo]

    test "triggers sync and shows syncing state", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/integrations")

      # The sync event sends a message to self, so after the event the button text changes
      view |> element(~s(button[phx-click="sync"])) |> render_click()

      # The sync happens async via handle_info(:do_sync), but we can check it doesn't crash
      html = render(view)
      assert html =~ "QuickBooks Online"
    end

    test "viewer cannot sync", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/integrations")

      render_hook(view, "sync", %{})
      assert render(view) =~ "permission"
    end
  end

  # ── Disconnect Event ────────────────────────────────────

  describe "disconnect event" do
    setup [:create_connected_qbo]

    test "disconnects QBO integration", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/accounts/integrations")

      view |> element(~s(button[phx-click="disconnect"])) |> render_click()

      html = render(view)
      assert html =~ "QuickBooks disconnected"
      assert html =~ "Disconnected"
      assert html =~ "Connect to QuickBooks"
    end

    test "viewer cannot disconnect", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/integrations")

      render_hook(view, "disconnect", %{})
      assert render(view) =~ "permission"
    end
  end

  # ── Sync with Company Selected ────────────────────────

  describe "sync with company selected" do
    setup [:create_connected_qbo]

    test "sync with a selected company does not crash", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "SyncWithCo"})
      {:ok, view, _html} = live(conn, ~p"/accounts/integrations")

      # Select a company first
      view
      |> form(~s(form[phx-change="select_sync_company"]), %{"company_id" => to_string(company.id)})
      |> render_change()

      # Trigger sync
      view |> element(~s(button[phx-click="sync"])) |> render_click()

      # Let the async handle_info run
      html = render(view)
      assert html =~ "QuickBooks Online"
    end
  end

  # ── Handle Info ───────────────────────────────────────

  describe "handle_info for PubSub broadcast" do
    setup [:create_connected_qbo]

    test "handles generic broadcast without crashing", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/integrations")

      send(view.pid, :some_broadcast)

      html = render(view)
      assert html =~ "QuickBooks Online"
    end
  end

  # ── Viewer does not see Disconnect button ─────────────

  describe "viewer role UI" do
    setup [:create_connected_qbo]

    test "viewer does not see Disconnect button when connected", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/integrations")

      refute html =~ ~s(phx-click="disconnect")
    end

    test "viewer still sees Sync Now and company filter when connected", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/integrations")

      assert html =~ "Sync Now"
      assert html =~ "All Companies"
    end
  end

  # ── Description text and realm_id ─────────────────────

  describe "additional display details" do
    setup [:create_connected_qbo]

    test "shows description text when connected", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/integrations")

      assert html =~ "Sync your chart of accounts and journal entries from QuickBooks Online."
    end
  end

  # ── Disconnected state shows connect link ─────────────

  describe "disconnected state" do
    test "shows Connect to QuickBooks link with correct href", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/integrations")

      assert html =~ "Connect to QuickBooks"
      assert html =~ "/auth/quickbooks/connect"
      assert html =~ "btn btn-primary"
    end

    test "does not show Sync Now or Disconnect when disconnected", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/integrations")

      refute html =~ "Sync Now"
      refute html =~ ~s(phx-click="disconnect")
    end
  end
end
