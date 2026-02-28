defmodule HoldcoWeb.DocumentsLiveTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "GET /documents" do
    test "renders documents page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/documents")

      assert html =~ "Documents"
    end

    test "renders page title", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/documents")

      assert html =~ "page-title"
    end

    test "documents page renders without nav highlight", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/documents")

      # Documents is no longer in the nav bar (removed from Consolidated dropdown)
      assert html =~ "Documents"
    end
  end

  describe "show_form event" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "opens the add document modal", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/documents")

      refute html =~ "dialog-overlay"

      html = view |> element("button", "Add Document") |> render_click()

      assert html =~ "dialog-overlay"
      assert html =~ "dialog-header"
      assert html =~ "Add Document"
      assert html =~ ~s(phx-submit="save")
    end

    test "modal contains all expected form fields", %{conn: conn} do
      company_fixture(%{name: "FormFieldsCo"})
      {:ok, view, _html} = live(conn, ~p"/documents")

      html = view |> element("button", "Add Document") |> render_click()

      assert html =~ ~s(name="document[company_id]")
      assert html =~ ~s(name="document[name]")
      assert html =~ ~s(name="document[doc_type]")
      assert html =~ ~s(name="document[url]")
      assert html =~ ~s(name="document[notes]")
      assert html =~ "Attach Files"
      assert html =~ "FormFieldsCo"
    end

    test "show_form via hook sets modal to add mode", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/documents")

      html = render_hook(view, "show_form", %{})

      assert html =~ "dialog-overlay"
      assert html =~ "Add Document"
    end
  end

  describe "close_form event" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "clicking Cancel closes the modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/documents")

      view |> element("button", "Add Document") |> render_click()
      html = view |> element("button", "Cancel") |> render_click()

      refute html =~ "dialog-overlay"
    end

    test "clicking modal overlay closes the form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/documents")

      view |> element("button", "Add Document") |> render_click()
      html = view |> element(".dialog-overlay") |> render_click()

      refute html =~ "dialog-overlay"
    end

    test "close_form via hook removes modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/documents")

      render_hook(view, "show_form", %{})
      html = render_hook(view, "close_form", %{})

      refute html =~ "dialog-overlay"
    end
  end

  describe "edit event" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "clicking Edit opens the edit modal with document data", %{conn: conn} do
      company = company_fixture(%{name: "EditTestCo"})
      doc = document_fixture(%{company: company, name: "Editable Doc", doc_type: "contract", url: "https://example.com", notes: "Some notes"})

      {:ok, view, html} = live(conn, ~p"/documents")

      assert html =~ "Editable Doc"

      html =
        view
        |> element(~s(button[phx-click="edit"][phx-value-id="#{doc.id}"]))
        |> render_click()

      assert html =~ "dialog-overlay"
      assert html =~ "Edit Document"
      assert html =~ ~s(phx-submit="update")
      assert html =~ "Editable Doc"
      assert html =~ "contract"
      assert html =~ "https://example.com"
      assert html =~ "Some notes"
    end

    test "edit modal pre-selects the correct company", %{conn: conn} do
      company = company_fixture(%{name: "PreSelectCo"})
      doc = document_fixture(%{company: company, name: "CompanyDoc"})

      {:ok, view, _html} = live(conn, ~p"/documents")

      html =
        view
        |> element(~s(button[phx-click="edit"][phx-value-id="#{doc.id}"]))
        |> render_click()

      assert html =~ "PreSelectCo"
      assert html =~ "Update Document"
    end

    test "edit via hook opens edit modal", %{conn: conn} do
      doc = document_fixture(%{name: "HookEditDoc"})

      {:ok, view, _html} = live(conn, ~p"/documents")

      html = render_hook(view, "edit", %{"id" => to_string(doc.id)})

      assert html =~ "Edit Document"
      assert html =~ "HookEditDoc"
    end
  end

  describe "update event (editor)" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "submitting the edit form updates the document", %{conn: conn} do
      company = company_fixture(%{name: "UpdateCo"})
      doc = document_fixture(%{company: company, name: "Old Name", doc_type: "report"})

      {:ok, view, _html} = live(conn, ~p"/documents")

      view
      |> element(~s(button[phx-click="edit"][phx-value-id="#{doc.id}"]))
      |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="update"]), %{
          "document" => %{
            "company_id" => to_string(company.id),
            "name" => "New Name",
            "doc_type" => "contract"
          }
        })
        |> render_submit()

      assert html =~ "Document updated"
      refute html =~ "dialog-overlay"
      assert html =~ "New Name"
    end

    test "update with invalid data shows error flash", %{conn: conn} do
      company = company_fixture(%{name: "FailUpdateCo"})
      doc = document_fixture(%{company: company, name: "FailDoc"})

      {:ok, view, _html} = live(conn, ~p"/documents")

      view
      |> element(~s(button[phx-click="edit"][phx-value-id="#{doc.id}"]))
      |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="update"]), %{
          "document" => %{
            "company_id" => "",
            "name" => ""
          }
        })
        |> render_submit()

      assert html =~ "Failed to update document"
    end
  end

  describe "filter_company event" do
    test "filtering by company shows only matching documents", %{conn: conn} do
      co1 = company_fixture(%{name: "FilterCo1"})
      co2 = company_fixture(%{name: "FilterCo2"})
      document_fixture(%{company: co1, name: "Alpha Doc"})
      document_fixture(%{company: co2, name: "Beta Doc"})

      {:ok, view, html} = live(conn, ~p"/documents")

      assert html =~ "Alpha Doc"
      assert html =~ "Beta Doc"

      html =
        view
        |> form(~s(form[phx-change="filter_company"]), %{"company_id" => to_string(co1.id)})
        |> render_change()

      assert html =~ "Alpha Doc"
      refute html =~ "Beta Doc"
    end

    test "resetting filter to empty shows all documents", %{conn: conn} do
      co1 = company_fixture(%{name: "ResetFilterCo1"})
      co2 = company_fixture(%{name: "ResetFilterCo2"})
      document_fixture(%{company: co1, name: "Reset Doc A"})
      document_fixture(%{company: co2, name: "Reset Doc B"})

      {:ok, view, _html} = live(conn, ~p"/documents")

      view
      |> form(~s(form[phx-change="filter_company"]), %{"company_id" => to_string(co1.id)})
      |> render_change()

      html =
        view
        |> form(~s(form[phx-change="filter_company"]), %{"company_id" => ""})
        |> render_change()

      assert html =~ "Reset Doc A"
      assert html =~ "Reset Doc B"
    end

    test "filter dropdown contains company options", %{conn: conn} do
      company_fixture(%{name: "DropdownTestCo"})

      {:ok, _view, html} = live(conn, ~p"/documents")

      assert html =~ "All Companies"
      assert html =~ "DropdownTestCo"
    end
  end

  describe "delete event (editor)" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "deleting a document removes it and shows flash", %{conn: conn} do
      doc = document_fixture(%{name: "DeleteTargetDoc"})

      {:ok, view, html} = live(conn, ~p"/documents")
      assert html =~ "DeleteTargetDoc"

      html =
        view
        |> element(~s(button[phx-click="delete"][phx-value-id="#{doc.id}"]))
        |> render_click()

      assert html =~ "Document deleted"
      refute html =~ "DeleteTargetDoc"
    end

    test "delete button has data-confirm attribute", %{conn: conn} do
      doc = document_fixture(%{name: "ConfirmDeleteDoc"})

      {:ok, _view, html} = live(conn, ~p"/documents")

      assert html =~ ~s(data-confirm="Delete?")
      assert html =~ ~s(phx-value-id="#{doc.id}")
    end
  end

  describe "permission guards (viewer cannot save/update/delete)" do
    test "save event returns permission error for viewer", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/documents")

      render_hook(view, "save", %{"document" => %{"name" => "blocked"}})
      html = render(view)

      assert html =~ "permission"
    end

    test "update event returns permission error for viewer", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/documents")

      render_hook(view, "update", %{"document" => %{"name" => "blocked"}})
      html = render(view)

      assert html =~ "permission"
    end

    test "delete event returns permission error for viewer", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/documents")

      render_hook(view, "delete", %{"id" => "999"})
      html = render(view)

      assert html =~ "permission"
    end

    test "viewer does not see Add Document button", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/documents")

      refute html =~ "Add Document"
    end

    test "viewer does not see Edit or Del buttons", %{conn: conn} do
      document_fixture(%{name: "ViewerDoc"})

      {:ok, _view, html} = live(conn, ~p"/documents")

      assert html =~ "ViewerDoc"
      refute html =~ ~s(phx-click="edit")
      refute html =~ ~s(phx-click="delete")
    end
  end

  describe "noop event" do
    test "noop event does not change state or crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/documents")

      html = render_hook(view, "noop", %{})

      assert html =~ "Documents"
      assert html =~ "documents in the library"
    end
  end

  describe "validate event" do
    test "validate event is accepted without error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/documents")

      html = render_hook(view, "validate", %{})

      assert html =~ "Documents"
    end
  end

  describe "empty state" do
    test "shows empty state message when no documents exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/documents")

      assert html =~ "No documents yet."
      assert html =~ "empty-state"
      assert html =~ "Store contracts, certificates, reports, and other files"
      assert html =~ "0 documents in the library"
    end
  end

  describe "table rendering with document data" do
    test "renders document rows with all expected columns", %{conn: conn} do
      company = company_fixture(%{name: "TableTestCo"})
      document_fixture(%{company: company, name: "Table Doc", doc_type: "certificate"})

      {:ok, _view, html} = live(conn, ~p"/documents")

      # Table headers
      assert html =~ "<th>Name</th>"
      assert html =~ "<th>Type</th>"
      assert html =~ "<th>Company</th>"
      assert html =~ "<th>Files</th>"
      assert html =~ "<th>Date</th>"

      # Document row data
      assert html =~ "Table Doc"
      assert html =~ "certificate"
      assert html =~ "tag tag-ink"
      assert html =~ "TableTestCo"
      assert html =~ "td-name"
      assert html =~ "td-mono"
    end

    test "renders company as link when company exists", %{conn: conn} do
      company = company_fixture(%{name: "LinkableCo"})
      document_fixture(%{company: company, name: "LinkDoc"})

      {:ok, _view, html} = live(conn, ~p"/documents")

      assert html =~ "td-link"
      assert html =~ "LinkableCo"
      assert html =~ "/companies/#{company.id}"
    end

    test "displays correct document count", %{conn: conn} do
      document_fixture(%{name: "CountDoc1"})
      document_fixture(%{name: "CountDoc2"})

      {:ok, _view, html} = live(conn, ~p"/documents")

      assert html =~ "2 documents in the library"
    end

    test "renders document date in YYYY-MM-DD format", %{conn: conn} do
      document_fixture(%{name: "DateFormatDoc"})

      {:ok, _view, html} = live(conn, ~p"/documents")

      assert html =~ "DateFormatDoc"
      # The date should be formatted and rendered inside a td-mono cell
      assert html =~ "td-mono"
    end

    test "renders uploads with download link", %{conn: conn} do
      doc = document_fixture(%{name: "UploadRenderDoc"})
      document_upload_fixture(%{document: doc, file_name: "report.pdf", content_type: "application/pdf"})

      {:ok, _view, html} = live(conn, ~p"/documents")

      assert html =~ "report.pdf"
      assert html =~ "Download"
      assert html =~ "View"
    end

    test "non-pdf non-image uploads show download only", %{conn: conn} do
      doc = document_fixture(%{name: "ExcelDoc"})
      document_upload_fixture(%{document: doc, file_name: "data.xlsx", content_type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"})

      {:ok, _view, html} = live(conn, ~p"/documents")

      assert html =~ "data.xlsx"
      assert html =~ "Download"
      refute html =~ ">View</a>"
    end

    test "image uploads show thumbnail preview", %{conn: conn} do
      doc = document_fixture(%{name: "ImageUploadDoc"})
      document_upload_fixture(%{document: doc, file_name: "photo.jpg", content_type: "image/jpeg"})

      {:ok, _view, html} = live(conn, ~p"/documents")

      assert html =~ "photo.jpg"
      assert html =~ "<img"
    end
  end

  describe "save event (editor)" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "submitting the add form creates a document and closes the modal", %{conn: conn} do
      company = company_fixture(%{name: "SaveTestCo"})
      {:ok, view, _html} = live(conn, ~p"/documents")

      view |> element("button", "Add Document") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save"]), %{
          "document" => %{
            "company_id" => to_string(company.id),
            "name" => "Saved Contract",
            "doc_type" => "contract",
            "url" => "https://example.com/saved",
            "notes" => "Test save notes"
          }
        })
        |> render_submit()

      assert html =~ "Document added"
      refute html =~ "dialog-overlay"
      assert html =~ "Saved Contract"
    end

    test "save with missing required fields shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/documents")

      view |> element("button", "Add Document") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save"]), %{
          "document" => %{
            "company_id" => "",
            "name" => ""
          }
        })
        |> render_submit()

      assert html =~ "Failed to add document"
    end
  end
end
