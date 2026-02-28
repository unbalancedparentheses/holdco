defmodule Holdco.Documents.DataRoomTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Documents

  describe "data_rooms CRUD" do
    test "list_data_rooms/0 returns all rooms" do
      room = data_room_fixture()
      assert Enum.any?(Documents.list_data_rooms(), &(&1.id == room.id))
    end

    test "list_data_rooms/1 filters by company_id" do
      company = company_fixture()
      room = data_room_fixture(%{company: company})
      other = data_room_fixture()

      results = Documents.list_data_rooms(company.id)
      assert Enum.any?(results, &(&1.id == room.id))
      refute Enum.any?(results, &(&1.id == other.id))
    end

    test "get_data_room!/1 returns room with preloads" do
      room = data_room_fixture()
      fetched = Documents.get_data_room!(room.id)
      assert fetched.id == room.id
      assert fetched.company != nil
    end

    test "get_data_room!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Documents.get_data_room!(0)
      end
    end

    test "create_data_room/1 with valid data" do
      company = company_fixture()

      assert {:ok, room} =
               Documents.create_data_room(%{
                 company_id: company.id,
                 name: "Series A Due Diligence",
                 description: "All documents for Series A",
                 access_level: "confidential",
                 status: "active",
                 watermark_enabled: true,
                 download_allowed: false
               })

      assert room.name == "Series A Due Diligence"
      assert room.access_level == "confidential"
      assert room.watermark_enabled == true
      assert room.download_allowed == false
      assert room.visitor_count == 0
    end

    test "create_data_room/1 with all access levels" do
      company = company_fixture()

      for level <- ~w(public restricted confidential) do
        assert {:ok, room} =
                 Documents.create_data_room(%{
                   company_id: company.id,
                   name: "Room #{level}",
                   access_level: level
                 })

        assert room.access_level == level
      end
    end

    test "create_data_room/1 with all statuses" do
      company = company_fixture()

      for status <- ~w(active archived expired) do
        assert {:ok, room} =
                 Documents.create_data_room(%{
                   company_id: company.id,
                   name: "Room #{status}",
                   status: status
                 })

        assert room.status == status
      end
    end

    test "create_data_room/1 fails without required fields" do
      assert {:error, changeset} = Documents.create_data_room(%{})
      errors = errors_on(changeset)
      assert errors[:company_id]
      assert errors[:name]
    end

    test "create_data_room/1 fails with invalid access_level" do
      company = company_fixture()

      assert {:error, changeset} =
               Documents.create_data_room(%{
                 company_id: company.id,
                 name: "Test",
                 access_level: "invalid"
               })

      assert errors_on(changeset)[:access_level]
    end

    test "create_data_room/1 fails with invalid status" do
      company = company_fixture()

      assert {:error, changeset} =
               Documents.create_data_room(%{
                 company_id: company.id,
                 name: "Test",
                 status: "invalid"
               })

      assert errors_on(changeset)[:status]
    end

    test "update_data_room/2 with valid data" do
      room = data_room_fixture()

      assert {:ok, updated} =
               Documents.update_data_room(room, %{
                 name: "Updated Room Name",
                 status: "archived",
                 visitor_count: 42
               })

      assert updated.name == "Updated Room Name"
      assert updated.status == "archived"
      assert updated.visitor_count == 42
    end

    test "delete_data_room/1 removes the room" do
      room = data_room_fixture()
      assert {:ok, _} = Documents.delete_data_room(room)

      assert_raise Ecto.NoResultsError, fn ->
        Documents.get_data_room!(room.id)
      end
    end
  end

  describe "data_room_documents" do
    test "add_document_to_room/1 creates association" do
      room = data_room_fixture()
      document = document_fixture()

      assert {:ok, drd} =
               Documents.add_document_to_room(%{
                 data_room_id: room.id,
                 document_id: document.id,
                 section_name: "Financials",
                 sort_order: 1
               })

      assert drd.data_room_id == room.id
      assert drd.document_id == document.id
      assert drd.section_name == "Financials"
      assert drd.sort_order == 1
    end

    test "list_room_documents/1 returns documents for a room" do
      room = data_room_fixture()
      doc1 = document_fixture()
      doc2 = document_fixture()

      {:ok, _} = Documents.add_document_to_room(%{data_room_id: room.id, document_id: doc1.id, sort_order: 1})
      {:ok, _} = Documents.add_document_to_room(%{data_room_id: room.id, document_id: doc2.id, sort_order: 2})

      docs = Documents.list_room_documents(room.id)
      assert length(docs) == 2
      assert Enum.at(docs, 0).sort_order <= Enum.at(docs, 1).sort_order
    end

    test "remove_document_from_room/1 deletes association" do
      drd = data_room_document_fixture()
      room_id = drd.data_room_id

      assert {:ok, _} = Documents.remove_document_from_room(drd)
      assert Documents.list_room_documents(room_id) == []
    end

    test "deleting a data room cascades to documents" do
      room = data_room_fixture()
      document = document_fixture()
      {:ok, _} = Documents.add_document_to_room(%{data_room_id: room.id, document_id: document.id})

      assert {:ok, _} = Documents.delete_data_room(room)
      assert Documents.list_room_documents(room.id) == []
    end
  end

  describe "defaults" do
    test "watermark_enabled defaults to true" do
      company = company_fixture()
      {:ok, room} = Documents.create_data_room(%{company_id: company.id, name: "Test"})
      assert room.watermark_enabled == true
    end

    test "download_allowed defaults to true" do
      company = company_fixture()
      {:ok, room} = Documents.create_data_room(%{company_id: company.id, name: "Test"})
      assert room.download_allowed == true
    end

    test "visitor_count defaults to 0" do
      company = company_fixture()
      {:ok, room} = Documents.create_data_room(%{company_id: company.id, name: "Test"})
      assert room.visitor_count == 0
    end
  end
end
