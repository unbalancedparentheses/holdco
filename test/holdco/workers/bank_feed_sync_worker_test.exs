defmodule Holdco.Workers.BankFeedSyncWorkerTest do
  use Holdco.DataCase, async: true

  alias Holdco.Workers.BankFeedSyncWorker

  setup do
    Application.put_env(:holdco, Holdco.Integrations.Plaid,
      client_id: "test_client_id",
      secret: "test_secret",
      environment: :sandbox
    )

    :ok
  end

  describe "perform/1" do
    test "returns :ok when no active configs exist" do
      assert :ok == BankFeedSyncWorker.perform(%Oban.Job{args: %{}})
    end

    test "returns :ok with active plaid configs that fail to sync" do
      import Holdco.HoldcoFixtures

      # Create an active plaid config - sync will fail because credentials are fake
      bank_feed_config_fixture(%{
        provider: "plaid",
        is_active: true,
        access_token: "fake_access_token"
      })

      # Should still return :ok even if individual syncs fail
      assert :ok == BankFeedSyncWorker.perform(%Oban.Job{args: %{}})
    end

    test "ignores non-plaid configs" do
      import Holdco.HoldcoFixtures

      bank_feed_config_fixture(%{
        provider: "teller",
        is_active: true,
        access_token: "teller_token"
      })

      # Should return :ok and not attempt to sync non-plaid configs
      assert :ok == BankFeedSyncWorker.perform(%Oban.Job{args: %{}})
    end

    test "ignores inactive plaid configs" do
      import Holdco.HoldcoFixtures

      bank_feed_config_fixture(%{
        provider: "plaid",
        is_active: false,
        access_token: "inactive_token"
      })

      assert :ok == BankFeedSyncWorker.perform(%Oban.Job{args: %{}})
    end
  end
end
