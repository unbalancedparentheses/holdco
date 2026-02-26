defmodule HoldcoWeb.DocumentsLiveIndexTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "mount and render" do
    test "renders the page title and deck", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/documents")

      assert html =~ "<h1>Documents</h1>"
      assert html =~ "documents in the library"
      assert html =~ "page-title"
      assert html =~ "page-title-rule"
    end

    test "renders the documents table headers", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/documents")

      assert html =~ "<th>Name</th>"
      assert html =~ "<th>Type</th>"
      assert html =~ "<th>Company</th>"
      assert html =~ "<th>Files</th>"
      assert html =~ "<th>Date</th>"
    end

    test "renders empty state when no documents exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/documents")

      assert html =~ "No documents yet."
      assert html =~ "empty-state"
    end

    test "renders company filter dropdown", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/documents")

      assert html =~ "All Companies"
      assert html =~ "form-select"
      assert html =~ ~s(name="company_id")
    end

    test "shows document data when documents exist", %{conn: conn} do
      company = company_fixture(%{name: "DocTestCo"})
      document_fixture(%{company: company, name: "Annual Report", doc_type: "report"})

      {:ok, _view, html} = live(conn, ~p"/documents")

      assert html =~ "DocTestCo"
      assert html =~ "Annual Report"
      assert html =~ "report"
      assert html =~ "tag tag-ink"
      assert html =~ "1 documents in the library"
    end

    test "shows --- when document has no uploads", %{conn: conn} do
      document_fixture(%{name: "NoFilesDoc"})

      {:ok, _view, html} = live(conn, ~p"/documents")

      assert html =~ "NoFilesDoc"
      # The "---" placeholder for no files
      assert html =~ "---"
    end

    test "company options appear in the filter dropdown", %{conn: conn} do
      company_fixture(%{name: "DocDropdownCo"})

      {:ok, _view, html} = live(conn, ~p"/documents")

      assert html =~ "DocDropdownCo"
    end
  end

  describe "viewer role (no can_write)" do
    test "does not show Add Document button for viewer", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/documents")

      refute html =~ "Add Document"
    end

    test "does not show delete buttons for viewer", %{conn: conn} do
      document_fixture()
      {:ok, _view, html} = live(conn, ~p"/documents")

      refute html =~ "btn btn-danger btn-sm"
    end
  end

  describe "editor role" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "shows Add Document button for editor", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/documents")

      assert html =~ "Add Document"
      assert html =~ ~s(phx-click="show_form")
    end

    test "shows delete button for editor when documents exist", %{conn: conn} do
      document_fixture()
      {:ok, _view, html} = live(conn, ~p"/documents")

      assert html =~ "btn btn-danger btn-sm"
      assert html =~ "Del"
      assert html =~ ~s(phx-click="delete")
    end

    test "clicking Add Document opens the modal form", %{conn: conn} do
      company_fixture(%{name: "DocFormCo"})
      {:ok, view, _html} = live(conn, ~p"/documents")

      html = view |> element("button", "Add Document") |> render_click()

      assert html =~ "modal-overlay"
      assert html =~ "modal-header"
      assert html =~ "Add Document"
      assert html =~ ~s(phx-submit="save")
      assert html =~ ~s(phx-change="validate")
      assert html =~ ~s(name="document[company_id]")
      assert html =~ ~s(name="document[name]")
      assert html =~ ~s(name="document[doc_type]")
      assert html =~ ~s(name="document[url]")
      assert html =~ ~s(name="document[notes]")
      assert html =~ "Attach Files"
      assert html =~ "DocFormCo"
    end

    test "form shows placeholder for document type", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/documents")

      html = view |> element("button", "Add Document") |> render_click()

      assert html =~ "e.g. contract, certificate, report"
    end

    test "clicking Cancel closes the modal form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/documents")

      view |> element("button", "Add Document") |> render_click()
      html = view |> element("button", "Cancel") |> render_click()

      refute html =~ "modal-overlay"
    end

    test "clicking modal overlay closes the form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/documents")

      view |> element("button", "Add Document") |> render_click()
      html = view |> element(".modal-overlay") |> render_click()

      refute html =~ "modal-overlay"
    end

    test "submitting the form creates a document", %{conn: conn} do
      company = company_fixture(%{name: "SaveDocCo"})
      {:ok, view, _html} = live(conn, ~p"/documents")

      view |> element("button", "Add Document") |> render_click()

      html =
        view
        |> form("form[phx-submit=\"save\"]", %{
          "document" => %{
            "company_id" => to_string(company.id),
            "name" => "New Contract",
            "doc_type" => "contract",
            "url" => "https://example.com/doc",
            "notes" => "Important contract"
          }
        })
        |> render_submit()

      assert html =~ "Document added"
      refute html =~ "modal-overlay"
    end

    test "deleting a document removes it from the list", %{conn: conn} do
      doc = document_fixture(%{name: "DeleteMeDoc"})
      {:ok, view, html} = live(conn, ~p"/documents")

      assert html =~ "DeleteMeDoc"

      html =
        view
        |> element(~s(button[phx-click="delete"][phx-value-id="#{doc.id}"]))
        |> render_click()

      assert html =~ "Document deleted"
      refute html =~ "DeleteMeDoc"
    end
  end

  describe "company filter" do
    test "filtering by company shows only that company's documents", %{conn: conn} do
      co1 = company_fixture(%{name: "DocFilterCo1"})
      co2 = company_fixture(%{name: "DocFilterCo2"})
      document_fixture(%{company: co1, name: "Doc Alpha"})
      document_fixture(%{company: co2, name: "Doc Beta"})

      {:ok, view, html} = live(conn, ~p"/documents")

      assert html =~ "Doc Alpha"
      assert html =~ "Doc Beta"

      html =
        view
        |> form("form[phx-change=\"filter_company\"]", %{"company_id" => to_string(co1.id)})
        |> render_change()

      assert html =~ "Doc Alpha"
      refute html =~ "Doc Beta"
    end

    test "resetting filter shows all documents", %{conn: conn} do
      co1 = company_fixture(%{name: "DocResetCo1"})
      co2 = company_fixture(%{name: "DocResetCo2"})
      document_fixture(%{company: co1, name: "Doc One"})
      document_fixture(%{company: co2, name: "Doc Two"})

      {:ok, view, _html} = live(conn, ~p"/documents")

      view
      |> form("form[phx-change=\"filter_company\"]", %{"company_id" => to_string(co1.id)})
      |> render_change()

      html =
        view
        |> form("form[phx-change=\"filter_company\"]", %{"company_id" => ""})
        |> render_change()

      assert html =~ "Doc One"
      assert html =~ "Doc Two"
    end
  end

  describe "document with uploads" do
    test "shows upload file name and download link", %{conn: conn} do
      doc = document_fixture(%{name: "WithUploadDoc"})
      document_upload_fixture(%{document: doc, file_name: "invoice.pdf", content_type: "application/pdf"})

      {:ok, _view, html} = live(conn, ~p"/documents")

      assert html =~ "WithUploadDoc"
      assert html =~ "invoice.pdf"
      assert html =~ "Download"
      # PDF files get a View button
      assert html =~ "View"
    end
  end

  describe "viewer permission guards for save and delete" do
    test "viewer save event returns permission error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/documents")

      render_hook(view, "save", %{"document" => %{"name" => "test"}})
      assert render(view) =~ "permission"
    end

    test "viewer delete event returns permission error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/documents")

      render_hook(view, "delete", %{"id" => "999"})
      assert render(view) =~ "permission"
    end
  end

  describe "noop and validate events" do
    test "noop event does not crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/documents")

      render_hook(view, "noop", %{})
      assert render(view) =~ "Documents"
    end

    test "validate event does not crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/documents")

      render_hook(view, "validate", %{})
      assert render(view) =~ "Documents"
    end
  end

  describe "editor save failure" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "submitting form with missing required fields shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/documents")

      view |> element("button", "Add Document") |> render_click()

      html =
        view
        |> form("form[phx-submit=\"save\"]", %{
          "document" => %{
            "company_id" => "",
            "name" => "",
            "doc_type" => ""
          }
        })
        |> render_submit()

      assert html =~ "Failed to add document"
    end
  end

  describe "document count display" do
    test "shows correct document count in deck text", %{conn: conn} do
      document_fixture(%{name: "Doc1"})
      document_fixture(%{name: "Doc2"})
      document_fixture(%{name: "Doc3"})

      {:ok, _view, html} = live(conn, ~p"/documents")

      assert html =~ "3 documents in the library"
    end
  end

  describe "document date display" do
    test "shows formatted date for documents", %{conn: conn} do
      document_fixture(%{name: "DatedDoc"})

      {:ok, _view, html} = live(conn, ~p"/documents")

      assert html =~ "DatedDoc"
      # Date should be formatted as YYYY-MM-DD
      assert html =~ "td-mono"
    end
  end

  describe "upload display details" do
    test "image uploads show preview thumbnail", %{conn: conn} do
      doc = document_fixture(%{name: "ImageDoc"})
      document_upload_fixture(%{document: doc, file_name: "photo.png", content_type: "image/png"})

      {:ok, _view, html} = live(conn, ~p"/documents")

      assert html =~ "photo.png"
      assert html =~ "img"
    end
  end

  describe "show_form and close_form events" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "show_form assigns show_form to true", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/documents")

      html = render_hook(view, "show_form", %{})
      assert html =~ "modal-overlay"
    end

    test "close_form assigns show_form to false", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/documents")

      render_hook(view, "show_form", %{})
      html = render_hook(view, "close_form", %{})
      refute html =~ "modal-overlay"
    end
  end

  describe "document with company shows company name" do
    test "shows company name for document with company", %{conn: conn} do
      company = company_fixture(%{name: "DocLinkedCo"})
      document_fixture(%{name: "LinkedDoc", company: company})

      {:ok, _view, html} = live(conn, ~p"/documents")

      assert html =~ "LinkedDoc"
      assert html =~ "DocLinkedCo"
    end
  end

  describe "non-image non-pdf upload" do
    test "shows file name and download for non-image non-pdf upload", %{conn: conn} do
      doc = document_fixture(%{name: "SpreadsheetDoc"})
      document_upload_fixture(%{document: doc, file_name: "data.xlsx", content_type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"})

      {:ok, _view, html} = live(conn, ~p"/documents")

      assert html =~ "data.xlsx"
      assert html =~ "Download"
      # Non-PDF should not have View button
      refute html =~ ">View</a>"
    end
  end

  describe "multiple documents count" do
    test "shows 0 documents for empty library", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/documents")

      assert html =~ "0 documents in the library"
    end
  end

  describe "editor delete permission guard" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "editor can delete a document via button", %{conn: conn} do
      doc = document_fixture(%{name: "EditorDelDoc"})
      {:ok, view, html} = live(conn, ~p"/documents")
      assert html =~ "EditorDelDoc"

      html =
        view
        |> element(~s(button[phx-click="delete"][phx-value-id="#{doc.id}"]))
        |> render_click()

      assert html =~ "Document deleted"
      refute html =~ "EditorDelDoc"
    end
  end

  describe "upload type detection edge cases" do
    test "gif upload detected as image by extension", %{conn: conn} do
      doc = document_fixture(%{name: "GifDoc"})
      document_upload_fixture(%{document: doc, file_name: "animation.gif", content_type: ""})

      {:ok, _view, html} = live(conn, ~p"/documents")

      assert html =~ "animation.gif"
      # gif extension triggers image? => true, so img tag is rendered
      assert html =~ "<img"
    end

    test "webp upload detected as image by extension", %{conn: conn} do
      doc = document_fixture(%{name: "WebpDoc"})
      document_upload_fixture(%{document: doc, file_name: "photo.webp", content_type: ""})

      {:ok, _view, html} = live(conn, ~p"/documents")

      assert html =~ "photo.webp"
      assert html =~ "<img"
    end

    test "jpeg upload detected as image by extension", %{conn: conn} do
      doc = document_fixture(%{name: "JpegDoc"})
      document_upload_fixture(%{document: doc, file_name: "scan.jpeg", content_type: ""})

      {:ok, _view, html} = live(conn, ~p"/documents")

      assert html =~ "scan.jpeg"
      assert html =~ "<img"
    end

    test "pdf upload detected by extension when content_type is empty", %{conn: conn} do
      doc = document_fixture(%{name: "PdfExtDoc"})
      document_upload_fixture(%{document: doc, file_name: "report.pdf", content_type: ""})

      {:ok, _view, html} = live(conn, ~p"/documents")

      assert html =~ "report.pdf"
      # PDF detected by extension triggers View button
      assert html =~ "View"
      assert html =~ "Download"
    end

    test "non-image non-pdf with nil content_type shows download only", %{conn: conn} do
      doc = document_fixture(%{name: "DocxDoc"})
      document_upload_fixture(%{document: doc, file_name: "letter.docx", content_type: ""})

      {:ok, _view, html} = live(conn, ~p"/documents")

      assert html =~ "letter.docx"
      assert html =~ "Download"
      refute html =~ "<img"
      refute html =~ ">View</a>"
    end
  end

  describe "multiple uploads per document" do
    test "shows all uploads for a single document", %{conn: conn} do
      doc = document_fixture(%{name: "MultiUploadDoc"})
      document_upload_fixture(%{document: doc, file_name: "image1.png", content_type: "image/png"})
      document_upload_fixture(%{document: doc, file_name: "contract.pdf", content_type: "application/pdf"})
      document_upload_fixture(%{document: doc, file_name: "data.xlsx", content_type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"})

      {:ok, _view, html} = live(conn, ~p"/documents")

      assert html =~ "image1.png"
      assert html =~ "contract.pdf"
      assert html =~ "data.xlsx"
      # Image should have img tag
      assert html =~ "<img"
      # PDF should have View button
      assert html =~ "View"
    end
  end

  describe "editor edit form with existing data" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "edit form shows existing url and notes", %{conn: conn} do
      company = company_fixture(%{name: "EditFormCo"})
      doc = document_fixture(%{
        company: company,
        name: "Full Doc",
        doc_type: "certificate",
        url: "https://example.com/cert",
        notes: "Important certificate notes"
      })

      {:ok, view, _html} = live(conn, ~p"/documents")

      html =
        view
        |> element(~s(button[phx-click="edit"][phx-value-id="#{doc.id}"]))
        |> render_click()

      assert html =~ "Edit Document"
      assert html =~ "Full Doc"
      assert html =~ "certificate"
      assert html =~ "https://example.com/cert"
      assert html =~ "Important certificate notes"
      assert html =~ "Update Document"
    end

    test "edit form shows company dropdown with correct selection", %{conn: conn} do
      company1 = company_fixture(%{name: "EditSelectCo1"})
      _company2 = company_fixture(%{name: "EditSelectCo2"})
      doc = document_fixture(%{company: company1, name: "SelectDoc"})

      {:ok, view, _html} = live(conn, ~p"/documents")

      html =
        view
        |> element(~s(button[phx-click="edit"][phx-value-id="#{doc.id}"]))
        |> render_click()

      assert html =~ "EditSelectCo1"
      assert html =~ "EditSelectCo2"
    end
  end

  describe "viewer cannot see action buttons" do
    test "viewer does not see Edit button for documents with uploads", %{conn: conn} do
      doc = document_fixture(%{name: "ViewerUploadDoc"})
      document_upload_fixture(%{document: doc, file_name: "file.pdf", content_type: "application/pdf"})

      {:ok, _view, html} = live(conn, ~p"/documents")

      assert html =~ "ViewerUploadDoc"
      assert html =~ "file.pdf"
      refute html =~ ~s(phx-click="edit")
      refute html =~ ~s(phx-click="delete")
    end
  end

  describe "viewer update permission guard" do
    test "viewer update event returns permission error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/documents")

      render_hook(view, "update", %{"document" => %{"name" => "blocked"}})
      assert render(view) =~ "permission"
    end
  end

  describe "document rendering edge cases" do
    test "renders doc_type as tag badge", %{conn: conn} do
      document_fixture(%{name: "BadgeDoc", doc_type: "lease_agreement"})

      {:ok, _view, html} = live(conn, ~p"/documents")

      assert html =~ "lease_agreement"
      assert html =~ "tag tag-ink"
    end

    test "document with nil doc_type renders without error", %{conn: conn} do
      document_fixture(%{name: "NilTypeDoc", doc_type: nil})

      {:ok, _view, html} = live(conn, ~p"/documents")

      assert html =~ "NilTypeDoc"
    end

    test "document with nil url and nil notes renders without error", %{conn: conn} do
      document_fixture(%{name: "NilFieldsDoc", url: nil, notes: nil})

      {:ok, _view, html} = live(conn, ~p"/documents")

      assert html =~ "NilFieldsDoc"
    end
  end

  describe "filter resets document count" do
    test "filtered view shows correct document count", %{conn: conn} do
      co1 = company_fixture(%{name: "CountFilterCo1"})
      co2 = company_fixture(%{name: "CountFilterCo2"})
      document_fixture(%{company: co1, name: "CFDoc1"})
      document_fixture(%{company: co1, name: "CFDoc2"})
      document_fixture(%{company: co2, name: "CFDoc3"})

      {:ok, view, html} = live(conn, ~p"/documents")
      assert html =~ "3 documents in the library"

      html =
        view
        |> form("form[phx-change=\"filter_company\"]", %{"company_id" => to_string(co1.id)})
        |> render_change()

      assert html =~ "2 documents in the library"
    end
  end
end
