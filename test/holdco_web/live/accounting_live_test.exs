defmodule HoldcoWeb.AccountingLiveTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "GET /accounts/chart" do
    test "renders chart of accounts page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/chart")
      assert html =~ "Chart of Accounts"
    end

    test "shows add button for editors", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, _view, html} = live(conn, ~p"/accounts/chart")
      assert html =~ "Add Account"
    end
  end

  describe "GET /accounts/journal" do
    test "renders journal entries page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/journal")
      assert html =~ "Journal"
    end
  end

  describe "GET /accounts/reports" do
    test "renders accounting reports page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/reports")
      assert html =~ "Report" or html =~ "report"
    end

    test "shows trial balance tab", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/reports")
      assert html =~ "Trial Balance" or html =~ "trial"
    end
  end

  describe "GET /accounts/integrations" do
    test "renders integrations page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/integrations")
      assert html =~ "Integration" or html =~ "integration"
    end
  end

  describe "integrations page - detailed" do
    test "shows QuickBooks Online section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/integrations")

      assert html =~ "QuickBooks Online"
    end

    test "shows Connect to QuickBooks when not connected", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/integrations")

      assert html =~ "Connect to QuickBooks"
      assert html =~ "Disconnected"
    end

    test "shows Connected status when integration is connected", %{conn: conn} do
      Holdco.Integrations.upsert_integration("quickbooks", %{"status" => "connected", "realm_id" => "123456"})

      {:ok, _view, html} = live(conn, ~p"/accounts/integrations")

      assert html =~ "Connected"
      assert html =~ "123456"
    end

    test "shows Sync Now button when connected", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      Holdco.Integrations.upsert_integration("quickbooks", %{"status" => "connected"})

      {:ok, _view, html} = live(conn, ~p"/accounts/integrations")

      assert html =~ "Sync Now"
    end

    test "shows Disconnect button for editor when connected", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      Holdco.Integrations.upsert_integration("quickbooks", %{"status" => "connected"})

      {:ok, _view, html} = live(conn, ~p"/accounts/integrations")

      assert html =~ "Disconnect"
    end
  end

  describe "integrations - viewer permission guards" do
    test "viewer disconnect returns permission error", %{conn: conn} do
      Holdco.Integrations.upsert_integration("quickbooks", %{"status" => "connected"})
      {:ok, view, _html} = live(conn, ~p"/accounts/integrations")

      html = render_hook(view, "disconnect", %{})
      assert html =~ "permission"
    end

    test "viewer sync returns permission error", %{conn: conn} do
      Holdco.Integrations.upsert_integration("quickbooks", %{"status" => "connected"})
      {:ok, view, _html} = live(conn, ~p"/accounts/integrations")

      html = render_hook(view, "sync", %{})
      assert html =~ "permission"
    end
  end

  describe "integrations - editor disconnect" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "editor can disconnect QuickBooks", %{conn: conn} do
      Holdco.Integrations.upsert_integration("quickbooks", %{"status" => "connected"})
      {:ok, view, _html} = live(conn, ~p"/accounts/integrations")

      html = view |> element(~s(button[phx-click="disconnect"])) |> render_click()

      assert html =~ "QuickBooks disconnected"
      assert html =~ "Disconnected"
    end
  end

  describe "integrations - select_sync_company" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "select_sync_company updates selected company", %{conn: conn} do
      Holdco.Integrations.upsert_integration("quickbooks", %{"status" => "connected"})
      company = company_fixture(%{name: "SyncTargetCo"})

      {:ok, view, _html} = live(conn, ~p"/accounts/integrations")

      html =
        view
        |> form(~s(form[phx-change="select_sync_company"]), %{"company_id" => to_string(company.id)})
        |> render_change()

      assert html =~ "SyncTargetCo"
    end
  end

  describe "integrations - unknown handle_info" do
    test "unknown messages reload integration state", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/integrations")

      send(view.pid, :unknown_event)

      html = render(view)
      assert html =~ "QuickBooks Online"
    end
  end

  describe "integrations - company selector" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "company dropdown shows All Companies option when connected", %{conn: conn} do
      Holdco.Integrations.upsert_integration("quickbooks", %{"status" => "connected"})
      company_fixture(%{name: "DropdownCo"})

      {:ok, _view, html} = live(conn, ~p"/accounts/integrations")

      assert html =~ "All Companies"
      assert html =~ "DropdownCo"
    end
  end
end
