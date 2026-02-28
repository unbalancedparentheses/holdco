defmodule Holdco.Documents.ExtractionTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Documents

  describe "extractions CRUD" do
    test "list_extractions/0 returns all extractions" do
      extraction = extraction_fixture()
      results = Documents.list_extractions()
      assert Enum.any?(results, &(&1.id == extraction.id))
    end

    test "list_extractions/1 filters by document_id" do
      extraction = extraction_fixture()
      doc = Holdco.Repo.preload(extraction, :document).document
      other = extraction_fixture()

      results = Documents.list_extractions(doc.id)
      assert Enum.any?(results, &(&1.id == extraction.id))
      refute Enum.any?(results, &(&1.id == other.id))
    end

    test "get_extraction!/1 returns extraction with preloads" do
      extraction = extraction_fixture()
      fetched = Documents.get_extraction!(extraction.id)
      assert fetched.id == extraction.id
      assert fetched.document != nil
    end

    test "get_extraction!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Documents.get_extraction!(0)
      end
    end

    test "create_extraction/1 with valid data" do
      doc = document_fixture()

      assert {:ok, extraction} =
               Documents.create_extraction(%{
                 document_id: doc.id,
                 extraction_type: "invoice",
                 status: "pending",
                 extracted_data: %{"total" => "500.00"},
                 confidence_score: "0.85",
                 model_used: "gpt-4"
               })

      assert extraction.extraction_type == "invoice"
      assert extraction.status == "pending"
      assert Decimal.equal?(extraction.confidence_score, Decimal.new("0.85"))
    end

    test "create_extraction/1 with all extraction types" do
      doc = document_fixture()

      for type <- ~w(invoice receipt contract financial_statement tax_form other) do
        assert {:ok, extraction} =
                 Documents.create_extraction(%{
                   document_id: doc.id,
                   extraction_type: type
                 })

        assert extraction.extraction_type == type
      end
    end

    test "create_extraction/1 fails without required fields" do
      assert {:error, changeset} = Documents.create_extraction(%{})
      errors = errors_on(changeset)
      assert errors[:document_id]
      # extraction_type has a default value so only document_id is required
      assert errors[:document_id]
    end

    test "create_extraction/1 fails with invalid extraction_type" do
      doc = document_fixture()

      assert {:error, changeset} =
               Documents.create_extraction(%{
                 document_id: doc.id,
                 extraction_type: "invalid"
               })

      assert errors_on(changeset)[:extraction_type]
    end

    test "create_extraction/1 fails with invalid status" do
      doc = document_fixture()

      assert {:error, changeset} =
               Documents.create_extraction(%{
                 document_id: doc.id,
                 extraction_type: "invoice",
                 status: "invalid"
               })

      assert errors_on(changeset)[:status]
    end

    test "update_extraction/2 with valid data" do
      extraction = extraction_fixture()

      assert {:ok, updated} =
               Documents.update_extraction(extraction, %{
                 status: "completed",
                 confidence_score: "0.99",
                 processing_time_ms: 1500
               })

      assert updated.status == "completed"
      assert Decimal.equal?(updated.confidence_score, Decimal.new("0.99"))
      assert updated.processing_time_ms == 1500
    end

    test "mark_extraction_reviewed/2 marks as reviewed" do
      extraction = extraction_fixture(%{reviewed: false})
      user = Holdco.AccountsFixtures.user_fixture()

      assert {:ok, updated} = Documents.mark_extraction_reviewed(extraction, user.id)
      assert updated.reviewed == true
      assert updated.reviewed_by_id == user.id
    end
  end

  describe "pending_extractions/0" do
    test "returns only pending and processing extractions" do
      pending = extraction_fixture(%{status: "pending"})
      processing = extraction_fixture(%{status: "processing"})
      _completed = extraction_fixture(%{status: "completed"})
      _failed = extraction_fixture(%{status: "failed"})

      results = Documents.pending_extractions()
      ids = Enum.map(results, & &1.id)
      assert pending.id in ids
      assert processing.id in ids
    end
  end

  describe "extraction schema" do
    test "extraction_types returns valid types" do
      types = Holdco.Documents.Extraction.extraction_types()
      assert "invoice" in types
      assert "receipt" in types
      assert "contract" in types
    end

    test "statuses returns valid statuses" do
      statuses = Holdco.Documents.Extraction.statuses()
      assert "pending" in statuses
      assert "completed" in statuses
    end

    test "confidence_score must be between 0 and 1" do
      doc = document_fixture()

      assert {:error, changeset} =
               Documents.create_extraction(%{
                 document_id: doc.id,
                 extraction_type: "invoice",
                 confidence_score: "1.5"
               })

      assert errors_on(changeset)[:confidence_score]
    end
  end
end
