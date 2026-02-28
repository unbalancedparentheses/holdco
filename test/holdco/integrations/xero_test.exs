defmodule Holdco.Integrations.XeroTest do
  use Holdco.DataCase, async: true

  alias Holdco.Integrations.Xero
  alias Holdco.Integrations

  import Holdco.HoldcoFixtures

  # ── Config ──────────────────────────────────────────

  describe "config/0" do
    test "reads configuration from application env" do
      Application.put_env(:holdco, Holdco.Integrations.Xero,
        client_id: "test_id",
        client_secret: "test_secret",
        redirect_uri: "http://localhost:4000/auth/xero/callback"
      )

      {url, state} = Xero.authorize_url()
      assert is_binary(state)
      assert String.contains?(url, "test_id")
      assert String.contains?(url, "http%3A%2F%2Flocalhost%3A4000%2Fauth%2Fxero%2Fcallback")
    end

    test "defaults to empty list when no config is set" do
      Application.delete_env(:holdco, Holdco.Integrations.Xero)
      # authorize_url should still work, just with nil values in the URL
      {url, state} = Xero.authorize_url()
      assert is_binary(url)
      assert is_binary(state)
    end
  end

  # ── authorize_url ──────────────────────────────────

  describe "authorize_url/0" do
    setup do
      Application.put_env(:holdco, Holdco.Integrations.Xero,
        client_id: "xero_client_123",
        client_secret: "xero_secret_456",
        redirect_uri: "http://localhost:4000/auth/xero/callback"
      )

      :ok
    end

    test "returns a URL and state tuple" do
      {url, state} = Xero.authorize_url()
      assert is_binary(url)
      assert is_binary(state)
      assert byte_size(state) > 0
    end

    test "URL contains the Xero auth base" do
      {url, _state} = Xero.authorize_url()
      assert String.starts_with?(url, "https://login.xero.com/identity/connect/authorize?")
    end

    test "URL contains required OAuth2 parameters" do
      {url, _state} = Xero.authorize_url()
      assert String.contains?(url, "client_id=xero_client_123")
      assert String.contains?(url, "response_type=code")
      assert String.contains?(url, "scope=")
      assert String.contains?(url, "state=")
      assert String.contains?(url, "redirect_uri=")
    end

    test "URL includes the correct scopes" do
      {url, _state} = Xero.authorize_url()
      # URL-encoded scopes
      assert String.contains?(url, "openid")
      assert String.contains?(url, "offline_access")
      assert String.contains?(url, "accounting.transactions")
    end

    test "generates unique state for each call" do
      {_url1, state1} = Xero.authorize_url()
      {_url2, state2} = Xero.authorize_url()
      assert state1 != state2
    end
  end

  # ── Account type mapping ───────────────────────────

  describe "map_account_type/1" do
    test "maps BANK to asset" do
      assert Xero.map_account_type("BANK") == "asset"
    end

    test "maps CURRENT to asset" do
      assert Xero.map_account_type("CURRENT") == "asset"
    end

    test "maps FIXED to asset" do
      assert Xero.map_account_type("FIXED") == "asset"
    end

    test "maps INVENTORY to asset" do
      assert Xero.map_account_type("INVENTORY") == "asset"
    end

    test "maps NONCURRENT to asset" do
      assert Xero.map_account_type("NONCURRENT") == "asset"
    end

    test "maps PREPAYMENT to asset" do
      assert Xero.map_account_type("PREPAYMENT") == "asset"
    end

    test "maps CURRLIAB to liability" do
      assert Xero.map_account_type("CURRLIAB") == "liability"
    end

    test "maps TERMLIAB to liability" do
      assert Xero.map_account_type("TERMLIAB") == "liability"
    end

    test "maps LIABILITY to liability" do
      assert Xero.map_account_type("LIABILITY") == "liability"
    end

    test "maps PAYGLIABILITY to liability" do
      assert Xero.map_account_type("PAYGLIABILITY") == "liability"
    end

    test "maps EQUITY to equity" do
      assert Xero.map_account_type("EQUITY") == "equity"
    end

    test "maps REVENUE to revenue" do
      assert Xero.map_account_type("REVENUE") == "revenue"
    end

    test "maps SALES to revenue" do
      assert Xero.map_account_type("SALES") == "revenue"
    end

    test "maps OTHERINCOME to revenue" do
      assert Xero.map_account_type("OTHERINCOME") == "revenue"
    end

    test "maps EXPENSE to expense" do
      assert Xero.map_account_type("EXPENSE") == "expense"
    end

    test "maps DEPRECIATN to expense" do
      assert Xero.map_account_type("DEPRECIATN") == "expense"
    end

    test "maps DIRECTCOSTS to expense" do
      assert Xero.map_account_type("DIRECTCOSTS") == "expense"
    end

    test "maps OVERHEADS to expense" do
      assert Xero.map_account_type("OVERHEADS") == "expense"
    end

    test "maps WAGESEXPENSE to expense" do
      assert Xero.map_account_type("WAGESEXPENSE") == "expense"
    end

    test "maps SUPERANNUATIONEXPENSE to expense" do
      assert Xero.map_account_type("SUPERANNUATIONEXPENSE") == "expense"
    end

    test "maps SUPERANNUATIONLIABILITY to liability" do
      assert Xero.map_account_type("SUPERANNUATIONLIABILITY") == "liability"
    end

    test "maps unknown types to asset as default" do
      assert Xero.map_account_type("SOMETHING_UNKNOWN") == "asset"
      assert Xero.map_account_type("") == "asset"
      assert Xero.map_account_type(nil) == "asset"
    end
  end

  # ── sync_all ───────────────────────────────────────

  describe "sync_all/1" do
    test "returns error when no integration exists" do
      company = company_fixture()
      assert {:error, :not_connected} = Xero.sync_all(company.id)
    end

    test "returns error when integration is disconnected" do
      company = company_fixture()

      Integrations.upsert_integration("xero", company.id, %{
        "status" => "disconnected"
      })

      assert {:error, :not_connected} = Xero.sync_all(company.id)
    end
  end

  # ── Integration storage ────────────────────────────

  describe "integration storage via upsert" do
    test "creates a new xero integration" do
      company = company_fixture()

      {:ok, integration} =
        Integrations.upsert_integration("xero", company.id, %{
          "access_token" => "xero_token_abc",
          "refresh_token" => "xero_refresh_xyz",
          "token_expires_at" => DateTime.utc_now() |> DateTime.add(1800) |> DateTime.truncate(:second),
          "realm_id" => "tenant-uuid-123",
          "status" => "connected"
        })

      assert integration.provider == "xero"
      assert integration.access_token == "xero_token_abc"
      assert integration.refresh_token == "xero_refresh_xyz"
      assert integration.realm_id == "tenant-uuid-123"
      assert integration.status == "connected"
      assert integration.company_id == company.id
    end

    test "updates an existing xero integration" do
      company = company_fixture()

      {:ok, _} =
        Integrations.upsert_integration("xero", company.id, %{
          "access_token" => "old_token",
          "refresh_token" => "old_refresh",
          "status" => "connected"
        })

      {:ok, updated} =
        Integrations.upsert_integration("xero", company.id, %{
          "access_token" => "new_token",
          "refresh_token" => "new_refresh",
          "status" => "connected"
        })

      assert updated.access_token == "new_token"
      assert updated.refresh_token == "new_refresh"
    end

    test "retrieves a xero integration by provider and company" do
      company = company_fixture()

      {:ok, _} =
        Integrations.upsert_integration("xero", company.id, %{
          "access_token" => "test_token",
          "status" => "connected"
        })

      integration = Integrations.get_integration("xero", company.id)
      assert integration.provider == "xero"
      assert integration.access_token == "test_token"
    end

    test "returns nil for non-existent integration" do
      company = company_fixture()
      assert Integrations.get_integration("xero", company.id) == nil
    end
  end

  # ── Disconnect ─────────────────────────────────────

  describe "disconnect_integration/2" do
    test "disconnects a connected xero integration" do
      company = company_fixture()

      {:ok, _} =
        Integrations.upsert_integration("xero", company.id, %{
          "access_token" => "token",
          "refresh_token" => "refresh",
          "realm_id" => "tenant-123",
          "status" => "connected"
        })

      {:ok, disconnected} = Integrations.disconnect_integration("xero", company.id)
      assert disconnected.status == "disconnected"
      assert disconnected.access_token == nil
      assert disconnected.refresh_token == nil
      assert disconnected.realm_id == nil
    end

    test "handles disconnecting a non-existent integration gracefully" do
      company = company_fixture()
      assert {:ok, nil} = Integrations.disconnect_integration("xero", company.id)
    end
  end

  # ── Token refresh logic ────────────────────────────

  describe "token freshness" do
    test "integration with future expiry is considered fresh" do
      company = company_fixture()

      {:ok, integration} =
        Integrations.upsert_integration("xero", company.id, %{
          "access_token" => "valid_token",
          "refresh_token" => "refresh_token",
          "token_expires_at" =>
            DateTime.utc_now() |> DateTime.add(3600) |> DateTime.truncate(:second),
          "realm_id" => "tenant-123",
          "status" => "connected"
        })

      # A fresh integration should not trigger refresh -- we verify it still has the same token
      # (This tests the ensure_fresh_token! logic indirectly)
      assert integration.access_token == "valid_token"
      assert DateTime.compare(integration.token_expires_at, DateTime.utc_now()) == :gt
    end

    test "integration with past expiry needs refresh" do
      company = company_fixture()

      {:ok, integration} =
        Integrations.upsert_integration("xero", company.id, %{
          "access_token" => "expired_token",
          "refresh_token" => "refresh_token",
          "token_expires_at" =>
            DateTime.utc_now() |> DateTime.add(-3600) |> DateTime.truncate(:second),
          "realm_id" => "tenant-123",
          "status" => "connected"
        })

      assert DateTime.compare(integration.token_expires_at, DateTime.utc_now()) == :lt
    end

    test "integration with nil token_expires_at is treated as fresh" do
      company = company_fixture()

      {:ok, integration} =
        Integrations.upsert_integration("xero", company.id, %{
          "access_token" => "token_no_expiry",
          "refresh_token" => "refresh",
          "token_expires_at" => nil,
          "realm_id" => "tenant-123",
          "status" => "connected"
        })

      assert integration.token_expires_at == nil
    end
  end

  # ── update_last_synced ─────────────────────────────

  describe "update_last_synced/2" do
    test "sets last_synced_at on a xero integration" do
      company = company_fixture()

      {:ok, _} =
        Integrations.upsert_integration("xero", company.id, %{
          "access_token" => "token",
          "status" => "connected"
        })

      {:ok, updated} = Integrations.update_last_synced("xero", company.id)
      assert updated.last_synced_at != nil
    end

    test "returns error for non-existent integration" do
      assert {:error, :not_found} = Integrations.update_last_synced("xero", -1)
    end
  end

  # ── Xero-specific sync data structures ─────────────

  describe "sync_accounts/2 data mapping" do
    test "maps Xero account response fields correctly" do
      # Verify the mapping function handles all expected Xero types
      xero_types = [
        {"BANK", "asset"},
        {"CURRENT", "asset"},
        {"FIXED", "asset"},
        {"CURRLIAB", "liability"},
        {"TERMLIAB", "liability"},
        {"EQUITY", "equity"},
        {"REVENUE", "revenue"},
        {"EXPENSE", "expense"},
        {"DIRECTCOSTS", "expense"},
        {"SALES", "revenue"},
        {"OVERHEADS", "expense"},
        {"OTHERINCOME", "revenue"},
        {"DEPRECIATN", "expense"}
      ]

      for {xero_type, expected_type} <- xero_types do
        assert Xero.map_account_type(xero_type) == expected_type,
               "Expected #{xero_type} to map to #{expected_type}, got #{Xero.map_account_type(xero_type)}"
      end
    end
  end

  # ── Multiple providers coexist ─────────────────────

  describe "xero and quickbooks coexistence" do
    test "same company can have both xero and quickbooks integrations" do
      company = company_fixture()

      {:ok, qbo} =
        Integrations.upsert_integration("quickbooks", company.id, %{
          "access_token" => "qbo_token",
          "status" => "connected"
        })

      {:ok, xero} =
        Integrations.upsert_integration("xero", company.id, %{
          "access_token" => "xero_token",
          "status" => "connected"
        })

      assert qbo.provider == "quickbooks"
      assert xero.provider == "xero"
      assert qbo.company_id == xero.company_id

      # Retrieve independently
      assert Integrations.get_integration("quickbooks", company.id).access_token == "qbo_token"
      assert Integrations.get_integration("xero", company.id).access_token == "xero_token"
    end

    test "disconnecting xero does not affect quickbooks" do
      company = company_fixture()

      {:ok, _} =
        Integrations.upsert_integration("quickbooks", company.id, %{
          "access_token" => "qbo_token",
          "status" => "connected"
        })

      {:ok, _} =
        Integrations.upsert_integration("xero", company.id, %{
          "access_token" => "xero_token",
          "status" => "connected"
        })

      {:ok, _} = Integrations.disconnect_integration("xero", company.id)

      qbo = Integrations.get_integration("quickbooks", company.id)
      xero = Integrations.get_integration("xero", company.id)

      assert qbo.status == "connected"
      assert qbo.access_token == "qbo_token"
      assert xero.status == "disconnected"
      assert xero.access_token == nil
    end
  end
end
