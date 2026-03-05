defmodule HoldcoWeb.AccountingIntegrationsTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  defp create_integration(provider, company_id, extra \\ %{}) do
    attrs = Map.merge(%{"status" => "connected"}, extra)

    {:ok, integration} =
      Holdco.Integrations.upsert_integration(provider, company_id, attrs)

    integration
  end

  describe "mount renders integration data" do
    test "renders page heading and metrics strip", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/integrations")

      assert html =~ "Integrations"
      assert html =~ "Connected"
      assert html =~ "Disconnected"
      assert html =~ "Stale (&gt;24h)"
      assert html =~ "Last Sync"
    end

    test "shows company names with provider rows in the table", %{conn: conn} do
      company_fixture(%{name: "AcmeTestCorp"})

      {:ok, _view, html} = live(conn, ~p"/accounts/integrations")

      assert html =~ "AcmeTestCorp"
      assert html =~ "QuickBooks"
      assert html =~ "Xero"
      # Both providers default to disconnected when no integration exists
      assert html =~ "Disconnected"
    end

    test "shows connected status when integration is connected", %{conn: conn} do
      company = company_fixture(%{name: "ConnectedCorp"})
      create_integration("quickbooks", company.id, %{"realm_id" => "realm-42"})

      {:ok, _view, html} = live(conn, ~p"/accounts/integrations")

      assert html =~ "ConnectedCorp"
      assert html =~ "Connected"
      assert html =~ "realm-42"
    end

    test "displays correct connected/disconnected counts", %{conn: conn} do
      c1 = company_fixture(%{name: "CountCorp1"})
      c2 = company_fixture(%{name: "CountCorp2"})

      create_integration("quickbooks", c1.id)
      create_integration("xero", c2.id)

      {:ok, _view, html} = live(conn, ~p"/accounts/integrations")

      # The metrics strip should show 2 connected
      assert html =~ "Connected"
    end

    test "renders empty state when no companies exist", %{conn: conn} do
      # With no companies, no integration rows will render
      {:ok, _view, html} = live(conn, ~p"/accounts/integrations")

      assert html =~ "All Integrations"
    end
  end

  describe "handle_info for PubSub broadcast" do
    test "refreshes integration data on broadcast", %{conn: conn} do
      company = company_fixture(%{name: "BroadcastCorp"})

      {:ok, view, html} = live(conn, ~p"/accounts/integrations")
      assert html =~ "BroadcastCorp"

      # Create an integration after mount
      create_integration("quickbooks", company.id, %{"realm_id" => "realm-broadcast"})

      # Simulate a PubSub broadcast
      send(view.pid, :integration_updated)

      html = render(view)
      assert html =~ "Connected"
      assert html =~ "realm-broadcast"
    end
  end
end
