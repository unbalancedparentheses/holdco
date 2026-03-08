defmodule Holdco.DocumentsTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Documents

  describe "documents" do
    test "CRUD operations" do
      company = company_fixture()
      {:ok, d} = Documents.create_document(%{company_id: company.id, name: "Board Minutes"})

      assert Enum.any?(Documents.list_documents(company.id), &(&1.id == d.id))
      assert Documents.get_document!(d.id).id == d.id

      {:ok, updated} = Documents.update_document(d, %{name: "Updated Minutes"})
      assert updated.name == "Updated Minutes"

      {:ok, _} = Documents.delete_document(updated)
    end

    test "create_document/1 invalid" do
      assert {:error, cs} = Documents.create_document(%{})
      assert errors_on(cs)[:company_id]
    end
  end

  describe "document_versions" do
    test "CRUD operations" do
      doc = document_fixture()
      {:ok, dv} = Documents.create_document_version(%{document_id: doc.id, version_number: 1, url: "/v1"})

      assert Enum.any?(Documents.list_document_versions(doc.id), &(&1.id == dv.id))
      assert Documents.get_document_version!(dv.id).id == dv.id

      {:ok, updated} = Documents.update_document_version(dv, %{version_number: 2})
      assert updated.version_number == 2

      {:ok, _} = Documents.delete_document_version(updated)
    end
  end

  describe "document_uploads" do
    test "CRUD operations" do
      doc = document_fixture()
      {:ok, du} = Documents.create_document_upload(%{document_id: doc.id, file_path: "/tmp/test.pdf", file_name: "test.pdf"})

      assert Enum.any?(Documents.list_document_uploads(doc.id), &(&1.id == du.id))
      assert Documents.get_document_upload!(du.id).id == du.id

      {:ok, updated} = Documents.update_document_upload(du, %{file_name: "new.pdf"})
      assert updated.file_name == "new.pdf"

      {:ok, _} = Documents.delete_document_upload(updated)
    end
  end

  describe "list_documents/0" do
    test "lists all documents without company filter" do
      doc = document_fixture()
      all_docs = Documents.list_documents()
      assert Enum.any?(all_docs, &(&1.id == doc.id))
    end
  end

end
