defmodule HoldcoWeb.CovenantLiveIndexTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "Index" do
    test "renders Loan Covenants page", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/covenants")
      assert html =~ "Loan Covenants"
      assert html =~ "Monitor loan covenant compliance across all entities"
    end

    test "shows metrics strip", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/covenants")
      assert html =~ "Total Covenants"
      assert html =~ "Compliant"
      assert html =~ "Warning"
      assert html =~ "Breached"
    end

    test "shows covenants table with headers", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/covenants")
      assert html =~ "Name"
      assert html =~ "Type"
      assert html =~ "Metric"
      assert html =~ "Threshold"
      assert html =~ "Current Value"
      assert html =~ "Status"
    end

    test "shows empty state when no covenants", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/covenants")
      assert html =~ "No loan covenants tracked yet"
    end

    test "shows action buttons", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/covenants")
      assert html =~ "Check All"
      assert html =~ "Add Covenant"
    end

    test "opens add covenant form", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/covenants")
      html = render_click(live, "show_form")
      assert html =~ "Add Covenant"
      assert html =~ "Covenant Type"
    end
  end

  describe "covenant data display" do
    test "displays covenant in the table", %{conn: conn} do
      _covenant = loan_covenant_fixture(%{name: "Debt Ratio Covenant", status: "compliant", covenant_type: "financial"})

      {:ok, _live, html} = live(conn, ~p"/covenants")
      assert html =~ "Debt Ratio Covenant"
      assert html =~ "compliant"
      assert html =~ "financial"
    end
  end

  describe "show_form and close_form events" do
    test "show_form opens the add form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/covenants")
      html = render_click(view, "show_form", %{})
      assert html =~ "Add Covenant"
      assert html =~ "Name"
      assert html =~ "Covenant Type"
      assert html =~ "Metric"
    end

    test "close_form closes the form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/covenants")
      render_click(view, "show_form", %{})
      html = render_click(view, "close_form", %{})
      refute html =~ "dialog-overlay"
    end
  end

  describe "filter_company event" do
    test "filters covenants by company", %{conn: conn} do
      company = company_fixture(%{name: "Covenant Filter Co"})
      loan_covenant_fixture(%{company: company, name: "Company Specific Covenant"})

      {:ok, view, _html} = live(conn, ~p"/covenants")
      html = render_change(view, "filter_company", %{"company_id" => to_string(company.id)})
      assert html =~ "Company Specific Covenant"
    end

    test "filters with empty company_id shows all", %{conn: conn} do
      loan_covenant_fixture(%{name: "Global Covenant"})

      {:ok, view, _html} = live(conn, ~p"/covenants")
      html = render_change(view, "filter_company", %{"company_id" => ""})
      assert html =~ "Global Covenant"
    end
  end

  describe "edit event" do
    test "opens edit form with existing data", %{conn: conn} do
      covenant = loan_covenant_fixture(%{name: "Edit This Covenant"})

      {:ok, view, _html} = live(conn, ~p"/covenants")
      html = render_click(view, "edit", %{"id" => to_string(covenant.id)})
      assert html =~ "Edit Covenant"
      assert html =~ "Edit This Covenant"
    end
  end

  describe "save event" do
    test "creates a new covenant", %{conn: conn} do
      company = company_fixture()

      {:ok, view, _html} = live(conn, ~p"/covenants")
      render_click(view, "show_form", %{})

      html =
        render_click(view, "save", %{
          "covenant" => %{
            "name" => "New Test Covenant",
            "covenant_type" => "financial",
            "metric" => "debt_to_equity",
            "threshold" => "3.0",
            "comparison" => "below",
            "status" => "compliant",
            "measurement_frequency" => "quarterly",
            "company_id" => to_string(company.id)
          }
        })

      assert html =~ "Covenant created"
    end

    test "save with invalid data shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/covenants")
      render_click(view, "show_form", %{})

      html =
        render_click(view, "save", %{
          "covenant" => %{"name" => "", "covenant_type" => ""}
        })

      assert html =~ "Failed to create covenant"
    end
  end

  describe "update event" do
    test "updates an existing covenant", %{conn: conn} do
      covenant = loan_covenant_fixture(%{name: "Update Me Covenant"})

      {:ok, view, _html} = live(conn, ~p"/covenants")
      render_click(view, "edit", %{"id" => to_string(covenant.id)})

      html =
        render_click(view, "update", %{
          "covenant" => %{
            "name" => "Updated Covenant Name",
            "status" => "warning"
          }
        })

      assert html =~ "Covenant updated"
    end
  end

  describe "delete event" do
    test "deletes a covenant", %{conn: conn} do
      covenant = loan_covenant_fixture(%{name: "Delete Me Covenant"})

      {:ok, view, _html} = live(conn, ~p"/covenants")
      html = render_click(view, "delete", %{"id" => to_string(covenant.id)})
      assert html =~ "Covenant deleted"
    end
  end

  describe "check_all event" do
    test "checks all covenants", %{conn: conn} do
      loan_covenant_fixture(%{name: "Check All Covenant"})

      {:ok, view, _html} = live(conn, ~p"/covenants")
      html = render_click(view, "check_all", %{})
      assert html =~ "All covenants checked"
    end

    test "check_all works with company filter", %{conn: conn} do
      company = company_fixture()
      loan_covenant_fixture(%{company: company, name: "Company Covenant"})

      {:ok, view, _html} = live(conn, ~p"/covenants")
      render_change(view, "filter_company", %{"company_id" => to_string(company.id)})
      html = render_click(view, "check_all", %{})
      assert html =~ "All covenants checked"
    end
  end

  describe "noop event" do
    test "noop does not change the page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/covenants")
      html = render_click(view, "noop", %{})
      assert html =~ "Loan Covenants"
    end
  end
end
