defmodule HoldcoWeb.ExportControllerTest do
  use HoldcoWeb.ConnCase

  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "CSV exports" do
    test "GET /export/companies.csv", %{conn: conn} do
      company_fixture(%{name: "Export Corp"})
      conn = get(conn, ~p"/export/companies.csv")
      assert response(conn, 200)
      assert response_content_type(conn, :csv) || get_resp_header(conn, "content-type") |> hd() =~ "csv"
    end

    test "GET /export/holdings.csv", %{conn: conn} do
      holding_fixture()
      conn = get(conn, ~p"/export/holdings.csv")
      assert response(conn, 200)
    end

    test "GET /export/transactions.csv", %{conn: conn} do
      transaction_fixture()
      conn = get(conn, ~p"/export/transactions.csv")
      assert response(conn, 200)
    end

    test "GET /export/chart-of-accounts.csv", %{conn: conn} do
      account_fixture()
      conn = get(conn, ~p"/export/chart-of-accounts.csv")
      assert response(conn, 200)
    end

    test "GET /export/journal-entries.csv", %{conn: conn} do
      journal_entry_fixture()
      conn = get(conn, ~p"/export/journal-entries.csv")
      assert response(conn, 200)
    end
  end
end
