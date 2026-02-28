defmodule Holdco.IntegrationsTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Integrations

  describe "accounting_sync_configs" do
    test "CRUD operations" do
      company = company_fixture()
      {:ok, asc} = Integrations.create_accounting_sync_config(%{company_id: company.id, provider: "xero"})

      assert Enum.any?(Integrations.list_accounting_sync_configs(), &(&1.id == asc.id))
      assert Integrations.get_accounting_sync_config!(asc.id).id == asc.id

      {:ok, updated} = Integrations.update_accounting_sync_config(asc, %{provider: "quickbooks"})
      assert updated.provider == "quickbooks"

      {:ok, _} = Integrations.delete_accounting_sync_config(updated)
    end
  end

  describe "accounting_sync_logs" do
    test "CRUD operations" do
      config = accounting_sync_config_fixture()
      {:ok, asl} = Integrations.create_accounting_sync_log(%{config_id: config.id, status: "success", records_synced: 42})

      assert Enum.any?(Integrations.list_accounting_sync_logs(config.id), &(&1.id == asl.id))
      assert Integrations.get_accounting_sync_log!(asl.id).id == asl.id

      {:ok, updated} = Integrations.update_accounting_sync_log(asl, %{records_synced: 50})
      assert updated.records_synced == 50

      {:ok, _} = Integrations.delete_accounting_sync_log(updated)
    end
  end

  describe "bank_feed_configs" do
    test "CRUD operations" do
      company = company_fixture()
      ba = bank_account_fixture(%{company: company})
      {:ok, bfc} = Integrations.create_bank_feed_config(%{company_id: company.id, bank_account_id: ba.id, provider: "plaid"})

      assert Enum.any?(Integrations.list_bank_feed_configs(), &(&1.id == bfc.id))
      assert Integrations.get_bank_feed_config!(bfc.id).id == bfc.id

      {:ok, updated} = Integrations.update_bank_feed_config(bfc, %{provider: "teller"})
      assert updated.provider == "teller"

      {:ok, _} = Integrations.delete_bank_feed_config(updated)
    end
  end

  describe "bank_feed_transactions" do
    test "CRUD operations" do
      bfc = bank_feed_config_fixture()
      {:ok, bft} = Integrations.create_bank_feed_transaction(%{feed_config_id: bfc.id, external_id: "ext_123", date: "2024-01-15"})

      assert Enum.any?(Integrations.list_bank_feed_transactions(bfc.id), &(&1.id == bft.id))
      assert Integrations.get_bank_feed_transaction!(bft.id).id == bft.id

      {:ok, updated} = Integrations.update_bank_feed_transaction(bft, %{description: "Groceries"})
      assert updated.description == "Groceries"

      {:ok, _} = Integrations.delete_bank_feed_transaction(updated)
    end
  end

  describe "signature_requests" do
    test "CRUD operations" do
      company = company_fixture()
      doc = document_fixture(%{company: company})
      {:ok, sr} = Integrations.create_signature_request(%{company_id: company.id, document_id: doc.id, provider: "docusign"})

      assert Enum.any?(Integrations.list_signature_requests(company.id), &(&1.id == sr.id))
      assert Enum.any?(Integrations.list_signature_requests(), &(&1.id == sr.id))
      assert Integrations.get_signature_request!(sr.id).id == sr.id

      {:ok, updated} = Integrations.update_signature_request(sr, %{status: "sent"})
      assert updated.status == "sent"

      {:ok, _} = Integrations.delete_signature_request(updated)
    end
  end

  describe "email_digest_configs" do
    test "CRUD operations" do
      user = Holdco.AccountsFixtures.user_fixture()
      {:ok, edc} = Integrations.create_email_digest_config(%{user_id: user.id, frequency: "daily"})

      assert Enum.any?(Integrations.list_email_digest_configs(), &(&1.id == edc.id))
      assert Integrations.get_email_digest_config!(edc.id).id == edc.id
      assert Integrations.get_email_digest_config_for_user(user.id) != nil

      {:ok, updated} = Integrations.update_email_digest_config(edc, %{frequency: "weekly"})
      assert updated.frequency == "weekly"

      {:ok, _} = Integrations.delete_email_digest_config(updated)
    end
  end

  describe "subscribe/0" do
    test "subscribes to integrations PubSub topic" do
      assert :ok = Integrations.subscribe()
    end
  end

  describe "broadcast/1" do
    test "broadcasts a message" do
      assert :ok = Integrations.broadcast({:test_event, %{}})
    end
  end

  describe "oauth integrations" do
    test "upsert_integration/3 creates new" do
      company = company_fixture()
      {:ok, i} = Integrations.upsert_integration("test_provider", company.id, %{"status" => "connected"})
      assert i.provider == "test_provider"
      assert i.company_id == company.id
    end

    test "upsert_integration/3 updates existing" do
      company = company_fixture()
      {:ok, i1} = Integrations.upsert_integration("update_provider", company.id, %{"status" => "connected"})
      {:ok, i2} = Integrations.upsert_integration("update_provider", company.id, %{"status" => "syncing"})
      assert i2.id == i1.id
      assert i2.status == "syncing"
    end

    test "get_integration/2" do
      company = company_fixture()
      Integrations.upsert_integration("get_test", company.id, %{"status" => "connected"})
      assert Integrations.get_integration("get_test", company.id) != nil
      assert Integrations.get_integration("nonexistent", company.id) == nil
    end

    test "disconnect_integration/2" do
      company = company_fixture()
      Integrations.upsert_integration("disconnect_test", company.id, %{"status" => "connected", "access_token" => "tok"})
      {:ok, i} = Integrations.disconnect_integration("disconnect_test", company.id)
      assert i.status == "disconnected"
      assert i.access_token == nil
    end

    test "disconnect_integration/2 for nonexistent" do
      company = company_fixture()
      {:ok, nil} = Integrations.disconnect_integration("no_such_provider", company.id)
    end

    test "update_last_synced/2" do
      company = company_fixture()
      Integrations.upsert_integration("sync_test", company.id, %{"status" => "connected"})
      {:ok, i} = Integrations.update_last_synced("sync_test", company.id)
      assert i.last_synced_at != nil
    end

    test "update_last_synced/2 for nonexistent" do
      company = company_fixture()
      {:error, :not_found} = Integrations.update_last_synced("missing", company.id)
    end

    test "list_integrations/0" do
      company = company_fixture()
      Integrations.upsert_integration("list_test", company.id, %{"status" => "connected"})
      assert length(Integrations.list_integrations()) > 0
    end
  end
end
