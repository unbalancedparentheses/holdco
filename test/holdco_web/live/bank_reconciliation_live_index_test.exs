defmodule HoldcoWeb.BankReconciliationLiveIndexTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "select_config event" do
    test "selects a bank feed config", %{conn: conn} do
      config = bank_feed_config_fixture(%{is_active: true})

      {:ok, view, _html} = live(conn, ~p"/bank-reconciliation")
      html = render_change(view, "select_config", %{"config_id" => to_string(config.id)})
      # After selecting, the summary section should render with data
      assert html =~ "Total Transactions"
    end

    test "deselects config when empty string", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/bank-reconciliation")
      html = render_change(view, "select_config", %{"config_id" => ""})
      assert html =~ "Bank Reconciliation"
    end
  end

  describe "filter_status event" do
    test "filters by matched status", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/bank-reconciliation")
      html = render_change(view, "filter_status", %{"status" => "matched"})
      assert html =~ "Bank Feed Transactions"
    end

    test "filters by all status", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/bank-reconciliation")
      html = render_change(view, "filter_status", %{"status" => "all"})
      assert html =~ "Bank Feed Transactions"
    end
  end

  describe "filter_dates event" do
    test "filters by date range", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/bank-reconciliation")
      html = render_change(view, "filter_dates", %{"date_from" => "2025-01-01", "date_to" => "2025-12-31"})
      assert html =~ "Bank Feed Transactions"
    end

    test "clears date filter with empty strings", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/bank-reconciliation")
      html = render_change(view, "filter_dates", %{"date_from" => "", "date_to" => ""})
      assert html =~ "Bank Feed Transactions"
    end
  end

  describe "auto_match event" do
    test "auto-matches with a config selected", %{conn: conn} do
      config = bank_feed_config_fixture(%{is_active: true})

      {:ok, view, _html} = live(conn, ~p"/bank-reconciliation")
      # First select the config
      render_change(view, "select_config", %{"config_id" => to_string(config.id)})
      html = render_click(view, "auto_match", %{})
      assert html =~ "Auto-matched"
    end

    test "auto-match with no config shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/bank-reconciliation")
      # Deselect any config
      render_change(view, "select_config", %{"config_id" => ""})
      html = render_click(view, "auto_match", %{})
      assert html =~ "No bank feed config selected"
    end
  end

  describe "select_feed_txn event" do
    test "selects a feed transaction to show candidates", %{conn: conn} do
      config = bank_feed_config_fixture(%{is_active: true})

      {:ok, bft} =
        Holdco.Integrations.create_bank_feed_transaction(%{
          feed_config_id: config.id,
          external_id: "ext_#{System.unique_integer([:positive])}",
          date: "2025-01-15",
          description: "Test bank txn",
          amount: 500.00,
          currency: "USD"
        })

      {:ok, view, _html} = live(conn, ~p"/bank-reconciliation")
      render_change(view, "select_config", %{"config_id" => to_string(config.id)})
      html = render_click(view, "select_feed_txn", %{"id" => to_string(bft.id)})
      # Candidates section should render (even if empty)
      assert html =~ "Candidate Book Entries"
    end

    test "deselects a feed transaction when clicked again", %{conn: conn} do
      config = bank_feed_config_fixture(%{is_active: true})

      {:ok, bft} =
        Holdco.Integrations.create_bank_feed_transaction(%{
          feed_config_id: config.id,
          external_id: "ext_#{System.unique_integer([:positive])}",
          date: "2025-01-15",
          description: "Toggle txn",
          amount: 250.00,
          currency: "USD"
        })

      {:ok, view, _html} = live(conn, ~p"/bank-reconciliation")
      render_change(view, "select_config", %{"config_id" => to_string(config.id)})
      # Select
      render_click(view, "select_feed_txn", %{"id" => to_string(bft.id)})
      # Deselect
      html = render_click(view, "select_feed_txn", %{"id" => to_string(bft.id)})
      assert html =~ "Select an unmatched bank feed transaction"
    end
  end

  describe "manual_match event" do
    test "manually matches a feed transaction to a book transaction", %{conn: conn} do
      company = company_fixture()
      config = bank_feed_config_fixture(%{company: company, is_active: true})
      book_txn = transaction_fixture(%{company: company, amount: 500.00, date: "2025-01-15", description: "Book entry"})

      {:ok, bft} =
        Holdco.Integrations.create_bank_feed_transaction(%{
          feed_config_id: config.id,
          external_id: "ext_#{System.unique_integer([:positive])}",
          date: "2025-01-15",
          description: "Manual match test",
          amount: 500.00,
          currency: "USD"
        })

      {:ok, view, _html} = live(conn, ~p"/bank-reconciliation")
      render_change(view, "select_config", %{"config_id" => to_string(config.id)})

      html = render_click(view, "manual_match", %{"feed_id" => to_string(bft.id), "book_id" => to_string(book_txn.id)})
      assert html =~ "Transaction matched"
    end
  end

  describe "unmatch event" do
    test "unmatches a previously matched transaction", %{conn: conn} do
      company = company_fixture()
      config = bank_feed_config_fixture(%{company: company, is_active: true})
      book_txn = transaction_fixture(%{company: company, amount: 300.00, date: "2025-01-10"})

      {:ok, bft} =
        Holdco.Integrations.create_bank_feed_transaction(%{
          feed_config_id: config.id,
          external_id: "ext_#{System.unique_integer([:positive])}",
          date: "2025-01-10",
          description: "Unmatch test",
          amount: 300.00,
          currency: "USD"
        })

      # Match first
      Holdco.Integrations.match_bank_feed_transaction(bft.id, book_txn.id)

      {:ok, view, _html} = live(conn, ~p"/bank-reconciliation")
      render_change(view, "select_config", %{"config_id" => to_string(config.id)})
      # Switch to matched filter to see the matched txn
      render_change(view, "filter_status", %{"status" => "matched"})

      html = render_click(view, "unmatch", %{"id" => to_string(bft.id)})
      assert html =~ "Match removed"
    end
  end

  # ------------------------------------------------------------------
  # Transaction display
  # ------------------------------------------------------------------

  describe "transaction display" do
    test "shows unmatched bank feed transactions", %{conn: conn} do
      config = bank_feed_config_fixture(%{is_active: true})

      Holdco.Integrations.create_bank_feed_transaction(%{
        feed_config_id: config.id,
        external_id: "ext_display_#{System.unique_integer([:positive])}",
        date: "2025-03-01",
        description: "Wire transfer from vendor",
        amount: 1234.56,
        currency: "USD"
      })

      {:ok, view, _html} = live(conn, ~p"/bank-reconciliation")
      render_change(view, "select_config", %{"config_id" => to_string(config.id)})

      html = render(view)
      assert html =~ "Wire transfer from vendor"
      assert html =~ "Unmatched"
    end

    test "shows matched badge for matched transactions", %{conn: conn} do
      company = company_fixture()
      config = bank_feed_config_fixture(%{company: company, is_active: true})
      book_txn = transaction_fixture(%{company: company, amount: 500.00, date: "2025-03-15"})

      {:ok, bft} =
        Holdco.Integrations.create_bank_feed_transaction(%{
          feed_config_id: config.id,
          external_id: "ext_matched_#{System.unique_integer([:positive])}",
          date: "2025-03-15",
          description: "Matched wire",
          amount: 500.00,
          currency: "USD"
        })

      Holdco.Integrations.match_bank_feed_transaction(bft.id, book_txn.id)

      {:ok, view, _html} = live(conn, ~p"/bank-reconciliation")
      render_change(view, "select_config", %{"config_id" => to_string(config.id)})
      html = render_change(view, "filter_status", %{"status" => "matched"})

      assert html =~ "Matched"
      assert html =~ "Matched wire"
    end
  end

  # ------------------------------------------------------------------
  # Filter combinations
  # ------------------------------------------------------------------

  describe "filter combinations" do
    test "switching from unmatched to all shows all transactions", %{conn: conn} do
      config = bank_feed_config_fixture(%{is_active: true})

      Holdco.Integrations.create_bank_feed_transaction(%{
        feed_config_id: config.id,
        external_id: "ext_all_#{System.unique_integer([:positive])}",
        date: "2025-04-01",
        description: "All filter test",
        amount: 100.00,
        currency: "USD"
      })

      {:ok, view, _html} = live(conn, ~p"/bank-reconciliation")
      render_change(view, "select_config", %{"config_id" => to_string(config.id)})

      html = render_change(view, "filter_status", %{"status" => "all"})
      assert html =~ "All filter test"
    end

    test "date filter with only from date", %{conn: conn} do
      config = bank_feed_config_fixture(%{is_active: true})

      Holdco.Integrations.create_bank_feed_transaction(%{
        feed_config_id: config.id,
        external_id: "ext_from_#{System.unique_integer([:positive])}",
        date: "2025-06-01",
        description: "June transaction",
        amount: 200.00,
        currency: "USD"
      })

      Holdco.Integrations.create_bank_feed_transaction(%{
        feed_config_id: config.id,
        external_id: "ext_jan_#{System.unique_integer([:positive])}",
        date: "2025-01-01",
        description: "January transaction",
        amount: 100.00,
        currency: "USD"
      })

      {:ok, view, _html} = live(conn, ~p"/bank-reconciliation")
      render_change(view, "select_config", %{"config_id" => to_string(config.id)})

      html = render_change(view, "filter_dates", %{"date_from" => "2025-05-01", "date_to" => ""})
      assert html =~ "June transaction"
      refute html =~ "January transaction"
    end

    test "date filter with only to date", %{conn: conn} do
      config = bank_feed_config_fixture(%{is_active: true})

      Holdco.Integrations.create_bank_feed_transaction(%{
        feed_config_id: config.id,
        external_id: "ext_to1_#{System.unique_integer([:positive])}",
        date: "2025-02-15",
        description: "February transaction",
        amount: 300.00,
        currency: "USD"
      })

      Holdco.Integrations.create_bank_feed_transaction(%{
        feed_config_id: config.id,
        external_id: "ext_to2_#{System.unique_integer([:positive])}",
        date: "2025-11-01",
        description: "November transaction",
        amount: 400.00,
        currency: "USD"
      })

      {:ok, view, _html} = live(conn, ~p"/bank-reconciliation")
      render_change(view, "select_config", %{"config_id" => to_string(config.id)})

      html = render_change(view, "filter_dates", %{"date_from" => "", "date_to" => "2025-06-01"})
      assert html =~ "February transaction"
      refute html =~ "November transaction"
    end
  end

  # ------------------------------------------------------------------
  # Summary metrics
  # ------------------------------------------------------------------

  describe "summary metrics" do
    test "shows zero metrics when no config is selected", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/bank-reconciliation")
      render_change(view, "select_config", %{"config_id" => ""})

      html = render(view)
      assert html =~ "Total Transactions"
      assert html =~ "---"
    end

  end

  # ------------------------------------------------------------------
  # Config dropdown
  # ------------------------------------------------------------------

  describe "query param pre-selection" do
    test "pre-selects config when config_id query param is present", %{conn: conn} do
      config = bank_feed_config_fixture(%{is_active: true})

      {:ok, bft} =
        Holdco.Integrations.create_bank_feed_transaction(%{
          feed_config_id: config.id,
          external_id: "ext_param_#{System.unique_integer([:positive])}",
          date: "2025-05-01",
          description: "Pre-selected txn",
          amount: 100.00,
          currency: "USD"
        })

      {:ok, _view, html} = live(conn, "/bank-reconciliation?config_id=#{config.id}")

      assert html =~ "Pre-selected txn"
    end
  end

  describe "config dropdown" do
    test "shows available bank feed configs in dropdown", %{conn: conn} do
      company = company_fixture()
      ba = bank_account_fixture(%{company: company, bank_name: "Chase Bank"})
      _config = bank_feed_config_fixture(%{company: company, bank_account: ba, is_active: true})

      {:ok, _view, html} = live(conn, ~p"/bank-reconciliation")

      assert html =~ "Chase Bank"
    end
  end

  # ------------------------------------------------------------------
  # Empty states
  # ------------------------------------------------------------------

  describe "empty states" do
    test "shows empty state when no transactions match filter", %{conn: conn} do
      config = bank_feed_config_fixture(%{is_active: true})

      {:ok, view, _html} = live(conn, ~p"/bank-reconciliation")
      render_change(view, "select_config", %{"config_id" => to_string(config.id)})

      html = render(view)
      assert html =~ "No transactions for current filters."
    end

    test "shows candidate empty state when selected txn has no matches", %{conn: conn} do
      config = bank_feed_config_fixture(%{is_active: true})

      {:ok, bft} =
        Holdco.Integrations.create_bank_feed_transaction(%{
          feed_config_id: config.id,
          external_id: "ext_nomatch_#{System.unique_integer([:positive])}",
          date: "2025-07-01",
          description: "No matches for this",
          amount: 99999.99,
          currency: "USD"
        })

      {:ok, view, _html} = live(conn, ~p"/bank-reconciliation")
      render_change(view, "select_config", %{"config_id" => to_string(config.id)})
      html = render_click(view, "select_feed_txn", %{"id" => to_string(bft.id)})

      assert html =~ "No matching book entries found"
    end
  end
end
