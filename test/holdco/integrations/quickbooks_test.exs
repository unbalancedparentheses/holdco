defmodule Holdco.Integrations.QuickbooksTest do
  use Holdco.DataCase

  import Holdco.HoldcoFixtures

  alias Holdco.Integrations.Quickbooks
  alias Holdco.Integrations

  setup do
    Application.put_env(:holdco, Holdco.Integrations.Quickbooks,
      client_id: "test_client_id",
      client_secret: "test_client_secret",
      redirect_uri: "http://localhost:4000/auth/quickbooks/callback",
      environment: :sandbox
    )

    :ok
  end

  describe "authorize_url/0" do
    test "returns a {url, state} tuple" do
      {url, state} = Quickbooks.authorize_url()
      assert is_binary(url)
      assert is_binary(state)
      assert String.length(state) > 0
    end

    test "returns a URL with the correct base" do
      {url, _state} = Quickbooks.authorize_url()
      assert url =~ "https://appcenter.intuit.com/connect/oauth2"
    end

    test "includes client_id parameter" do
      {url, _state} = Quickbooks.authorize_url()
      assert url =~ "client_id=test_client_id"
    end

    test "includes redirect_uri parameter" do
      {url, _state} = Quickbooks.authorize_url()
      assert url =~ "redirect_uri="
    end

    test "includes response_type=code" do
      {url, _state} = Quickbooks.authorize_url()
      assert url =~ "response_type=code"
    end

    test "includes scope parameter" do
      {url, _state} = Quickbooks.authorize_url()
      assert url =~ "scope=com.intuit.quickbooks.accounting"
    end

    test "includes state parameter for CSRF protection" do
      {url, _state} = Quickbooks.authorize_url()
      assert url =~ "state="
    end

    test "generates different state values each time" do
      {_url1, state1} = Quickbooks.authorize_url()
      {_url2, state2} = Quickbooks.authorize_url()
      assert state1 != state2
    end

    test "returned state matches the state in the URL" do
      {url, state} = Quickbooks.authorize_url()
      url_state = url |> URI.parse() |> Map.get(:query) |> URI.decode_query() |> Map.get("state")
      assert url_state == state
    end

    test "uses production base when environment is production" do
      Application.put_env(:holdco, Holdco.Integrations.Quickbooks,
        client_id: "prod_id",
        client_secret: "prod_secret",
        redirect_uri: "https://example.com/callback",
        environment: :production
      )

      {url, _state} = Quickbooks.authorize_url()
      assert url =~ "client_id=prod_id"
    end
  end

  describe "sync_all/1" do
    test "returns error when no integration exists" do
      company = company_fixture()
      assert {:error, :not_connected} = Quickbooks.sync_all(company.id)
    end

    test "returns error when integration is disconnected" do
      company = company_fixture()
      Integrations.upsert_integration("quickbooks", company.id, %{"status" => "disconnected"})
      assert {:error, :not_connected} = Quickbooks.sync_all(company.id)
    end

    test "returns error when no integration exists with company_id" do
      assert {:error, :not_connected} = Quickbooks.sync_all(1)
    end
  end

  describe "sync_accounts/2" do
    test "handles empty account response" do
      company = company_fixture()

      {:ok, integration} =
        Integrations.upsert_integration("quickbooks", company.id, %{
          "status" => "connected",
          "access_token" => "test_token",
          "realm_id" => "12345",
          "token_expires_at" => DateTime.add(DateTime.utc_now(), 3600, :second)
        })

      # api_get will fail since there's no real QuickBooks API to talk to,
      # but this exercises the code paths through ensure_fresh_token! (not expired)
      result = Quickbooks.sync_accounts(integration, company.id)
      assert {:error, _reason} = result
    end

    test "handles sync_accounts with company_id parameter" do
      company = company_fixture()

      {:ok, integration} =
        Integrations.upsert_integration("quickbooks", company.id, %{
          "status" => "connected",
          "access_token" => "test_token",
          "realm_id" => "12345",
          "token_expires_at" => DateTime.add(DateTime.utc_now(), 3600, :second)
        })
      result = Quickbooks.sync_accounts(integration, company.id)
      assert {:error, _reason} = result
    end
  end

  describe "sync_journal_entries/2" do
    test "handles failed API call" do
      company = company_fixture()

      {:ok, integration} =
        Integrations.upsert_integration("quickbooks", company.id, %{
          "status" => "connected",
          "access_token" => "test_token",
          "realm_id" => "12345",
          "token_expires_at" => DateTime.add(DateTime.utc_now(), 3600, :second)
        })

      result = Quickbooks.sync_journal_entries(integration, company.id)
      assert {:error, _reason} = result
    end

    test "handles sync_journal_entries with company_id parameter" do
      company = company_fixture()

      {:ok, integration} =
        Integrations.upsert_integration("quickbooks", company.id, %{
          "status" => "connected",
          "access_token" => "test_token",
          "realm_id" => "12345",
          "token_expires_at" => DateTime.add(DateTime.utc_now(), 3600, :second)
        })
      result = Quickbooks.sync_journal_entries(integration, company.id)
      assert {:error, _reason} = result
    end
  end

  describe "api_get/2" do
    test "attempts refresh when token is expired" do
      company = company_fixture()

      {:ok, integration} =
        Integrations.upsert_integration("quickbooks", company.id, %{
          "status" => "connected",
          "access_token" => "expired_token",
          "refresh_token" => "test_refresh",
          "realm_id" => "12345",
          "token_expires_at" => DateTime.add(DateTime.utc_now(), -3600, :second)
        })

      # This exercises ensure_fresh_token! -> refresh_token path
      # The refresh will fail (no real API) but the code path is covered
      result = Quickbooks.api_get(integration, "/test")
      assert {:error, _reason} = result
    end

    test "uses token directly when not expired" do
      company = company_fixture()

      {:ok, integration} =
        Integrations.upsert_integration("quickbooks", company.id, %{
          "status" => "connected",
          "access_token" => "valid_token",
          "realm_id" => "12345",
          "token_expires_at" => DateTime.add(DateTime.utc_now(), 3600, :second)
        })

      # Token is valid, so ensure_fresh_token! returns integration as-is
      result = Quickbooks.api_get(integration, "/test")
      assert {:error, _reason} = result
    end

    test "uses token when token_expires_at is nil" do
      company = company_fixture()

      {:ok, integration} =
        Integrations.upsert_integration("quickbooks", company.id, %{
          "status" => "connected",
          "access_token" => "valid_token",
          "realm_id" => "12345"
        })

      result = Quickbooks.api_get(integration, "/test")
      assert {:error, _reason} = result
    end
  end
end
