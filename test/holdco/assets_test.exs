defmodule Holdco.AssetsTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Assets

  # Helper: convert Decimal to float for test assertions
  defp d(val) when is_struct(val, Decimal), do: Decimal.to_float(val)
  defp d(val) when is_number(val), do: val / 1
  defp d(nil), do: 0.0

  describe "holdings" do
    test "list_holdings/0 returns all" do
      h = holding_fixture()
      assert Enum.any?(Assets.list_holdings(), &(&1.id == h.id))
    end

    test "get_holding!/1 returns with preloads" do
      h = holding_fixture()
      fetched = Assets.get_holding!(h.id)
      assert fetched.id == h.id
      assert is_list(fetched.cost_basis_lots)
    end

    test "create_holding/1 valid" do
      company = company_fixture()
      assert {:ok, h} = Assets.create_holding(%{company_id: company.id, asset: "MSFT", ticker: "MSFT"})
      assert h.asset == "MSFT"
    end

    test "create_holding/1 invalid" do
      assert {:error, cs} = Assets.create_holding(%{})
      assert errors_on(cs)[:company_id]
    end

    test "update_holding/2" do
      h = holding_fixture()
      assert {:ok, updated} = Assets.update_holding(h, %{asset: "GOOG"})
      assert updated.asset == "GOOG"
    end

    test "delete_holding/1" do
      h = holding_fixture()
      assert {:ok, _} = Assets.delete_holding(h)
    end
  end

  describe "custodian_accounts" do
    test "CRUD operations" do
      holding = holding_fixture()
      {:ok, ca} = Assets.create_custodian_account(%{asset_holding_id: holding.id, bank: "Schwab"})
      assert ca.bank == "Schwab"

      assert Enum.any?(Assets.list_custodian_accounts(), &(&1.id == ca.id))
      assert Assets.get_custodian_account!(ca.id).id == ca.id

      {:ok, updated} = Assets.update_custodian_account(ca, %{bank: "Fidelity"})
      assert updated.bank == "Fidelity"

      {:ok, _} = Assets.delete_custodian_account(updated)
    end
  end

  describe "cost_basis_lots" do
    test "CRUD operations" do
      holding = holding_fixture()
      {:ok, cbl} = Assets.create_cost_basis_lot(%{holding_id: holding.id, purchase_date: "2024-01-01", quantity: 50.0, price_per_unit: 100.0})

      assert Enum.any?(Assets.list_cost_basis_lots(holding.id), &(&1.id == cbl.id))
      assert Assets.get_cost_basis_lot!(cbl.id).id == cbl.id

      {:ok, updated} = Assets.update_cost_basis_lot(cbl, %{quantity: 75.0})
      assert d(updated.quantity) == 75.0

      {:ok, _} = Assets.delete_cost_basis_lot(updated)
    end
  end

  describe "crypto_wallets" do
    test "CRUD operations" do
      holding = holding_fixture()
      {:ok, cw} = Assets.create_crypto_wallet(%{holding_id: holding.id, wallet_address: "0xABC123"})

      assert Enum.any?(Assets.list_crypto_wallets(holding.id), &(&1.id == cw.id))
      assert Enum.any?(Assets.list_crypto_wallets(), &(&1.id == cw.id))
      assert Assets.get_crypto_wallet!(cw.id).id == cw.id

      {:ok, updated} = Assets.update_crypto_wallet(cw, %{blockchain: "solana"})
      assert updated.blockchain == "solana"

      {:ok, _} = Assets.delete_crypto_wallet(updated)
    end
  end

  describe "real_estate_properties" do
    test "CRUD operations" do
      company = company_fixture()
      {:ok, re} = Assets.create_real_estate_property(%{company_id: company.id, name: "Office Tower"})

      assert Enum.any?(Assets.list_real_estate_properties(company.id), &(&1.id == re.id))
      assert Enum.any?(Assets.list_real_estate_properties(), &(&1.id == re.id))
      assert Assets.get_real_estate_property!(re.id).id == re.id

      {:ok, updated} = Assets.update_real_estate_property(re, %{name: "Warehouse"})
      assert updated.name == "Warehouse"

      {:ok, _} = Assets.delete_real_estate_property(updated)
    end
  end

  describe "fund_investments" do
    test "CRUD operations" do
      company = company_fixture()
      {:ok, fi} = Assets.create_fund_investment(%{company_id: company.id, fund_name: "Growth Fund"})

      assert Enum.any?(Assets.list_fund_investments(company.id), &(&1.id == fi.id))
      assert Enum.any?(Assets.list_fund_investments(), &(&1.id == fi.id))
      assert Assets.get_fund_investment!(fi.id).id == fi.id

      {:ok, updated} = Assets.update_fund_investment(fi, %{fund_name: "Value Fund"})
      assert updated.fund_name == "Value Fund"

      {:ok, _} = Assets.delete_fund_investment(updated)
    end
  end

  describe "subscribe/0" do
    test "subscribes to portfolio PubSub topic" do
      assert :ok = Assets.subscribe()
    end
  end

  describe "portfolio_snapshots" do
    test "CRUD operations" do
      {:ok, ps} = Assets.create_portfolio_snapshot(%{date: "2024-06-01", nav: 500_000.0})

      assert Enum.any?(Assets.list_portfolio_snapshots(), &(&1.id == ps.id))
      assert Assets.get_portfolio_snapshot!(ps.id).id == ps.id

      {:ok, updated} = Assets.update_portfolio_snapshot(ps, %{nav: 600_000.0})
      assert d(updated.nav) == 600_000.0

      {:ok, _} = Assets.delete_portfolio_snapshot(updated)
    end
  end
end
