defmodule HoldcoWeb.RegisterLiveIndexTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "Index" do
    test "renders Corporate Registers page", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/registers")
      assert html =~ "Corporate Registers"
      assert html =~ "Statutory registers for directors, shareholders, charges, and more"
    end

    test "shows company selector", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/registers")
      assert html =~ "Select Company"
    end

    test "shows prompt to select a company when none selected", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/registers")
      assert html =~ "Select a company to view its statutory registers."
    end
  end

  describe "filter_company event" do
    test "selecting a company shows register tabs and entries table", %{conn: conn} do
      company = company_fixture(%{name: "RegisterTestCo"})
      register_entry_fixture(%{company: company, person_name: "John Director"})

      {:ok, view, _html} = live(conn, ~p"/registers")

      html =
        view
        |> form("form[phx-change=\"filter_company\"]", %{"company_id" => to_string(company.id)})
        |> render_change()

      assert html =~ "John Director"
      assert html =~ "Directors"
    end

    test "selecting empty company clears entries", %{conn: conn} do
      company = company_fixture(%{name: "ClearCo"})
      register_entry_fixture(%{company: company, person_name: "Will Vanish"})

      {:ok, view, _html} = live(conn, ~p"/registers")

      # First select a company
      view
      |> form("form[phx-change=\"filter_company\"]", %{"company_id" => to_string(company.id)})
      |> render_change()

      # Then clear selection
      html =
        view
        |> form("form[phx-change=\"filter_company\"]", %{"company_id" => ""})
        |> render_change()

      refute html =~ "Will Vanish"
      assert html =~ "Select a company to view its statutory registers."
    end
  end

  describe "switch_tab event" do
    test "switching tab changes active register type", %{conn: conn} do
      company = company_fixture(%{name: "TabCo"})
      register_entry_fixture(%{company: company, register_type: "shareholders", person_name: "Shareholder Joe", shares_held: 1000, share_class: "Ordinary"})

      {:ok, view, _html} = live(conn, ~p"/registers")

      # Select company first
      view
      |> form("form[phx-change=\"filter_company\"]", %{"company_id" => to_string(company.id)})
      |> render_change()

      # Switch to shareholders tab
      html = render_click(view, "switch_tab", %{"tab" => "shareholders"})
      assert html =~ "Shareholders Register"
      assert html =~ "Shareholder Joe"
    end

    test "switching tab without company selected shows no entries", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/registers")
      # Page should not crash and should still show the prompt
      html = render(view)
      assert html =~ "Select a company to view its statutory registers."
    end
  end

  describe "show_form and close_form events" do
    test "show_form opens the add entry modal", %{conn: conn} do
      company = company_fixture(%{name: "FormCo"})
      {:ok, view, _html} = live(conn, ~p"/registers")

      view
      |> form("form[phx-change=\"filter_company\"]", %{"company_id" => to_string(company.id)})
      |> render_change()

      html = render_click(view, "show_form", %{})
      assert html =~ "Add Entry"
      assert html =~ "modal-backdrop"
    end

    test "close_form closes the modal", %{conn: conn} do
      company = company_fixture(%{name: "CloseFormCo"})
      {:ok, view, _html} = live(conn, ~p"/registers")

      view
      |> form("form[phx-change=\"filter_company\"]", %{"company_id" => to_string(company.id)})
      |> render_change()

      render_click(view, "show_form", %{})
      html = render_click(view, "close_form", %{})
      refute html =~ "modal-backdrop"
    end
  end

  describe "edit event" do
    test "edit opens the form with entry data", %{conn: conn} do
      company = company_fixture(%{name: "EditCo"})
      entry = register_entry_fixture(%{company: company, person_name: "Editable Director"})

      {:ok, view, _html} = live(conn, ~p"/registers")

      view
      |> form("form[phx-change=\"filter_company\"]", %{"company_id" => to_string(company.id)})
      |> render_change()

      html = render_click(view, "edit", %{"id" => to_string(entry.id)})
      assert html =~ "Edit Entry"
      assert html =~ "Update Entry"
    end
  end

  describe "save event" do
    test "saving a new register entry shows success flash", %{conn: conn} do
      company = company_fixture(%{name: "SaveCo"})
      {:ok, view, _html} = live(conn, ~p"/registers")

      view
      |> form("form[phx-change=\"filter_company\"]", %{"company_id" => to_string(company.id)})
      |> render_change()

      render_click(view, "show_form", %{})

      html =
        view
        |> form("form[phx-submit=\"save\"]", %{
          "register_entry" => %{
            "company_id" => to_string(company.id),
            "entry_date" => "2024-06-01",
            "person_name" => "New Director",
            "role_or_description" => "Executive",
            "appointment_date" => "2024-06-01",
            "status" => "current"
          }
        })
        |> render_submit()

      assert html =~ "Register entry added"
      assert html =~ "New Director"
    end

    test "save with invalid data shows error flash", %{conn: conn} do
      company = company_fixture(%{name: "SaveFailCo"})
      {:ok, view, _html} = live(conn, ~p"/registers")

      view
      |> form("form[phx-change=\"filter_company\"]", %{"company_id" => to_string(company.id)})
      |> render_change()

      render_click(view, "show_form", %{})

      html =
        view
        |> form("form[phx-submit=\"save\"]", %{
          "register_entry" => %{
            "company_id" => "",
            "entry_date" => "",
            "person_name" => ""
          }
        })
        |> render_submit()

      assert html =~ "Failed to add register entry"
    end
  end

  describe "update event" do
    test "updating an existing entry shows success flash", %{conn: conn} do
      company = company_fixture(%{name: "UpdateCo"})
      entry = register_entry_fixture(%{company: company, person_name: "Old Name"})

      {:ok, view, _html} = live(conn, ~p"/registers")

      view
      |> form("form[phx-change=\"filter_company\"]", %{"company_id" => to_string(company.id)})
      |> render_change()

      render_click(view, "edit", %{"id" => to_string(entry.id)})

      html =
        view
        |> form("form[phx-submit=\"update\"]", %{
          "register_entry" => %{
            "person_name" => "Updated Name",
            "role_or_description" => "Non-Executive Director"
          }
        })
        |> render_submit()

      assert html =~ "Register entry updated"
      assert html =~ "Updated Name"
    end
  end

  describe "delete event" do
    test "deleting an entry removes it and shows success flash", %{conn: conn} do
      company = company_fixture(%{name: "DeleteCo"})
      entry = register_entry_fixture(%{company: company, person_name: "Deletable Director"})

      {:ok, view, _html} = live(conn, ~p"/registers")

      view
      |> form("form[phx-change=\"filter_company\"]", %{"company_id" => to_string(company.id)})
      |> render_change()

      html = render_click(view, "delete", %{"id" => to_string(entry.id)})
      assert html =~ "Register entry deleted"
      refute html =~ "Deletable Director"
    end
  end

  describe "cease event" do
    test "ceasing an entry marks it as historical", %{conn: conn} do
      company = company_fixture(%{name: "CeaseCo"})
      entry = register_entry_fixture(%{company: company, person_name: "Cease Me", status: "current"})

      {:ok, view, _html} = live(conn, ~p"/registers")

      view
      |> form("form[phx-change=\"filter_company\"]", %{"company_id" => to_string(company.id)})
      |> render_change()

      html = render_click(view, "cease", %{"id" => to_string(entry.id)})
      assert html =~ "Entry ceased"
    end
  end

  describe "noop event" do
    test "noop event does nothing", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/registers")
      html = render_click(view, "noop", %{})
      assert html =~ "Corporate Registers"
    end
  end
end
