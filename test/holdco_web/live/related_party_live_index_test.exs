defmodule HoldcoWeb.RelatedPartyLiveIndexTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "Index" do
    test "renders Related Party Transactions page", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/related-party-transactions")
      assert html =~ "Related Party Transactions"
      assert html =~ "Register and monitor related party transactions for compliance"
    end

    test "shows metrics strip", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/related-party-transactions")
      assert html =~ "Total Transactions"
      assert html =~ "Total Amount"
    end

    test "shows table with headers", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/related-party-transactions")
      assert html =~ "All Transactions"
      assert html =~ "Related Party"
      assert html =~ "Relationship"
      assert html =~ "Arm&#39;s Length"
      assert html =~ "Disclosure"
    end

    test "shows empty state when no transactions exist", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/related-party-transactions")
      assert html =~ "No related party transactions found."
    end

    test "shows company filter", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/related-party-transactions")
      assert html =~ "All Companies"
    end
  end

  describe "filter_company event" do
    test "filtering by company shows only that company's transactions", %{conn: conn} do
      co1 = company_fixture(%{name: "RPTCo1"})
      co2 = company_fixture(%{name: "RPTCo2"})
      related_party_transaction_fixture(%{company: co1, related_party_name: "Alpha Party"})
      related_party_transaction_fixture(%{company: co2, related_party_name: "Beta Party"})

      {:ok, view, html} = live(conn, ~p"/related-party-transactions")

      # Both visible initially (all companies)
      assert html =~ "Alpha Party"
      assert html =~ "Beta Party"

      # Filter to co1 only
      html =
        view
        |> form("form[phx-change=\"filter_company\"]", %{"company_id" => to_string(co1.id)})
        |> render_change()

      assert html =~ "Alpha Party"
      refute html =~ "Beta Party"
    end

    test "selecting empty company shows all transactions", %{conn: conn} do
      company = company_fixture(%{name: "AllRPTCo"})
      related_party_transaction_fixture(%{company: company, related_party_name: "Show All"})

      {:ok, view, _html} = live(conn, ~p"/related-party-transactions")

      # Filter to company
      view
      |> form("form[phx-change=\"filter_company\"]", %{"company_id" => to_string(company.id)})
      |> render_change()

      # Clear filter
      html =
        view
        |> form("form[phx-change=\"filter_company\"]", %{"company_id" => ""})
        |> render_change()

      assert html =~ "Show All"
    end
  end

  describe "show_form and close_form events" do
    test "show_form opens the add transaction modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/related-party-transactions")
      html = render_click(view, "show_form", %{})
      assert html =~ "Add Transaction"
      assert html =~ "dialog-overlay"
    end

    test "close_form closes the modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/related-party-transactions")
      render_click(view, "show_form", %{})
      html = render_click(view, "close_form", %{})
      refute html =~ "dialog-overlay"
    end
  end

  describe "edit event" do
    test "edit opens the form with transaction data", %{conn: conn} do
      company = company_fixture(%{name: "EditRPTCo"})
      txn = related_party_transaction_fixture(%{company: company, related_party_name: "Edit Target"})

      {:ok, view, _html} = live(conn, ~p"/related-party-transactions")

      html = render_click(view, "edit", %{"id" => to_string(txn.id)})
      assert html =~ "Edit Transaction"
      assert html =~ "Update"
    end
  end

  describe "save event" do
    test "saving a new transaction shows success flash", %{conn: conn} do
      company = company_fixture(%{name: "SaveRPTCo"})
      {:ok, view, _html} = live(conn, ~p"/related-party-transactions")

      render_click(view, "show_form", %{})

      html =
        view
        |> form("form[phx-submit=\"save\"]", %{
          "related_party_transaction" => %{
            "company_id" => to_string(company.id),
            "related_party_name" => "New Counterparty",
            "relationship" => "subsidiary",
            "transaction_type" => "service",
            "transaction_date" => "2024-06-15",
            "amount" => "75000",
            "currency" => "USD"
          }
        })
        |> render_submit()

      assert html =~ "Transaction added"
      assert html =~ "New Counterparty"
    end

    test "save with invalid data shows error flash", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/related-party-transactions")

      render_click(view, "show_form", %{})

      html =
        view
        |> form("form[phx-submit=\"save\"]", %{
          "related_party_transaction" => %{
            "company_id" => "",
            "related_party_name" => "",
            "relationship" => "",
            "transaction_type" => "",
            "transaction_date" => "",
            "amount" => ""
          }
        })
        |> render_submit()

      assert html =~ "Failed to add transaction"
    end
  end

  describe "update event" do
    test "updating an existing transaction shows success flash", %{conn: conn} do
      company = company_fixture(%{name: "UpdateRPTCo"})
      txn = related_party_transaction_fixture(%{company: company, related_party_name: "Old Party Name"})

      {:ok, view, _html} = live(conn, ~p"/related-party-transactions")

      render_click(view, "edit", %{"id" => to_string(txn.id)})

      html =
        view
        |> form("form[phx-submit=\"update\"]", %{
          "related_party_transaction" => %{
            "related_party_name" => "Updated Party Name"
          }
        })
        |> render_submit()

      assert html =~ "Transaction updated"
      assert html =~ "Updated Party Name"
    end
  end

  describe "delete event" do
    test "deleting a transaction removes it and shows success flash", %{conn: conn} do
      company = company_fixture(%{name: "DeleteRPTCo"})
      txn = related_party_transaction_fixture(%{company: company, related_party_name: "Delete Target"})

      {:ok, view, html} = live(conn, ~p"/related-party-transactions")
      assert html =~ "Delete Target"

      html = render_click(view, "delete", %{"id" => to_string(txn.id)})
      assert html =~ "Transaction deleted"
      refute html =~ "Delete Target"
    end
  end

  describe "noop event" do
    test "noop event does nothing", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/related-party-transactions")
      html = render_click(view, "noop", %{})
      assert html =~ "Related Party Transactions"
    end
  end

  describe "data display" do
    test "shows transaction details in the table", %{conn: conn} do
      company = company_fixture(%{name: "DisplayCo"})

      related_party_transaction_fixture(%{
        company: company,
        related_party_name: "Acme Subsidiary",
        relationship: "subsidiary",
        transaction_type: "service",
        transaction_date: "2024-06-15",
        amount: "50000.00",
        currency: "USD"
      })

      {:ok, _view, html} = live(conn, ~p"/related-party-transactions")

      assert html =~ "Acme Subsidiary"
      assert html =~ "Subsidiary"
      assert html =~ "2024-06-15"
    end
  end
end
