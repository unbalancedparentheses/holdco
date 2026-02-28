defmodule HoldcoWeb.ApiTest do
  use HoldcoWeb.ConnCase, async: true

  import Holdco.HoldcoFixtures

  setup do
    user = Holdco.AccountsFixtures.user_fixture()
    {:ok, api_key} = Holdco.Accounts.create_api_key(user, "test-key")

    conn =
      Phoenix.ConnTest.build_conn()
      |> put_req_header("x-api-key", api_key.key)
      |> put_req_header("accept", "application/json")

    %{conn: conn, user: user, api_key: api_key}
  end

  describe "API health" do
    test "GET /api/health returns ok", %{conn: conn} do
      conn = get(conn, "/api/health")
      assert json_response(conn, 200)["status"] == "ok"
    end
  end

  describe "API companies" do
    test "GET /api/companies returns list", %{conn: conn} do
      company_fixture(%{name: "API Corp"})
      conn = get(conn, "/api/companies")
      assert json_response(conn, 200)
    end

    test "GET /api/companies/:id returns company", %{conn: conn} do
      company = company_fixture(%{name: "API Show Corp"})
      conn = get(conn, "/api/companies/#{company.id}")
      assert json_response(conn, 200)
    end
  end

  describe "API portfolio" do
    test "GET /api/portfolio returns data", %{conn: conn} do
      conn = get(conn, "/api/portfolio")
      assert json_response(conn, 200)
    end

    test "GET /api/portfolio/allocation returns data", %{conn: conn} do
      conn = get(conn, "/api/portfolio/allocation")
      assert json_response(conn, 200)
    end

    test "GET /api/portfolio/fx-exposure returns data", %{conn: conn} do
      conn = get(conn, "/api/portfolio/fx-exposure")
      assert json_response(conn, 200)
    end
  end

  describe "API holdings" do
    test "GET /api/holdings returns list", %{conn: conn} do
      holding_fixture()
      conn = get(conn, "/api/holdings")
      assert json_response(conn, 200)
    end
  end

  describe "API transactions" do
    test "GET /api/transactions returns list", %{conn: conn} do
      transaction_fixture()
      conn = get(conn, "/api/transactions")
      assert json_response(conn, 200)
    end
  end

  describe "API key auth" do
    test "rejects request without API key" do
      conn =
        Phoenix.ConnTest.build_conn()
        |> put_req_header("accept", "application/json")
        |> get("/api/health")

      assert json_response(conn, 401)
    end

    test "rejects request with invalid API key" do
      conn =
        Phoenix.ConnTest.build_conn()
        |> put_req_header("x-api-key", "invalid_key_xxx")
        |> put_req_header("accept", "application/json")
        |> get("/api/health")

      assert json_response(conn, 401)
    end
  end
end
