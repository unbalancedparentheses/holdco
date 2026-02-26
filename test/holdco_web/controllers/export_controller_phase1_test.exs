defmodule HoldcoWeb.ExportControllerPhase1Test do
  use HoldcoWeb.ConnCase

  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "GET /export/audit-log.csv" do
    test "returns CSV with headers", %{conn: conn} do
      conn = get(conn, ~p"/export/audit-log.csv")
      assert response(conn, 200)
      assert get_resp_header(conn, "content-type") |> hd() =~ "text/csv"
      body = response(conn, 200)
      assert body =~ "ID"
      assert body =~ "Action"
      assert body =~ "Table"
    end

    test "includes audit log entries in CSV", %{conn: conn} do
      audit_log_fixture(%{action: "create", table_name: "companies", record_id: 1})
      audit_log_fixture(%{action: "update", table_name: "holdings", record_id: 2})

      conn = get(conn, ~p"/export/audit-log.csv")
      body = response(conn, 200)

      assert body =~ "create"
      assert body =~ "companies"
      assert body =~ "update"
      assert body =~ "holdings"
    end

    test "sets content-disposition header for download", %{conn: conn} do
      conn = get(conn, ~p"/export/audit-log.csv")
      assert get_resp_header(conn, "content-disposition") |> hd() =~ "audit-log.csv"
    end
  end

  describe "GET /export/audit-package.zip" do
    test "returns ZIP file", %{conn: conn} do
      conn = get(conn, ~p"/export/audit-package.zip")
      assert response(conn, 200)
      assert get_resp_header(conn, "content-type") |> hd() =~ "application/zip"
    end

    test "sets content-disposition header for download", %{conn: conn} do
      conn = get(conn, ~p"/export/audit-package.zip")
      assert get_resp_header(conn, "content-disposition") |> hd() =~ "audit-package.zip"
    end

    test "accepts company_id parameter", %{conn: conn} do
      company = company_fixture()
      conn = get(conn, ~p"/export/audit-package.zip?company_id=#{company.id}")
      assert response(conn, 200)
    end

    test "returns valid ZIP data", %{conn: conn} do
      conn = get(conn, ~p"/export/audit-package.zip")
      body = response(conn, 200)

      # ZIP files start with PK magic bytes
      assert <<0x50, 0x4B, _rest::binary>> = body
    end
  end
end
