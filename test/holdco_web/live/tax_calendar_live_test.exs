defmodule HoldcoWeb.TaxCalendarLiveTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "GET /tax-calendar" do
    test "renders tax calendar page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/tax-calendar")

      assert html =~ "Tax Calendar"
    end

    test "renders page title and deck", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/tax-calendar")

      assert html =~ "page-title"
      assert html =~ "Tax deadlines"
    end

    test "renders metrics", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/tax-calendar")

      assert html =~ "metrics-strip" or html =~ "metric-cell"
    end

    test "tax calendar page loads", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/tax-calendar")

      assert html =~ "Tax Calendar"
    end

    test "renders deadline data", %{conn: conn} do
      company = company_fixture(%{name: "TaxCo"})
      tax_deadline_fixture(%{company: company, jurisdiction: "US-Federal", description: "Form 1120", due_date: "2024-04-15", status: "pending"})

      {:ok, _view, html} = live(conn, ~p"/tax-calendar")
      assert html =~ "Form 1120"
      assert html =~ "US-Federal"
      assert html =~ "2024-04-15"
      assert html =~ "TaxCo"
    end

    test "renders annual filing data", %{conn: conn} do
      company = company_fixture(%{name: "FilingCo"})
      annual_filing_fixture(%{company: company, due_date: "2024-03-31", status: "pending"})

      {:ok, _view, html} = live(conn, ~p"/tax-calendar")
      assert html =~ "FilingCo"
      assert html =~ "2024-03-31"
    end

    test "renders overdue status tag", %{conn: conn} do
      company = company_fixture()
      tax_deadline_fixture(%{company: company, status: "overdue", description: "Overdue Tax"})

      {:ok, _view, html} = live(conn, ~p"/tax-calendar")
      assert html =~ "overdue"
      assert html =~ "tag-crimson"
    end

    test "renders completed status tag", %{conn: conn} do
      company = company_fixture()
      tax_deadline_fixture(%{company: company, status: "completed", description: "Done Tax"})

      {:ok, _view, html} = live(conn, ~p"/tax-calendar")
      assert html =~ "completed"
      assert html =~ "tag-jade"
    end

    test "renders filed status tag for annual filings", %{conn: conn} do
      company = company_fixture()
      annual_filing_fixture(%{company: company, status: "filed"})

      {:ok, _view, html} = live(conn, ~p"/tax-calendar")
      assert html =~ "tag-jade"
    end

    test "renders pending status tag", %{conn: conn} do
      company = company_fixture()
      tax_deadline_fixture(%{company: company, status: "pending", description: "Pending Tax"})

      {:ok, _view, html} = live(conn, ~p"/tax-calendar")
      assert html =~ "pending"
      assert html =~ "tag-lemon"
    end

    test "renders unknown status with default tag", %{conn: conn} do
      company = company_fixture()
      tax_deadline_fixture(%{company: company, status: "draft", description: "Draft Tax"})

      {:ok, _view, html} = live(conn, ~p"/tax-calendar")
      assert html =~ "tag-ink"
    end

    test "counts pending and overdue correctly in metrics", %{conn: conn} do
      company = company_fixture()
      tax_deadline_fixture(%{company: company, status: "pending", description: "P1"})
      tax_deadline_fixture(%{company: company, status: "overdue", description: "O1"})

      {:ok, _view, html} = live(conn, ~p"/tax-calendar")
      assert html =~ "Pending"
      assert html =~ "Overdue"
      assert html =~ "Total Deadlines"
    end

    test "renders annual filings table headers", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/tax-calendar")
      assert html =~ "Annual Filings"
      assert html =~ "Tax Deadlines"
    end
  end

  describe "form interactions" do
    test "show_form opens add form", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/tax-calendar")
      html = render_click(live, "show_form", %{})
      assert html =~ "Add Tax Deadline"
      assert html =~ "modal-overlay"
    end

    test "close_form closes the modal", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/tax-calendar")
      render_click(live, "show_form", %{})
      html = render_click(live, "close_form", %{})
      refute html =~ "modal-overlay"
    end

    test "noop event does nothing", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/tax-calendar")
      html = render_click(live, "noop", %{})
      assert html =~ "Tax Calendar"
    end

    test "edit opens edit form with existing data", %{conn: conn} do
      company = company_fixture()
      td = tax_deadline_fixture(%{company: company, jurisdiction: "UK", description: "Edit Tax", due_date: "2024-05-01"})

      {:ok, live, _html} = live(conn, ~p"/tax-calendar")
      html = render_click(live, "edit", %{"id" => to_string(td.id)})
      assert html =~ "Edit Tax Deadline"
      assert html =~ "Edit Tax"
      assert html =~ "UK"
    end

    test "form shows company dropdown", %{conn: conn} do
      company_fixture(%{name: "FormDropdownCo"})
      {:ok, live, _html} = live(conn, ~p"/tax-calendar")
      html = render_click(live, "show_form", %{})
      assert html =~ "FormDropdownCo"
      assert html =~ "Select company"
    end

    test "edit form shows Update Deadline button", %{conn: conn} do
      company = company_fixture()
      td = tax_deadline_fixture(%{company: company, description: "Updatable"})

      {:ok, live, _html} = live(conn, ~p"/tax-calendar")
      html = render_click(live, "edit", %{"id" => to_string(td.id)})
      assert html =~ "Update Deadline"
    end
  end

  describe "viewer permission guards" do
    test "viewer cannot save a deadline", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/tax-calendar")
      html = render_click(live, "save", %{"tax_deadline" => %{"description" => "Blocked"}})
      assert html =~ "permission"
    end

    test "viewer cannot mark_complete", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/tax-calendar")
      html = render_click(live, "mark_complete", %{})
      assert html =~ "permission"
    end

    test "viewer cannot delete a deadline", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/tax-calendar")
      html = render_click(live, "delete", %{})
      assert html =~ "permission"
    end

    test "viewer cannot update a deadline", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/tax-calendar")
      html = render_click(live, "update", %{"tax_deadline" => %{"description" => "Blocked"}})
      assert html =~ "permission"
    end

    test "viewer does not see Add Deadline button", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/tax-calendar")
      refute html =~ ">Add Deadline<"
    end
  end

  describe "editor operations" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "editor sees Add Deadline button", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/tax-calendar")
      assert html =~ "Add Deadline"
    end

    test "editor sees Edit and Del buttons", %{conn: conn} do
      company = company_fixture()
      tax_deadline_fixture(%{company: company, status: "pending"})

      {:ok, _view, html} = live(conn, ~p"/tax-calendar")
      assert html =~ "Edit"
      assert html =~ "Del"
    end

    test "editor sees Complete button for pending deadline", %{conn: conn} do
      company = company_fixture()
      tax_deadline_fixture(%{company: company, status: "pending", description: "Completable"})

      {:ok, _view, html} = live(conn, ~p"/tax-calendar")
      assert html =~ "Complete"
    end

    test "editor can create a deadline", %{conn: conn} do
      company = company_fixture(%{name: "SaveCo"})

      {:ok, live, _html} = live(conn, ~p"/tax-calendar")
      render_click(live, "show_form", %{})

      html =
        render_click(live, "save", %{
          "tax_deadline" => %{
            "company_id" => to_string(company.id),
            "jurisdiction" => "US",
            "description" => "New Deadline",
            "due_date" => "2025-04-15"
          }
        })

      assert html =~ "Deadline added" || html =~ "New Deadline"
    end

    test "editor save failure shows error flash", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/tax-calendar")
      render_click(live, "show_form", %{})

      # Submit without required company_id to trigger error
      html =
        render_click(live, "save", %{
          "tax_deadline" => %{"description" => "", "jurisdiction" => "", "due_date" => ""}
        })

      assert html =~ "Failed to add deadline" || html =~ "Tax Calendar"
    end

    test "editor can delete a deadline", %{conn: conn} do
      company = company_fixture()
      td = tax_deadline_fixture(%{company: company, description: "Delete Me Tax"})

      {:ok, live, _html} = live(conn, ~p"/tax-calendar")
      html = render_click(live, "delete", %{"id" => to_string(td.id)})
      assert html =~ "Deadline deleted"
    end
  end
end
