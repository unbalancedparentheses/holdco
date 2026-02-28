defmodule HoldcoWeb.ContractLiveIndexTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "Index" do
    test "renders Contract Management page", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/contracts")
      assert html =~ "Contract Management"
      assert html =~ "Track contracts, renewals, and counterparty relationships"
    end

    test "shows metrics strip", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/contracts")
      assert html =~ "Total Contracts"
      assert html =~ "Total Value"
      assert html =~ "Expiring (30d)"
    end

    test "shows contracts table with headers", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/contracts")
      assert html =~ "Title"
      assert html =~ "Counterparty"
      assert html =~ "Type"
      assert html =~ "Status"
    end

    test "shows empty state when no contracts", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/contracts")
      assert html =~ "No contracts found"
    end

    test "shows add contract button", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/contracts")
      assert html =~ "Add Contract"
    end

    test "opens add contract form", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/contracts")
      html = render_click(live, "show_form")
      assert html =~ "Add Contract"
      assert html =~ "Title"
      assert html =~ "Counterparty"
    end
  end

  describe "close_form" do
    test "closes the add contract form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/contracts")
      render_click(view, "show_form")
      html = render_click(view, "close_form")
      refute html =~ "dialog-overlay"
    end
  end

  describe "save (create contract)" do
    test "creates a contract with valid data", %{conn: conn} do
      company = company_fixture(%{name: "Contract Corp"})

      {:ok, view, _html} = live(conn, ~p"/contracts")
      render_click(view, "show_form")

      html =
        render_click(view, "save", %{
          "contract" => %{
            "company_id" => to_string(company.id),
            "title" => "Service Agreement Q1",
            "counterparty" => "Vendor Inc",
            "contract_type" => "service",
            "status" => "active",
            "start_date" => "2025-01-01",
            "end_date" => "2025-12-31",
            "value" => "50000",
            "currency" => "USD"
          }
        })

      assert html =~ "Contract added"
      assert html =~ "Service Agreement Q1"
    end

    test "shows error when creating contract with missing fields", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/contracts")
      render_click(view, "show_form")

      html =
        render_click(view, "save", %{
          "contract" => %{
            "title" => "",
            "counterparty" => ""
          }
        })

      assert html =~ "Failed to add contract"
    end
  end

  describe "edit" do
    test "opens edit form for an existing contract", %{conn: conn} do
      company = company_fixture()
      contract = contract_fixture(%{company: company, title: "Editable Contract"})

      {:ok, view, _html} = live(conn, ~p"/contracts")
      html = render_click(view, "edit", %{"id" => to_string(contract.id)})

      assert html =~ "Edit Contract"
      assert html =~ "Update Contract"
    end
  end

  describe "update" do
    test "updates a contract", %{conn: conn} do
      company = company_fixture()
      contract = contract_fixture(%{company: company, title: "Old Contract Title"})

      {:ok, view, _html} = live(conn, ~p"/contracts")
      render_click(view, "edit", %{"id" => to_string(contract.id)})

      html =
        render_click(view, "update", %{
          "contract" => %{
            "company_id" => to_string(company.id),
            "title" => "Updated Contract Title",
            "counterparty" => "New Vendor",
            "contract_type" => "service",
            "value" => "75000"
          }
        })

      assert html =~ "Contract updated"
      assert html =~ "Updated Contract Title"
    end
  end

  describe "delete" do
    test "deletes a contract", %{conn: conn} do
      company = company_fixture()
      contract = contract_fixture(%{company: company, title: "Delete Me Contract"})

      {:ok, view, _html} = live(conn, ~p"/contracts")
      assert render(view) =~ "Delete Me Contract"

      html = render_click(view, "delete", %{"id" => to_string(contract.id)})
      assert html =~ "Contract deleted"
      refute html =~ "Delete Me Contract"
    end
  end

  describe "filter_company" do
    test "filters contracts by company", %{conn: conn} do
      company = company_fixture(%{name: "Filter Contract Corp"})
      contract_fixture(%{company: company, title: "Filtered Contract"})

      {:ok, view, _html} = live(conn, ~p"/contracts")
      html = render_click(view, "filter_company", %{"company_id" => to_string(company.id)})
      assert html =~ "Filtered Contract"
    end

    test "clears company filter with empty string", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/contracts")
      html = render_click(view, "filter_company", %{"company_id" => ""})
      assert html =~ "Contract Management"
    end
  end

  describe "displays existing data" do
    test "shows contract in table", %{conn: conn} do
      company = company_fixture(%{name: "Display Corp"})
      contract_fixture(%{company: company, title: "Visible Contract", counterparty: "Big Vendor"})

      {:ok, _view, html} = live(conn, ~p"/contracts")
      assert html =~ "Visible Contract"
      assert html =~ "Big Vendor"
    end
  end
end
