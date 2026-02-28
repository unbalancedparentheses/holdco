defmodule HoldcoWeb.CorporateActionLiveIndexTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "Index" do
    test "renders Corporate Actions page", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/corporate-actions")
      assert html =~ "Corporate Actions"
      assert html =~ "Track splits, mergers, spin-offs, and other corporate actions"
    end

    test "shows company filter", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/corporate-actions")
      assert html =~ "Select Company"
    end

    test "shows prompt to select company when none selected", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/corporate-actions")
      assert html =~ "Select a company to view its corporate actions"
    end
  end

  describe "filter_company event" do
    test "selecting a company shows its corporate actions", %{conn: conn} do
      company = company_fixture(%{name: "ActionCo"})
      corporate_action_fixture(%{company: company, description: "2-for-1 stock split"})

      {:ok, view, _html} = live(conn, ~p"/corporate-actions")

      html =
        view
        |> form("form[phx-change=\"filter_company\"]", %{"company_id" => to_string(company.id)})
        |> render_change()

      assert html =~ "2-for-1 stock split"
      assert html =~ "All Corporate Actions"
    end

    test "selecting empty company clears actions", %{conn: conn} do
      company = company_fixture(%{name: "ClearActionCo"})
      corporate_action_fixture(%{company: company, description: "Will vanish"})

      {:ok, view, _html} = live(conn, ~p"/corporate-actions")

      # Select company
      view
      |> form("form[phx-change=\"filter_company\"]", %{"company_id" => to_string(company.id)})
      |> render_change()

      # Clear selection
      html =
        view
        |> form("form[phx-change=\"filter_company\"]", %{"company_id" => ""})
        |> render_change()

      refute html =~ "Will vanish"
      assert html =~ "Select a company to view its corporate actions"
    end
  end

  describe "show_form and close_form events" do
    test "show_form opens the add action modal", %{conn: conn} do
      company = company_fixture(%{name: "FormActionCo"})
      {:ok, view, _html} = live(conn, ~p"/corporate-actions")

      view
      |> form("form[phx-change=\"filter_company\"]", %{"company_id" => to_string(company.id)})
      |> render_change()

      html = render_click(view, "show_form", %{})
      assert html =~ "Add Action"
      assert html =~ "modal-backdrop"
    end

    test "close_form closes the modal", %{conn: conn} do
      company = company_fixture(%{name: "CloseActionCo"})
      {:ok, view, _html} = live(conn, ~p"/corporate-actions")

      view
      |> form("form[phx-change=\"filter_company\"]", %{"company_id" => to_string(company.id)})
      |> render_change()

      render_click(view, "show_form", %{})
      html = render_click(view, "close_form", %{})
      refute html =~ "modal-backdrop"
    end
  end

  describe "edit event" do
    test "edit opens the form with action data", %{conn: conn} do
      company = company_fixture(%{name: "EditActionCo"})
      action = corporate_action_fixture(%{company: company, description: "Edit this action"})

      {:ok, view, _html} = live(conn, ~p"/corporate-actions")

      view
      |> form("form[phx-change=\"filter_company\"]", %{"company_id" => to_string(company.id)})
      |> render_change()

      html = render_click(view, "edit", %{"id" => to_string(action.id)})
      assert html =~ "Edit Action"
      assert html =~ "Update Action"
    end
  end

  describe "save event" do
    test "saving a new corporate action shows success flash", %{conn: conn} do
      company = company_fixture(%{name: "SaveActionCo"})
      {:ok, view, _html} = live(conn, ~p"/corporate-actions")

      view
      |> form("form[phx-change=\"filter_company\"]", %{"company_id" => to_string(company.id)})
      |> render_change()

      render_click(view, "show_form", %{})

      html =
        view
        |> form("form[phx-submit=\"save\"]", %{
          "corporate_action" => %{
            "company_id" => to_string(company.id),
            "action_type" => "stock_split",
            "announcement_date" => "2024-01-01",
            "record_date" => "2024-01-15",
            "effective_date" => "2024-02-01",
            "description" => "New 3-for-1 split",
            "ratio_numerator" => "3",
            "ratio_denominator" => "1",
            "status" => "announced",
            "currency" => "USD"
          }
        })
        |> render_submit()

      assert html =~ "Corporate action added"
      assert html =~ "New 3-for-1 split"
    end

    test "save with invalid data shows error flash", %{conn: conn} do
      company = company_fixture(%{name: "SaveFailActionCo"})
      {:ok, view, _html} = live(conn, ~p"/corporate-actions")

      view
      |> form("form[phx-change=\"filter_company\"]", %{"company_id" => to_string(company.id)})
      |> render_change()

      render_click(view, "show_form", %{})

      # Use render_submit directly since form selects require valid options
      html = render_submit(view, "save", %{
        "corporate_action" => %{
          "company_id" => "",
          "action_type" => "stock_split",
          "description" => ""
        }
      })

      assert html =~ "Failed to add corporate action"
    end
  end

  describe "update event" do
    test "updating an existing action shows success flash", %{conn: conn} do
      company = company_fixture(%{name: "UpdateActionCo"})
      action = corporate_action_fixture(%{company: company, description: "Old description"})

      {:ok, view, _html} = live(conn, ~p"/corporate-actions")

      view
      |> form("form[phx-change=\"filter_company\"]", %{"company_id" => to_string(company.id)})
      |> render_change()

      render_click(view, "edit", %{"id" => to_string(action.id)})

      html =
        view
        |> form("form[phx-submit=\"update\"]", %{
          "corporate_action" => %{
            "description" => "Updated description"
          }
        })
        |> render_submit()

      assert html =~ "Corporate action updated"
      assert html =~ "Updated description"
    end
  end

  describe "delete event" do
    test "deleting an action removes it and shows success flash", %{conn: conn} do
      company = company_fixture(%{name: "DeleteActionCo"})
      action = corporate_action_fixture(%{company: company, description: "Delete this action"})

      {:ok, view, _html} = live(conn, ~p"/corporate-actions")

      view
      |> form("form[phx-change=\"filter_company\"]", %{"company_id" => to_string(company.id)})
      |> render_change()

      html = render_click(view, "delete", %{"id" => to_string(action.id)})
      assert html =~ "Corporate action deleted"
      refute html =~ "Delete this action"
    end
  end

  describe "advance_status event" do
    test "advancing status from announced to approved", %{conn: conn} do
      company = company_fixture(%{name: "AdvanceCo"})
      action = corporate_action_fixture(%{company: company, status: "announced", description: "Advance me"})

      {:ok, view, _html} = live(conn, ~p"/corporate-actions")

      view
      |> form("form[phx-change=\"filter_company\"]", %{"company_id" => to_string(company.id)})
      |> render_change()

      html = render_click(view, "advance_status", %{"id" => to_string(action.id)})
      assert html =~ "Status advanced to approved"
    end

    test "advancing status from approved to in_progress", %{conn: conn} do
      company = company_fixture(%{name: "AdvanceCo2"})
      action = corporate_action_fixture(%{company: company, status: "approved", description: "Advance again"})

      {:ok, view, _html} = live(conn, ~p"/corporate-actions")

      view
      |> form("form[phx-change=\"filter_company\"]", %{"company_id" => to_string(company.id)})
      |> render_change()

      html = render_click(view, "advance_status", %{"id" => to_string(action.id)})
      assert html =~ "Status advanced to in_progress"
    end

    test "advancing status from in_progress to completed", %{conn: conn} do
      company = company_fixture(%{name: "AdvanceCo3"})
      action = corporate_action_fixture(%{company: company, status: "in_progress", description: "Complete me"})

      {:ok, view, _html} = live(conn, ~p"/corporate-actions")

      view
      |> form("form[phx-change=\"filter_company\"]", %{"company_id" => to_string(company.id)})
      |> render_change()

      html = render_click(view, "advance_status", %{"id" => to_string(action.id)})
      assert html =~ "Status advanced to completed"
    end
  end

  describe "noop event" do
    test "noop event does nothing", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/corporate-actions")
      html = render_click(view, "noop", %{})
      assert html =~ "Corporate Actions"
    end
  end

  describe "data display" do
    test "shows action details in the table", %{conn: conn} do
      company = company_fixture(%{name: "DisplayActionCo"})

      corporate_action_fixture(%{
        company: company,
        action_type: "stock_split",
        announcement_date: "2024-01-01",
        record_date: "2024-01-15",
        effective_date: "2024-02-01",
        description: "2-for-1 stock split",
        ratio_numerator: 2,
        ratio_denominator: 1,
        status: "announced"
      })

      {:ok, view, _html} = live(conn, ~p"/corporate-actions")

      html =
        view
        |> form("form[phx-change=\"filter_company\"]", %{"company_id" => to_string(company.id)})
        |> render_change()

      assert html =~ "Stock Split"
      assert html =~ "2-for-1 stock split"
      assert html =~ "2024-01-01"
      assert html =~ "2:1"
      assert html =~ "Announced"
    end

    test "shows no corporate actions message when empty", %{conn: conn} do
      company = company_fixture(%{name: "EmptyActionCo"})

      {:ok, view, _html} = live(conn, ~p"/corporate-actions")

      html =
        view
        |> form("form[phx-change=\"filter_company\"]", %{"company_id" => to_string(company.id)})
        |> render_change()

      assert html =~ "No corporate actions recorded."
    end
  end
end
