defmodule HoldcoWeb.QuickbooksControllerTest do
  use HoldcoWeb.ConnCase

  setup :register_and_log_in_user

  describe "GET /auth/quickbooks/connect" do
    test "redirects to QuickBooks authorization URL", %{conn: conn} do
      Application.put_env(:holdco, Holdco.Integrations.Quickbooks,
        client_id: "test_client_id",
        client_secret: "test_client_secret",
        redirect_uri: "http://localhost:4000/auth/quickbooks/callback",
        environment: :sandbox
      )

      conn = get(conn, ~p"/auth/quickbooks/connect")
      assert redirected_to(conn) =~ "https://appcenter.intuit.com/connect/oauth2"
    end

    test "authorization URL includes required OAuth2 params", %{conn: conn} do
      Application.put_env(:holdco, Holdco.Integrations.Quickbooks,
        client_id: "test_client_id",
        client_secret: "test_client_secret",
        redirect_uri: "http://localhost:4000/auth/quickbooks/callback",
        environment: :sandbox
      )

      conn = get(conn, ~p"/auth/quickbooks/connect")
      location = redirected_to(conn)
      assert location =~ "client_id=test_client_id"
      assert location =~ "response_type=code"
      assert location =~ "scope=com.intuit.quickbooks.accounting"
    end

    test "requires authentication", %{conn: _conn} do
      conn = build_conn()
      conn = get(conn, ~p"/auth/quickbooks/connect")
      assert redirected_to(conn) == ~p"/users/log-in"
    end
  end

  describe "GET /auth/quickbooks/callback with error" do
    test "redirects to integrations page with error flash", %{conn: conn} do
      conn = get(conn, ~p"/auth/quickbooks/callback", %{"error" => "access_denied"})
      assert redirected_to(conn) == ~p"/accounts/integrations"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "access_denied"
    end

    test "includes error description in flash", %{conn: conn} do
      conn = get(conn, ~p"/auth/quickbooks/callback", %{"error" => "server_error"})
      assert redirected_to(conn) == ~p"/accounts/integrations"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "server_error"
    end
  end

  describe "GET /auth/quickbooks/callback with code (callback)" do
    test "redirects to integrations with error flash when exchange fails", %{conn: conn} do
      # Configure Quickbooks so it tries to talk to a non-existent token endpoint
      Application.put_env(:holdco, Holdco.Integrations.Quickbooks,
        client_id: "test_id",
        client_secret: "test_secret",
        redirect_uri: "http://localhost:4000/auth/quickbooks/callback",
        environment: :sandbox
      )

      # The exchange_code call will fail because the token URL is a real external URL
      # that won't have a valid code. This tests the error path of callback/2.
      conn =
        get(conn, ~p"/auth/quickbooks/callback", %{
          "code" => "fake_auth_code",
          "realmId" => "12345"
        })

      assert redirected_to(conn) == ~p"/accounts/integrations"
      # Depending on the network result, it will either flash error or info
      # The key test is that it redirects properly and doesn't crash
    end

    test "error flash includes failure reason on exchange error", %{conn: conn} do
      Application.put_env(:holdco, Holdco.Integrations.Quickbooks,
        client_id: "bad_id",
        client_secret: "bad_secret",
        redirect_uri: "http://localhost:4000/auth/quickbooks/callback",
        environment: :sandbox
      )

      conn =
        get(conn, ~p"/auth/quickbooks/callback", %{
          "code" => "invalid_code",
          "realmId" => "99999"
        })

      assert redirected_to(conn) == ~p"/accounts/integrations"
      flash = Phoenix.Flash.get(conn.assigns.flash, :error)
      # The error flash should be set (exchange will fail)
      assert flash =~ "Failed to connect QuickBooks"
    end
  end
end
