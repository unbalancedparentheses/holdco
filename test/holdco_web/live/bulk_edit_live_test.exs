defmodule HoldcoWeb.BulkEditLiveTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "mount and render" do
    test "renders the page title and entity type selector", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/bulk-edit")

      assert html =~ "<h1>Bulk Edit</h1>"
      assert html =~ "Select records and apply bulk operations"
      assert html =~ "Companies"
      assert html =~ "Holdings"
      assert html =~ "Transactions"
      assert html =~ "Bank Accounts"
    end

    test "defaults to companies entity type", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/bulk-edit")

      # Companies button should be primary (active)
      assert html =~ "btn btn-primary"
      assert html =~ "Select All"
      assert html =~ "Deselect All"
    end

    test "shows empty state when no records exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/bulk-edit")

      assert html =~ "No Companies found."
    end

    test "displays company records when they exist", %{conn: conn} do
      company_fixture(%{name: "BulkTestCo"})

      {:ok, _view, html} = live(conn, ~p"/bulk-edit")

      assert html =~ "BulkTestCo"
    end
  end

  describe "switching entity types" do
    test "switching to holdings loads holdings records", %{conn: conn} do
      holding_fixture(%{asset: "TestHolding"})

      {:ok, view, _html} = live(conn, ~p"/bulk-edit")

      html =
        view
        |> element(~s(button[phx-value-entity_type="holdings"]))
        |> render_click()

      assert html =~ "TestHolding"
    end

    test "switching to transactions loads transaction records", %{conn: conn} do
      transaction_fixture(%{description: "BulkTxn"})

      {:ok, view, _html} = live(conn, ~p"/bulk-edit")

      html =
        view
        |> element(~s(button[phx-value-entity_type="transactions"]))
        |> render_click()

      assert html =~ "BulkTxn"
    end

    test "switching to bank_accounts loads bank account records", %{conn: conn} do
      bank_account_fixture(%{bank_name: "BulkBank"})

      {:ok, view, _html} = live(conn, ~p"/bulk-edit")

      html =
        view
        |> element(~s(button[phx-value-entity_type="bank_accounts"]))
        |> render_click()

      assert html =~ "BulkBank"
    end

    test "switching entity type clears selection", %{conn: conn} do
      company_fixture(%{name: "ClearCo"})

      {:ok, view, _html} = live(conn, ~p"/bulk-edit")

      # Select all
      view |> element("button", "Select All") |> render_click()

      # Switch entity type
      html =
        view
        |> element(~s(button[phx-value-entity_type="holdings"]))
        |> render_click()

      # Should show 0 selected
      assert html =~ "0 of"
    end
  end

  describe "record selection" do
    test "selecting a record adds it to selection", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "SelectCo"})

      {:ok, view, _html} = live(conn, ~p"/bulk-edit")

      html =
        view
        |> element(~s(input[phx-value-id="#{company.id}"]))
        |> render_click()

      assert html =~ "1 of 1 selected"
    end

    test "select all selects all records", %{conn: conn} do
      company_fixture(%{name: "All1"})
      company_fixture(%{name: "All2"})
      company_fixture(%{name: "All3"})

      {:ok, view, _html} = live(conn, ~p"/bulk-edit")

      html = view |> element("button", "Select All") |> render_click()

      assert html =~ "3 of 3 selected"
    end

    test "deselect all clears all selections", %{conn: conn} do
      company_fixture(%{name: "Desel1"})
      company_fixture(%{name: "Desel2"})

      {:ok, view, _html} = live(conn, ~p"/bulk-edit")

      view |> element("button", "Select All") |> render_click()
      html = view |> element("button", "Deselect All") |> render_click()

      assert html =~ "0 of 2 selected"
    end

    test "toggling a selected record deselects it", %{conn: conn} do
      company = company_fixture(%{name: "ToggleCo"})

      {:ok, view, _html} = live(conn, ~p"/bulk-edit")

      # Select
      view
      |> element(~s(input[phx-value-id="#{company.id}"]))
      |> render_click()

      # Deselect (toggle)
      html =
        view
        |> element(~s(input[phx-value-id="#{company.id}"]))
        |> render_click()

      assert html =~ "0 of 1 selected"
    end
  end

  describe "bulk update (editor role)" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "bulk update applies field change to selected records", %{conn: conn} do
      c1 = company_fixture(%{name: "UpdateCo1", category: "holding"})
      company_fixture(%{name: "UpdateCo2", category: "holding"})

      {:ok, view, _html} = live(conn, ~p"/bulk-edit")

      # Select the first company
      view
      |> element(~s(input[phx-value-id="#{c1.id}"]))
      |> render_click()

      # Set field and value
      view
      |> element(~s(select[name="field"]))
      |> render_change(%{"field" => "category"})

      view
      |> element(~s(input[name="value"]))
      |> render_change(%{"value" => "operating"})

      # Execute bulk update
      html = view |> element("button", "Update Selected") |> render_click()

      assert html =~ "1 succeeded"
      assert html =~ "Bulk Update Results"

      # Verify the update applied
      updated = Holdco.Corporate.get_company!(c1.id)
      assert updated.category == "operating"
    end

    test "bulk update with empty selection shows error", %{conn: conn} do
      company_fixture(%{name: "NoSelectCo"})

      {:ok, view, _html} = live(conn, ~p"/bulk-edit")

      html = view |> element("button", "Update Selected") |> render_click()

      assert html =~ "No records selected"
    end

    test "bulk update without selecting a field shows error", %{conn: conn} do
      company = company_fixture(%{name: "NoFieldCo"})

      {:ok, view, _html} = live(conn, ~p"/bulk-edit")

      view
      |> element(~s(input[phx-value-id="#{company.id}"]))
      |> render_click()

      html = view |> element("button", "Update Selected") |> render_click()

      assert html =~ "Please select a field to update"
    end
  end

  describe "bulk delete (editor role)" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "bulk delete with confirmation removes selected records", %{conn: conn} do
      c1 = company_fixture(%{name: "DeleteCo1"})
      _c2 = company_fixture(%{name: "DeleteCo2"})

      {:ok, view, _html} = live(conn, ~p"/bulk-edit")

      # Select the first company
      view
      |> element(~s(input[phx-value-id="#{c1.id}"]))
      |> render_click()

      # Click delete (should show confirmation)
      html = view |> element("button", "Delete Selected") |> render_click()
      assert html =~ "Are you sure?"
      assert html =~ "permanently delete 1 record(s)"

      # Confirm delete
      html = view |> element("button", "Yes, Delete") |> render_click()

      assert html =~ "1 succeeded"
      assert html =~ "Bulk Delete Results"
      refute html =~ "DeleteCo1"
      assert html =~ "DeleteCo2"
    end

    test "cancel delete hides confirmation", %{conn: conn} do
      company = company_fixture(%{name: "CancelDelCo"})

      {:ok, view, _html} = live(conn, ~p"/bulk-edit")

      view
      |> element(~s(input[phx-value-id="#{company.id}"]))
      |> render_click()

      view |> element("button", "Delete Selected") |> render_click()

      html = view |> element("button", "Cancel") |> render_click()

      refute html =~ "Are you sure?"
      assert html =~ "CancelDelCo"
    end

    test "bulk delete with empty selection shows error", %{conn: conn} do
      company_fixture(%{name: "NoDelSelCo"})

      {:ok, view, _html} = live(conn, ~p"/bulk-edit")

      html = view |> element("button", "Delete Selected") |> render_click()

      assert html =~ "No records selected"
    end
  end

  describe "viewer role (no can_write)" do
    test "viewer cannot see bulk action buttons", %{conn: conn} do
      company_fixture(%{name: "ViewerCo"})

      {:ok, _view, html} = live(conn, ~p"/bulk-edit")

      refute html =~ "Update Selected"
      refute html =~ "Delete Selected"
      assert html =~ "don&#39;t have permission"
    end

    test "viewer events are blocked with error message", %{conn: conn} do
      company = company_fixture(%{name: "BlockedCo"})

      {:ok, view, _html} = live(conn, ~p"/bulk-edit")

      # Select a record
      view
      |> element(~s(input[phx-value-id="#{company.id}"]))
      |> render_click()

      # Try to bulk_update via event directly
      html = render_click(view, "bulk_update", %{})
      assert html =~ "don&#39;t have permission to edit"
    end

    test "viewer bulk_delete event is blocked", %{conn: conn} do
      company = company_fixture(%{name: "BlockDelCo"})

      {:ok, view, _html} = live(conn, ~p"/bulk-edit")

      view
      |> element(~s(input[phx-value-id="#{company.id}"]))
      |> render_click()

      html = render_click(view, "bulk_delete", %{})
      assert html =~ "don&#39;t have permission to delete"
    end
  end
end
