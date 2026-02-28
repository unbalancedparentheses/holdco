defmodule Holdco.Analytics.AirdropTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Analytics

  describe "airdrops CRUD" do
    test "list_airdrops/0 returns all airdrops" do
      airdrop = airdrop_fixture()
      assert Enum.any?(Analytics.list_airdrops(), &(&1.id == airdrop.id))
    end

    test "list_airdrops/1 filters by company_id" do
      company = company_fixture()
      airdrop = airdrop_fixture(%{company: company})
      other = airdrop_fixture()

      results = Analytics.list_airdrops(company.id)
      assert Enum.any?(results, &(&1.id == airdrop.id))
      refute Enum.any?(results, &(&1.id == other.id))
    end

    test "get_airdrop!/1 returns airdrop with preloads" do
      airdrop = airdrop_fixture()
      fetched = Analytics.get_airdrop!(airdrop.id)
      assert fetched.id == airdrop.id
      assert fetched.company != nil
    end

    test "get_airdrop!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Analytics.get_airdrop!(0)
      end
    end

    test "create_airdrop/1 with valid data" do
      company = company_fixture()

      assert {:ok, airdrop} =
               Analytics.create_airdrop(%{
                 company_id: company.id,
                 event_type: "airdrop",
                 token_name: "ARB",
                 chain: "arbitrum",
                 amount: "1000.0",
                 value_at_receipt: "1200.00",
                 current_value: "1500.00",
                 currency: "USD",
                 received_date: "2025-03-23",
                 claimed: true,
                 claimed_date: "2025-03-25"
               })

      assert airdrop.event_type == "airdrop"
      assert airdrop.token_name == "ARB"
      assert airdrop.chain == "arbitrum"
      assert airdrop.claimed == true
    end

    test "create_airdrop/1 with all event types" do
      company = company_fixture()

      for type <- ~w(airdrop fork token_split migration) do
        assert {:ok, airdrop} =
                 Analytics.create_airdrop(%{
                   company_id: company.id,
                   event_type: type,
                   token_name: "TOKEN_#{type}",
                   chain: "ethereum"
                 })

        assert airdrop.event_type == type
      end
    end

    test "create_airdrop/1 with all chains" do
      company = company_fixture()

      for chain <- ~w(ethereum polygon arbitrum solana avalanche bsc other) do
        assert {:ok, airdrop} =
                 Analytics.create_airdrop(%{
                   company_id: company.id,
                   event_type: "airdrop",
                   token_name: "TOKEN_#{chain}",
                   chain: chain
                 })

        assert airdrop.chain == chain
      end
    end

    test "create_airdrop/1 fails without required fields" do
      assert {:error, changeset} = Analytics.create_airdrop(%{})
      errors = errors_on(changeset)
      assert errors[:company_id]
      assert errors[:token_name]
    end

    test "create_airdrop/1 fails with invalid event_type" do
      company = company_fixture()

      assert {:error, changeset} =
               Analytics.create_airdrop(%{
                 company_id: company.id,
                 event_type: "invalid",
                 token_name: "TEST",
                 chain: "ethereum"
               })

      assert errors_on(changeset)[:event_type]
    end

    test "create_airdrop/1 fails with invalid chain" do
      company = company_fixture()

      assert {:error, changeset} =
               Analytics.create_airdrop(%{
                 company_id: company.id,
                 event_type: "airdrop",
                 token_name: "TEST",
                 chain: "invalid"
               })

      assert errors_on(changeset)[:chain]
    end

    test "create_airdrop/1 defaults claimed to false" do
      company = company_fixture()

      assert {:ok, airdrop} =
               Analytics.create_airdrop(%{
                 company_id: company.id,
                 event_type: "airdrop",
                 token_name: "UNI",
                 chain: "ethereum"
               })

      assert airdrop.claimed == false
    end

    test "create_airdrop/1 defaults eligible to true" do
      company = company_fixture()

      assert {:ok, airdrop} =
               Analytics.create_airdrop(%{
                 company_id: company.id,
                 event_type: "airdrop",
                 token_name: "UNI",
                 chain: "ethereum"
               })

      assert airdrop.eligible == true
    end

    test "update_airdrop/2 with valid data" do
      airdrop = airdrop_fixture()

      assert {:ok, updated} =
               Analytics.update_airdrop(airdrop, %{
                 claimed: true,
                 claimed_date: "2025-07-01",
                 current_value: "3000.00",
                 tax_treated: true
               })

      assert updated.claimed == true
      assert updated.tax_treated == true
      assert Decimal.equal?(updated.current_value, Decimal.new("3000.00"))
    end

    test "delete_airdrop/1 removes the airdrop" do
      airdrop = airdrop_fixture()
      assert {:ok, _} = Analytics.delete_airdrop(airdrop)

      assert_raise Ecto.NoResultsError, fn ->
        Analytics.get_airdrop!(airdrop.id)
      end
    end
  end

  describe "unclaimed_airdrops/1" do
    test "returns unclaimed eligible airdrops" do
      company = company_fixture()
      unclaimed = airdrop_fixture(%{company: company, claimed: false, eligible: true})
      _claimed = airdrop_fixture(%{company: company, claimed: true, eligible: true})
      _ineligible = airdrop_fixture(%{company: company, claimed: false, eligible: false})

      results = Analytics.unclaimed_airdrops(company.id)
      assert Enum.any?(results, &(&1.id == unclaimed.id))
      assert length(results) == 1
    end
  end

  describe "airdrop_value_summary/1" do
    test "returns value summary" do
      company = company_fixture()
      airdrop_fixture(%{company: company, value_at_receipt: "1000.00", current_value: "1500.00", claimed: true})
      airdrop_fixture(%{company: company, value_at_receipt: "2000.00", current_value: "2500.00", claimed: false})

      summary = Analytics.airdrop_value_summary(company.id)
      assert Decimal.equal?(summary.total_value_at_receipt, Decimal.new("3000.00"))
      assert Decimal.equal?(summary.total_current_value, Decimal.new("4000.00"))
      assert summary.total_count == 2
    end

    test "returns nil values when no airdrops" do
      company = company_fixture()
      summary = Analytics.airdrop_value_summary(company.id)
      assert summary.total_count == 0
    end
  end
end
