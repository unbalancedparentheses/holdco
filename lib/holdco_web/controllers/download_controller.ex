defmodule HoldcoWeb.DownloadController do
  use HoldcoWeb, :controller

  alias Holdco.Documents

  def show(conn, %{"id" => id}) do
    upload = Documents.get_document_upload!(id)

    if File.exists?(upload.file_path) do
      content_type =
        if upload.content_type != "" do
          upload.content_type
        else
          MIME.from_path(upload.file_name)
        end

      send_download(conn, {:file, upload.file_path},
        filename: upload.file_name,
        content_type: content_type,
        disposition: :attachment
      )
    else
      conn
      |> put_flash(:error, "File not found on disk")
      |> redirect(to: ~p"/documents")
    end
  end

  def preview(conn, %{"id" => id}) do
    upload = Documents.get_document_upload!(id)

    if File.exists?(upload.file_path) do
      content_type =
        if upload.content_type != "" do
          upload.content_type
        else
          MIME.from_path(upload.file_name)
        end

      send_download(conn, {:file, upload.file_path},
        filename: upload.file_name,
        content_type: content_type,
        disposition: :inline
      )
    else
      conn
      |> put_flash(:error, "File not found on disk")
      |> redirect(to: ~p"/documents")
    end
  end
end
