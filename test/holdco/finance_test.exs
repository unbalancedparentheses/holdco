defmodule Holdco.FinanceTest do
  use Holdco.DataCase

  import Holdco.HoldcoFixtures

  alias Holdco.Finance

  describe "financials" do
    test "CRUD operations" do
      company = company_fixture()
      {:ok, f} = Finance.create_financial(%{company_id: company.id, period: "2024-Q1", revenue: 100_000.0, expenses: 50_000.0})

      assert Enum.any?(Finance.list_financials(company.id), &(&1.id == f.id))
      assert Finance.get_financial!(f.id).id == f.id

      {:ok, updated} = Finance.update_financial(f, %{revenue: 120_000.0})
      assert updated.revenue == 120_000.0

      {:ok, _} = Finance.delete_financial(updated)
    end
  end

  describe "accounts (chart of accounts)" do
    test "CRUD operations" do
      company = company_fixture()
      {:ok, a} = Finance.create_account(%{company_id: company.id, name: "Cash", account_type: "asset", code: "1001"})

      assert Enum.any?(Finance.list_accounts(company.id), &(&1.id == a.id))
      assert Finance.get_account!(a.id).id == a.id

      {:ok, updated} = Finance.update_account(a, %{name: "Petty Cash"})
      assert updated.name == "Petty Cash"

      {:ok, _} = Finance.delete_account(updated)
    end

    test "create_account/1 with invalid data" do
      assert {:error, cs} = Finance.create_account(%{})
      assert errors_on(cs)[:name]
    end
  end

  describe "journal_entries and lines" do
    test "CRUD operations for entries" do
      company = company_fixture()
      {:ok, je} = Finance.create_journal_entry(%{company_id: company.id, date: "2024-01-01", description: "Opening balance"})

      assert Enum.any?(Finance.list_journal_entries(company.id), &(&1.id == je.id))
      assert Finance.get_journal_entry!(je.id).id == je.id

      {:ok, updated} = Finance.update_journal_entry(je, %{description: "Updated"})
      assert updated.description == "Updated"

      {:ok, _} = Finance.delete_journal_entry(updated)
    end

    test "CRUD operations for lines" do
      company = company_fixture()
      {:ok, je} = Finance.create_journal_entry(%{company_id: company.id, date: "2024-01-01", description: "Test"})
      {:ok, acct} = Finance.create_account(%{company_id: company.id, name: "Cash", account_type: "asset", code: "#{System.unique_integer([:positive])}"})
      {:ok, jl} = Finance.create_journal_line(%{entry_id: je.id, account_id: acct.id, debit: 500.0})

      assert Enum.any?(Finance.list_journal_lines(je.id), &(&1.id == jl.id))
      assert Finance.get_journal_line!(jl.id).id == jl.id

      {:ok, updated} = Finance.update_journal_line(jl, %{debit: 600.0})
      assert updated.debit == 600.0

      {:ok, _} = Finance.delete_journal_line(updated)
    end
  end

  describe "inter_company_transfers" do
    test "CRUD operations" do
      c1 = company_fixture()
      c2 = company_fixture()
      {:ok, ict} = Finance.create_inter_company_transfer(%{from_company_id: c1.id, to_company_id: c2.id, amount: 10_000.0, date: "2024-01-01"})

      assert Enum.any?(Finance.list_inter_company_transfers(), &(&1.id == ict.id))
      assert Finance.get_inter_company_transfer!(ict.id).id == ict.id

      {:ok, updated} = Finance.update_inter_company_transfer(ict, %{amount: 20_000.0})
      assert updated.amount == 20_000.0

      {:ok, _} = Finance.delete_inter_company_transfer(updated)
    end
  end

  describe "dividends" do
    test "CRUD operations" do
      company = company_fixture()
      {:ok, d} = Finance.create_dividend(%{company_id: company.id, amount: 1000.0, date: "2024-06-01"})

      assert Enum.any?(Finance.list_dividends(company.id), &(&1.id == d.id))
      assert Finance.get_dividend!(d.id).id == d.id

      {:ok, updated} = Finance.update_dividend(d, %{amount: 2000.0})
      assert updated.amount == 2000.0

      {:ok, _} = Finance.delete_dividend(updated)
    end
  end

  describe "capital_contributions" do
    test "CRUD operations" do
      company = company_fixture()
      {:ok, cc} = Finance.create_capital_contribution(%{company_id: company.id, contributor: "Investor", amount: 50_000.0, date: "2024-01-01"})

      assert Enum.any?(Finance.list_capital_contributions(company.id), &(&1.id == cc.id))
      assert Finance.get_capital_contribution!(cc.id).id == cc.id

      {:ok, updated} = Finance.update_capital_contribution(cc, %{contributor: "New Investor"})
      assert updated.contributor == "New Investor"

      {:ok, _} = Finance.delete_capital_contribution(updated)
    end
  end

  describe "tax_payments" do
    test "CRUD operations" do
      company = company_fixture()
      {:ok, tp} = Finance.create_tax_payment(%{company_id: company.id, jurisdiction: "US", tax_type: "income", amount: 5000.0, date: "2024-04-15"})

      assert Enum.any?(Finance.list_tax_payments(company.id), &(&1.id == tp.id))
      assert Finance.get_tax_payment!(tp.id).id == tp.id

      {:ok, updated} = Finance.update_tax_payment(tp, %{amount: 6000.0})
      assert updated.amount == 6000.0

      {:ok, _} = Finance.delete_tax_payment(updated)
    end
  end

  describe "budgets" do
    test "CRUD operations" do
      company = company_fixture()
      {:ok, b} = Finance.create_budget(%{company_id: company.id, period: "2024", category: "Marketing"})

      assert Enum.any?(Finance.list_budgets(company.id), &(&1.id == b.id))
      assert Finance.get_budget!(b.id).id == b.id

      {:ok, updated} = Finance.update_budget(b, %{category: "Engineering"})
      assert updated.category == "Engineering"

      {:ok, _} = Finance.delete_budget(updated)
    end
  end

  describe "liabilities" do
    test "CRUD operations" do
      company = company_fixture()
      {:ok, l} = Finance.create_liability(%{company_id: company.id, liability_type: "bond", creditor: "Investor", principal: 200_000.0})

      assert Enum.any?(Finance.list_liabilities(company.id), &(&1.id == l.id))
      assert Finance.get_liability!(l.id).id == l.id

      {:ok, updated} = Finance.update_liability(l, %{creditor: "Bank"})
      assert updated.creditor == "Bank"

      {:ok, _} = Finance.delete_liability(updated)
    end
  end

  describe "financial reports" do
    test "trial_balance/1 returns list" do
      company = company_fixture()
      result = Finance.trial_balance(company.id)
      assert is_list(result)
    end

    test "balance_sheet/1 returns map" do
      company = company_fixture()
      result = Finance.balance_sheet(company.id)
      assert is_map(result)
    end

    test "income_statement/3 returns map" do
      company = company_fixture()
      result = Finance.income_statement(company.id, "2024-01-01", "2024-12-31")
      assert is_map(result)
    end
  end

  describe "aggregations" do
    test "total_revenue/0" do
      assert is_number(Finance.total_revenue())
    end

    test "total_expenses/0" do
      assert is_number(Finance.total_expenses())
    end

    test "total_liabilities/0" do
      assert is_number(Finance.total_liabilities())
    end
  end

  describe "list functions without company filter" do
    test "list_financials/0 returns all" do
      company = company_fixture()
      {:ok, f} = Finance.create_financial(%{company_id: company.id, period: "2024-Q2", revenue: 50_000.0})
      assert Enum.any?(Finance.list_financials(), &(&1.id == f.id))
    end

    test "list_accounts/0 returns all" do
      company = company_fixture()
      {:ok, a} = Finance.create_account(%{company_id: company.id, name: "AR", account_type: "asset", code: "#{System.unique_integer([:positive])}"})
      assert Enum.any?(Finance.list_accounts(), &(&1.id == a.id))
    end

    test "list_journal_entries/0 returns all" do
      company = company_fixture()
      {:ok, je} = Finance.create_journal_entry(%{company_id: company.id, date: "2024-03-01", description: "All entries"})
      assert Enum.any?(Finance.list_journal_entries(), &(&1.id == je.id))
    end

    test "list_dividends/0 returns all" do
      company = company_fixture()
      {:ok, d} = Finance.create_dividend(%{company_id: company.id, amount: 500.0, date: "2024-07-01"})
      assert Enum.any?(Finance.list_dividends(), &(&1.id == d.id))
    end

    test "list_capital_contributions/0 returns all" do
      company = company_fixture()
      {:ok, cc} = Finance.create_capital_contribution(%{company_id: company.id, contributor: "AllInvestor", amount: 10_000.0, date: "2024-02-01"})
      assert Enum.any?(Finance.list_capital_contributions(), &(&1.id == cc.id))
    end

    test "list_tax_payments/0 returns all" do
      company = company_fixture()
      {:ok, tp} = Finance.create_tax_payment(%{company_id: company.id, jurisdiction: "UK", tax_type: "vat", amount: 2000.0, date: "2024-05-01"})
      assert Enum.any?(Finance.list_tax_payments(), &(&1.id == tp.id))
    end

    test "list_budgets/0 returns all" do
      company = company_fixture()
      {:ok, b} = Finance.create_budget(%{company_id: company.id, period: "2025", category: "Ops"})
      assert Enum.any?(Finance.list_budgets(), &(&1.id == b.id))
    end

    test "list_liabilities/0 returns all" do
      company = company_fixture()
      {:ok, l} = Finance.create_liability(%{company_id: company.id, liability_type: "loan", creditor: "AllBank", principal: 100_000.0})
      assert Enum.any?(Finance.list_liabilities(), &(&1.id == l.id))
    end
  end

  describe "segments" do
    test "CRUD operations" do
      company = company_fixture()
      {:ok, s} = Finance.create_segment(%{company_id: company.id, name: "APAC"})

      assert Enum.any?(Finance.list_segments(company.id), &(&1.id == s.id))
      assert Enum.any?(Finance.list_segments(), &(&1.id == s.id))
      assert Finance.get_segment!(s.id).id == s.id

      {:ok, updated} = Finance.update_segment(s, %{name: "EMEA"})
      assert updated.name == "EMEA"

      {:ok, _} = Finance.delete_segment(updated)
    end
  end

  describe "leases" do
    test "CRUD operations" do
      company = company_fixture()
      {:ok, l} = Finance.create_lease(%{company_id: company.id, lessor: "PropCo"})

      assert Enum.any?(Finance.list_leases(company.id), &(&1.id == l.id))
      assert Enum.any?(Finance.list_leases(), &(&1.id == l.id))
      assert Finance.get_lease!(l.id).id == l.id

      {:ok, updated} = Finance.update_lease(l, %{lessor: "NewPropCo"})
      assert updated.lessor == "NewPropCo"

      {:ok, _} = Finance.delete_lease(updated)
    end
  end

  describe "trial_balance_by_segment" do
    test "returns results for a segment" do
      company = company_fixture()
      {:ok, s} = Finance.create_segment(%{company_id: company.id, name: "North America"})
      result = Finance.trial_balance_by_segment(s.id)
      assert is_list(result)
    end
  end

  describe "reports without company filter" do
    test "trial_balance/0 returns all accounts" do
      assert is_list(Finance.trial_balance())
    end

    test "balance_sheet/0 returns all" do
      result = Finance.balance_sheet()
      assert is_map(result)
      assert Map.has_key?(result, :assets)
    end

    test "income_statement/0 returns all" do
      result = Finance.income_statement()
      assert is_map(result)
      assert Map.has_key?(result, :revenue)
    end
  end

  describe "subscribe/0" do
    test "subscribes to finance PubSub topic" do
      assert :ok = Finance.subscribe()
    end
  end
end
