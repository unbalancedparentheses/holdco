defmodule HoldcoWeb.CalendarLiveIndexTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  # ── Show/Close Form ─────────────────────────────────────

  describe "show_form and close_form events" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "show_form opens Add Tax Deadline modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/calendar")

      html = view |> element("button", "Add Deadline") |> render_click()

      assert html =~ "dialog-overlay"
      assert html =~ "Add Tax Deadline"
      assert html =~ ~s(phx-submit="save")
      assert html =~ ~s(name="tax_deadline[jurisdiction]")
      assert html =~ ~s(name="tax_deadline[description]")
      assert html =~ ~s(name="tax_deadline[due_date]")
    end

    test "close_form via Cancel button", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/calendar")

      view |> element("button", "Add Deadline") |> render_click()
      html = view |> element(~s(button[phx-click="close_form"]), "Cancel") |> render_click()

      refute html =~ "dialog-overlay"
    end

    test "close_form via overlay click", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/calendar")

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

      {:ok, view, _html} = live(conn, ~p"/calendar")
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

  end

  # ── Mark Complete ───────────────────────────────────────

  describe "mark_complete event" do
    test "editor sees Complete button for pending deadlines", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()
      tax_deadline_fixture(%{company_id: company.id, status: "pending", description: "Pending deadline"})

      {:ok, _view, html} = live(conn, ~p"/calendar")

      assert html =~ "pending"
      assert html =~ "Complete"
      assert html =~ ~s(phx-click="mark_complete")
    end

  end

  # ── Delete Tax Deadline ─────────────────────────────────

  describe "delete event" do
    test "deletes a tax deadline", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()
      td = tax_deadline_fixture(%{company_id: company.id, jurisdiction: "Delaware", description: "Del test"})

      {:ok, view, html} = live(conn, ~p"/calendar")
      assert html =~ "Delaware"

      view |> element(~s(button[phx-click="delete"][phx-value-id="#{td.id}"])) |> render_click()

      html = render(view)
      assert html =~ "Deadline deleted"
      refute html =~ "Del test"
    end

  end

  # ── Mark Complete (editor) ─────────────────────────────

  describe "mark_complete by editor" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "completed deadline does not show Complete button", %{conn: conn} do
      company = company_fixture(%{name: "AlreadyDoneCo"})
      tax_deadline_fixture(%{company_id: company.id, status: "completed", description: "Already done"})

      {:ok, _view, html} = live(conn, ~p"/calendar")

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
      {:ok, view, _html} = live(conn, ~p"/calendar")
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

  # ── Form fields in modal ───────────────────────────────

  describe "form modal details" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "modal form has company selector with existing companies", %{conn: conn} do
      company_fixture(%{name: "FormTestCo"})
      {:ok, view, _html} = live(conn, ~p"/calendar")

      html = view |> element("button", "Add Deadline") |> render_click()

      assert html =~ "FormTestCo"
      assert html =~ ~s(name="tax_deadline[company_id]")
    end
  end
end
