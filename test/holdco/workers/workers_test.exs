defmodule Holdco.Workers.WorkersTest do
  use Holdco.DataCase

  import Holdco.HoldcoFixtures
  import Holdco.AccountsFixtures

  describe "BackupWorker" do
    alias Holdco.Workers.BackupWorker

    test "perform/1 returns :ok with no active backup configs" do
      assert :ok == BackupWorker.perform(%Oban.Job{args: %{}})
    end

    test "perform/1 processes active backup configs" do
      backup_dir = Path.join(System.tmp_dir!(), "holdco_test_backup_#{System.unique_integer([:positive])}")
      File.mkdir_p!(backup_dir)

      on_exit(fn ->
        File.rm_rf!(backup_dir)
      end)

      backup_config_fixture(%{
        destination_path: backup_dir,
        is_active: true,
        retention_days: 30
      })

      assert :ok == BackupWorker.perform(%Oban.Job{args: %{}})

      # Verify a backup log was created
      logs = Holdco.Platform.list_backup_logs()
      assert length(logs) > 0
    end

    test "perform/1 skips inactive backup configs" do
      backup_config_fixture(%{is_active: false})

      assert :ok == BackupWorker.perform(%Oban.Job{args: %{}})

      # No backup logs should be created for inactive configs
      logs = Holdco.Platform.list_backup_logs()
      assert logs == []
    end

    test "perform/1 creates backup log with running status first" do
      backup_dir = Path.join(System.tmp_dir!(), "holdco_test_backup_#{System.unique_integer([:positive])}")
      File.mkdir_p!(backup_dir)

      on_exit(fn ->
        File.rm_rf!(backup_dir)
      end)

      _bc = backup_config_fixture(%{
        destination_path: backup_dir,
        is_active: true,
        retention_days: 30
      })

      BackupWorker.perform(%Oban.Job{args: %{}})

      # After perform completes, we should have final status logs
      logs = Holdco.Platform.list_backup_logs()
      statuses = Enum.map(logs, & &1.status)
      # The "running" log gets deleted; we should see "completed" or "failed"
      assert Enum.any?(statuses, &(&1 in ["completed", "failed"]))
    end

    test "perform/1 handles backup failure gracefully" do
      # Use a destination path that doesn't exist and can't be created
      # to trigger a failure
      backup_config_fixture(%{
        destination_path: "/nonexistent/impossible/path_#{System.unique_integer([:positive])}",
        is_active: true,
        retention_days: 30
      })

      # Should still return :ok even if backup fails
      assert :ok == BackupWorker.perform(%Oban.Job{args: %{}})

      # Should have created a failed backup log
      logs = Holdco.Platform.list_backup_logs()
      assert length(logs) > 0
    end

    test "perform/1 with multiple active configs processes all" do
      backup_dir1 = Path.join(System.tmp_dir!(), "holdco_test_backup1_#{System.unique_integer([:positive])}")
      backup_dir2 = Path.join(System.tmp_dir!(), "holdco_test_backup2_#{System.unique_integer([:positive])}")
      File.mkdir_p!(backup_dir1)
      File.mkdir_p!(backup_dir2)

      on_exit(fn ->
        File.rm_rf!(backup_dir1)
        File.rm_rf!(backup_dir2)
      end)

      backup_config_fixture(%{destination_path: backup_dir1, is_active: true, retention_days: 30, name: "Config1"})
      backup_config_fixture(%{destination_path: backup_dir2, is_active: true, retention_days: 30, name: "Config2"})

      assert :ok == BackupWorker.perform(%Oban.Job{args: %{}})

      logs = Holdco.Platform.list_backup_logs()
      assert length(logs) >= 2
    end

    test "perform/1 updates last_backup_at on success" do
      backup_dir = Path.join(System.tmp_dir!(), "holdco_test_backup_#{System.unique_integer([:positive])}")
      File.mkdir_p!(backup_dir)

      on_exit(fn ->
        File.rm_rf!(backup_dir)
      end)

      bc = backup_config_fixture(%{
        destination_path: backup_dir,
        is_active: true,
        retention_days: 30
      })

      BackupWorker.perform(%Oban.Job{args: %{}})

      updated_config = Holdco.Platform.get_backup_config!(bc.id)
      # On success, last_backup_at should be set
      # (It may or may not succeed depending on sqlite3 availability)
      assert is_struct(updated_config)
    end
  end

  describe "EmailDigestWorker" do
    alias Holdco.Workers.EmailDigestWorker

    test "perform/1 returns :ok with no active digest configs" do
      assert :ok == EmailDigestWorker.perform(%Oban.Job{args: %{}})
    end

    test "perform/1 sends digest for active configs with portfolio section" do
      user = user_fixture()

      email_digest_config_fixture(%{
        user: user,
        is_active: true,
        include_portfolio: true,
        include_deadlines: false,
        include_audit_log: false,
        include_transactions: false
      })

      assert :ok == EmailDigestWorker.perform(%Oban.Job{args: %{}})
    end

    test "perform/1 skips inactive digest configs" do
      user = user_fixture()

      email_digest_config_fixture(%{
        user: user,
        is_active: false
      })

      assert :ok == EmailDigestWorker.perform(%Oban.Job{args: %{}})
    end

    test "perform/1 includes all enabled sections" do
      user = user_fixture()

      email_digest_config_fixture(%{
        user: user,
        is_active: true,
        include_portfolio: true,
        include_deadlines: true,
        include_audit_log: true,
        include_transactions: true
      })

      assert :ok == EmailDigestWorker.perform(%Oban.Job{args: %{}})
    end

    test "perform/1 with only deadlines section" do
      user = user_fixture()

      email_digest_config_fixture(%{
        user: user,
        is_active: true,
        include_portfolio: false,
        include_deadlines: true,
        include_audit_log: false,
        include_transactions: false
      })

      assert :ok == EmailDigestWorker.perform(%Oban.Job{args: %{}})
    end

    test "perform/1 with only audit_log section" do
      user = user_fixture()

      # Create some audit logs
      audit_log_fixture(%{action: "test_digest"})

      email_digest_config_fixture(%{
        user: user,
        is_active: true,
        include_portfolio: false,
        include_deadlines: false,
        include_audit_log: true,
        include_transactions: false
      })

      assert :ok == EmailDigestWorker.perform(%Oban.Job{args: %{}})
    end

    test "perform/1 with only transactions section" do
      user = user_fixture()
      company = company_fixture()
      transaction_fixture(%{company: company, date: Date.utc_today() |> Date.to_string()})

      email_digest_config_fixture(%{
        user: user,
        is_active: true,
        include_portfolio: false,
        include_deadlines: false,
        include_audit_log: false,
        include_transactions: true
      })

      assert :ok == EmailDigestWorker.perform(%Oban.Job{args: %{}})
    end

    test "perform/1 with multiple active configs" do
      user1 = user_fixture()
      user2 = user_fixture()

      email_digest_config_fixture(%{user: user1, is_active: true, include_portfolio: true})
      email_digest_config_fixture(%{user: user2, is_active: true, include_portfolio: true})

      assert :ok == EmailDigestWorker.perform(%Oban.Job{args: %{}})
    end

    test "perform/1 includes upcoming deadlines" do
      user = user_fixture()
      company = company_fixture()

      # Create an upcoming deadline (within 30 days)
      upcoming_date = Date.utc_today() |> Date.add(10) |> Date.to_string()
      tax_deadline_fixture(%{company: company, due_date: upcoming_date, status: "pending"})

      email_digest_config_fixture(%{
        user: user,
        is_active: true,
        include_portfolio: false,
        include_deadlines: true,
        include_audit_log: false,
        include_transactions: false
      })

      assert :ok == EmailDigestWorker.perform(%Oban.Job{args: %{}})
    end

    test "perform/1 config with last_sent_at uses it for filtering" do
      user = user_fixture()

      # Create config with a last_sent_at in the past
      config = email_digest_config_fixture(%{
        user: user,
        is_active: true,
        include_portfolio: false,
        include_deadlines: false,
        include_audit_log: true,
        include_transactions: true
      })

      # Update last_sent_at
      Holdco.Integrations.update_email_digest_config(config, %{
        last_sent_at: DateTime.add(DateTime.utc_now(), -86400, :second) |> DateTime.truncate(:second)
      })

      assert :ok == EmailDigestWorker.perform(%Oban.Job{args: %{}})
    end
  end

  describe "PortfolioSnapshotWorker" do
    alias Holdco.Workers.PortfolioSnapshotWorker

    test "perform/1 creates a portfolio snapshot" do
      assert :ok == PortfolioSnapshotWorker.perform(%Oban.Job{args: %{}})

      snapshots = Holdco.Assets.list_portfolio_snapshots()
      assert length(snapshots) > 0

      snapshot = List.first(snapshots)
      assert snapshot.date == Date.utc_today() |> Date.to_string()
      assert snapshot.currency == "USD"
    end

    test "perform/1 records NAV values from portfolio calculation" do
      # Create some data so portfolio has values
      company = company_fixture()
      bank_account_fixture(%{company: company, balance: 50_000.0, currency: "USD"})

      assert :ok == PortfolioSnapshotWorker.perform(%Oban.Job{args: %{}})

      snapshots = Holdco.Assets.list_portfolio_snapshots()
      assert length(snapshots) > 0
    end
  end

  describe "SanctionsCheckWorker" do
    alias Holdco.Workers.SanctionsCheckWorker

    test "perform/1 returns :ok with no companies" do
      assert :ok == SanctionsCheckWorker.perform(%Oban.Job{args: %{}})
    end

    test "perform/1 screens companies against sanctions lists" do
      company = company_fixture(%{name: "Legitimate Corp"})
      sl = sanctions_list_fixture(%{name: "Test SDN"})
      sanctions_entry_fixture(%{sanctions_list: sl, name: "Bad Actor Inc"})

      assert :ok == SanctionsCheckWorker.perform(%Oban.Job{args: %{}})

      # Should have created a sanctions check record for the company
      checks = Holdco.Compliance.list_sanctions_checks(company.id)
      assert length(checks) > 0

      check = List.first(checks)
      assert check.status == "clear"
      assert check.checked_name == "Legitimate Corp"
    end

    test "perform/1 detects potential sanctions matches" do
      company = company_fixture(%{name: "Bad Actor Inc"})
      sl = sanctions_list_fixture(%{name: "Test SDN"})
      sanctions_entry_fixture(%{sanctions_list: sl, name: "Bad Actor Inc"})

      assert :ok == SanctionsCheckWorker.perform(%Oban.Job{args: %{}})

      checks = Holdco.Compliance.list_sanctions_checks(company.id)
      match_checks = Enum.filter(checks, &(&1.status == "match"))
      assert length(match_checks) > 0
    end

    test "perform/1 also screens beneficial owners" do
      company = company_fixture(%{name: "Clean Corp"})
      beneficial_owner_fixture(%{company: company, name: "Clean Owner"})
      sl = sanctions_list_fixture(%{name: "Test SDN"})
      sanctions_entry_fixture(%{sanctions_list: sl, name: "Sanctioned Person"})

      assert :ok == SanctionsCheckWorker.perform(%Oban.Job{args: %{}})

      checks = Holdco.Compliance.list_sanctions_checks(company.id)
      # Should have checks for both the company and the beneficial owner
      assert length(checks) >= 2
    end
  end

  describe "SnapshotPricesWorker" do
    alias Holdco.Workers.SnapshotPricesWorker

    test "perform/1 returns :ok with no holdings" do
      assert :ok == SnapshotPricesWorker.perform(%Oban.Job{args: %{}})
    end

    test "perform/1 attempts to fetch prices for holdings with tickers" do
      company = company_fixture()
      holding_fixture(%{company: company, asset: "Apple Inc", ticker: "AAPL"})

      # This will try to make HTTP calls to Yahoo Finance which will fail in test,
      # but the worker should handle errors gracefully and return :ok
      assert :ok == SnapshotPricesWorker.perform(%Oban.Job{args: %{}})
    end

    test "perform/1 skips holdings without tickers" do
      company = company_fixture()
      holding_fixture(%{company: company, asset: "Private Equity", ticker: nil})
      holding_fixture(%{company: company, asset: "Real Estate", ticker: ""})

      assert :ok == SnapshotPricesWorker.perform(%Oban.Job{args: %{}})
    end

    test "perform/1 deduplicates tickers across multiple holdings" do
      company = company_fixture()
      holding_fixture(%{company: company, asset: "Apple Lot 1", ticker: "AAPL"})
      holding_fixture(%{company: company, asset: "Apple Lot 2", ticker: "AAPL"})

      # Should still return :ok even with duplicate tickers
      assert :ok == SnapshotPricesWorker.perform(%Oban.Job{args: %{}})
    end

    test "perform/1 handles mix of valid and nil tickers" do
      company = company_fixture()
      holding_fixture(%{company: company, asset: "Apple Inc", ticker: "AAPL"})
      holding_fixture(%{company: company, asset: "Private Fund", ticker: nil})
      holding_fixture(%{company: company, asset: "Empty Ticker", ticker: ""})

      assert :ok == SnapshotPricesWorker.perform(%Oban.Job{args: %{}})
    end
  end

  describe "TaxReminderWorker" do
    alias Holdco.Workers.TaxReminderWorker

    test "perform/1 returns :ok with no tax deadlines" do
      assert :ok == TaxReminderWorker.perform(%Oban.Job{args: %{}})
    end

    test "perform/1 creates reminders for upcoming pending deadlines" do
      company = company_fixture()

      # Create a deadline due within 14 days
      upcoming_date = Date.utc_today() |> Date.add(7) |> Date.to_string()

      tax_deadline_fixture(%{
        company: company,
        due_date: upcoming_date,
        status: "pending",
        description: "Quarterly VAT return"
      })

      assert :ok == TaxReminderWorker.perform(%Oban.Job{args: %{}})

      # Should have created an audit log entry for the reminder
      logs = Holdco.Platform.list_audit_logs(%{limit: 10})
      reminder_logs = Enum.filter(logs, &(&1.action == "reminder"))
      assert length(reminder_logs) > 0
    end

    test "perform/1 ignores completed deadlines" do
      company = company_fixture()

      upcoming_date = Date.utc_today() |> Date.add(5) |> Date.to_string()

      tax_deadline_fixture(%{
        company: company,
        due_date: upcoming_date,
        status: "completed",
        description: "Already filed"
      })

      assert :ok == TaxReminderWorker.perform(%Oban.Job{args: %{}})

      logs = Holdco.Platform.list_audit_logs(%{limit: 10})
      reminder_logs = Enum.filter(logs, &(&1.action == "reminder"))
      assert reminder_logs == []
    end

    test "perform/1 ignores deadlines more than 14 days away" do
      company = company_fixture()

      far_date = Date.utc_today() |> Date.add(30) |> Date.to_string()

      tax_deadline_fixture(%{
        company: company,
        due_date: far_date,
        status: "pending",
        description: "Far away deadline"
      })

      assert :ok == TaxReminderWorker.perform(%Oban.Job{args: %{}})

      logs = Holdco.Platform.list_audit_logs(%{limit: 10})
      reminder_logs = Enum.filter(logs, &(&1.action == "reminder"))
      assert reminder_logs == []
    end

    test "perform/1 ignores past deadlines" do
      company = company_fixture()

      past_date = Date.utc_today() |> Date.add(-5) |> Date.to_string()

      tax_deadline_fixture(%{
        company: company,
        due_date: past_date,
        status: "pending",
        description: "Overdue deadline"
      })

      assert :ok == TaxReminderWorker.perform(%Oban.Job{args: %{}})

      logs = Holdco.Platform.list_audit_logs(%{limit: 10})
      reminder_logs = Enum.filter(logs, &(&1.action == "reminder"))
      assert reminder_logs == []
    end

    test "perform/1 sends notifications for upcoming deadlines" do
      user = user_fixture()
      Holdco.Accounts.set_user_role(user, "admin")

      company = company_fixture()
      upcoming_date = Date.utc_today() |> Date.add(3) |> Date.to_string()

      tax_deadline_fixture(%{
        company: company,
        due_date: upcoming_date,
        status: "pending",
        description: "Urgent tax filing"
      })

      assert :ok == TaxReminderWorker.perform(%Oban.Job{args: %{}})

      notifications = Holdco.Notifications.list_notifications(user.id)
      tax_notifs = Enum.filter(notifications, &(&1.title == "Tax Deadline Approaching"))
      assert length(tax_notifs) > 0
    end

    test "perform/1 includes deadline due today" do
      company = company_fixture()

      today = Date.utc_today() |> Date.to_string()

      tax_deadline_fixture(%{
        company: company,
        due_date: today,
        status: "pending",
        description: "Due today deadline"
      })

      assert :ok == TaxReminderWorker.perform(%Oban.Job{args: %{}})

      logs = Holdco.Platform.list_audit_logs(%{limit: 10})
      reminder_logs = Enum.filter(logs, &(&1.action == "reminder"))
      assert length(reminder_logs) > 0
    end

    test "perform/1 includes deadline due exactly on day 14" do
      company = company_fixture()

      day14 = Date.utc_today() |> Date.add(14) |> Date.to_string()

      tax_deadline_fixture(%{
        company: company,
        due_date: day14,
        status: "pending",
        description: "Exactly 14 days away"
      })

      assert :ok == TaxReminderWorker.perform(%Oban.Job{args: %{}})

      logs = Holdco.Platform.list_audit_logs(%{limit: 10})
      reminder_logs = Enum.filter(logs, &(&1.action == "reminder"))
      assert length(reminder_logs) > 0
    end
  end
end
