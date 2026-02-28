defmodule HoldcoWeb.DownloadControllerTest do
  use HoldcoWeb.ConnCase, async: true

  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "GET /downloads/:id" do
    test "downloads file when it exists on disk", %{conn: conn} do
      # Create a temporary file to download
      tmp_path = Path.join(System.tmp_dir!(), "holdco_test_download_#{System.unique_integer([:positive])}.txt")
      File.write!(tmp_path, "test file content")

      on_exit(fn -> File.rm(tmp_path) end)

      upload = document_upload_fixture(%{
        file_path: tmp_path,
        file_name: "test_document.txt",
        content_type: "text/plain"
      })

      conn = get(conn, ~p"/downloads/#{upload.id}")

      assert conn.status == 200
      assert get_resp_header(conn, "content-disposition") |> List.first() =~ "attachment"
      assert get_resp_header(conn, "content-disposition") |> List.first() =~ "test_document.txt"
      assert conn.resp_body == "test file content"
    end

    test "redirects with error when file does not exist on disk", %{conn: conn} do
      upload = document_upload_fixture(%{
        file_path: "/nonexistent/path/missing.pdf",
        file_name: "missing.pdf"
      })

      conn = get(conn, ~p"/downloads/#{upload.id}")

      assert redirected_to(conn) == ~p"/documents"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "File not found on disk"
    end

    test "uses content_type from upload when available", %{conn: conn} do
      tmp_path = Path.join(System.tmp_dir!(), "holdco_test_#{System.unique_integer([:positive])}.pdf")
      File.write!(tmp_path, "fake pdf content")

      on_exit(fn -> File.rm(tmp_path) end)

      upload = document_upload_fixture(%{
        file_path: tmp_path,
        file_name: "report.pdf",
        content_type: "application/pdf"
      })

      conn = get(conn, ~p"/downloads/#{upload.id}")

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") |> List.first() =~ "application/pdf"
    end

    test "falls back to MIME type from filename when content_type is empty", %{conn: conn} do
      tmp_path = Path.join(System.tmp_dir!(), "holdco_test_#{System.unique_integer([:positive])}.csv")
      File.write!(tmp_path, "a,b,c")

      on_exit(fn -> File.rm(tmp_path) end)

      upload = document_upload_fixture(%{
        file_path: tmp_path,
        file_name: "data.csv",
        content_type: ""
      })

      conn = get(conn, ~p"/downloads/#{upload.id}")

      assert conn.status == 200
    end
  end

  describe "GET /downloads/:id/preview" do
    test "previews file inline when it exists", %{conn: conn} do
      tmp_path = Path.join(System.tmp_dir!(), "holdco_test_preview_#{System.unique_integer([:positive])}.txt")
      File.write!(tmp_path, "preview content")

      on_exit(fn -> File.rm(tmp_path) end)

      upload = document_upload_fixture(%{
        file_path: tmp_path,
        file_name: "preview_doc.txt",
        content_type: "text/plain"
      })

      conn = get(conn, ~p"/downloads/#{upload.id}/preview")

      assert conn.status == 200
      assert get_resp_header(conn, "content-disposition") |> List.first() =~ "inline"
      assert conn.resp_body == "preview content"
    end

    test "redirects with error when file does not exist for preview", %{conn: conn} do
      upload = document_upload_fixture(%{
        file_path: "/nonexistent/path/missing.pdf",
        file_name: "missing.pdf"
      })

      conn = get(conn, ~p"/downloads/#{upload.id}/preview")

      assert redirected_to(conn) == ~p"/documents"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "File not found on disk"
    end

    test "uses content_type from upload for preview", %{conn: conn} do
      tmp_path = Path.join(System.tmp_dir!(), "holdco_test_preview_#{System.unique_integer([:positive])}.html")
      File.write!(tmp_path, "<h1>Hello</h1>")

      on_exit(fn -> File.rm(tmp_path) end)

      upload = document_upload_fixture(%{
        file_path: tmp_path,
        file_name: "page.html",
        content_type: "text/html"
      })

      conn = get(conn, ~p"/downloads/#{upload.id}/preview")

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") |> List.first() =~ "text/html"
    end
  end

  describe "GET /downloads/:id/preview with empty content_type fallback" do
    test "falls back to MIME type from filename when content_type is empty for preview", %{conn: conn} do
      tmp_path = Path.join(System.tmp_dir!(), "holdco_test_preview_fallback_#{System.unique_integer([:positive])}.csv")
      File.write!(tmp_path, "a,b,c")

      on_exit(fn -> File.rm(tmp_path) end)

      upload = document_upload_fixture(%{
        file_path: tmp_path,
        file_name: "data.csv",
        content_type: ""
      })

      conn = get(conn, ~p"/downloads/#{upload.id}/preview")

      assert conn.status == 200
      assert get_resp_header(conn, "content-disposition") |> List.first() =~ "inline"
    end
  end

  describe "authentication required" do
    test "redirects to login when not authenticated", %{conn: _conn} do
      upload = document_upload_fixture(%{
        file_path: "/tmp/test.pdf",
        file_name: "test.pdf"
      })

      # Use a fresh conn without auth
      conn = build_conn()
      conn = get(conn, ~p"/downloads/#{upload.id}")

      assert redirected_to(conn) =~ ~p"/users/log-in"
    end
  end
end
