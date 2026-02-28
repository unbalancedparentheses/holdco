defmodule Holdco.Analytics.DefiPositionTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Analytics

  describe "defi_positions CRUD" do
    test "list_defi_positions/0 returns all positions" do
      position = defi_position_fixture()
      assert Enum.any?(Analytics.list_defi_positions(), &(&1.id == position.id))
    end

    test "list_defi_positions/1 filters by company_id" do
      company = company_fixture()
      position = defi_position_fixture(%{company: company})
      other = defi_position_fixture()

      results = Analytics.list_defi_positions(company.id)
      assert Enum.any?(results, &(&1.id == position.id))
      refute Enum.any?(results, &(&1.id == other.id))
    end

    test "get_defi_position!/1 returns position with preloads" do
      position = defi_position_fixture()
      fetched = Analytics.get_defi_position!(position.id)
      assert fetched.id == position.id
      assert fetched.company != nil
    end

    test "get_defi_position!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Analytics.get_defi_position!(0)
      end
    end

    test "create_defi_position/1 with valid data" do
      company = company_fixture()

      assert {:ok, position} =
               Analytics.create_defi_position(%{
                 company_id: company.id,
                 protocol_name: "Uniswap",
                 chain: "ethereum",
                 position_type: "liquidity_pool",
                 asset_pair: "ETH/USDC",
                 deposited_amount: "50000.00",
                 current_value: "52000.00",
                 apy_current: "12.5",
                 status: "active"
               })

      assert position.protocol_name == "Uniswap"
      assert position.chain == "ethereum"
      assert position.position_type == "liquidity_pool"
      assert Decimal.equal?(position.deposited_amount, Decimal.new("50000.00"))
    end

    test "create_defi_position/1 with all chains" do
      company = company_fixture()

      for chain <- ~w(ethereum polygon arbitrum solana avalanche bsc other) do
        assert {:ok, position} =
                 Analytics.create_defi_position(%{
                   company_id: company.id,
                   protocol_name: "Protocol #{chain}",
                   chain: chain,
                   position_type: "staking"
                 })

        assert position.chain == chain
      end
    end

    test "create_defi_position/1 with all position types" do
      company = company_fixture()

      for type <- ~w(lending borrowing liquidity_pool staking farming vault other) do
        assert {:ok, position} =
                 Analytics.create_defi_position(%{
                   company_id: company.id,
                   protocol_name: "Protocol #{type}",
                   chain: "ethereum",
                   position_type: type
                 })

        assert position.position_type == type
      end
    end

    test "create_defi_position/1 fails without required fields" do
      assert {:error, changeset} = Analytics.create_defi_position(%{})
      errors = errors_on(changeset)
      assert errors[:company_id]
      assert errors[:protocol_name]
    end

    test "create_defi_position/1 fails with invalid chain" do
      company = company_fixture()

      assert {:error, changeset} =
               Analytics.create_defi_position(%{
                 company_id: company.id,
                 protocol_name: "Aave",
                 chain: "invalid_chain",
                 position_type: "lending"
               })

      assert errors_on(changeset)[:chain]
    end

    test "create_defi_position/1 fails with invalid position_type" do
      company = company_fixture()

      assert {:error, changeset} =
               Analytics.create_defi_position(%{
                 company_id: company.id,
                 protocol_name: "Aave",
                 chain: "ethereum",
                 position_type: "invalid_type"
               })

      assert errors_on(changeset)[:position_type]
    end

    test "create_defi_position/1 fails with invalid status" do
      company = company_fixture()

      assert {:error, changeset} =
               Analytics.create_defi_position(%{
                 company_id: company.id,
                 protocol_name: "Aave",
                 chain: "ethereum",
                 position_type: "lending",
                 status: "invalid_status"
               })

      assert errors_on(changeset)[:status]
    end

    test "update_defi_position/2 with valid data" do
      position = defi_position_fixture()

      assert {:ok, updated} =
               Analytics.update_defi_position(position, %{
                 current_value: "15000.00",
                 status: "closed",
                 exit_date: "2025-12-31"
               })

      assert Decimal.equal?(updated.current_value, Decimal.new("15000.00"))
      assert updated.status == "closed"
    end

    test "delete_defi_position/1 removes the position" do
      position = defi_position_fixture()
      assert {:ok, _} = Analytics.delete_defi_position(position)

      assert_raise Ecto.NoResultsError, fn ->
        Analytics.get_defi_position!(position.id)
      end
    end
  end

  describe "total_defi_value/1" do
    test "returns total current value for active positions" do
      company = company_fixture()
      defi_position_fixture(%{company: company, current_value: "1000.00", status: "active"})
      defi_position_fixture(%{company: company, current_value: "2000.00", status: "active"})
      defi_position_fixture(%{company: company, current_value: "500.00", status: "closed"})

      total = Analytics.total_defi_value(company.id)
      assert Decimal.equal?(total, Decimal.new("3000.00"))
    end

    test "returns zero when no active positions" do
      company = company_fixture()
      total = Analytics.total_defi_value(company.id)
      assert Decimal.equal?(total, Decimal.new(0))
    end
  end

  describe "defi_by_chain/1" do
    test "groups positions by chain" do
      company = company_fixture()
      defi_position_fixture(%{company: company, chain: "ethereum", current_value: "1000.00"})
      defi_position_fixture(%{company: company, chain: "ethereum", current_value: "2000.00"})
      defi_position_fixture(%{company: company, chain: "polygon", current_value: "500.00"})

      result = Analytics.defi_by_chain(company.id)
      assert length(result) == 2

      eth = Enum.find(result, fn {chain, _, _} -> chain == "ethereum" end)
      assert eth != nil
      {_, value, count} = eth
      assert count == 2
      assert Decimal.equal?(value, Decimal.new("3000.00"))
    end
  end

  describe "defi_by_protocol/1" do
    test "groups positions by protocol" do
      company = company_fixture()
      defi_position_fixture(%{company: company, protocol_name: "Aave", current_value: "1000.00"})
      defi_position_fixture(%{company: company, protocol_name: "Aave", current_value: "2000.00"})
      defi_position_fixture(%{company: company, protocol_name: "Uniswap", current_value: "500.00"})

      result = Analytics.defi_by_protocol(company.id)
      assert length(result) == 2

      aave = Enum.find(result, fn {protocol, _, _} -> protocol == "Aave" end)
      assert aave != nil
      {_, value, count} = aave
      assert count == 2
      assert Decimal.equal?(value, Decimal.new("3000.00"))
    end
  end
end
