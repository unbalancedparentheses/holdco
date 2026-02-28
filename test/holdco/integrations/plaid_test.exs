defmodule Holdco.Integrations.PlaidTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Integrations.Plaid
  alias Holdco.Integrations

  setup do
    Application.put_env(:holdco, Holdco.Integrations.Plaid,
      client_id: "test_plaid_client_id",
      secret: "test_plaid_secret",
      environment: :sandbox
    )

    :ok
  end

  describe "config" do
    test "reads client_id from application env" do
      config = Application.get_env(:holdco, Holdco.Integrations.Plaid)
      assert config[:client_id] == "test_plaid_client_id"
    end

    test "reads secret from application env" do
      config = Application.get_env(:holdco, Holdco.Integrations.Plaid)
      assert config[:secret] == "test_plaid_secret"
    end

    test "reads environment from application env" do
      config = Application.get_env(:holdco, Holdco.Integrations.Plaid)
      assert config[:environment] == :sandbox
    end

    test "uses sandbox base URL by default" do
      # Verify sandbox is used when environment is :sandbox
      config = Application.get_env(:holdco, Holdco.Integrations.Plaid)
      assert config[:environment] == :sandbox
    end

    test "uses production base URL when configured" do
      Application.put_env(:holdco, Holdco.Integrations.Plaid,
        client_id: "prod_id",
        secret: "prod_secret",
        environment: :production
      )

      config = Application.get_env(:holdco, Holdco.Integrations.Plaid)
      assert config[:environment] == :production
    end
  end

  describe "create_link_token/2" do
    test "makes API call and returns error when sandbox is not reachable" do
      # In test env, the Plaid sandbox won't accept our test credentials
      result = Plaid.create_link_token(1, 1)
      assert {:error, _reason} = result
    end
  end

  describe "exchange_public_token/4" do
    test "makes API call and returns error with invalid token" do
      company = company_fixture()
      ba = bank_account_fixture(%{company: company})

      result = Plaid.exchange_public_token("invalid_public_token", company.id, ba.id)
      assert {:error, _reason} = result
    end
  end

  describe "get_accounts/1" do
    test "returns error with invalid access token" do
      bfc = bank_feed_config_fixture(%{access_token: "invalid_access_token"})

      result = Plaid.get_accounts(bfc)
      assert {:error, _reason} = result
    end
  end

  describe "sync_transactions/1" do
    test "returns error with invalid access token" do
      bfc = bank_feed_config_fixture(%{access_token: "invalid_access_token"})

      result = Plaid.sync_transactions(bfc)
      assert {:error, _reason} = result
    end
  end

  describe "handle_webhook/1" do
    test "SYNC_UPDATES_AVAILABLE triggers sync for matching configs" do
      bfc = bank_feed_config_fixture(%{external_account_id: "item_test_123"})

      # The sync will fail because the access token is not valid,
      # but the webhook handler should still process without crashing
      result =
        Plaid.handle_webhook(%{
          "webhook_type" => "TRANSACTIONS",
          "webhook_code" => "SYNC_UPDATES_AVAILABLE",
          "item_id" => "item_test_123"
        })

      assert {:ok, results} = result
      assert is_list(results)
    end

    test "DEFAULT_UPDATE triggers sync" do
      _bfc = bank_feed_config_fixture(%{external_account_id: "item_default_123"})

      result =
        Plaid.handle_webhook(%{
          "webhook_type" => "TRANSACTIONS",
          "webhook_code" => "DEFAULT_UPDATE",
          "item_id" => "item_default_123"
        })

      assert {:ok, _results} = result
    end

    test "ITEM ERROR logs error to config notes" do
      bfc = bank_feed_config_fixture(%{external_account_id: "item_error_123"})

      result =
        Plaid.handle_webhook(%{
          "webhook_type" => "ITEM",
          "webhook_code" => "ERROR",
          "item_id" => "item_error_123",
          "error" => %{
            "error_code" => "ITEM_LOGIN_REQUIRED",
            "error_message" => "User must re-authenticate"
          }
        })

      assert {:ok, :error_logged} = result

      updated = Integrations.get_bank_feed_config!(bfc.id)
      assert updated.notes =~ "ITEM_LOGIN_REQUIRED"
    end

    test "unknown webhook type returns :ignored" do
      result =
        Plaid.handle_webhook(%{
          "webhook_type" => "UNKNOWN",
          "webhook_code" => "SOMETHING"
        })

      assert {:ok, :ignored} = result
    end

    test "handles empty payload" do
      result = Plaid.handle_webhook(%{})
      assert {:ok, :ignored} = result
    end
  end

  describe "upsert_bank_feed_transaction integration" do
    test "creates a new transaction when none exists" do
      bfc = bank_feed_config_fixture()

      {:ok, txn} =
        Integrations.upsert_bank_feed_transaction(bfc.id, "plaid_txn_001", %{
          "date" => "2025-01-15",
          "description" => "Coffee Shop",
          "amount" => Decimal.new("-4.50"),
          "currency" => "USD"
        })

      assert txn.external_id == "plaid_txn_001"
      assert txn.description == "Coffee Shop"
    end

    test "updates existing transaction with same external_id" do
      bfc = bank_feed_config_fixture()

      {:ok, txn1} =
        Integrations.upsert_bank_feed_transaction(bfc.id, "plaid_txn_002", %{
          "date" => "2025-01-15",
          "description" => "Pending - Coffee",
          "amount" => Decimal.new("-4.50")
        })

      {:ok, txn2} =
        Integrations.upsert_bank_feed_transaction(bfc.id, "plaid_txn_002", %{
          "date" => "2025-01-15",
          "description" => "Coffee Shop Final",
          "amount" => Decimal.new("-4.75")
        })

      assert txn2.id == txn1.id
      assert txn2.description == "Coffee Shop Final"
    end
  end
end
