defmodule Holdco.Governance.ShareholderCommunicationTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Governance

  describe "shareholder communications CRUD" do
    test "list_shareholder_communications/0 returns all communications" do
      sc = shareholder_communication_fixture()
      assert Enum.any?(Governance.list_shareholder_communications(), &(&1.id == sc.id))
    end

    test "list_shareholder_communications/1 filters by company_id" do
      company = company_fixture()
      sc = shareholder_communication_fixture(%{company: company})
      other = shareholder_communication_fixture()

      results = Governance.list_shareholder_communications(company.id)
      assert Enum.any?(results, &(&1.id == sc.id))
      refute Enum.any?(results, &(&1.id == other.id))
    end

    test "get_shareholder_communication!/1 returns with preloads" do
      sc = shareholder_communication_fixture()
      fetched = Governance.get_shareholder_communication!(sc.id)
      assert fetched.id == sc.id
      assert fetched.company != nil
    end

    test "create_shareholder_communication/1 with valid data" do
      company = company_fixture()

      assert {:ok, sc} =
               Governance.create_shareholder_communication(%{
                 company_id: company.id,
                 communication_type: "annual_report",
                 title: "2025 Annual Report",
                 content: "Dear shareholders...",
                 target_audience: "all_shareholders",
                 distribution_date: ~D[2026-03-01],
                 response_deadline: ~D[2026-04-01],
                 status: "draft",
                 delivery_method: "email",
                 recipients_count: 500,
                 acknowledged_count: 0
               })

      assert sc.communication_type == "annual_report"
      assert sc.title == "2025 Annual Report"
      assert sc.target_audience == "all_shareholders"
      assert sc.recipients_count == 500
    end

    test "create_shareholder_communication/1 with all communication types" do
      company = company_fixture()

      for type <- ~w(notice circular annual_report interim_report proxy_statement dividend_notice agm_notice special_notice) do
        assert {:ok, sc} =
                 Governance.create_shareholder_communication(%{
                   company_id: company.id,
                   communication_type: type,
                   title: "Test #{type}"
                 })

        assert sc.communication_type == type
      end
    end

    test "create_shareholder_communication/1 with invalid type fails" do
      company = company_fixture()

      assert {:error, cs} =
               Governance.create_shareholder_communication(%{
                 company_id: company.id,
                 communication_type: "invalid_type",
                 title: "Test"
               })

      assert errors_on(cs)[:communication_type]
    end

    test "create_shareholder_communication/1 with invalid audience fails" do
      company = company_fixture()

      assert {:error, cs} =
               Governance.create_shareholder_communication(%{
                 company_id: company.id,
                 communication_type: "notice",
                 title: "Test",
                 target_audience: "invalid_audience"
               })

      assert errors_on(cs)[:target_audience]
    end

    test "create_shareholder_communication/1 without required fields fails" do
      assert {:error, cs} = Governance.create_shareholder_communication(%{})
      assert errors_on(cs)[:company_id]
      assert errors_on(cs)[:communication_type]
      assert errors_on(cs)[:title]
    end

    test "create_shareholder_communication/1 with invalid status fails" do
      company = company_fixture()

      assert {:error, cs} =
               Governance.create_shareholder_communication(%{
                 company_id: company.id,
                 communication_type: "notice",
                 title: "Test",
                 status: "bogus"
               })

      assert errors_on(cs)[:status]
    end

    test "create_shareholder_communication/1 with invalid delivery_method fails" do
      company = company_fixture()

      assert {:error, cs} =
               Governance.create_shareholder_communication(%{
                 company_id: company.id,
                 communication_type: "notice",
                 title: "Test",
                 delivery_method: "pigeon"
               })

      assert errors_on(cs)[:delivery_method]
    end

    test "update_shareholder_communication/2 updates fields" do
      sc = shareholder_communication_fixture()

      assert {:ok, updated} =
               Governance.update_shareholder_communication(sc, %{
                 title: "Updated Title",
                 status: "sent",
                 recipients_count: 200,
                 acknowledged_count: 50
               })

      assert updated.title == "Updated Title"
      assert updated.status == "sent"
      assert updated.recipients_count == 200
      assert updated.acknowledged_count == 50
    end

    test "delete_shareholder_communication/1 removes the communication" do
      sc = shareholder_communication_fixture()
      assert {:ok, _} = Governance.delete_shareholder_communication(sc)
      assert_raise Ecto.NoResultsError, fn -> Governance.get_shareholder_communication!(sc.id) end
    end

    test "create_shareholder_communication/1 with documents array" do
      company = company_fixture()

      assert {:ok, sc} =
               Governance.create_shareholder_communication(%{
                 company_id: company.id,
                 communication_type: "notice",
                 title: "With Docs",
                 documents: ["annual_report.pdf", "proxy_form.pdf"]
               })

      assert sc.documents == ["annual_report.pdf", "proxy_form.pdf"]
    end

    test "create_shareholder_communication/1 with negative recipients fails" do
      company = company_fixture()

      assert {:error, cs} =
               Governance.create_shareholder_communication(%{
                 company_id: company.id,
                 communication_type: "notice",
                 title: "Test",
                 recipients_count: -1
               })

      assert errors_on(cs)[:recipients_count]
    end
  end

  describe "pending_communications/1" do
    test "returns draft and approved communications" do
      company = company_fixture()

      {:ok, draft} =
        Governance.create_shareholder_communication(%{
          company_id: company.id,
          communication_type: "notice",
          title: "Draft Notice",
          status: "draft"
        })

      {:ok, approved} =
        Governance.create_shareholder_communication(%{
          company_id: company.id,
          communication_type: "circular",
          title: "Approved Circular",
          status: "approved"
        })

      {:ok, _sent} =
        Governance.create_shareholder_communication(%{
          company_id: company.id,
          communication_type: "notice",
          title: "Sent Notice",
          status: "sent"
        })

      results = Governance.pending_communications(company.id)
      ids = Enum.map(results, & &1.id)
      assert draft.id in ids
      assert approved.id in ids
      refute Enum.any?(results, fn c -> c.title == "Sent Notice" end)
    end
  end

  describe "communication_summary/1" do
    test "returns counts by status" do
      company = company_fixture()

      for _ <- 1..3 do
        Governance.create_shareholder_communication(%{
          company_id: company.id,
          communication_type: "notice",
          title: "Draft #{System.unique_integer([:positive])}",
          status: "draft"
        })
      end

      Governance.create_shareholder_communication(%{
        company_id: company.id,
        communication_type: "notice",
        title: "Sent One",
        status: "sent"
      })

      summary = Governance.communication_summary(company.id)
      assert summary["draft"] == 3
      assert summary["sent"] == 1
    end
  end

  describe "shareholder communication PubSub" do
    test "broadcast on create" do
      Governance.subscribe()
      company = company_fixture()

      {:ok, _} =
        Governance.create_shareholder_communication(%{
          company_id: company.id,
          communication_type: "notice",
          title: "PubSub Test"
        })

      assert_receive {:shareholder_communications_created, _}
    end
  end
end
