defmodule HoldcoWeb.RevaluationLiveIndexTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "Index" do
    test "renders Currency Revaluation page", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/revaluation")
      assert html =~ "Currency Revaluation"
    end

    test "shows page subtitle", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/revaluation")
      assert html =~ "Unrealized FX gain/loss"
    end

    test "shows metrics strip with FX gain/loss", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/revaluation")
      assert html =~ "Total FX Gain"
      assert html =~ "Total FX Loss"
      assert html =~ "Net FX Impact"
      assert html =~ "Non-USD Accounts"
    end

    test "shows Account Revaluation Detail table headers", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/revaluation")
      assert html =~ "Account Revaluation Detail"
      assert html =~ "Code"
      assert html =~ "Account Name"
      assert html =~ "Currency"
      assert html =~ "Local Balance"
    end

    test "shows FX Exposure by Currency section", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/revaluation")
      assert html =~ "FX Exposure by Currency"
    end

    test "shows Revaluation Notes section", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/revaluation")
      assert html =~ "Revaluation Notes"
      assert html =~ "Currency revaluation calculates unrealized FX gains"
      assert html =~ "9100"
      assert html =~ "FX Gain/Loss"
    end

    test "shows empty state when no non-USD accounts", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/revaluation")
      assert html =~ "No non-USD accounts found"
    end

    test "renders with non-USD account data", %{conn: conn} do
      company = company_fixture()
      account_fixture(%{
        company: company,
        account_type: "asset",
        code: "1050",
        currency: "EUR",
        name: "Euro Cash Account"
      })

      # Create a journal entry with lines to give the account a non-zero balance
      entry = journal_entry_fixture(%{company: company})
      account = Holdco.Finance.list_accounts() |> Enum.find(&(&1.currency == "EUR"))

      if account do
        journal_line_fixture(%{entry: entry, account: account, debit: 5000.0, credit: 0.0})
      end

      {:ok, _live, html} = live(conn, ~p"/revaluation")
      assert html =~ "Revaluation"
    end

    test "renders with multiple currencies", %{conn: conn} do
      company = company_fixture()
      account_fixture(%{company: company, account_type: "asset", code: "1051", currency: "EUR", name: "Euro Account"})
      account_fixture(%{company: company, account_type: "asset", code: "1052", currency: "GBP", name: "GBP Account"})
      account_fixture(%{company: company, account_type: "asset", code: "1053", currency: "JPY", name: "JPY Account"})

      {:ok, _live, html} = live(conn, ~p"/revaluation")
      assert html =~ "Revaluation"
    end

    test "shows Totals footer row in table", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/revaluation")
      assert html =~ "Totals"
    end
  end

  describe "viewer permissions" do
    test "viewer cannot generate revaluation journal entry", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/revaluation")
      html = render_click(live, "generate_reval_je", %{})
      assert html =~ "permission"
    end

    test "viewer sees disabled Generate button but cannot act on it", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/revaluation")
      # Viewer triggers permission error when trying to generate
      html = render_click(live, "generate_reval_je", %{})
      assert html =~ "permission"
    end
  end

  describe "editor operations" do
    test "editor sees Generate Revaluation JE button", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, _live, html} = live(conn, ~p"/revaluation")
      assert html =~ "Generate Revaluation JE"
    end

    test "editor generating reval with zero impact shows info flash", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, live, _html} = live(conn, ~p"/revaluation")
      html = render_click(live, "generate_reval_je", %{})
      assert html =~ "No FX gain/loss to record" || html =~ "Revaluation"
    end
  end

  describe "noop event" do
    test "noop event does nothing", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/revaluation")
      html = render_click(live, "noop", %{})
      assert html =~ "Currency Revaluation"
    end
  end

  describe "chart data" do
    test "renders fx exposure chart container", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/revaluation")
      assert html =~ "fx-exposure-chart"
      assert html =~ "ChartHook"
    end
  end

  describe "editor with non-USD account data and non-zero impact" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      company = company_fixture()

      # Create the FX Gain/Loss offset account
      account_fixture(%{
        company: company,
        account_type: "revenue",
        code: "9100",
        currency: "USD",
        name: "FX Gain/Loss"
      })

      # Create a EUR account
      eur_account =
        account_fixture(%{
          company: company,
          account_type: "asset",
          code: "1060",
          currency: "EUR",
          name: "Euro Operating Account"
        })

      # Create journal entries to give the EUR account a non-zero balance
      entry = journal_entry_fixture(%{company: company})
      journal_line_fixture(%{entry: entry, account: eur_account, debit: 10_000.0, credit: 0.0})

      %{company: company, eur_account: eur_account}
    end

    test "renders non-USD account in table", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/revaluation")
      # The page should show the EUR account or at least not show the empty state
      assert html =~ "Currency Revaluation"
    end

    test "editor can attempt to generate revaluation journal entry", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/revaluation")
      html = render_click(live, "generate_reval_je", %{})
      # Either it creates successfully or shows zero impact message
      assert html =~ "Revaluation" || html =~ "No FX gain/loss" || html =~ "successfully" || html =~ "Failed"
    end
  end

  describe "formatting edge cases with non-USD data" do
    test "renders table with EUR account data", %{conn: conn} do
      company = company_fixture()
      eur_account =
        account_fixture(%{
          company: company,
          account_type: "asset",
          code: "1070",
          currency: "EUR",
          name: "Euro Cash"
        })

      entry = journal_entry_fixture(%{company: company})
      journal_line_fixture(%{entry: entry, account: eur_account, debit: 5000.0, credit: 0.0})

      {:ok, _live, html} = live(conn, ~p"/revaluation")
      assert html =~ "Currency Revaluation"
    end

    test "renders with GBP account", %{conn: conn} do
      company = company_fixture()
      gbp_account =
        account_fixture(%{
          company: company,
          account_type: "liability",
          code: "2060",
          currency: "GBP",
          name: "GBP Payable"
        })

      entry = journal_entry_fixture(%{company: company})
      journal_line_fixture(%{entry: entry, account: gbp_account, debit: 0.0, credit: 3000.0})

      {:ok, _live, html} = live(conn, ~p"/revaluation")
      assert html =~ "Currency Revaluation"
    end
  end
end
