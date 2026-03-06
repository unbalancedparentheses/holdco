defmodule Holdco.Workers.AccountingSyncWorkerTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Workers.AccountingSyncWorker
  alias Holdco.Integrations

  describe "perform/1" do
    test "returns :ok with no configs" do
      assert :ok = AccountingSyncWorker.perform(%{})
    end

    test "skips inactive configs" do
      _config = accounting_sync_config_fixture(%{is_active: false})

      assert :ok = AccountingSyncWorker.perform(%{})

      # No sync logs should be created for inactive configs
      configs = Integrations.list_accounting_sync_configs()
      config = hd(configs)
      logs = Integrations.list_accounting_sync_logs(config.id)
      assert logs == []
    end

    test "creates a sync log for active configs" do
      config = accounting_sync_config_fixture(%{provider: "quickbooks", is_active: true})

      assert :ok = AccountingSyncWorker.perform(%{})

      logs = Integrations.list_accounting_sync_logs(config.id)
      assert length(logs) >= 1

      # Without an actual QuickBooks integration connected, sync_all returns :not_connected
      log = hd(logs)
      assert log.status in ["completed", "failed"]
      assert log.completed_at != nil
    end

    test "handles unknown provider gracefully" do
      config = accounting_sync_config_fixture(%{provider: "unknown", is_active: true})

      assert :ok = AccountingSyncWorker.perform(%{})

      logs = Integrations.list_accounting_sync_logs(config.id)
      assert length(logs) >= 1
      log = hd(logs)
      assert log.status == "failed"
      assert log.error_message =~ "Unknown provider"
    end

    test "processes multiple active configs" do
      config1 = accounting_sync_config_fixture(%{provider: "xero", is_active: true})
      config2 = accounting_sync_config_fixture(%{provider: "quickbooks", is_active: true})

      assert :ok = AccountingSyncWorker.perform(%{})

      logs1 = Integrations.list_accounting_sync_logs(config1.id)
      logs2 = Integrations.list_accounting_sync_logs(config2.id)
      assert length(logs1) >= 1
      assert length(logs2) >= 1
    end
  end

  describe "Oban.Worker configuration" do
    test "uses the :default queue" do
      opts = AccountingSyncWorker.__opts__()
      assert opts[:queue] == :default
    end

    test "allows max 3 attempts" do
      opts = AccountingSyncWorker.__opts__()
      assert opts[:max_attempts] == 3
    end
  end
end
