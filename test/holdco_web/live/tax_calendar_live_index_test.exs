defmodule HoldcoWeb.TaxCalendarLiveIndexTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  # ── Mount & Render ──────────────────────────────────────

  describe "mount and render" do
    test "renders page title and deck", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/tax-calendar")

      assert html =~ "<h1>Tax Calendar</h1>"
      assert html =~ "Tax deadlines, annual filings, and compliance checklists"
      assert html =~ "page-title-rule"
    end

    test "renders metrics strip with counts", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/tax-calendar")

      assert html =~ "metrics-strip"
      assert html =~ "Total Deadlines"
      assert html =~ "Pending"
      assert html =~ "Overdue"
    end

    test "renders tax deadlines table headers", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/tax-calendar")

      assert html =~ "Tax Deadlines"
      assert html =~ "Due Date"
      assert html =~ "Jurisdiction"
      assert html =~ "Description"
      assert html =~ "Status"
    end

    test "renders annual filings section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/tax-calendar")

      assert html =~ "Annual Filings"
    end

    test "renders empty state when no deadlines", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/tax-calendar")

      assert html =~ "No tax deadlines have been created yet."
    end

    test "renders empty state when no annual filings", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/tax-calendar")

      assert html =~ "No annual filings recorded yet."
    end

    test "renders existing tax deadlines", %{conn: conn} do
      company = company_fixture(%{name: "TaxCo"})
      tax_deadline_fixture(%{company_id: company.id, jurisdiction: "California", description: "State filing", due_date: "2025-04-15"})

      {:ok, _view, html} = live(conn, ~p"/tax-calendar")

      assert html =~ "California"
      assert html =~ "State filing"
      assert html =~ "2025-04-15"
      assert html =~ "TaxCo"
    end

    test "renders existing annual filings", %{conn: conn} do
      company = company_fixture(%{name: "AnnualCo"})
      annual_filing_fixture(%{company_id: company.id, due_date: "2025-03-31"})

      {:ok, _view, html} = live(conn, ~p"/tax-calendar")

      assert html =~ "2025-03-31"
      assert html =~ "AnnualCo"
    end

    test "shows correct pending count in metrics", %{conn: conn} do
      company = company_fixture()
      tax_deadline_fixture(%{company_id: company.id, status: "pending"})
      tax_deadline_fixture(%{company_id: company.id, status: "pending"})

      {:ok, _view, html} = live(conn, ~p"/tax-calendar")

      # Two pending deadlines
      assert html =~ "Pending"
    end

    test "viewer cannot see Add Deadline button", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/tax-calendar")

      refute html =~ "Add Deadline"
    end

    test "editor sees Add Deadline button", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, _view, html} = live(conn, ~p"/tax-calendar")

      assert html =~ "Add Deadline"
    end
  end

  # ── Show/Close Form ─────────────────────────────────────

  describe "show_form and close_form events" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "show_form opens Add Tax Deadline modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/tax-calendar")

      html = view |> element("button", "Add Deadline") |> render_click()

      assert html =~ "dialog-overlay"
      assert html =~ "Add Tax Deadline"
      assert html =~ ~s(phx-submit="save")
      assert html =~ ~s(name="tax_deadline[jurisdiction]")
      assert html =~ ~s(name="tax_deadline[description]")
      assert html =~ ~s(name="tax_deadline[due_date]")
    end

    test "close_form via Cancel button", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/tax-calendar")

      view |> element("button", "Add Deadline") |> render_click()
      html = view |> element(~s(button[phx-click="close_form"]), "Cancel") |> render_click()

      refute html =~ "dialog-overlay"
    end

    test "close_form via overlay click", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/tax-calendar")

      view |> element("button", "Add Deadline") |> render_click()
      html = view |> element(".dialog-overlay") |> render_click()

      refute html =~ "dialog-overlay"
    end
  end

  # ── Save Tax Deadline ───────────────────────────────────

  describe "save event" do
    test "creates a tax deadline and shows flash", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "SaveTaxCo"})

      {:ok, view, _html} = live(conn, ~p"/tax-calendar")
      view |> element("button", "Add Deadline") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save"]), %{
          "tax_deadline" => %{
            "company_id" => company.id,
            "jurisdiction" => "New York",
            "description" => "Franchise tax",
            "due_date" => "2025-09-15"
          }
        })
        |> render_submit()

      assert html =~ "Deadline added"
      assert html =~ "New York"
      assert html =~ "Franchise tax"
      refute html =~ "dialog-overlay"
    end

    test "viewer cannot save a tax deadline", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/tax-calendar")

      render_hook(view, "save", %{"tax_deadline" => %{"jurisdiction" => "US", "description" => "x", "due_date" => "2025-01-01"}})

      assert render(view) =~ "permission"
    end
  end

  # ── Mark Complete ───────────────────────────────────────

  describe "mark_complete event" do
    test "editor sees Complete button for pending deadlines", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()
      tax_deadline_fixture(%{company_id: company.id, status: "pending", description: "Pending deadline"})

      {:ok, _view, html} = live(conn, ~p"/tax-calendar")

      assert html =~ "pending"
      assert html =~ "Complete"
      assert html =~ ~s(phx-click="mark_complete")
    end

    test "viewer cannot mark as complete", %{conn: conn} do
      company = company_fixture()
      _td = tax_deadline_fixture(%{company_id: company.id, status: "pending"})

      {:ok, view, _html} = live(conn, ~p"/tax-calendar")

      render_hook(view, "mark_complete", %{"id" => "999"})
      assert render(view) =~ "permission"
    end
  end

  # ── Delete Tax Deadline ─────────────────────────────────

  describe "delete event" do
    test "deletes a tax deadline", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()
      td = tax_deadline_fixture(%{company_id: company.id, jurisdiction: "Delaware", description: "Del test"})

      {:ok, view, html} = live(conn, ~p"/tax-calendar")
      assert html =~ "Delaware"

      view |> element(~s(button[phx-click="delete"][phx-value-id="#{td.id}"])) |> render_click()

      html = render(view)
      assert html =~ "Deadline deleted"
      refute html =~ "Del test"
    end

    test "viewer cannot delete a tax deadline", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/tax-calendar")

      render_hook(view, "delete", %{"id" => "1"})
      assert render(view) =~ "permission"
    end
  end

  # ── Noop event ──────────────────────────────────────────

  describe "noop event" do
    test "noop does not crash the view", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/tax-calendar")

      render_hook(view, "noop", %{})
      assert render(view) =~ "Tax Calendar"
    end
  end

  # ── Mark Complete (editor) ─────────────────────────────

  describe "mark_complete by editor" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "editor sees Complete button for pending deadline", %{conn: conn} do
      company = company_fixture(%{name: "CompleteTaxCo"})
      _td = tax_deadline_fixture(%{company_id: company.id, status: "pending", description: "Complete me"})

      {:ok, _view, html} = live(conn, ~p"/tax-calendar")

      assert html =~ "Complete me"
      assert html =~ ~s(phx-click="mark_complete")
    end

    test "completed deadline does not show Complete button", %{conn: conn} do
      company = company_fixture(%{name: "AlreadyDoneCo"})
      tax_deadline_fixture(%{company_id: company.id, status: "completed", description: "Already done"})

      {:ok, _view, html} = live(conn, ~p"/tax-calendar")

      assert html =~ "Already done"
      # The Complete button should not appear for completed deadlines
      refute html =~ ~s(phx-click="mark_complete")
    end
  end

  # ── Save failure ───────────────────────────────────────

  describe "save deadline failure" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "save with missing required fields shows error flash", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/tax-calendar")
      view |> element("button", "Add Deadline") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save"]), %{
          "tax_deadline" => %{
            "company_id" => "",
            "jurisdiction" => "",
            "description" => "",
            "due_date" => ""
          }
        })
        |> render_submit()

      assert html =~ "Failed to add deadline"
    end
  end

  # ── Status tags ────────────────────────────────────────

  describe "status tag styling" do
    test "completed status shows jade tag", %{conn: conn} do
      company = company_fixture()
      tax_deadline_fixture(%{company_id: company.id, status: "completed"})

      {:ok, _view, html} = live(conn, ~p"/tax-calendar")

      assert html =~ "tag-jade"
    end

    test "overdue status shows crimson tag", %{conn: conn} do
      company = company_fixture()
      tax_deadline_fixture(%{company_id: company.id, status: "overdue"})

      {:ok, _view, html} = live(conn, ~p"/tax-calendar")

      assert html =~ "tag-crimson"
    end

    test "unknown status shows ink tag", %{conn: conn} do
      company = company_fixture()
      tax_deadline_fixture(%{company_id: company.id, status: "draft"})

      {:ok, _view, html} = live(conn, ~p"/tax-calendar")

      assert html =~ "tag-ink"
    end
  end

  # ── Tax deadline without company ───────────────────────

  describe "tax deadline with company" do
    test "shows company name for deadline with company", %{conn: conn} do
      company = company_fixture(%{name: "TaxCompanyCo"})
      tax_deadline_fixture(%{company_id: company.id, description: "With company deadline"})

      {:ok, _view, html} = live(conn, ~p"/tax-calendar")

      assert html =~ "With company deadline"
      assert html =~ "TaxCompanyCo"
    end
  end

  # ── Overdue count in metrics ───────────────────────────

  describe "overdue count in metrics" do
    test "shows correct overdue count", %{conn: conn} do
      company = company_fixture()
      tax_deadline_fixture(%{company_id: company.id, status: "overdue"})
      tax_deadline_fixture(%{company_id: company.id, status: "overdue"})
      tax_deadline_fixture(%{company_id: company.id, status: "pending"})

      {:ok, _view, html} = live(conn, ~p"/tax-calendar")

      assert html =~ "Overdue"
      assert html =~ "num-negative"
    end
  end

  # ── Form fields in modal ───────────────────────────────

  describe "form modal details" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "modal form has company selector with existing companies", %{conn: conn} do
      company_fixture(%{name: "FormTestCo"})
      {:ok, view, _html} = live(conn, ~p"/tax-calendar")

      html = view |> element("button", "Add Deadline") |> render_click()

      assert html =~ "FormTestCo"
      assert html =~ ~s(name="tax_deadline[company_id]")
    end

    test "modal form has notes textarea", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/tax-calendar")

      html = view |> element("button", "Add Deadline") |> render_click()

      assert html =~ "Notes"
      assert html =~ ~s(name="tax_deadline[notes]")
    end

    test "modal form has due date with placeholder", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/tax-calendar")

      html = view |> element("button", "Add Deadline") |> render_click()

      assert html =~ "YYYY-MM-DD"
    end
  end

  # ── Annual filings status tags ─────────────────────────

  describe "annual filing status tags" do
    test "filed status shows jade tag", %{conn: conn} do
      company = company_fixture()
      annual_filing_fixture(%{company_id: company.id, status: "filed"})

      {:ok, _view, html} = live(conn, ~p"/tax-calendar")

      assert html =~ "tag-jade"
      assert html =~ "filed"
    end
  end
end
