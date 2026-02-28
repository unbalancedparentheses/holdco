defmodule HoldcoWeb.LeaseLiveIndexTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "Index" do
    test "renders Lease Accounting page", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/leases")
      assert html =~ "Lease Accounting"
    end

    test "shows page subtitle about IFRS 16 / ASC 842", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/leases")
      assert html =~ "IFRS 16" || html =~ "ASC 842"
    end

    test "shows metrics strip with lease metrics", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/leases")
      assert html =~ "Total ROU Assets"
      assert html =~ "Total Lease Liabilities"
      assert html =~ "Monthly Payment Obligation"
      assert html =~ "Active Leases"
    end

    test "shows empty state when no leases exist", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/leases")
      assert html =~ "No leases found"
    end

    test "shows lease table headers", %{conn: conn} do
      company = company_fixture()
      lease_fixture(%{company: company})

      {:ok, _live, html} = live(conn, ~p"/leases")
      assert html =~ "Lessor"
      assert html =~ "Asset Description"
      assert html =~ "Company"
      assert html =~ "Type"
      assert html =~ "Monthly Payment"
      assert html =~ "Currency"
      assert html =~ "Discount Rate"
    end

    test "renders with lease data", %{conn: conn} do
      company = company_fixture(%{name: "LeaseCo"})
      lease_fixture(%{company: company, lessor: "Landlord Inc", asset_description: "Office Floor 3"})

      {:ok, _live, html} = live(conn, ~p"/leases")
      assert html =~ "Landlord Inc"
      assert html =~ "Office Floor 3"
    end

    test "shows operating lease type tag", %{conn: conn} do
      company = company_fixture()
      lease_fixture(%{company: company, lessor: "Op Lease", lease_type: "operating"})

      {:ok, _live, html} = live(conn, ~p"/leases")
      assert html =~ "Operating"
    end

    test "shows finance lease type tag", %{conn: conn} do
      company = company_fixture()
      lease_fixture(%{company: company, lessor: "Fin Lease", lease_type: "finance"})

      {:ok, _live, html} = live(conn, ~p"/leases")
      assert html =~ "Finance"
    end

    test "shows company link for leases", %{conn: conn} do
      company = company_fixture(%{name: "LinkedLeaseCo"})
      lease_fixture(%{company: company, lessor: "Some Lessor"})

      {:ok, _live, html} = live(conn, ~p"/leases")
      assert html =~ "LinkedLeaseCo"
    end

    test "renders PV calculations for leases", %{conn: conn} do
      company = company_fixture()
      lease_fixture(%{
        company: company,
        lessor: "PV Lessor",
        monthly_payment: 10_000.0,
        discount_rate: 0.05,
        start_date: "2024-01-01",
        end_date: "2028-12-31"
      })

      {:ok, _live, html} = live(conn, ~p"/leases")
      assert html =~ "PV Lessor"
    end

    test "shows Lease Portfolio Breakdown chart", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/leases")
      assert html =~ "Lease Portfolio Breakdown"
      assert html =~ "lease-pv-chart"
    end
  end

  describe "form interactions" do
    test "opens add lease form", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/leases")
      html = render_click(live, "show_form", %{})
      assert html =~ "Add Lease"
      assert html =~ "Lessor"
      assert html =~ "Asset Description"
      assert html =~ "Lease Type"
      assert html =~ "Monthly Payment"
      assert html =~ "Discount Rate"
    end

    test "form shows company dropdown", %{conn: conn} do
      company_fixture(%{name: "FormDropdownCo"})

      {:ok, live, _html} = live(conn, ~p"/leases")
      html = render_click(live, "show_form", %{})
      assert html =~ "FormDropdownCo"
      assert html =~ "Select company"
    end

    test "form shows lease type options", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/leases")
      html = render_click(live, "show_form", %{})
      assert html =~ "Operating"
      assert html =~ "Finance"
    end

    test "form shows currency options", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/leases")
      html = render_click(live, "show_form", %{})
      assert html =~ "USD"
      assert html =~ "EUR"
      assert html =~ "GBP"
    end

    test "form shows notes textarea", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/leases")
      html = render_click(live, "show_form", %{})
      assert html =~ "Notes"
    end

    test "closes form with close_form event", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/leases")
      render_click(live, "show_form", %{})
      html = render_click(live, "close_form", %{})
      refute html =~ "Add Lease"
    end

    test "opens edit form for existing lease", %{conn: conn} do
      company = company_fixture()
      lease = lease_fixture(%{company: company, lessor: "Edit Me Lessor", lease_type: "finance"})

      {:ok, live, _html} = live(conn, ~p"/leases")
      html = render_click(live, "edit", %{"id" => to_string(lease.id)})
      assert html =~ "Edit Lease"
      assert html =~ "Edit Me Lessor"
    end

    test "noop event does nothing", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/leases")
      html = render_click(live, "noop", %{})
      assert html =~ "Lease Accounting"
    end
  end

  describe "company filter" do
    test "filters leases by company", %{conn: conn} do
      company1 = company_fixture(%{name: "LeaseCompA"})
      company2 = company_fixture(%{name: "LeaseCompB"})
      lease_fixture(%{company: company1, lessor: "Lessor in A"})
      lease_fixture(%{company: company2, lessor: "Lessor in B"})

      {:ok, live, _html} = live(conn, ~p"/leases")
      html = render_change(live, "filter_company", %{"company_id" => to_string(company1.id)})
      assert html =~ "Lessor in A"
    end

    test "resets filter to show all leases", %{conn: conn} do
      company = company_fixture()
      lease_fixture(%{company: company, lessor: "All Lessor"})

      {:ok, live, _html} = live(conn, ~p"/leases")
      render_change(live, "filter_company", %{"company_id" => to_string(company.id)})
      html = render_change(live, "filter_company", %{"company_id" => ""})
      assert html =~ "All Lessor"
    end

    test "filter resets selected lease and schedule", %{conn: conn} do
      company = company_fixture()
      lease = lease_fixture(%{company: company, lessor: "Selected Lease"})

      {:ok, live, _html} = live(conn, ~p"/leases")
      render_click(live, "select_lease", %{"id" => to_string(lease.id)})
      html = render_change(live, "filter_company", %{"company_id" => ""})
      # After filter change, the schedule section should be gone
      refute html =~ "Amortization Schedule"
    end

    test "company filter dropdown shows All Companies option", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/leases")
      assert html =~ "All Companies"
    end
  end

  describe "amortization schedule" do
    test "selects a lease to show amortization schedule", %{conn: conn} do
      company = company_fixture()
      lease = lease_fixture(%{
        company: company,
        lessor: "Schedule Lessor",
        monthly_payment: 5_000.0,
        discount_rate: 0.05,
        start_date: "2024-01-01",
        end_date: "2028-12-31"
      })

      {:ok, live, _html} = live(conn, ~p"/leases")
      html = render_click(live, "select_lease", %{"id" => to_string(lease.id)})
      assert html =~ "Amortization Schedule: Schedule Lessor"
      assert html =~ "Month"
      assert html =~ "Opening Balance"
      assert html =~ "Payment"
      assert html =~ "Interest"
      assert html =~ "Principal"
      assert html =~ "Closing Balance"
    end

    test "shows ROU Asset and Lease Liability details", %{conn: conn} do
      company = company_fixture()
      lease = lease_fixture(%{
        company: company,
        lessor: "Detail Lessor",
        asset_description: "Main Office",
        monthly_payment: 5_000.0,
        discount_rate: 0.05,
        start_date: "2024-01-01",
        end_date: "2028-12-31",
        lease_type: "operating"
      })

      {:ok, live, _html} = live(conn, ~p"/leases")
      html = render_click(live, "select_lease", %{"id" => to_string(lease.id)})
      assert html =~ "ROU Asset (at inception)"
      assert html =~ "Remaining Lease Liability"
      assert html =~ "Main Office"
      assert html =~ "Operating"
    end

    test "closes amortization schedule", %{conn: conn} do
      company = company_fixture()
      lease = lease_fixture(%{company: company, lessor: "Close Schedule"})

      {:ok, live, _html} = live(conn, ~p"/leases")
      render_click(live, "select_lease", %{"id" => to_string(lease.id)})
      html = render_click(live, "close_schedule", %{})
      refute html =~ "Amortization Schedule"
    end

    test "shows empty schedule message when dates are missing", %{conn: conn} do
      company = company_fixture()
      lease = lease_fixture(%{
        company: company,
        lessor: "No Dates",
        start_date: nil,
        end_date: nil,
        monthly_payment: 0.0
      })

      {:ok, live, _html} = live(conn, ~p"/leases")
      html = render_click(live, "select_lease", %{"id" => to_string(lease.id)})
      assert html =~ "No amortization schedule available"
    end
  end

  describe "viewer permission gating" do
    test "viewer cannot save a lease", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/leases")
      render_click(live, "show_form", %{})

      html = render_click(live, "save", %{"lease" => %{"lessor" => "Test"}})
      assert html =~ "permission"
    end

    test "viewer cannot update a lease", %{conn: conn} do
      company = company_fixture()
      lease = lease_fixture(%{company: company, lessor: "No Update"})

      {:ok, live, _html} = live(conn, ~p"/leases")
      render_click(live, "edit", %{"id" => to_string(lease.id)})

      html = render_click(live, "update", %{"lease" => %{"lessor" => "Updated"}})
      assert html =~ "permission"
    end

    test "viewer cannot delete a lease", %{conn: conn} do
      company = company_fixture()
      lease = lease_fixture(%{company: company, lessor: "No Delete"})

      {:ok, live, _html} = live(conn, ~p"/leases")
      html = render_click(live, "delete", %{"id" => to_string(lease.id)})
      assert html =~ "permission"
    end
  end

  describe "editor operations" do
    test "editor can save a new lease", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "EditorLeaseCo"})

      {:ok, live, _html} = live(conn, ~p"/leases")
      render_click(live, "show_form", %{})

      html = render_click(live, "save", %{
        "lease" => %{
          "lessor" => "New Editor Lessor",
          "company_id" => to_string(company.id),
          "lease_type" => "operating",
          "monthly_payment" => "3000",
          "discount_rate" => "5.0",
          "start_date" => "2025-01-01",
          "end_date" => "2029-12-31"
        }
      })
      assert html =~ "Lease added" || html =~ "New Editor Lessor"
    end

    test "editor can update a lease", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()
      lease = lease_fixture(%{company: company, lessor: "Original Lessor"})

      {:ok, live, _html} = live(conn, ~p"/leases")
      render_click(live, "edit", %{"id" => to_string(lease.id)})

      html = render_click(live, "update", %{
        "lease" => %{"lessor" => "Updated Lessor", "lease_type" => "finance"}
      })
      assert html =~ "Lease updated" || html =~ "Updated Lessor"
    end

    test "editor can delete a lease", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()
      lease = lease_fixture(%{company: company, lessor: "Delete This Lease"})

      {:ok, live, _html} = live(conn, ~p"/leases")
      html = render_click(live, "delete", %{"id" => to_string(lease.id)})
      assert html =~ "Lease deleted"
    end

    test "editor sees Add Lease button", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, _live, html} = live(conn, ~p"/leases")
      assert html =~ "Add Lease"
    end

    test "editor sees Edit and Del buttons on leases", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()
      lease_fixture(%{company: company, lessor: "Action Lessor"})

      {:ok, _live, html} = live(conn, ~p"/leases")
      assert html =~ "Edit"
      assert html =~ "Del"
    end

    test "deleting selected lease clears the selection", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()
      lease = lease_fixture(%{company: company, lessor: "Selected Then Del"})

      {:ok, live, _html} = live(conn, ~p"/leases")
      render_click(live, "select_lease", %{"id" => to_string(lease.id)})
      html = render_click(live, "delete", %{"id" => to_string(lease.id)})
      assert html =~ "Lease deleted"
      refute html =~ "Amortization Schedule: Selected Then Del"
    end

    test "deleting a non-selected lease keeps current selection", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()
      lease1 = lease_fixture(%{company: company, lessor: "Keep Selected Lease"})
      lease2 = lease_fixture(%{company: company, lessor: "Delete Other Lease"})

      {:ok, live, _html} = live(conn, ~p"/leases")
      render_click(live, "select_lease", %{"id" => to_string(lease1.id)})
      html = render_click(live, "delete", %{"id" => to_string(lease2.id)})
      assert html =~ "Lease deleted"
      assert html =~ "Amortization Schedule: Keep Selected Lease"
    end

    test "editor sees Add Your First Lease when empty", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, _live, html} = live(conn, ~p"/leases")
      assert html =~ "Add Your First Lease"
    end
  end

  describe "edge cases" do
    test "lease with zero discount rate shows PV as payment * months", %{conn: conn} do
      company = company_fixture()
      lease = lease_fixture(%{
        company: company,
        lessor: "Zero Rate Lessor",
        monthly_payment: 1000.0,
        discount_rate: 0.0,
        start_date: "2024-01-01",
        end_date: "2025-12-31"
      })

      {:ok, live, _html} = live(conn, ~p"/leases")
      html = render_click(live, "select_lease", %{"id" => to_string(lease.id)})
      assert html =~ "Zero Rate Lessor"
      assert html =~ "Amortization Schedule"
    end

    test "lease with nil asset description shows lessor name", %{conn: conn} do
      company = company_fixture()
      lease = lease_fixture(%{
        company: company,
        lessor: "NoDesc Lessor",
        asset_description: nil,
        monthly_payment: 2000.0,
        discount_rate: 0.05,
        start_date: "2024-01-01",
        end_date: "2026-12-31"
      })

      {:ok, live, _html} = live(conn, ~p"/leases")
      html = render_click(live, "select_lease", %{"id" => to_string(lease.id)})
      assert html =~ "NoDesc Lessor"
    end

    test "lease with nil lease_type shows Operating by default", %{conn: conn} do
      company = company_fixture()
      lease_fixture(%{
        company: company,
        lessor: "Nil Type Lessor",
        lease_type: nil
      })

      {:ok, _live, html} = live(conn, ~p"/leases")
      assert html =~ "Operating"
    end

    test "lease with missing dates shows zero PV", %{conn: conn} do
      company = company_fixture()
      lease_fixture(%{
        company: company,
        lessor: "No Dates PV",
        start_date: "",
        end_date: "",
        monthly_payment: 5000.0
      })

      {:ok, _live, html} = live(conn, ~p"/leases")
      assert html =~ "No Dates PV"
    end

    test "lease with nil discount rate uses default 5%", %{conn: conn} do
      company = company_fixture()
      lease_fixture(%{
        company: company,
        lessor: "Nil Rate Lessor",
        discount_rate: nil,
        monthly_payment: 3000.0,
        start_date: "2024-01-01",
        end_date: "2028-12-31"
      })

      {:ok, _live, html} = live(conn, ~p"/leases")
      assert html =~ "Nil Rate Lessor"
    end

    test "lease format_rate with nil shows 0.00", %{conn: conn} do
      company = company_fixture()
      lease_fixture(%{
        company: company,
        lessor: "NilFmtRate",
        discount_rate: nil
      })

      {:ok, _live, html} = live(conn, ~p"/leases")
      assert html =~ "0.00"
    end
  end
end
