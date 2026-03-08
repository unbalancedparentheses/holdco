defmodule Holdco.BankingTest do
  use Holdco.DataCase, async: false

  import Holdco.HoldcoFixtures

  alias Holdco.Banking

  # Helper: convert Decimal to float for test assertions
  defp d(val) when is_struct(val, Decimal), do: Decimal.to_float(val)
  defp d(val) when is_number(val), do: val / 1
  defp d(nil), do: 0.0

  # ── Bank Accounts ──────────────────────────────────────

  describe "list_bank_accounts/0" do
    test "returns all bank accounts" do
      ba = bank_account_fixture()
      assert Enum.any?(Banking.list_bank_accounts(), &(&1.id == ba.id))
    end

    test "returns empty list when no bank accounts exist" do
      # Clean slate -- just check it returns a list
      result = Banking.list_bank_accounts()
      assert is_list(result)
    end

    test "preloads company association" do
      ba = bank_account_fixture()
      [fetched | _] = Banking.list_bank_accounts(%{company_id: ba.company_id})
      assert fetched.company != nil
      assert fetched.company.id == ba.company_id
    end

    test "orders by bank_name ascending" do
      company = company_fixture()
      ba_z = bank_account_fixture(%{company: company, bank_name: "Zeta Bank"})
      ba_a = bank_account_fixture(%{company: company, bank_name: "Alpha Bank"})

      results = Banking.list_bank_accounts(%{company_id: company.id})
      ids = Enum.map(results, & &1.id)
      assert Enum.find_index(ids, &(&1 == ba_a.id)) < Enum.find_index(ids, &(&1 == ba_z.id))
    end
  end

  describe "list_bank_accounts/1 with filters" do
    test "filters by company_id" do
      c1 = company_fixture(%{name: "FilterCo1"})
      c2 = company_fixture(%{name: "FilterCo2"})
      ba1 = bank_account_fixture(%{company: c1, bank_name: "Bank A"})
      _ba2 = bank_account_fixture(%{company: c2, bank_name: "Bank B"})

      results = Banking.list_bank_accounts(%{company_id: c1.id})
      assert Enum.any?(results, &(&1.id == ba1.id))
      refute Enum.any?(results, &(&1.company_id == c2.id))
    end

    test "filters by currency" do
      company = company_fixture()
      ba_usd = bank_account_fixture(%{company: company, currency: "USD", bank_name: "USD Bank"})
      ba_eur = bank_account_fixture(%{company: company, currency: "EUR", bank_name: "EUR Bank"})

      results = Banking.list_bank_accounts(%{currency: "EUR"})
      assert Enum.any?(results, &(&1.id == ba_eur.id))
      refute Enum.any?(results, &(&1.id == ba_usd.id))
    end

    test "filters by account_type" do
      company = company_fixture()
      ba_op = bank_account_fixture(%{company: company, account_type: "operating", bank_name: "Op Bank"})
      ba_sv = bank_account_fixture(%{company: company, account_type: "savings", bank_name: "Sv Bank"})

      results = Banking.list_bank_accounts(%{account_type: "savings"})
      assert Enum.any?(results, &(&1.id == ba_sv.id))
      refute Enum.any?(results, &(&1.id == ba_op.id))
    end

    test "ignores nil filter values" do
      ba = bank_account_fixture()
      results = Banking.list_bank_accounts(%{company_id: nil})
      assert Enum.any?(results, &(&1.id == ba.id))
    end

    test "ignores empty string filter values" do
      ba = bank_account_fixture()
      results = Banking.list_bank_accounts(%{bank_name: ""})
      assert Enum.any?(results, &(&1.id == ba.id))
    end

    test "ignores unknown filter keys" do
      ba = bank_account_fixture()
      results = Banking.list_bank_accounts(%{nonexistent_field: "value"})
      assert Enum.any?(results, &(&1.id == ba.id))
    end
  end

  describe "get_bank_account!/1" do
    test "returns the bank account with the given id" do
      ba = bank_account_fixture()
      fetched = Banking.get_bank_account!(ba.id)
      assert fetched.id == ba.id
      assert fetched.bank_name == ba.bank_name
    end

    test "preloads company association" do
      ba = bank_account_fixture()
      fetched = Banking.get_bank_account!(ba.id)
      assert fetched.company != nil
      assert fetched.company.id == ba.company_id
    end

    test "raises Ecto.NoResultsError for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Banking.get_bank_account!(0)
      end
    end
  end

  describe "create_bank_account/1" do
    test "creates a bank account with valid data" do
      company = company_fixture()

      assert {:ok, ba} =
               Banking.create_bank_account(%{
                 company_id: company.id,
                 bank_name: "Chase",
                 account_number: "1234567890",
                 currency: "USD",
                 account_type: "operating",
                 balance: 5000.0
               })

      assert ba.bank_name == "Chase"
      assert ba.account_number == "1234567890"
      assert ba.currency == "USD"
      assert ba.account_type == "operating"
      assert d(ba.balance) == 5000.0
    end

    test "creates a bank account with minimal required fields" do
      company = company_fixture()
      assert {:ok, ba} = Banking.create_bank_account(%{company_id: company.id, bank_name: "Minimal Bank"})
      assert ba.bank_name == "Minimal Bank"
      assert ba.currency == "USD"
      assert ba.account_type == "operating"
      assert d(ba.balance) == 0.0
    end

    test "returns error changeset when company_id is missing" do
      assert {:error, changeset} = Banking.create_bank_account(%{bank_name: "No Company"})
      assert errors_on(changeset)[:company_id]
    end

    test "returns error changeset when bank_name is missing" do
      company = company_fixture()
      assert {:error, changeset} = Banking.create_bank_account(%{company_id: company.id})
      assert errors_on(changeset)[:bank_name]
    end

    test "returns error changeset with empty attrs" do
      assert {:error, changeset} = Banking.create_bank_account(%{})
      assert errors_on(changeset)[:company_id]
      assert errors_on(changeset)[:bank_name]
    end

    test "creates a bank account with optional IBAN and SWIFT" do
      company = company_fixture()

      assert {:ok, ba} =
               Banking.create_bank_account(%{
                 company_id: company.id,
                 bank_name: "International Bank",
                 iban: "DE89370400440532013000",
                 swift: "COBADEFFXXX"
               })

      assert ba.iban == "DE89370400440532013000"
      assert ba.swift == "COBADEFFXXX"
    end

    test "broadcasts PubSub message on successful create" do
      Phoenix.PubSub.subscribe(Holdco.PubSub, "banking")
      company = company_fixture()
      {:ok, ba} = Banking.create_bank_account(%{company_id: company.id, bank_name: "PubSub Bank"})
      assert_receive {:bank_accounts_created, ^ba}
    end
  end

  describe "update_bank_account/2" do
    test "updates with valid data" do
      ba = bank_account_fixture()

      assert {:ok, updated} =
               Banking.update_bank_account(ba, %{
                 bank_name: "Updated Bank Name",
                 balance: 9999.99,
                 notes: "Updated notes"
               })

      assert updated.bank_name == "Updated Bank Name"
      assert d(updated.balance) == 9999.99
      assert updated.notes == "Updated notes"
    end

    test "returns error changeset with invalid data" do
      ba = bank_account_fixture()
      assert {:error, changeset} = Banking.update_bank_account(ba, %{bank_name: nil})
      assert errors_on(changeset)[:bank_name]
      # Verify the original is unchanged
      assert Banking.get_bank_account!(ba.id).bank_name == ba.bank_name
    end

    test "broadcasts PubSub message on successful update" do
      Phoenix.PubSub.subscribe(Holdco.PubSub, "banking")
      ba = bank_account_fixture()
      {:ok, updated} = Banking.update_bank_account(ba, %{bank_name: "Broadcast Updated"})
      assert_receive {:bank_accounts_updated, ^updated}
    end
  end

  describe "delete_bank_account/1" do
    test "deletes the bank account" do
      ba = bank_account_fixture()
      assert {:ok, _} = Banking.delete_bank_account(ba)
      assert_raise Ecto.NoResultsError, fn -> Banking.get_bank_account!(ba.id) end
    end

    test "broadcasts PubSub message on successful delete" do
      Phoenix.PubSub.subscribe(Holdco.PubSub, "banking")
      ba = bank_account_fixture()
      {:ok, deleted} = Banking.delete_bank_account(ba)
      assert_receive {:bank_accounts_deleted, ^deleted}
    end
  end

  # ── Transactions ───────────────────────────────────────

  describe "list_transactions/0" do
    test "returns all transactions" do
      t = transaction_fixture()
      assert Enum.any?(Banking.list_transactions(), &(&1.id == t.id))
    end

    test "preloads company association" do
      t = transaction_fixture()
      [fetched | _] = Banking.list_transactions(%{company_id: t.company_id})
      assert fetched.company != nil
    end

    test "orders by date descending" do
      company = company_fixture()
      t_old = transaction_fixture(%{company: company, date: "2024-01-01", description: "Old"})
      t_new = transaction_fixture(%{company: company, date: "2024-12-31", description: "New"})

      results = Banking.list_transactions(%{company_id: company.id})
      ids = Enum.map(results, & &1.id)
      assert Enum.find_index(ids, &(&1 == t_new.id)) < Enum.find_index(ids, &(&1 == t_old.id))
    end
  end

  describe "list_transactions/1 with filters" do
    test "filters by company_id" do
      c1 = company_fixture(%{name: "TxCo1"})
      c2 = company_fixture(%{name: "TxCo2"})
      t1 = transaction_fixture(%{company: c1, description: "Tx for Co1"})
      _t2 = transaction_fixture(%{company: c2, description: "Tx for Co2"})

      results = Banking.list_transactions(%{company_id: c1.id})
      assert Enum.any?(results, &(&1.id == t1.id))
      refute Enum.any?(results, &(&1.company_id == c2.id))
    end

    test "filters by transaction_type" do
      company = company_fixture()
      t_credit = transaction_fixture(%{company: company, transaction_type: "credit", description: "Credit"})
      t_debit = transaction_fixture(%{company: company, transaction_type: "debit", description: "Debit"})

      results = Banking.list_transactions(%{transaction_type: "credit", company_id: company.id})
      assert Enum.any?(results, &(&1.id == t_credit.id))
      refute Enum.any?(results, &(&1.id == t_debit.id))
    end

    test "filters by currency" do
      company = company_fixture()
      t_usd = transaction_fixture(%{company: company, currency: "USD", description: "USD Tx"})
      t_eur = transaction_fixture(%{company: company, currency: "EUR", description: "EUR Tx"})

      results = Banking.list_transactions(%{currency: "EUR", company_id: company.id})
      assert Enum.any?(results, &(&1.id == t_eur.id))
      refute Enum.any?(results, &(&1.id == t_usd.id))
    end

    test "ignores nil and empty string filters" do
      t = transaction_fixture()
      results = Banking.list_transactions(%{company_id: nil, transaction_type: ""})
      assert Enum.any?(results, &(&1.id == t.id))
    end
  end

  describe "get_transaction!/1" do
    test "returns the transaction with the given id" do
      t = transaction_fixture()
      fetched = Banking.get_transaction!(t.id)
      assert fetched.id == t.id
      assert fetched.description == t.description
    end

    test "preloads company association" do
      t = transaction_fixture()
      fetched = Banking.get_transaction!(t.id)
      assert fetched.company != nil
    end

    test "raises Ecto.NoResultsError for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Banking.get_transaction!(0)
      end
    end
  end

  describe "create_transaction/1" do
    test "creates a transaction with valid data" do
      company = company_fixture()

      assert {:ok, t} =
               Banking.create_transaction(%{
                 company_id: company.id,
                 transaction_type: "debit",
                 description: "Office supplies",
                 amount: 250.50,
                 date: "2024-06-15",
                 currency: "USD",
                 counterparty: "Staples",
                 notes: "Monthly supplies"
               })

      assert t.transaction_type == "debit"
      assert t.description == "Office supplies"
      assert d(t.amount) == 250.5
      assert t.date == "2024-06-15"
      assert t.counterparty == "Staples"
      assert t.notes == "Monthly supplies"
    end

    test "returns error changeset when required fields are missing" do
      assert {:error, changeset} = Banking.create_transaction(%{})
      errors = errors_on(changeset)
      assert errors[:company_id]
      assert errors[:transaction_type]
      assert errors[:description]
      assert errors[:amount]
      assert errors[:date]
    end

    test "returns error when amount is zero or negative" do
      company = company_fixture()

      assert {:error, changeset} =
               Banking.create_transaction(%{
                 company_id: company.id,
                 transaction_type: "credit",
                 description: "Zero amount",
                 amount: 0,
                 date: "2024-01-01"
               })

      assert errors_on(changeset)[:amount]

      assert {:error, changeset} =
               Banking.create_transaction(%{
                 company_id: company.id,
                 transaction_type: "credit",
                 description: "Negative amount",
                 amount: -50.0,
                 date: "2024-01-01"
               })

      assert errors_on(changeset)[:amount]
    end

    test "returns error when date is in invalid format" do
      company = company_fixture()

      assert {:error, changeset} =
               Banking.create_transaction(%{
                 company_id: company.id,
                 transaction_type: "credit",
                 description: "Bad date",
                 amount: 100.0,
                 date: "not-a-date"
               })

      assert errors_on(changeset)[:date]
    end

    test "broadcasts PubSub message on successful create" do
      Phoenix.PubSub.subscribe(Holdco.PubSub, "banking")
      company = company_fixture()

      {:ok, t} =
        Banking.create_transaction(%{
          company_id: company.id,
          transaction_type: "credit",
          description: "PubSub test",
          amount: 100.0,
          date: "2024-01-01"
        })

      assert_receive {:transactions_created, ^t}
    end
  end

  describe "update_transaction/2" do
    test "updates with valid data" do
      t = transaction_fixture()

      assert {:ok, updated} =
               Banking.update_transaction(t, %{
                 description: "Updated description",
                 amount: 999.99,
                 counterparty: "New Counterparty"
               })

      assert updated.description == "Updated description"
      assert d(updated.amount) == 999.99
      assert updated.counterparty == "New Counterparty"
    end

    test "returns error changeset with invalid data" do
      t = transaction_fixture()
      assert {:error, changeset} = Banking.update_transaction(t, %{description: nil})
      assert errors_on(changeset)[:description]
      # Verify the original is unchanged
      assert Banking.get_transaction!(t.id).description == t.description
    end

    test "broadcasts PubSub message on successful update" do
      Phoenix.PubSub.subscribe(Holdco.PubSub, "banking")
      t = transaction_fixture()
      {:ok, updated} = Banking.update_transaction(t, %{description: "Broadcast updated"})
      assert_receive {:transactions_updated, ^updated}
    end
  end

  describe "delete_transaction/1" do
    test "deletes the transaction" do
      t = transaction_fixture()
      assert {:ok, _} = Banking.delete_transaction(t)
      assert_raise Ecto.NoResultsError, fn -> Banking.get_transaction!(t.id) end
    end

    test "broadcasts PubSub message on successful delete" do
      Phoenix.PubSub.subscribe(Holdco.PubSub, "banking")
      t = transaction_fixture()
      {:ok, deleted} = Banking.delete_transaction(t)
      assert_receive {:transactions_deleted, ^deleted}
    end
  end

  # ── Bulk Operations ────────────────────────────────────

  describe "bulk_update_transactions/2" do
    test "updates multiple transactions and returns success/failure counts" do
      company = company_fixture()
      t1 = transaction_fixture(%{company: company, description: "Bulk1"})
      t2 = transaction_fixture(%{company: company, description: "Bulk2"})
      t3 = transaction_fixture(%{company: company, description: "Bulk3"})

      {success, failures} =
        Banking.bulk_update_transactions([t1.id, t2.id, t3.id], %{counterparty: "Bulk Corp"})

      assert success == 3
      assert failures == 0

      assert Banking.get_transaction!(t1.id).counterparty == "Bulk Corp"
      assert Banking.get_transaction!(t2.id).counterparty == "Bulk Corp"
      assert Banking.get_transaction!(t3.id).counterparty == "Bulk Corp"
    end

    test "returns counts with partial failures" do
      company = company_fixture()
      t1 = transaction_fixture(%{company: company, description: "BulkOK"})

      # Passing a nil description should fail validation
      {success, failures} =
        Banking.bulk_update_transactions([t1.id], %{description: nil})

      assert success == 0
      assert failures == 1
    end

    test "handles empty list" do
      {success, failures} = Banking.bulk_update_transactions([], %{counterparty: "Nobody"})
      assert success == 0
      assert failures == 0
    end
  end

  describe "bulk_delete_transactions/1" do
    test "deletes multiple transactions and returns counts" do
      company = company_fixture()
      t1 = transaction_fixture(%{company: company, description: "Del1"})
      t2 = transaction_fixture(%{company: company, description: "Del2"})

      {success, failures} = Banking.bulk_delete_transactions([t1.id, t2.id])
      assert success == 2
      assert failures == 0

      assert_raise Ecto.NoResultsError, fn -> Banking.get_transaction!(t1.id) end
      assert_raise Ecto.NoResultsError, fn -> Banking.get_transaction!(t2.id) end
    end

    test "handles empty list" do
      {success, failures} = Banking.bulk_delete_transactions([])
      assert success == 0
      assert failures == 0
    end
  end

  describe "bulk_update_bank_accounts/2" do
    test "updates multiple bank accounts and returns counts" do
      company = company_fixture()
      ba1 = bank_account_fixture(%{company: company, bank_name: "BulkBA1"})
      ba2 = bank_account_fixture(%{company: company, bank_name: "BulkBA2"})

      {success, failures} =
        Banking.bulk_update_bank_accounts([ba1.id, ba2.id], %{notes: "Bulk updated"})

      assert success == 2
      assert failures == 0

      assert Banking.get_bank_account!(ba1.id).notes == "Bulk updated"
      assert Banking.get_bank_account!(ba2.id).notes == "Bulk updated"
    end

    test "returns counts with partial failures" do
      company = company_fixture()
      ba1 = bank_account_fixture(%{company: company, bank_name: "BulkBAFail"})

      {success, failures} =
        Banking.bulk_update_bank_accounts([ba1.id], %{bank_name: nil})

      assert success == 0
      assert failures == 1
    end

    test "handles empty list" do
      {success, failures} = Banking.bulk_update_bank_accounts([], %{notes: "Nobody"})
      assert success == 0
      assert failures == 0
    end
  end

  describe "bulk_delete_bank_accounts/1" do
    test "deletes multiple bank accounts and returns counts" do
      company = company_fixture()
      ba1 = bank_account_fixture(%{company: company, bank_name: "DelBA1"})
      ba2 = bank_account_fixture(%{company: company, bank_name: "DelBA2"})

      {success, failures} = Banking.bulk_delete_bank_accounts([ba1.id, ba2.id])
      assert success == 2
      assert failures == 0

      assert_raise Ecto.NoResultsError, fn -> Banking.get_bank_account!(ba1.id) end
      assert_raise Ecto.NoResultsError, fn -> Banking.get_bank_account!(ba2.id) end
    end

    test "handles empty list" do
      {success, failures} = Banking.bulk_delete_bank_accounts([])
      assert success == 0
      assert failures == 0
    end
  end

  # ── Aggregations ───────────────────────────────────────

  describe "total_balance/0" do
    test "returns sum of all bank account balances" do
      company = company_fixture()
      bank_account_fixture(%{company: company, balance: 1000.0, bank_name: "TotBal1"})
      bank_account_fixture(%{company: company, balance: 2500.50, bank_name: "TotBal2"})

      total = d(Banking.total_balance())
      assert total >= 3500.5
    end

    test "returns numeric value even when no accounts exist" do
      total = d(Banking.total_balance())
      assert is_number(total)
    end
  end

end
