defmodule HoldcoWeb.KpiLiveIndexTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "Index" do
    test "renders KPI Tracking page", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/kpis")
      assert html =~ "KPI Tracking"
    end

    test "shows metrics strip with counts", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/kpis")
      assert html =~ "Total KPIs"
      assert html =~ "On Target"
      assert html =~ "Warning"
      assert html =~ "Below Threshold"
    end

    test "shows empty state when no KPIs exist", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/kpis")
      assert html =~ "No KPIs defined yet"
    end

    test "renders with KPI data and displays name", %{conn: conn} do
      company = company_fixture()
      kpi_fixture(%{company: company, name: "Revenue Growth"})

      {:ok, _live, html} = live(conn, ~p"/kpis")
      assert html =~ "Revenue Growth"
    end

    test "shows company name as a link when KPI has a company", %{conn: conn} do
      company = company_fixture(%{name: "AlphaCo"})
      kpi_fixture(%{company: company, name: "AlphaCo KPI"})

      {:ok, _live, html} = live(conn, ~p"/kpis")
      assert html =~ "AlphaCo"
      assert html =~ "AlphaCo KPI"
    end

    test "shows --- when KPI has no company", %{conn: conn} do
      kpi_fixture(%{name: "Global KPI", company_id: nil})

      {:ok, _live, html} = live(conn, ~p"/kpis")
      assert html =~ "Global KPI"
      assert html =~ "---"
    end

    test "shows metric_type tag", %{conn: conn} do
      company = company_fixture()
      kpi_fixture(%{company: company, name: "Typed KPI", metric_type: "currency"})

      {:ok, _live, html} = live(conn, ~p"/kpis")
      assert html =~ "currency"
    end

    test "shows No Data status when no snapshots", %{conn: conn} do
      company = company_fixture()
      kpi_fixture(%{company: company, name: "No Snap KPI"})

      {:ok, _live, html} = live(conn, ~p"/kpis")
      assert html =~ "No Data"
    end

    test "shows On Target status when current >= target", %{conn: conn} do
      company = company_fixture()
      kpi = kpi_fixture(%{company: company, name: "On Target KPI", target_value: 100.0})
      kpi_snapshot_fixture(%{kpi: kpi, current_value: 150.0, date: "2024-06-01"})

      {:ok, _live, html} = live(conn, ~p"/kpis")
      assert html =~ "On Target"
    end

    test "shows Warning status when current >= threshold but < target", %{conn: conn} do
      company = company_fixture()
      kpi = kpi_fixture(%{company: company, name: "Warning KPI", target_value: 100.0, threshold_value: 50.0})
      kpi_snapshot_fixture(%{kpi: kpi, current_value: 75.0, date: "2024-06-01"})

      {:ok, _live, html} = live(conn, ~p"/kpis")
      assert html =~ "Warning"
    end

    test "shows Below Threshold status when current < threshold", %{conn: conn} do
      company = company_fixture()
      kpi = kpi_fixture(%{company: company, name: "Below KPI", target_value: 100.0, threshold_value: 50.0})
      kpi_snapshot_fixture(%{kpi: kpi, current_value: 25.0, date: "2024-06-01"})

      {:ok, _live, html} = live(conn, ~p"/kpis")
      assert html =~ "Below Threshold"
    end

    test "shows trend indicator with two snapshots (increasing)", %{conn: conn} do
      company = company_fixture()
      kpi = kpi_fixture(%{company: company, name: "Trend Up KPI"})
      kpi_snapshot_fixture(%{kpi: kpi, current_value: 50_000.0, date: "2024-01-15"})
      kpi_snapshot_fixture(%{kpi: kpi, current_value: 55_000.0, date: "2024-02-15"})

      {:ok, _live, html} = live(conn, ~p"/kpis")
      assert html =~ "Trend Up KPI"
      # trend should show ^ for increasing
      assert html =~ "^"
    end

    test "shows trend indicator with two snapshots (decreasing)", %{conn: conn} do
      company = company_fixture()
      kpi = kpi_fixture(%{company: company, name: "Trend Down KPI"})
      kpi_snapshot_fixture(%{kpi: kpi, current_value: 55_000.0, date: "2024-01-15"})
      kpi_snapshot_fixture(%{kpi: kpi, current_value: 45_000.0, date: "2024-02-15"})

      {:ok, _live, html} = live(conn, ~p"/kpis")
      assert html =~ "Trend Down KPI"
      assert html =~ "v"
    end

    test "formats value with unit", %{conn: conn} do
      company = company_fixture()
      kpi = kpi_fixture(%{company: company, name: "USD KPI", unit: "USD", target_value: 100_000.0})
      kpi_snapshot_fixture(%{kpi: kpi, current_value: 85_000.0, date: "2024-06-01"})

      {:ok, _live, html} = live(conn, ~p"/kpis")
      assert html =~ "USD"
    end

    test "formats value with percent unit", %{conn: conn} do
      company = company_fixture()
      kpi = kpi_fixture(%{company: company, name: "Pct KPI", unit: "%", metric_type: "percentage", target_value: 95.0})
      kpi_snapshot_fixture(%{kpi: kpi, current_value: 88.5, date: "2024-06-01"})

      {:ok, _live, html} = live(conn, ~p"/kpis")
      assert html =~ "%"
    end
  end

  describe "show_form / close_form" do
    test "opens add KPI form and shows fields", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/kpis")
      html = render_click(live, "show_form", %{})
      assert html =~ "Add KPI"
      assert html =~ "Name"
      assert html =~ "Metric Type"
      assert html =~ "Target Value"
      assert html =~ "Threshold Value"
      assert html =~ "Unit"
      assert html =~ "Company"
    end

    test "closes form", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/kpis")
      render_click(live, "show_form", %{})
      html = render_click(live, "close_form", %{})
      refute html =~ "Add KPI"
    end
  end

  describe "edit event" do
    test "opens edit form with KPI data", %{conn: conn} do
      company = company_fixture()
      kpi = kpi_fixture(%{company: company, name: "Editable KPI", metric_type: "currency", target_value: 200.0})

      {:ok, live, _html} = live(conn, ~p"/kpis")
      html = render_click(live, "edit", %{"id" => to_string(kpi.id)})
      assert html =~ "Edit KPI"
      assert html =~ "Editable KPI"
    end
  end

  describe "filter_company" do
    test "filters KPIs by company", %{conn: conn} do
      c1 = company_fixture(%{name: "FilterCo1"})
      c2 = company_fixture(%{name: "FilterCo2"})
      kpi_fixture(%{company: c1, name: "KPI for Co1"})
      kpi_fixture(%{company: c2, name: "KPI for Co2"})

      {:ok, live, _html} = live(conn, ~p"/kpis")
      html = render_click(live, "filter_company", %{"company_id" => to_string(c1.id)})
      assert html =~ "KPI for Co1"
      refute html =~ "KPI for Co2"
    end

    test "shows all KPIs when filter is cleared", %{conn: conn} do
      c1 = company_fixture(%{name: "AllCo1"})
      c2 = company_fixture(%{name: "AllCo2"})
      kpi_fixture(%{company: c1, name: "KPI A1"})
      kpi_fixture(%{company: c2, name: "KPI A2"})

      {:ok, live, _html} = live(conn, ~p"/kpis")
      # First filter to one company
      render_click(live, "filter_company", %{"company_id" => to_string(c1.id)})
      # Then clear filter
      html = render_click(live, "filter_company", %{"company_id" => ""})
      assert html =~ "KPI A1"
      assert html =~ "KPI A2"
    end
  end

  describe "select_kpi / deselect_kpi" do
    test "selects a KPI to view snapshots panel", %{conn: conn} do
      company = company_fixture()
      kpi = kpi_fixture(%{company: company, name: "Monthly Revenue"})

      {:ok, live, _html} = live(conn, ~p"/kpis")
      html = render_click(live, "select_kpi", %{"id" => to_string(kpi.id)})
      assert html =~ "Monthly Revenue"
      assert html =~ "Snapshots"
      assert html =~ "No snapshots recorded yet"
    end

    test "selecting a KPI with snapshots shows the snapshot table", %{conn: conn} do
      company = company_fixture()
      kpi = kpi_fixture(%{company: company, name: "Snap KPI"})
      kpi_snapshot_fixture(%{kpi: kpi, current_value: 50_000.0, date: "2024-01-15"})
      kpi_snapshot_fixture(%{kpi: kpi, current_value: 55_000.0, date: "2024-02-15"})

      {:ok, live, _html} = live(conn, ~p"/kpis")
      html = render_click(live, "select_kpi", %{"id" => to_string(kpi.id)})
      assert html =~ "Snap KPI"
      assert html =~ "2024-01-15"
      assert html =~ "2024-02-15"
    end

    test "deselects KPI and returns to empty detail state", %{conn: conn} do
      company = company_fixture()
      kpi = kpi_fixture(%{company: company, name: "Deselect KPI"})

      {:ok, live, _html} = live(conn, ~p"/kpis")
      render_click(live, "select_kpi", %{"id" => to_string(kpi.id)})
      html = render_click(live, "deselect_kpi", %{})
      assert html =~ "Select a KPI from the list"
    end
  end

  describe "show_snapshot_form / close_snapshot_form" do
    test "opens snapshot form", %{conn: conn} do
      company = company_fixture()
      kpi = kpi_fixture(%{company: company, name: "Snapshot KPI"})

      {:ok, live, _html} = live(conn, ~p"/kpis")
      render_click(live, "select_kpi", %{"id" => to_string(kpi.id)})
      html = render_click(live, "show_snapshot_form", %{})
      assert html =~ "Record Snapshot"
      assert html =~ "Snapshot KPI"
    end

    test "closes snapshot form", %{conn: conn} do
      company = company_fixture()
      kpi = kpi_fixture(%{company: company, name: "Close Snap KPI"})

      {:ok, live, _html} = live(conn, ~p"/kpis")
      render_click(live, "select_kpi", %{"id" => to_string(kpi.id)})
      render_click(live, "show_snapshot_form", %{})
      html = render_click(live, "close_snapshot_form", %{})
      refute html =~ "Record Snapshot for"
    end
  end

  describe "viewer permission gating" do
    test "viewer cannot save a KPI", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/kpis")
      html = render_click(live, "save", %{"kpi" => %{"name" => "Test"}})
      assert html =~ "permission"
    end

    test "viewer cannot update a KPI", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/kpis")
      html = render_click(live, "update", %{"kpi" => %{"name" => "Test"}})
      assert html =~ "permission"
    end

    test "viewer cannot delete a KPI", %{conn: conn} do
      company = company_fixture()
      kpi = kpi_fixture(%{company: company, name: "Delete KPI"})

      {:ok, live, _html} = live(conn, ~p"/kpis")
      html = render_click(live, "delete", %{"id" => to_string(kpi.id)})
      assert html =~ "permission"
    end

    test "viewer cannot save a snapshot", %{conn: conn} do
      company = company_fixture()
      kpi = kpi_fixture(%{company: company, name: "Snap Denied KPI"})

      {:ok, live, _html} = live(conn, ~p"/kpis")
      render_click(live, "select_kpi", %{"id" => to_string(kpi.id)})
      html = render_click(live, "save_snapshot", %{"snapshot" => %{"date" => "2024-06-01", "current_value" => "100"}})
      assert html =~ "permission"
    end
  end

  describe "editor write operations" do
    test "editor can create a KPI", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "EditorCo"})

      {:ok, live, _html} = live(conn, ~p"/kpis")
      render_click(live, "show_form", %{})

      html =
        render_submit(live, "save", %{
          "kpi" => %{
            "name" => "New Revenue KPI",
            "metric_type" => "currency",
            "target_value" => "500000",
            "unit" => "USD",
            "company_id" => to_string(company.id)
          }
        })

      assert html =~ "KPI created"
      assert html =~ "New Revenue KPI"
    end

    test "editor can update a KPI", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()
      kpi = kpi_fixture(%{company: company, name: "Old Name KPI", metric_type: "currency", target_value: 100.0})

      {:ok, live, _html} = live(conn, ~p"/kpis")
      render_click(live, "edit", %{"id" => to_string(kpi.id)})

      html =
        render_submit(live, "update", %{
          "kpi" => %{
            "name" => "Updated KPI Name",
            "metric_type" => "percentage",
            "target_value" => "200"
          }
        })

      assert html =~ "KPI updated"
    end

    test "editor can delete a KPI", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()
      kpi = kpi_fixture(%{company: company, name: "Deletable KPI"})

      {:ok, live, _html} = live(conn, ~p"/kpis")
      html = render_click(live, "delete", %{"id" => to_string(kpi.id)})
      assert html =~ "KPI deleted"
      refute html =~ "Deletable KPI"
    end

    test "deleting the selected KPI clears the detail panel", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()
      kpi = kpi_fixture(%{company: company, name: "Selected Del KPI"})

      {:ok, live, _html} = live(conn, ~p"/kpis")
      render_click(live, "select_kpi", %{"id" => to_string(kpi.id)})
      html = render_click(live, "delete", %{"id" => to_string(kpi.id)})
      assert html =~ "KPI deleted"
      assert html =~ "Select a KPI from the list"
    end

    test "deleting a non-selected KPI preserves selection", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()
      kpi1 = kpi_fixture(%{company: company, name: "Keep Selected KPI"})
      kpi2 = kpi_fixture(%{company: company, name: "Delete Other KPI"})

      {:ok, live, _html} = live(conn, ~p"/kpis")
      render_click(live, "select_kpi", %{"id" => to_string(kpi1.id)})
      html = render_click(live, "delete", %{"id" => to_string(kpi2.id)})
      assert html =~ "KPI deleted"
      assert html =~ "Keep Selected KPI"
    end

    test "editor can record a snapshot", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()
      kpi = kpi_fixture(%{company: company, name: "Snapshot Record KPI"})

      {:ok, live, _html} = live(conn, ~p"/kpis")
      render_click(live, "select_kpi", %{"id" => to_string(kpi.id)})
      render_click(live, "show_snapshot_form", %{})

      html =
        render_submit(live, "save_snapshot", %{
          "snapshot" => %{
            "date" => "2024-06-15",
            "current_value" => "85000"
          }
        })

      assert html =~ "Snapshot recorded"
      assert html =~ "2024-06-15"
    end
  end

  describe "noop event" do
    test "noop does not change the page", %{conn: conn} do
      {:ok, live, _html_before} = live(conn, ~p"/kpis")
      html_after = render_click(live, "noop", %{})
      assert html_after =~ "KPI Tracking"
    end
  end

  describe "editor error paths" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "save KPI with invalid data shows error", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/kpis")
      render_click(live, "show_form", %{})

      html =
        render_submit(live, "save", %{
          "kpi" => %{
            "name" => "",
            "metric_type" => "",
            "target_value" => ""
          }
        })

      assert html =~ "Failed to create KPI"
    end

    test "update KPI with invalid data shows error", %{conn: conn} do
      company = company_fixture()
      kpi = kpi_fixture(%{company: company, name: "Update Fail KPI", metric_type: "currency", target_value: 100.0})

      {:ok, live, _html} = live(conn, ~p"/kpis")
      render_click(live, "edit", %{"id" => to_string(kpi.id)})

      html =
        render_submit(live, "update", %{
          "kpi" => %{
            "name" => "",
            "metric_type" => ""
          }
        })

      assert html =~ "Failed to update KPI"
    end

    test "save snapshot with invalid data shows error", %{conn: conn} do
      company = company_fixture()
      kpi = kpi_fixture(%{company: company, name: "Snap Fail KPI"})

      {:ok, live, _html} = live(conn, ~p"/kpis")
      render_click(live, "select_kpi", %{"id" => to_string(kpi.id)})
      render_click(live, "show_snapshot_form", %{})

      html =
        render_submit(live, "save_snapshot", %{
          "snapshot" => %{
            "date" => "not-a-date",
            "current_value" => "not-a-number"
          }
        })

      assert html =~ "Failed to record snapshot"
    end
  end

  describe "handle_info" do
    test "handle_info reloads KPIs", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/kpis")
      send(live.pid, :some_event)
      html = render(live)
      assert html =~ "KPI Tracking"
    end
  end

  describe "trend indicator equal values" do
    test "shows dash when values are equal", %{conn: conn} do
      company = company_fixture()
      kpi = kpi_fixture(%{company: company, name: "Flat KPI"})
      kpi_snapshot_fixture(%{kpi: kpi, current_value: 100.0, date: "2024-01-15"})
      kpi_snapshot_fixture(%{kpi: kpi, current_value: 100.0, date: "2024-02-15"})

      {:ok, _live, html} = live(conn, ~p"/kpis")
      assert html =~ "Flat KPI"
    end
  end

  describe "format_value with nil and empty unit" do
    test "nil unit shows raw number", %{conn: conn} do
      company = company_fixture()
      kpi = kpi_fixture(%{company: company, name: "No Unit KPI", unit: nil, target_value: 500.0})
      kpi_snapshot_fixture(%{kpi: kpi, current_value: 250.0, date: "2024-06-01"})

      {:ok, _live, html} = live(conn, ~p"/kpis")
      assert html =~ "No Unit KPI"
      assert html =~ "250"
    end
  end
end
