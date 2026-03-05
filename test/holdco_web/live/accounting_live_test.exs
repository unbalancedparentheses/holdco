defmodule HoldcoWeb.AccountingLiveTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  # ------------------------------------------------------------------
  # Reports - change_currency (unique to this file)
  # ------------------------------------------------------------------

  describe "reports change_currency" do
    test "change currency to EUR", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/reports")
      html = render_change(view, "change_currency", %{"currency" => "EUR"})
      assert html =~ "EUR"
    end

    test "change currency to GBP", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/reports")
      html = render_change(view, "change_currency", %{"currency" => "GBP"})
      assert html =~ "GBP"
    end

    test "change currency to JPY", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/reports")
      html = render_change(view, "change_currency", %{"currency" => "JPY"})
      assert html =~ "JPY"
    end

    test "change currency to CHF", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/reports")
      html = render_change(view, "change_currency", %{"currency" => "CHF"})
      assert html =~ "CHF"
    end

    test "change currency to ARS uses catch-all symbol", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/reports")
      html = render_change(view, "change_currency", %{"currency" => "ARS"})
      assert html =~ "ARS"
    end

    test "change currency back to USD resets rate", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/reports")
      render_change(view, "change_currency", %{"currency" => "EUR"})
      html = render_change(view, "change_currency", %{"currency" => "USD"})
      assert html =~ "$"
    end
  end

  # ------------------------------------------------------------------
  # Journal - handle_params with account_id filter (unique)
  # ------------------------------------------------------------------

  describe "journal handle_params with account_id filter" do
    test "filters entries by account_id when provided", %{conn: conn} do
      company = company_fixture(%{name: "ParamFilterCo"})
      a1 = account_fixture(%{company: company, name: "Filtered Account", code: "1050", account_type: "asset"})
      a2 = account_fixture(%{company: company, name: "Other Account", code: "1051", account_type: "asset"})

      entry1 = journal_entry_fixture(%{company: company, description: "Filtered entry"})
      journal_line_fixture(%{entry: entry1, account: a1, debit: 100.0})

      entry2 = journal_entry_fixture(%{company: company, description: "Unfiltered entry"})
      journal_line_fixture(%{entry: entry2, account: a2, debit: 100.0})

      {:ok, _view, html} = live(conn, ~p"/accounts/journal?account_id=#{a1.id}")

      assert html =~ "Filtered entry"
      assert html =~ "Filtered Account"
      assert html =~ "Clear filter"
      refute html =~ "Unfiltered entry"
    end

    test "without account_id param shows all entries", %{conn: conn} do
      company = company_fixture(%{name: "NoParamCo"})
      a1 = account_fixture(%{company: company, name: "Acct A", code: "1060", account_type: "asset"})
      a2 = account_fixture(%{company: company, name: "Acct B", code: "1061", account_type: "asset"})

      entry1 = journal_entry_fixture(%{company: company, description: "Entry A"})
      journal_line_fixture(%{entry: entry1, account: a1, debit: 50.0})

      entry2 = journal_entry_fixture(%{company: company, description: "Entry B"})
      journal_line_fixture(%{entry: entry2, account: a2, debit: 50.0})

      {:ok, _view, html} = live(conn, ~p"/accounts/journal")

      assert html =~ "Entry A"
      assert html =~ "Entry B"
      refute html =~ "Clear filter"
    end
  end
end
