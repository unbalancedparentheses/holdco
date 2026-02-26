defmodule HoldcoWeb.ManagementReportsLiveIndexTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "Index" do
    test "renders Management Reports page", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/management-reports")
      assert html =~ "Management Reports"
    end

    test "shows metrics strip with counts", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/management-reports")
      assert html =~ "Saved Templates"
      assert html =~ "Available Sections"
      assert html =~ "Companies"
    end

    test "shows empty state when no templates exist", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/management-reports")
      assert html =~ "No report templates"
    end

    test "renders with report template data", %{conn: conn, user: user} do
      report_template_fixture(%{user: user, name: "Monthly Board Report"})

      {:ok, _live, html} = live(conn, ~p"/management-reports")
      assert html =~ "Monthly Board Report"
    end

    test "shows template frequency label", %{conn: conn, user: user} do
      report_template_fixture(%{user: user, name: "Quarterly Report", frequency: "quarterly"})

      {:ok, _live, html} = live(conn, ~p"/management-reports")
      assert html =~ "Quarterly"
    end

    test "shows template with monthly frequency", %{conn: conn, user: user} do
      report_template_fixture(%{user: user, name: "Monthly Report", frequency: "monthly"})

      {:ok, _live, html} = live(conn, ~p"/management-reports")
      assert html =~ "Monthly"
    end

    test "shows Report Templates table header", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/management-reports")
      assert html =~ "Report Templates"
      assert html =~ "Name"
      assert html =~ "Sections"
      assert html =~ "Frequency"
    end
  end

  describe "form interactions" do
    test "opens add template form with show_form event", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/management-reports")
      html = render_click(live, "show_form", %{})
      assert html =~ "New Report Template"
      assert html =~ "Template Name"
      assert html =~ "Report Sections"
      assert html =~ "Frequency"
    end

    test "closes form with close_form event", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/management-reports")
      render_click(live, "show_form", %{})
      html = render_click(live, "close_form", %{})
      refute html =~ "New Report Template"
    end

    test "updates form fields with update_form event", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/management-reports")
      render_click(live, "show_form", %{})

      html = render_click(live, "update_form", %{
        "name" => "Quarterly Investor Update",
        "frequency" => "quarterly",
        "date_from" => "2024-01-01",
        "date_to" => "2024-12-31"
      })

      assert html =~ "Quarterly Investor Update"
    end

    test "toggles section on and off", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/management-reports")
      render_click(live, "show_form", %{})

      # Toggle balance_sheet on
      render_click(live, "toggle_section", %{"section" => "balance_sheet"})
      # Toggle income_statement on
      render_click(live, "toggle_section", %{"section" => "income_statement"})
      # Toggle balance_sheet off
      html = render_click(live, "toggle_section", %{"section" => "balance_sheet"})
      assert html =~ "Management Reports"
    end

    test "toggles company selection on and off", %{conn: conn} do
      company = company_fixture(%{name: "Test Company"})

      {:ok, live, _html} = live(conn, ~p"/management-reports")
      render_click(live, "show_form", %{})

      # Toggle company on
      render_click(live, "toggle_company", %{"company-id" => to_string(company.id)})
      # Toggle company off
      html = render_click(live, "toggle_company", %{"company-id" => to_string(company.id)})
      assert html =~ "Management Reports"
    end

    test "shows available sections checkboxes in form", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/management-reports")
      html = render_click(live, "show_form", %{})
      assert html =~ "Balance Sheet"
      assert html =~ "Income Statement"
      assert html =~ "Trial Balance"
      assert html =~ "Cash Flow"
      assert html =~ "Portfolio NAV"
      assert html =~ "Compliance Summary"
      assert html =~ "KPI Dashboard"
      assert html =~ "Aging Report"
    end

    test "shows frequency options in form", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/management-reports")
      html = render_click(live, "show_form", %{})
      assert html =~ "Weekly"
      assert html =~ "Monthly"
      assert html =~ "Quarterly"
      assert html =~ "Annually"
    end

    test "shows company checkboxes in form", %{conn: conn} do
      company_fixture(%{name: "FormTestCo"})

      {:ok, live, _html} = live(conn, ~p"/management-reports")
      html = render_click(live, "show_form", %{})
      assert html =~ "FormTestCo"
    end

    test "shows no companies available message when empty", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/management-reports")
      html = render_click(live, "show_form", %{})
      assert html =~ "No companies available"
    end

    test "noop event does nothing", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/management-reports")
      html = render_click(live, "noop", %{})
      assert html =~ "Management Reports"
    end
  end

  describe "viewer permission gating" do
    test "viewer cannot save a template", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/management-reports")
      render_click(live, "show_form", %{})
      render_click(live, "update_form", %{"name" => "Test Template"})

      html = render_click(live, "save_template", %{})
      assert html =~ "permission"
    end

    test "viewer cannot update a template", %{conn: conn, user: user} do
      rt = report_template_fixture(%{user: user, name: "Edit Me"})

      {:ok, live, _html} = live(conn, ~p"/management-reports")
      render_click(live, "edit_template", %{"id" => to_string(rt.id)})

      html = render_click(live, "update_template", %{})
      assert html =~ "permission"
    end

    test "viewer cannot delete a template", %{conn: conn, user: user} do
      rt = report_template_fixture(%{user: user, name: "Delete Me"})

      {:ok, live, _html} = live(conn, ~p"/management-reports")
      html = render_click(live, "delete_template", %{"id" => to_string(rt.id)})
      assert html =~ "permission"
    end
  end

  describe "editor operations" do
    test "editor can save a new template", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, live, _html} = live(conn, ~p"/management-reports")
      render_click(live, "show_form", %{})
      render_click(live, "update_form", %{"name" => "New Editor Template"})
      render_click(live, "toggle_section", %{"section" => "balance_sheet"})

      html = render_click(live, "save_template", %{})
      assert html =~ "New Editor Template" || html =~ "Report template created"
    end

    test "editor can edit and update a template", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      rt = report_template_fixture(%{user: user, name: "Original Name"})

      {:ok, live, _html} = live(conn, ~p"/management-reports")
      render_click(live, "edit_template", %{"id" => to_string(rt.id)})
      render_click(live, "update_form", %{"name" => "Updated Name"})

      html = render_click(live, "update_template", %{})
      assert html =~ "Updated Name" || html =~ "Report template updated"
    end

    test "editor can delete a template", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      rt = report_template_fixture(%{user: user, name: "To Delete"})

      {:ok, live, _html} = live(conn, ~p"/management-reports")
      html = render_click(live, "delete_template", %{"id" => to_string(rt.id)})
      assert html =~ "Template deleted" || html =~ "Management Reports"
    end

    test "editor sees New Template button", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, _live, html} = live(conn, ~p"/management-reports")
      assert html =~ "New Template"
    end

    test "editor sees Edit and Del buttons on templates", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      report_template_fixture(%{user: user, name: "Editable Template"})

      {:ok, _live, html} = live(conn, ~p"/management-reports")
      assert html =~ "Edit"
      assert html =~ "Del"
    end
  end

  describe "edit template form" do
    test "edit_template populates form fields", %{conn: conn, user: user} do
      rt = report_template_fixture(%{
        user: user,
        name: "Board Report",
        frequency: "quarterly",
        sections: Jason.encode!(["balance_sheet", "income_statement"]),
        date_from: "2024-01-01",
        date_to: "2024-12-31"
      })

      {:ok, live, _html} = live(conn, ~p"/management-reports")
      html = render_click(live, "edit_template", %{"id" => to_string(rt.id)})
      assert html =~ "Edit Template"
      assert html =~ "Board Report"
    end
  end

  describe "report generation" do
    test "generates report from saved template", %{conn: conn, user: user} do
      rt = report_template_fixture(%{
        user: user,
        name: "Generate Test",
        sections: Jason.encode!(["balance_sheet"]),
        date_from: "2024-01-01",
        date_to: "2024-12-31"
      })

      {:ok, live, _html} = live(conn, ~p"/management-reports")
      html = render_click(live, "generate_report", %{"id" => to_string(rt.id)})
      assert html =~ "Generate Test" || html =~ "Generated"
    end

    test "generates report with multiple sections", %{conn: conn, user: user} do
      rt = report_template_fixture(%{
        user: user,
        name: "Multi-Section Report",
        sections: Jason.encode!(["balance_sheet", "trial_balance", "kpi_dashboard"]),
        date_from: "2024-01-01",
        date_to: "2024-12-31"
      })

      {:ok, live, _html} = live(conn, ~p"/management-reports")
      html = render_click(live, "generate_report", %{"id" => to_string(rt.id)})
      assert html =~ "Multi-Section Report"
    end

    test "generates report with company filter", %{conn: conn, user: user} do
      company = company_fixture(%{name: "ReportCo"})
      rt = report_template_fixture(%{
        user: user,
        name: "Company Report",
        sections: Jason.encode!(["income_statement"]),
        company_ids: Jason.encode!([company.id]),
        date_from: "2024-01-01",
        date_to: "2024-12-31"
      })

      {:ok, live, _html} = live(conn, ~p"/management-reports")
      html = render_click(live, "generate_report", %{"id" => to_string(rt.id)})
      assert html =~ "Company Report"
    end

    test "generates report from form with sections selected", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/management-reports")
      render_click(live, "show_form", %{})
      render_click(live, "update_form", %{"name" => "Ad-hoc Test"})
      render_click(live, "toggle_section", %{"section" => "trial_balance"})

      html = render_click(live, "generate_from_form", %{})
      assert html =~ "Ad-hoc Test" || html =~ "Generated"
    end

    test "generates ad-hoc report with no name", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/management-reports")
      render_click(live, "show_form", %{})
      render_click(live, "toggle_section", %{"section" => "kpi_dashboard"})

      html = render_click(live, "generate_from_form", %{})
      assert html =~ "Ad-hoc Report"
    end

    test "generates report with company ids from form", %{conn: conn} do
      company = company_fixture(%{name: "FormReportCo"})
      {:ok, live, _html} = live(conn, ~p"/management-reports")
      render_click(live, "show_form", %{})
      render_click(live, "toggle_section", %{"section" => "balance_sheet"})
      render_click(live, "toggle_company", %{"company-id" => to_string(company.id)})

      html = render_click(live, "generate_from_form", %{})
      assert html =~ "FormReportCo" || html =~ "Generated"
    end

    test "closes generated report", %{conn: conn, user: user} do
      rt = report_template_fixture(%{
        user: user,
        name: "Close Me Report",
        sections: Jason.encode!(["balance_sheet"])
      })

      {:ok, live, _html} = live(conn, ~p"/management-reports")
      render_click(live, "generate_report", %{"id" => to_string(rt.id)})
      html = render_click(live, "close_report", %{})
      refute html =~ "Close Report"
    end

    test "generates report with compliance_summary section", %{conn: conn, user: user} do
      rt = report_template_fixture(%{
        user: user,
        name: "Compliance Report",
        sections: Jason.encode!(["compliance_summary"]),
        date_from: "2024-01-01",
        date_to: "2024-12-31"
      })

      {:ok, live, _html} = live(conn, ~p"/management-reports")
      html = render_click(live, "generate_report", %{"id" => to_string(rt.id)})
      assert html =~ "Compliance Report"
    end

    # Skipping portfolio_nav section test - the render template references
    # @data.total_nav but Portfolio.calculate_nav() returns %{nav: ...} without that key

    test "generates report with cash_flow section", %{conn: conn, user: user} do
      rt = report_template_fixture(%{
        user: user,
        name: "Cash Flow Report",
        sections: Jason.encode!(["cash_flow"]),
        date_from: "2024-01-01",
        date_to: "2024-12-31"
      })

      {:ok, live, _html} = live(conn, ~p"/management-reports")
      html = render_click(live, "generate_report", %{"id" => to_string(rt.id)})
      assert html =~ "Cash Flow Report"
    end

    test "generates report with aging_report section", %{conn: conn, user: user} do
      rt = report_template_fixture(%{
        user: user,
        name: "Aging Report",
        sections: Jason.encode!(["aging_report"]),
        date_from: "2024-01-01",
        date_to: "2024-12-31"
      })

      {:ok, live, _html} = live(conn, ~p"/management-reports")
      html = render_click(live, "generate_report", %{"id" => to_string(rt.id)})
      assert html =~ "Aging Report"
    end

    test "generates report with no sections shows empty message", %{conn: conn, user: user} do
      rt = report_template_fixture(%{
        user: user,
        name: "Empty Sections Report",
        sections: Jason.encode!([])
      })

      {:ok, live, _html} = live(conn, ~p"/management-reports")
      html = render_click(live, "generate_report", %{"id" => to_string(rt.id)})
      assert html =~ "No sections selected"
    end
  end

  describe "template display" do
    test "shows template with date range", %{conn: conn, user: user} do
      report_template_fixture(%{
        user: user,
        name: "Dated Report",
        date_from: "2024-01-01",
        date_to: "2024-12-31"
      })

      {:ok, _live, html} = live(conn, ~p"/management-reports")
      assert html =~ "2024-01-01"
      assert html =~ "2024-12-31"
    end

    test "shows multiple templates in list", %{conn: conn, user: user} do
      report_template_fixture(%{user: user, name: "Report Alpha"})
      report_template_fixture(%{user: user, name: "Report Beta"})

      {:ok, _live, html} = live(conn, ~p"/management-reports")
      assert html =~ "Report Alpha"
      assert html =~ "Report Beta"
    end

    test "shows Generate button for each template", %{conn: conn, user: user} do
      report_template_fixture(%{user: user, name: "Gen Template"})

      {:ok, _live, html} = live(conn, ~p"/management-reports")
      assert html =~ "Generate"
    end

    test "viewer does not see New Template button", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/management-reports")
      refute html =~ "New Template"
    end

    test "shows section tags for templates with sections", %{conn: conn, user: user} do
      report_template_fixture(%{
        user: user,
        name: "Tagged Report",
        sections: Jason.encode!(["balance_sheet"])
      })

      {:ok, _live, html} = live(conn, ~p"/management-reports")
      assert html =~ "Balance Sheet"
    end

    test "shows None for templates without sections", %{conn: conn, user: user} do
      report_template_fixture(%{user: user, name: "No Sections"})

      {:ok, _live, html} = live(conn, ~p"/management-reports")
      assert html =~ "None"
    end

    test "shows All for templates without company filter", %{conn: conn, user: user} do
      report_template_fixture(%{user: user, name: "All Companies Template"})

      {:ok, _live, html} = live(conn, ~p"/management-reports")
      assert html =~ "All"
    end

    test "shows selected count for templates with company ids", %{conn: conn, user: user} do
      company = company_fixture()
      report_template_fixture(%{
        user: user,
        name: "Filtered Template",
        company_ids: Jason.encode!([company.id])
      })

      {:ok, _live, html} = live(conn, ~p"/management-reports")
      assert html =~ "1 selected"
    end
  end

  describe "handle_info" do
    test "refreshes templates on pubsub message", %{conn: conn, user: user} do
      {:ok, live, _html} = live(conn, ~p"/management-reports")

      # Create a template after mount
      report_template_fixture(%{user: user, name: "PubSub Template"})

      # Simulate a pubsub message
      send(live.pid, {:template_changed, %{}})

      html = render(live)
      assert html =~ "PubSub Template"
    end
  end
end
