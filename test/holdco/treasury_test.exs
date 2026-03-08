defmodule Holdco.TreasuryTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Treasury

  describe "cash_pools" do
    test "CRUD operations" do
      {:ok, cp} = Treasury.create_cash_pool(%{name: "EUR Pool", currency: "EUR"})

      assert Enum.any?(Treasury.list_cash_pools(), &(&1.id == cp.id))
      assert Treasury.get_cash_pool!(cp.id).id == cp.id

      {:ok, updated} = Treasury.update_cash_pool(cp, %{name: "USD Pool"})
      assert updated.name == "USD Pool"

      {:ok, _} = Treasury.delete_cash_pool(updated)
    end
  end

  describe "cash_pool_entries" do
    test "CRUD operations" do
      pool = cash_pool_fixture()
      company = company_fixture()

      {:ok, cpe} = Treasury.create_cash_pool_entry(%{pool_id: pool.id, company_id: company.id, allocated_amount: 5000.0})

      assert Enum.any?(Treasury.list_cash_pool_entries(pool.id), &(&1.id == cpe.id))
      assert Treasury.get_cash_pool_entry!(cpe.id).id == cpe.id

      {:ok, updated} = Treasury.update_cash_pool_entry(cpe, %{allocated_amount: 10_000.0})
      assert Decimal.equal?(updated.allocated_amount, Decimal.new("10000.0"))

      {:ok, _} = Treasury.delete_cash_pool_entry(updated)
    end
  end

  describe "cash_pools extended" do
    test "list_cash_pools returns pools ordered by name" do
      Treasury.create_cash_pool(%{name: "Zebra Pool"})
      Treasury.create_cash_pool(%{name: "Alpha Pool"})

      pools = Treasury.list_cash_pools()
      names = Enum.map(pools, & &1.name)
      assert names == Enum.sort(names)
    end

    test "list_cash_pools preloads entries" do
      pool = cash_pool_fixture()
      company = company_fixture()
      Treasury.create_cash_pool_entry(%{pool_id: pool.id, company_id: company.id, allocated_amount: 1000.0})

      pools = Treasury.list_cash_pools()
      target = Enum.find(pools, &(&1.id == pool.id))
      assert length(target.entries) > 0
    end

    test "get_cash_pool! preloads entries with company and bank_account" do
      pool = cash_pool_fixture()
      company = company_fixture()
      ba = bank_account_fixture(%{company: company})
      Treasury.create_cash_pool_entry(%{pool_id: pool.id, company_id: company.id, bank_account_id: ba.id, allocated_amount: 2000.0})

      fetched = Treasury.get_cash_pool!(pool.id)
      assert length(fetched.entries) > 0
      entry = List.first(fetched.entries)
      assert entry.company != nil
    end

    test "get_cash_pool! raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Treasury.get_cash_pool!(999_999)
      end
    end

    test "create_cash_pool with invalid data returns error" do
      # name is required by the changeset
      {:error, changeset} = Treasury.create_cash_pool(%{})
      refute changeset.valid?
    end

    test "delete_cash_pool removes the record" do
      {:ok, cp} = Treasury.create_cash_pool(%{name: "To Delete"})
      {:ok, _} = Treasury.delete_cash_pool(cp)

      assert_raise Ecto.NoResultsError, fn ->
        Treasury.get_cash_pool!(cp.id)
      end
    end
  end

  describe "cash_pool_entries extended" do
    test "list_cash_pool_entries returns entries for specific pool only" do
      pool1 = cash_pool_fixture(%{name: "Pool 1"})
      pool2 = cash_pool_fixture(%{name: "Pool 2"})
      company = company_fixture()

      Treasury.create_cash_pool_entry(%{pool_id: pool1.id, company_id: company.id, allocated_amount: 1000.0})
      Treasury.create_cash_pool_entry(%{pool_id: pool2.id, company_id: company.id, allocated_amount: 2000.0})

      entries1 = Treasury.list_cash_pool_entries(pool1.id)
      assert length(entries1) == 1
      assert List.first(entries1).pool_id == pool1.id
    end

    test "get_cash_pool_entry! preloads associations" do
      pool = cash_pool_fixture()
      company = company_fixture()

      {:ok, cpe} = Treasury.create_cash_pool_entry(%{pool_id: pool.id, company_id: company.id, allocated_amount: 3000.0})

      fetched = Treasury.get_cash_pool_entry!(cpe.id)
      assert fetched.pool != nil
      assert fetched.company != nil
    end

    test "get_cash_pool_entry! raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Treasury.get_cash_pool_entry!(999_999)
      end
    end

    test "delete_cash_pool_entry removes the record" do
      pool = cash_pool_fixture()
      company = company_fixture()
      {:ok, cpe} = Treasury.create_cash_pool_entry(%{pool_id: pool.id, company_id: company.id, allocated_amount: 1000.0})

      {:ok, _} = Treasury.delete_cash_pool_entry(cpe)

      assert_raise Ecto.NoResultsError, fn ->
        Treasury.get_cash_pool_entry!(cpe.id)
      end
    end
  end

end
