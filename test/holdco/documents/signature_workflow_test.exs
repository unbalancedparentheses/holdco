defmodule Holdco.Documents.SignatureWorkflowTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Documents

  describe "signature workflows CRUD" do
    test "list_signature_workflows/0 returns all workflows" do
      sw = signature_workflow_fixture()
      assert Enum.any?(Documents.list_signature_workflows(), &(&1.id == sw.id))
    end

    test "list_signature_workflows/1 filters by company_id" do
      company = company_fixture()
      sw = signature_workflow_fixture(%{company: company})
      other = signature_workflow_fixture()

      results = Documents.list_signature_workflows(company.id)
      assert Enum.any?(results, &(&1.id == sw.id))
      refute Enum.any?(results, &(&1.id == other.id))
    end

    test "get_signature_workflow!/1 returns with preloads" do
      sw = signature_workflow_fixture()
      fetched = Documents.get_signature_workflow!(sw.id)
      assert fetched.id == sw.id
      assert fetched.company != nil
    end

    test "create_signature_workflow/1 with valid data" do
      company = company_fixture()

      signers = [
        %{"name" => "Alice", "email" => "alice@example.com", "role" => "CEO", "status" => "pending"},
        %{"name" => "Bob", "email" => "bob@example.com", "role" => "CFO", "status" => "pending"}
      ]

      assert {:ok, sw} =
               Documents.create_signature_workflow(%{
                 company_id: company.id,
                 title: "NDA Signing",
                 status: "pending_signatures",
                 created_by: "admin@test.com",
                 signers: signers,
                 expiry_date: ~D[2026-06-01],
                 reminder_frequency: "weekly",
                 notes: "Urgent NDA"
               })

      assert sw.title == "NDA Signing"
      assert sw.status == "pending_signatures"
      assert length(sw.signers) == 2
      assert sw.reminder_frequency == "weekly"
    end

    test "create_signature_workflow/1 with document reference" do
      company = company_fixture()
      doc = document_fixture(%{company: company})

      assert {:ok, sw} =
               Documents.create_signature_workflow(%{
                 company_id: company.id,
                 document_id: doc.id,
                 title: "Doc Signing",
                 signers: []
               })

      fetched = Documents.get_signature_workflow!(sw.id)
      assert fetched.document_id == doc.id
      assert fetched.document != nil
    end

    test "create_signature_workflow/1 without required fields fails" do
      assert {:error, cs} = Documents.create_signature_workflow(%{})
      assert errors_on(cs)[:company_id]
      assert errors_on(cs)[:title]
    end

    test "create_signature_workflow/1 with invalid status fails" do
      company = company_fixture()

      assert {:error, cs} =
               Documents.create_signature_workflow(%{
                 company_id: company.id,
                 title: "Test",
                 status: "invalid"
               })

      assert errors_on(cs)[:status]
    end

    test "create_signature_workflow/1 with invalid reminder_frequency fails" do
      company = company_fixture()

      assert {:error, cs} =
               Documents.create_signature_workflow(%{
                 company_id: company.id,
                 title: "Test",
                 reminder_frequency: "hourly"
               })

      assert errors_on(cs)[:reminder_frequency]
    end

    test "create_signature_workflow/1 with all valid statuses" do
      company = company_fixture()

      for status <- ~w(draft pending_signatures partially_signed completed expired cancelled) do
        assert {:ok, sw} =
                 Documents.create_signature_workflow(%{
                   company_id: company.id,
                   title: "Status #{status}",
                   status: status
                 })

        assert sw.status == status
      end
    end

    test "update_signature_workflow/2 updates fields" do
      sw = signature_workflow_fixture()

      assert {:ok, updated} =
               Documents.update_signature_workflow(sw, %{
                 title: "Updated Workflow",
                 status: "pending_signatures",
                 notes: "Updated notes"
               })

      assert updated.title == "Updated Workflow"
      assert updated.status == "pending_signatures"
      assert updated.notes == "Updated notes"
    end

    test "delete_signature_workflow/1 removes the workflow" do
      sw = signature_workflow_fixture()
      assert {:ok, _} = Documents.delete_signature_workflow(sw)
      assert_raise Ecto.NoResultsError, fn -> Documents.get_signature_workflow!(sw.id) end
    end
  end

  describe "pending_signatures/0" do
    test "returns workflows awaiting signatures" do
      company = company_fixture()

      {:ok, pending} =
        Documents.create_signature_workflow(%{
          company_id: company.id,
          title: "Pending One",
          status: "pending_signatures",
          signers: [%{"name" => "A", "email" => "a@test.com", "status" => "pending"}]
        })

      {:ok, partial} =
        Documents.create_signature_workflow(%{
          company_id: company.id,
          title: "Partial One",
          status: "partially_signed",
          signers: [%{"name" => "B", "email" => "b@test.com", "status" => "signed"}]
        })

      {:ok, _completed} =
        Documents.create_signature_workflow(%{
          company_id: company.id,
          title: "Done One",
          status: "completed"
        })

      {:ok, _draft} =
        Documents.create_signature_workflow(%{
          company_id: company.id,
          title: "Draft One",
          status: "draft"
        })

      results = Documents.pending_signatures()
      ids = Enum.map(results, & &1.id)
      assert pending.id in ids
      assert partial.id in ids
      refute Enum.any?(results, fn w -> w.title == "Done One" end)
      refute Enum.any?(results, fn w -> w.title == "Draft One" end)
    end
  end

  describe "sign_document/2" do
    test "signs a specific signer and advances status to partially_signed" do
      company = company_fixture()

      {:ok, sw} =
        Documents.create_signature_workflow(%{
          company_id: company.id,
          title: "Multi-signer",
          status: "pending_signatures",
          signers: [
            %{"name" => "Alice", "email" => "alice@test.com", "role" => "CEO", "status" => "pending"},
            %{"name" => "Bob", "email" => "bob@test.com", "role" => "CFO", "status" => "pending"}
          ]
        })

      assert {:ok, updated} = Documents.sign_document(sw.id, "alice@test.com")
      assert updated.status == "partially_signed"

      alice = Enum.find(updated.signers, fn s -> s["email"] == "alice@test.com" end)
      assert alice["status"] == "signed"
      assert alice["signed_at"] != nil

      bob = Enum.find(updated.signers, fn s -> s["email"] == "bob@test.com" end)
      assert bob["status"] == "pending"
    end

    test "completes workflow when all signers sign" do
      company = company_fixture()

      {:ok, sw} =
        Documents.create_signature_workflow(%{
          company_id: company.id,
          title: "Two-signer",
          status: "pending_signatures",
          signers: [
            %{"name" => "Alice", "email" => "alice@test.com", "role" => "CEO", "status" => "pending"},
            %{"name" => "Bob", "email" => "bob@test.com", "role" => "CFO", "status" => "pending"}
          ]
        })

      {:ok, _} = Documents.sign_document(sw.id, "alice@test.com")
      {:ok, completed} = Documents.sign_document(sw.id, "bob@test.com")

      assert completed.status == "completed"
      assert Enum.all?(completed.signers, fn s -> s["status"] == "signed" end)
    end

    test "single signer completes immediately" do
      company = company_fixture()

      {:ok, sw} =
        Documents.create_signature_workflow(%{
          company_id: company.id,
          title: "Single-signer",
          status: "pending_signatures",
          signers: [
            %{"name" => "Alice", "email" => "alice@test.com", "role" => "CEO", "status" => "pending"}
          ]
        })

      {:ok, completed} = Documents.sign_document(sw.id, "alice@test.com")
      assert completed.status == "completed"
    end

    test "does not double-sign an already signed signer" do
      company = company_fixture()

      {:ok, sw} =
        Documents.create_signature_workflow(%{
          company_id: company.id,
          title: "No-double-sign",
          status: "pending_signatures",
          signers: [
            %{"name" => "Alice", "email" => "alice@test.com", "role" => "CEO", "status" => "pending"},
            %{"name" => "Bob", "email" => "bob@test.com", "role" => "CFO", "status" => "pending"}
          ]
        })

      {:ok, first} = Documents.sign_document(sw.id, "alice@test.com")
      alice_time = Enum.find(first.signers, fn s -> s["email"] == "alice@test.com" end)["signed_at"]

      {:ok, second} = Documents.sign_document(sw.id, "alice@test.com")
      alice_time2 = Enum.find(second.signers, fn s -> s["email"] == "alice@test.com" end)["signed_at"]
      assert alice_time == alice_time2
      assert second.status == "partially_signed"
    end

    test "does nothing for unknown email" do
      company = company_fixture()

      {:ok, sw} =
        Documents.create_signature_workflow(%{
          company_id: company.id,
          title: "Unknown signer",
          status: "pending_signatures",
          signers: [
            %{"name" => "Alice", "email" => "alice@test.com", "role" => "CEO", "status" => "pending"}
          ]
        })

      {:ok, unchanged} = Documents.sign_document(sw.id, "unknown@test.com")
      assert unchanged.status == "pending_signatures"
      alice = Enum.find(unchanged.signers, fn s -> s["email"] == "alice@test.com" end)
      assert alice["status"] == "pending"
    end
  end

  describe "signature workflow PubSub" do
    test "broadcast on create" do
      Documents.subscribe()
      company = company_fixture()

      {:ok, _} =
        Documents.create_signature_workflow(%{
          company_id: company.id,
          title: "PubSub Test"
        })

      assert_receive {:signature_workflows_created, _}
    end

    test "broadcast on update" do
      Documents.subscribe()
      sw = signature_workflow_fixture()

      {:ok, _} = Documents.update_signature_workflow(sw, %{title: "Updated"})
      assert_receive {:signature_workflows_updated, _}
    end
  end
end
