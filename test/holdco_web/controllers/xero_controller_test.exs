defmodule HoldcoWeb.XeroControllerTest do
  use HoldcoWeb.ConnCase

  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "GET /auth/xero/connect" do
    test "redirects to Xero authorization URL with company_id", %{conn: conn} do
      Application.put_env(:holdco, Holdco.Integrations.Xero,
        client_id: "test_xero_client_id",
        client_secret: "test_xero_client_secret",
        redirect_uri: "http://localhost:4000/auth/xero/callback",
        environment: :sandbox
      )

      company = company_fixture(%{name: "XeroConnectCo"})
      conn = get(conn, ~p"/auth/xero/connect", %{"company_id" => to_string(company.id)})

      assert redirected_to(conn) =~ "https://login.xero.com/identity/connect/authorize"
    end

    test "authorization URL includes required OAuth2 params", %{conn: conn} do
      Application.put_env(:holdco, Holdco.Integrations.Xero,
        client_id: "test_xero_client_id",
        client_secret: "test_xero_client_secret",
        redirect_uri: "http://localhost:4000/auth/xero/callback",
        environment: :sandbox
      )

      company = company_fixture(%{name: "XeroParamsCo"})
      conn = get(conn, ~p"/auth/xero/connect", %{"company_id" => to_string(company.id)})
      location = redirected_to(conn)

      assert location =~ "client_id=test_xero_client_id"
      assert location =~ "response_type=code"
      assert location =~ "scope="
    end

    test "redirects to integrations with error when company_id is missing", %{conn: conn} do
      conn = get(conn, ~p"/auth/xero/connect")

      assert redirected_to(conn) == ~p"/accounts/integrations"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Company ID is required to connect Xero"
    end

    test "requires authentication" do
      conn = build_conn()
      conn = get(conn, ~p"/auth/xero/connect")
      assert redirected_to(conn) == ~p"/users/log-in"
    end
  end

  describe "GET /auth/xero/callback with error" do
    test "redirects to integrations with error flash when no company in session", %{conn: conn} do
      conn = get(conn, ~p"/auth/xero/callback", %{"error" => "access_denied"})

      assert redirected_to(conn) == ~p"/accounts/integrations"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "access_denied"
    end

    test "redirects to company page with error flash when company in session", %{conn: conn} do
      company = company_fixture(%{name: "XeroErrorCo"})

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{xero_company_id: to_string(company.id)})
        |> get(~p"/auth/xero/callback", %{"error" => "server_error"})

      assert redirected_to(conn) == ~p"/companies/#{company.id}"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "server_error"
    end
  end

  describe "GET /auth/xero/callback with code" do
    test "redirects with error flash on OAuth state mismatch", %{conn: conn} do
      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{
          xero_company_id: "1",
          xero_oauth_state: "expected_state"
        })
        |> get(~p"/auth/xero/callback", %{
          "code" => "auth_code",
          "state" => "wrong_state"
        })

      assert redirected_to(conn) == ~p"/accounts/integrations"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "OAuth state mismatch"
    end

    test "redirects with error when no OAuth state in session", %{conn: conn} do
      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{xero_company_id: "1"})
        |> get(~p"/auth/xero/callback", %{
          "code" => "auth_code",
          "state" => "some_state"
        })

      assert redirected_to(conn) == ~p"/accounts/integrations"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "OAuth state mismatch"
    end

    test "redirects with error when company_id is missing from session", %{conn: conn} do
      state = "valid_state"

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{xero_oauth_state: state})
        |> get(~p"/auth/xero/callback", %{
          "code" => "auth_code",
          "state" => state
        })

      assert redirected_to(conn) == ~p"/accounts/integrations"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Missing company context"
    end

    test "redirects with error flash when code exchange fails", %{conn: conn} do
      Application.put_env(:holdco, Holdco.Integrations.Xero,
        client_id: "bad_xero_id",
        client_secret: "bad_xero_secret",
        redirect_uri: "http://localhost:4000/auth/xero/callback",
        environment: :sandbox
      )

      company = company_fixture(%{name: "XeroExchangeCo"})
      state = "test_state_value"

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{
          xero_oauth_state: state,
          xero_company_id: to_string(company.id)
        })
        |> get(~p"/auth/xero/callback", %{
          "code" => "invalid_code",
          "state" => state
        })

      assert redirected_to(conn) == ~p"/companies/#{company.id}"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Failed to connect Xero"
    end
  end
end
