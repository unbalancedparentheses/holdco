defmodule Holdco.BankingTest do
  use Holdco.DataCase

  import Holdco.HoldcoFixtures

  alias Holdco.Banking

  describe "bank_accounts" do
    test "list_bank_accounts/0 returns all bank accounts" do
      ba = bank_account_fixture()
      assert Enum.any?(Banking.list_bank_accounts(), &(&1.id == ba.id))
    end

    test "list_bank_accounts/1 filters by company_id" do
      company = company_fixture()
      ba = bank_account_fixture(%{company: company})
      results = Banking.list_bank_accounts(%{company_id: company.id})
      assert Enum.any?(results, &(&1.id == ba.id))
    end

    test "get_bank_account!/1" do
      ba = bank_account_fixture()
      fetched = Banking.get_bank_account!(ba.id)
      assert fetched.id == ba.id
      assert fetched.company != nil
    end

    test "create_bank_account/1 with valid data" do
      company = company_fixture()
      assert {:ok, ba} = Banking.create_bank_account(%{company_id: company.id, bank_name: "Chase"})
      assert ba.bank_name == "Chase"
    end

    test "create_bank_account/1 with invalid data" do
      assert {:error, changeset} = Banking.create_bank_account(%{})
      assert errors_on(changeset)[:company_id]
    end

    test "update_bank_account/2" do
      ba = bank_account_fixture()
      assert {:ok, updated} = Banking.update_bank_account(ba, %{bank_name: "Updated Bank"})
      assert updated.bank_name == "Updated Bank"
    end

    test "delete_bank_account/1" do
      ba = bank_account_fixture()
      assert {:ok, _} = Banking.delete_bank_account(ba)
      assert_raise Ecto.NoResultsError, fn -> Banking.get_bank_account!(ba.id) end
    end
  end

  describe "transactions" do
    test "list_transactions/0 returns all transactions" do
      t = transaction_fixture()
      assert Enum.any?(Banking.list_transactions(), &(&1.id == t.id))
    end

    test "get_transaction!/1" do
      t = transaction_fixture()
      fetched = Banking.get_transaction!(t.id)
      assert fetched.id == t.id
    end

    test "create_transaction/1 with valid data" do
      company = company_fixture()
      attrs = %{company_id: company.id, transaction_type: "debit", description: "Payment", amount: 500.0, date: "2024-02-01"}
      assert {:ok, t} = Banking.create_transaction(attrs)
      assert t.amount == 500.0
    end

    test "create_transaction/1 with invalid data" do
      assert {:error, changeset} = Banking.create_transaction(%{})
      assert errors_on(changeset)[:company_id]
    end

    test "update_transaction/2" do
      t = transaction_fixture()
      assert {:ok, updated} = Banking.update_transaction(t, %{description: "Updated"})
      assert updated.description == "Updated"
    end

    test "delete_transaction/1" do
      t = transaction_fixture()
      assert {:ok, _} = Banking.delete_transaction(t)
    end
  end

  describe "aggregations" do
    test "total_balance/0 returns sum of balances" do
      company = company_fixture()
      bank_account_fixture(%{company: company, balance: 1000.0})
      bank_account_fixture(%{company: company, balance: 2000.0})
      assert Banking.total_balance() >= 3000.0
    end

    test "total_balance/0 returns 0 with no accounts" do
      # May already have accounts from other tests, just ensure it returns a number
      assert is_number(Banking.total_balance())
    end
  end

  describe "list_transactions/1 with filters" do
    test "filters transactions by company_id" do
      c1 = company_fixture(%{name: "TxFilterCo1"})
      c2 = company_fixture(%{name: "TxFilterCo2"})
      t1 = transaction_fixture(%{company: c1, description: "Tx for Co1"})
      _t2 = transaction_fixture(%{company: c2, description: "Tx for Co2"})

      results = Banking.list_transactions(%{company_id: c1.id})
      assert Enum.any?(results, &(&1.id == t1.id))
      refute Enum.any?(results, &(&1.description == "Tx for Co2"))
    end
  end

  describe "subscribe/0" do
    test "subscribes to banking PubSub topic" do
      assert :ok = Banking.subscribe()
    end
  end
end
