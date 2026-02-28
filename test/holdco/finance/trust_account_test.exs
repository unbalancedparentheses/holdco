defmodule Holdco.Finance.TrustAccountTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Finance

  describe "trust_accounts CRUD" do
    test "list_trust_accounts/0 returns all trust accounts" do
      account = trust_account_fixture()
      assert Enum.any?(Finance.list_trust_accounts(), &(&1.id == account.id))
    end

    test "list_trust_accounts/1 filters by company_id" do
      company = company_fixture()
      account = trust_account_fixture(%{company: company})
      other = trust_account_fixture()

      results = Finance.list_trust_accounts(company.id)
      assert Enum.any?(results, &(&1.id == account.id))
      refute Enum.any?(results, &(&1.id == other.id))
    end

    test "get_trust_account!/1 returns account with preloads" do
      account = trust_account_fixture()
      fetched = Finance.get_trust_account!(account.id)
      assert fetched.id == account.id
      assert fetched.company != nil
    end

    test "get_trust_account!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Finance.get_trust_account!(0)
      end
    end

    test "create_trust_account/1 with valid data" do
      company = company_fixture()

      assert {:ok, account} =
               Finance.create_trust_account(%{
                 company_id: company.id,
                 trust_name: "Family Trust",
                 trust_type: "irrevocable",
                 trustee_name: "John Trustee",
                 grantor_name: "Jane Grantor",
                 jurisdiction: "Delaware",
                 corpus_value: "5000000.00",
                 distribution_schedule: "quarterly",
                 status: "active"
               })

      assert account.trust_name == "Family Trust"
      assert account.trust_type == "irrevocable"
      assert account.trustee_name == "John Trustee"
      assert Decimal.equal?(account.corpus_value, Decimal.new("5000000.00"))
    end

    test "create_trust_account/1 with all trust types" do
      company = company_fixture()

      for type <- ~w(revocable irrevocable testamentary charitable special_needs grantor_retained) do
        assert {:ok, account} =
                 Finance.create_trust_account(%{
                   company_id: company.id,
                   trust_name: "Trust #{type}",
                   trust_type: type,
                   trustee_name: "Trustee"
                 })

        assert account.trust_type == type
      end
    end

    test "create_trust_account/1 fails without required fields" do
      assert {:error, changeset} = Finance.create_trust_account(%{})
      errors = errors_on(changeset)
      assert errors[:company_id]
      assert errors[:trust_name]
      assert errors[:trustee_name]
    end

    test "create_trust_account/1 fails with invalid trust type" do
      company = company_fixture()

      assert {:error, changeset} =
               Finance.create_trust_account(%{
                 company_id: company.id,
                 trust_name: "Test",
                 trust_type: "invalid",
                 trustee_name: "Trustee"
               })

      assert errors_on(changeset)[:trust_type]
    end

    test "update_trust_account/2 with valid data" do
      account = trust_account_fixture()

      assert {:ok, updated} =
               Finance.update_trust_account(account, %{
                 trust_name: "Updated Trust",
                 status: "suspended"
               })

      assert updated.trust_name == "Updated Trust"
      assert updated.status == "suspended"
    end

    test "delete_trust_account/1 removes the account" do
      account = trust_account_fixture()
      assert {:ok, _} = Finance.delete_trust_account(account)

      assert_raise Ecto.NoResultsError, fn ->
        Finance.get_trust_account!(account.id)
      end
    end
  end

  describe "trust_transactions" do
    test "list_trust_transactions/1 returns transactions for account" do
      account = trust_account_fixture()
      tx = trust_transaction_fixture(%{trust_account: account})

      results = Finance.list_trust_transactions(account.id)
      assert Enum.any?(results, &(&1.id == tx.id))
    end

    test "create_trust_transaction/1 with valid data" do
      account = trust_account_fixture()

      assert {:ok, tx} =
               Finance.create_trust_transaction(%{
                 trust_account_id: account.id,
                 transaction_type: "distribution",
                 amount: "25000.00",
                 transaction_date: "2024-06-15",
                 category: "income",
                 description: "Quarterly distribution"
               })

      assert tx.transaction_type == "distribution"
      assert Decimal.equal?(tx.amount, Decimal.new("25000.00"))
      assert tx.category == "income"
    end

    test "create_trust_transaction/1 fails with invalid type" do
      account = trust_account_fixture()

      assert {:error, changeset} =
               Finance.create_trust_transaction(%{
                 trust_account_id: account.id,
                 transaction_type: "invalid",
                 amount: "1000.00",
                 transaction_date: "2024-06-15"
               })

      assert errors_on(changeset)[:transaction_type]
    end

    test "trust_balance/1 calculates correct balance" do
      account = trust_account_fixture()

      Finance.create_trust_transaction(%{
        trust_account_id: account.id,
        transaction_type: "contribution",
        amount: "100000.00",
        transaction_date: "2024-01-01"
      })

      Finance.create_trust_transaction(%{
        trust_account_id: account.id,
        transaction_type: "income",
        amount: "5000.00",
        transaction_date: "2024-03-01"
      })

      Finance.create_trust_transaction(%{
        trust_account_id: account.id,
        transaction_type: "distribution",
        amount: "20000.00",
        transaction_date: "2024-06-01"
      })

      balance = Finance.trust_balance(account.id)
      assert Decimal.equal?(balance, Decimal.new("85000.00"))
    end

    test "trust_income_summary/1 groups by transaction type" do
      account = trust_account_fixture()

      Finance.create_trust_transaction(%{
        trust_account_id: account.id,
        transaction_type: "contribution",
        amount: "50000.00",
        transaction_date: "2024-01-01"
      })

      Finance.create_trust_transaction(%{
        trust_account_id: account.id,
        transaction_type: "contribution",
        amount: "25000.00",
        transaction_date: "2024-02-01"
      })

      summary = Finance.trust_income_summary(account.id)
      contrib = Enum.find(summary, &(&1.transaction_type == "contribution"))
      assert contrib != nil
      assert Decimal.equal?(contrib.total, Decimal.new("75000.00"))
    end
  end
end
