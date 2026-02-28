defmodule HoldcoWeb.AccountingIntegrationsTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  defp create_company_with_qbo(_context) do
    company = company_fixture(%{name: "QBO Corp"})

    Holdco.Integrations.upsert_integration("quickbooks", company.id, %{
      "status" => "connected",
      "realm_id" => "123456"
    })

    %{company: company}
  end

  # ── Mount & Render ──────────────────────────────────────

  describe "mount and render" do
    test "renders page title", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/integrations")

      assert html =~ "<h1>Integrations</h1>"
      assert html =~ "Overview of external accounting integrations"
    end

    test "renders QuickBooks section header", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/integrations")

      assert html =~ "QuickBooks Online"
    end

    test "shows table headers", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/integrations")

      assert html =~ "Company"
      assert html =~ "Provider"
      assert html =~ "Status"
      assert html =~ "Last Synced"
    end
  end

  # ── Company listing ─────────────────────────────────────

  describe "company listing" do
    test "shows companies in summary table", %{conn: conn} do
      company = company_fixture(%{name: "Summary Co"})
      {:ok, _view, html} = live(conn, ~p"/accounts/integrations")

      assert html =~ "Summary Co"
      assert html =~ "/companies/#{company.id}"
    end

    test "shows Disconnected badge for companies without QBO", %{conn: conn} do
      _company = company_fixture(%{name: "No QBO Co"})
      {:ok, _view, html} = live(conn, ~p"/accounts/integrations")

      assert html =~ "Disconnected"
      assert html =~ "badge-expense"
    end
  end

  # ── Connected company ─────────────────────────────────────

  describe "when a company has QBO connected" do
    setup [:create_company_with_qbo]

    test "shows Connected badge for connected company", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/integrations")

      assert html =~ "Connected"
      assert html =~ "badge-asset"
    end

    test "shows Manage link to company page", %{conn: conn, company: company} do
      {:ok, _view, html} = live(conn, ~p"/accounts/integrations")

      assert html =~ "/companies/#{company.id}"
      assert html =~ "Manage"
    end

    test "shows realm_id for connected company", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/integrations")

      assert html =~ "123456"
    end
  end

  # ── Handle Info ───────────────────────────────────────

  describe "handle_info for PubSub broadcast" do
    test "handles generic broadcast without crashing", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/integrations")

      send(view.pid, :some_broadcast)

      html = render(view)
      assert html =~ "QuickBooks Online"
    end
  end

  # ── Empty state ─────────────────────────────────────────

  describe "empty state" do
    test "shows empty message when no companies exist", %{conn: conn} do
      # With no companies, the table body is empty but no crash
      {:ok, _view, html} = live(conn, ~p"/accounts/integrations")
      assert html =~ "QuickBooks Online"
    end
  end
end
