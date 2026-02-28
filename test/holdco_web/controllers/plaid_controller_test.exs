defmodule HoldcoWeb.PlaidControllerTest do
  use HoldcoWeb.ConnCase

  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "POST /auth/plaid/link-token" do
    test "returns error when company_id is missing", %{conn: conn} do
      conn = post(conn, ~p"/auth/plaid/link-token", %{})
      assert json_response(conn, 400)["error"] == "company_id is required"
    end

    test "requires authentication" do
      conn = build_conn()
      conn = post(conn, ~p"/auth/plaid/link-token", %{"company_id" => "1"})
      assert redirected_to(conn) == ~p"/users/log-in"
    end

    test "returns error when Plaid API call fails", %{conn: conn} do
      # Configure Plaid with invalid credentials so the API call fails
      Application.put_env(:holdco, Holdco.Integrations.Plaid,
        client_id: "invalid_test_id",
        secret: "invalid_test_secret",
        environment: :sandbox
      )

      company = company_fixture(%{name: "PlaidLinkCo"})
      conn = post(conn, ~p"/auth/plaid/link-token", %{"company_id" => to_string(company.id)})

      # The Plaid API call will fail (invalid credentials or network), returning 422
      assert json_response(conn, 422)["error"]
    end
  end

  describe "POST /auth/plaid/exchange-token" do
    test "returns error when required params are missing", %{conn: conn} do
      conn = post(conn, ~p"/auth/plaid/exchange-token", %{})
      assert json_response(conn, 400)["error"] == "public_token, company_id, and bank_account_id are required"
    end

    test "returns error when public_token is missing", %{conn: conn} do
      conn = post(conn, ~p"/auth/plaid/exchange-token", %{
        "company_id" => "1",
        "bank_account_id" => "1"
      })

      assert json_response(conn, 400)["error"] == "public_token, company_id, and bank_account_id are required"
    end

    test "returns error when company_id is missing", %{conn: conn} do
      conn = post(conn, ~p"/auth/plaid/exchange-token", %{
        "public_token" => "public-sandbox-xxx",
        "bank_account_id" => "1"
      })

      assert json_response(conn, 400)["error"] == "public_token, company_id, and bank_account_id are required"
    end

    test "returns error when bank_account_id is missing", %{conn: conn} do
      conn = post(conn, ~p"/auth/plaid/exchange-token", %{
        "public_token" => "public-sandbox-xxx",
        "company_id" => "1"
      })

      assert json_response(conn, 400)["error"] == "public_token, company_id, and bank_account_id are required"
    end

    test "requires authentication" do
      conn = build_conn()
      conn = post(conn, ~p"/auth/plaid/exchange-token", %{
        "public_token" => "public-sandbox-xxx",
        "company_id" => "1",
        "bank_account_id" => "1"
      })

      assert redirected_to(conn) == ~p"/users/log-in"
    end

    test "returns error when Plaid API call fails", %{conn: conn} do
      Application.put_env(:holdco, Holdco.Integrations.Plaid,
        client_id: "invalid_test_id",
        secret: "invalid_test_secret",
        environment: :sandbox
      )

      company = company_fixture(%{name: "PlaidExchangeCo"})
      ba = bank_account_fixture(%{company: company})

      conn = post(conn, ~p"/auth/plaid/exchange-token", %{
        "public_token" => "public-sandbox-invalid",
        "company_id" => to_string(company.id),
        "bank_account_id" => to_string(ba.id)
      })

      assert json_response(conn, 422)["error"]
    end
  end

  describe "POST /auth/plaid/exchange-token with institution params" do
    test "returns error when exchange fails but includes institution params", %{conn: conn} do
      Application.put_env(:holdco, Holdco.Integrations.Plaid,
        client_id: "invalid_test_id",
        secret: "invalid_test_secret",
        environment: :sandbox
      )

      company = company_fixture(%{name: "PlaidInstCo"})
      ba = bank_account_fixture(%{company: company})

      conn =
        post(conn, ~p"/auth/plaid/exchange-token", %{
          "public_token" => "public-sandbox-invalid",
          "company_id" => to_string(company.id),
          "bank_account_id" => to_string(ba.id),
          "institution_id" => "ins_123",
          "institution_name" => "Test Bank"
        })

      assert json_response(conn, 422)["error"]
    end
  end

  describe "POST /webhooks/plaid" do
    test "returns ok for unrecognized webhook type", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> post(~p"/webhooks/plaid", %{
          "webhook_type" => "UNKNOWN",
          "webhook_code" => "UNKNOWN"
        })

      assert json_response(conn, 200)["status"] == "ok"
    end

    test "returns ok for TRANSACTIONS SYNC_UPDATES_AVAILABLE with no matching configs", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> post(~p"/webhooks/plaid", %{
          "webhook_type" => "TRANSACTIONS",
          "webhook_code" => "SYNC_UPDATES_AVAILABLE",
          "item_id" => "nonexistent_item_id"
        })

      assert json_response(conn, 200)["status"] == "ok"
    end

    test "returns ok for ITEM ERROR webhook", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> post(~p"/webhooks/plaid", %{
          "webhook_type" => "ITEM",
          "webhook_code" => "ERROR",
          "item_id" => "nonexistent_item_id",
          "error" => %{"error_type" => "ITEM_ERROR", "error_code" => "ITEM_LOGIN_REQUIRED"}
        })

      assert json_response(conn, 200)["status"] == "ok"
    end

    test "returns ok for DEFAULT_UPDATE webhook", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> post(~p"/webhooks/plaid", %{
          "webhook_type" => "TRANSACTIONS",
          "webhook_code" => "DEFAULT_UPDATE",
          "item_id" => "nonexistent_item_id"
        })

      assert json_response(conn, 200)["status"] == "ok"
    end

    test "webhook endpoint does not require authentication" do
      conn = build_conn()

      conn =
        conn
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> post(~p"/webhooks/plaid", %{
          "webhook_type" => "UNKNOWN",
          "webhook_code" => "TEST"
        })

      # Should not redirect to login; webhook is public
      assert json_response(conn, 200)["status"] == "ok"
    end

    test "webhook with empty payload returns ok", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> post(~p"/webhooks/plaid", %{})

      assert json_response(conn, 200)["status"] == "ok"
    end

    test "webhook with ITEM ERROR and matching configs returns ok", %{conn: conn} do
      _bfc = bank_feed_config_fixture(%{external_account_id: "webhook_ctrl_item"})

      conn =
        conn
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> post(~p"/webhooks/plaid", %{
          "webhook_type" => "ITEM",
          "webhook_code" => "ERROR",
          "item_id" => "webhook_ctrl_item",
          "error" => %{
            "error_code" => "ITEM_LOGIN_REQUIRED",
            "error_message" => "Re-authenticate"
          }
        })

      assert json_response(conn, 200)["status"] == "ok"
    end
  end

  describe "POST /auth/plaid/link-token with valid company" do
    test "attempts link token creation with real company_id", %{conn: conn} do
      Application.put_env(:holdco, Holdco.Integrations.Plaid,
        client_id: "invalid_test_id",
        secret: "invalid_test_secret",
        environment: :sandbox
      )

      company = company_fixture(%{name: "PlaidLinkTokenCo"})
      conn = post(conn, ~p"/auth/plaid/link-token", %{"company_id" => to_string(company.id)})

      # Will fail with Plaid API error (invalid credentials), returns 422
      assert json_response(conn, 422)["error"]
    end
  end

  describe "POST /auth/plaid/exchange-token with all params" do
    test "attempts exchange with all required params plus institution info", %{conn: conn} do
      Application.put_env(:holdco, Holdco.Integrations.Plaid,
        client_id: "invalid_test_id",
        secret: "invalid_test_secret",
        environment: :sandbox
      )

      company = company_fixture(%{name: "PlaidExchangeFullCo"})
      ba = bank_account_fixture(%{company: company})

      conn =
        post(conn, ~p"/auth/plaid/exchange-token", %{
          "public_token" => "public-sandbox-test-token",
          "company_id" => to_string(company.id),
          "bank_account_id" => to_string(ba.id),
          "institution_id" => "ins_456",
          "institution_name" => "Bank of Testing"
        })

      assert json_response(conn, 422)["error"]
    end
  end
end
