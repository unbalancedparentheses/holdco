defmodule Holdco.Analytics.OnChainRecordTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Analytics

  describe "on_chain_records CRUD" do
    test "list_on_chain_records/0 returns all records" do
      record = on_chain_record_fixture()
      assert Enum.any?(Analytics.list_on_chain_records(), &(&1.id == record.id))
    end

    test "list_on_chain_records/1 filters by company_id" do
      company = company_fixture()
      record = on_chain_record_fixture(%{company: company})
      other = on_chain_record_fixture()

      results = Analytics.list_on_chain_records(company.id)
      assert Enum.any?(results, &(&1.id == record.id))
      refute Enum.any?(results, &(&1.id == other.id))
    end

    test "get_on_chain_record!/1 returns record with preloads" do
      record = on_chain_record_fixture()
      fetched = Analytics.get_on_chain_record!(record.id)
      assert fetched.id == record.id
      assert fetched.company != nil
    end

    test "get_on_chain_record!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Analytics.get_on_chain_record!(0)
      end
    end

    test "create_on_chain_record/1 with valid data" do
      company = company_fixture()

      assert {:ok, record} =
               Analytics.create_on_chain_record(%{
                 company_id: company.id,
                 chain: "ethereum",
                 tx_hash: "0xabc123def456",
                 block_number: 18_000_000,
                 from_address: "0xsender",
                 to_address: "0xreceiver",
                 amount: "1.5",
                 currency: "ETH",
                 verification_status: "pending"
               })

      assert record.chain == "ethereum"
      assert record.tx_hash == "0xabc123def456"
      assert record.block_number == 18_000_000
      assert record.verification_status == "pending"
    end

    test "create_on_chain_record/1 with all chains" do
      company = company_fixture()

      for chain <- ~w(ethereum polygon arbitrum solana avalanche bsc other) do
        assert {:ok, record} =
                 Analytics.create_on_chain_record(%{
                   company_id: company.id,
                   chain: chain,
                   tx_hash: "0x#{:crypto.strong_rand_bytes(32) |> Base.encode16(case: :lower)}"
                 })

        assert record.chain == chain
      end
    end

    test "create_on_chain_record/1 with all verification statuses" do
      company = company_fixture()

      for status <- ~w(pending confirmed failed mismatch) do
        assert {:ok, record} =
                 Analytics.create_on_chain_record(%{
                   company_id: company.id,
                   chain: "ethereum",
                   tx_hash: "0x#{:crypto.strong_rand_bytes(32) |> Base.encode16(case: :lower)}",
                   verification_status: status
                 })

        assert record.verification_status == status
      end
    end

    test "create_on_chain_record/1 fails without required fields" do
      assert {:error, changeset} = Analytics.create_on_chain_record(%{})
      errors = errors_on(changeset)
      assert errors[:company_id]
      assert errors[:tx_hash]
    end

    test "create_on_chain_record/1 fails with invalid chain" do
      company = company_fixture()

      assert {:error, changeset} =
               Analytics.create_on_chain_record(%{
                 company_id: company.id,
                 chain: "invalid",
                 tx_hash: "0xtest"
               })

      assert errors_on(changeset)[:chain]
    end

    test "create_on_chain_record/1 fails with invalid verification_status" do
      company = company_fixture()

      assert {:error, changeset} =
               Analytics.create_on_chain_record(%{
                 company_id: company.id,
                 chain: "ethereum",
                 tx_hash: "0xtest",
                 verification_status: "invalid"
               })

      assert errors_on(changeset)[:verification_status]
    end

    test "create_on_chain_record/1 enforces unique tx_hash" do
      company = company_fixture()
      tx_hash = "0xuniquehash123"

      assert {:ok, _} =
               Analytics.create_on_chain_record(%{
                 company_id: company.id,
                 chain: "ethereum",
                 tx_hash: tx_hash
               })

      assert {:error, changeset} =
               Analytics.create_on_chain_record(%{
                 company_id: company.id,
                 chain: "ethereum",
                 tx_hash: tx_hash
               })

      assert errors_on(changeset)[:tx_hash]
    end

    test "update_on_chain_record/2 with valid data" do
      record = on_chain_record_fixture()

      assert {:ok, updated} =
               Analytics.update_on_chain_record(record, %{
                 verification_status: "confirmed",
                 notes: "Verified on etherscan"
               })

      assert updated.verification_status == "confirmed"
      assert updated.notes == "Verified on etherscan"
    end

    test "delete_on_chain_record/1 removes the record" do
      record = on_chain_record_fixture()
      assert {:ok, _} = Analytics.delete_on_chain_record(record)

      assert_raise Ecto.NoResultsError, fn ->
        Analytics.get_on_chain_record!(record.id)
      end
    end
  end

  describe "unverified_records/1" do
    test "returns only pending records for a company" do
      company = company_fixture()
      pending = on_chain_record_fixture(%{company: company, verification_status: "pending"})
      _confirmed = on_chain_record_fixture(%{company: company, verification_status: "confirmed"})

      results = Analytics.unverified_records(company.id)
      assert Enum.any?(results, &(&1.id == pending.id))
      assert Enum.all?(results, &(&1.verification_status == "pending"))
    end
  end

  describe "verification_summary/1" do
    test "returns counts by status" do
      company = company_fixture()
      on_chain_record_fixture(%{company: company, verification_status: "pending"})
      on_chain_record_fixture(%{company: company, verification_status: "pending"})
      on_chain_record_fixture(%{company: company, verification_status: "confirmed"})

      summary = Analytics.verification_summary(company.id)
      assert summary["pending"] == 2
      assert summary["confirmed"] == 1
    end

    test "returns empty map when no records" do
      company = company_fixture()
      summary = Analytics.verification_summary(company.id)
      assert summary == %{}
    end
  end
end
