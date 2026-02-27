defmodule Holdco.FinanceTest do
  use Holdco.DataCase

  import Holdco.HoldcoFixtures

  alias Holdco.Finance

  # Helper: convert Decimal to float for test assertions
  defp d(val) when is_struct(val, Decimal), do: Decimal.to_float(val)
  defp d(val) when is_number(val), do: val / 1
  defp d(nil), do: 0.0

  describe "financials" do
    test "CRUD operations" do
      company = company_fixture()
      {:ok, f} = Finance.create_financial(%{company_id: company.id, period: "2024-Q1", revenue: 100_000.0, expenses: 50_000.0})

      assert Enum.any?(Finance.list_financials(company.id), &(&1.id == f.id))
      assert Finance.get_financial!(f.id).id == f.id

      {:ok, updated} = Finance.update_financial(f, %{revenue: 120_000.0})
      assert d(updated.revenue) == 120_000.0

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
      assert d(updated.debit) == 600.0

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
      assert d(updated.amount) == 20_000.0

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
      assert d(updated.amount) == 2000.0

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
      assert d(updated.amount) == 6000.0

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
      assert Finance.total_revenue() != nil
    end

    test "total_expenses/0" do
      assert Finance.total_expenses() != nil
    end

    test "total_liabilities/0" do
      assert Finance.total_liabilities() != nil
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

  # ── create_journal_entry_with_lines/2 ────────────────────────

  describe "create_journal_entry_with_lines/2" do
    setup do
      company = company_fixture()

      {:ok, cash_acct} =
        Finance.create_account(%{
          company_id: company.id,
          name: "Cash",
          account_type: "asset",
          code: "#{System.unique_integer([:positive])}"
        })

      {:ok, revenue_acct} =
        Finance.create_account(%{
          company_id: company.id,
          name: "Revenue",
          account_type: "revenue",
          code: "#{System.unique_integer([:positive])}"
        })

      {:ok, expense_acct} =
        Finance.create_account(%{
          company_id: company.id,
          name: "Rent Expense",
          account_type: "expense",
          code: "#{System.unique_integer([:positive])}"
        })

      %{
        company: company,
        cash_acct: cash_acct,
        revenue_acct: revenue_acct,
        expense_acct: expense_acct
      }
    end

    test "successfully creates a balanced journal entry with two lines", ctx do
      entry_attrs = %{
        "company_id" => ctx.company.id,
        "date" => "2024-03-15",
        "description" => "Revenue received"
      }

      lines_attrs = [
        %{"account_id" => ctx.cash_acct.id, "debit" => 1000.0, "credit" => 0.0},
        %{"account_id" => ctx.revenue_acct.id, "debit" => 0.0, "credit" => 1000.0}
      ]

      assert {:ok, entry} = Finance.create_journal_entry_with_lines(entry_attrs, lines_attrs)
      assert entry.description == "Revenue received"
      assert entry.date == "2024-03-15"
      assert length(entry.lines) == 2
    end

    test "returns the created entry with its lines preloaded", ctx do
      entry_attrs = %{
        "company_id" => ctx.company.id,
        "date" => "2024-04-01",
        "description" => "Atomic creation test"
      }

      lines_attrs = [
        %{"account_id" => ctx.cash_acct.id, "debit" => 500.0, "credit" => 0.0},
        %{"account_id" => ctx.revenue_acct.id, "debit" => 0.0, "credit" => 500.0}
      ]

      {:ok, entry} = Finance.create_journal_entry_with_lines(entry_attrs, lines_attrs)

      assert is_list(entry.lines)
      debit_line = Enum.find(entry.lines, fn l -> d(l.debit) == 500.0 end)
      credit_line = Enum.find(entry.lines, fn l -> d(l.credit) == 500.0 end)
      assert debit_line != nil
      assert credit_line != nil
      assert debit_line.account_id == ctx.cash_acct.id
      assert credit_line.account_id == ctx.revenue_acct.id
    end

    test "persists both entry and lines to the database", ctx do
      entry_attrs = %{
        "company_id" => ctx.company.id,
        "date" => "2024-05-01",
        "description" => "Persistence test"
      }

      lines_attrs = [
        %{"account_id" => ctx.cash_acct.id, "debit" => 250.0, "credit" => 0.0},
        %{"account_id" => ctx.revenue_acct.id, "debit" => 0.0, "credit" => 250.0}
      ]

      {:ok, entry} = Finance.create_journal_entry_with_lines(entry_attrs, lines_attrs)

      # Verify the entry is persisted and can be fetched
      fetched = Finance.get_journal_entry!(entry.id)
      assert fetched.id == entry.id
      assert fetched.description == "Persistence test"

      # Verify the lines are persisted
      db_lines = Finance.list_journal_lines(entry.id)
      assert length(db_lines) == 2
    end

    test "rejects fewer than 2 lines", ctx do
      entry_attrs = %{
        "company_id" => ctx.company.id,
        "date" => "2024-01-01",
        "description" => "Single line attempt"
      }

      lines_attrs = [
        %{"account_id" => ctx.cash_acct.id, "debit" => 100.0, "credit" => 0.0}
      ]

      assert {:error, :insufficient_lines} =
               Finance.create_journal_entry_with_lines(entry_attrs, lines_attrs)
    end

    test "rejects an empty lines list", ctx do
      entry_attrs = %{
        "company_id" => ctx.company.id,
        "date" => "2024-01-01",
        "description" => "No lines"
      }

      assert {:error, :insufficient_lines} =
               Finance.create_journal_entry_with_lines(entry_attrs, [])
    end

    test "rejects unbalanced debits and credits", ctx do
      entry_attrs = %{
        "company_id" => ctx.company.id,
        "date" => "2024-01-01",
        "description" => "Unbalanced entry"
      }

      lines_attrs = [
        %{"account_id" => ctx.cash_acct.id, "debit" => 1000.0, "credit" => 0.0},
        %{"account_id" => ctx.revenue_acct.id, "debit" => 0.0, "credit" => 500.0}
      ]

      assert {:error, :unbalanced} =
               Finance.create_journal_entry_with_lines(entry_attrs, lines_attrs)
    end

    test "rejects when credits exceed debits", ctx do
      entry_attrs = %{
        "company_id" => ctx.company.id,
        "date" => "2024-01-01",
        "description" => "Credits > Debits"
      }

      lines_attrs = [
        %{"account_id" => ctx.cash_acct.id, "debit" => 100.0, "credit" => 0.0},
        %{"account_id" => ctx.revenue_acct.id, "debit" => 0.0, "credit" => 999.0}
      ]

      assert {:error, :unbalanced} =
               Finance.create_journal_entry_with_lines(entry_attrs, lines_attrs)
    end

    test "allows small floating-point rounding within tolerance", ctx do
      entry_attrs = %{
        "company_id" => ctx.company.id,
        "date" => "2024-06-01",
        "description" => "Rounding tolerance test"
      }

      # Difference of 0.005 which is within the 0.01 tolerance
      lines_attrs = [
        %{"account_id" => ctx.cash_acct.id, "debit" => 100.005, "credit" => 0.0},
        %{"account_id" => ctx.revenue_acct.id, "debit" => 0.0, "credit" => 100.0}
      ]

      assert {:ok, _entry} =
               Finance.create_journal_entry_with_lines(entry_attrs, lines_attrs)
    end

    test "rejects difference just outside tolerance", ctx do
      entry_attrs = %{
        "company_id" => ctx.company.id,
        "date" => "2024-06-01",
        "description" => "Outside tolerance test"
      }

      # Difference of 0.02 which exceeds the 0.01 tolerance
      lines_attrs = [
        %{"account_id" => ctx.cash_acct.id, "debit" => 100.02, "credit" => 0.0},
        %{"account_id" => ctx.revenue_acct.id, "debit" => 0.0, "credit" => 100.0}
      ]

      assert {:error, :unbalanced} =
               Finance.create_journal_entry_with_lines(entry_attrs, lines_attrs)
    end

    test "handles more than two lines (compound entry)", ctx do
      entry_attrs = %{
        "company_id" => ctx.company.id,
        "date" => "2024-07-01",
        "description" => "Compound journal entry"
      }

      lines_attrs = [
        %{"account_id" => ctx.cash_acct.id, "debit" => 1000.0, "credit" => 0.0},
        %{"account_id" => ctx.revenue_acct.id, "debit" => 0.0, "credit" => 700.0},
        %{"account_id" => ctx.expense_acct.id, "debit" => 0.0, "credit" => 300.0}
      ]

      assert {:ok, entry} = Finance.create_journal_entry_with_lines(entry_attrs, lines_attrs)
      assert length(entry.lines) == 3

      total_debit = Enum.reduce(entry.lines, 0.0, &(d(&1.debit) + &2))
      total_credit = Enum.reduce(entry.lines, 0.0, &(d(&1.credit) + &2))
      assert abs(total_debit - total_credit) < 0.01
    end

    test "handles string amounts in line attributes", ctx do
      entry_attrs = %{
        "company_id" => ctx.company.id,
        "date" => "2024-08-01",
        "description" => "String amounts test"
      }

      lines_attrs = [
        %{"account_id" => ctx.cash_acct.id, "debit" => "750.0", "credit" => "0.0"},
        %{"account_id" => ctx.revenue_acct.id, "debit" => "0.0", "credit" => "750.0"}
      ]

      assert {:ok, entry} = Finance.create_journal_entry_with_lines(entry_attrs, lines_attrs)
      assert length(entry.lines) == 2
    end

    test "handles integer amounts", ctx do
      entry_attrs = %{
        "company_id" => ctx.company.id,
        "date" => "2024-09-01",
        "description" => "Integer amounts test"
      }

      lines_attrs = [
        %{"account_id" => ctx.cash_acct.id, "debit" => 300, "credit" => 0},
        %{"account_id" => ctx.revenue_acct.id, "debit" => 0, "credit" => 300}
      ]

      assert {:ok, entry} = Finance.create_journal_entry_with_lines(entry_attrs, lines_attrs)
      assert length(entry.lines) == 2
    end

    test "does not persist anything when entry validation fails", ctx do
      entries_before = length(Finance.list_journal_entries(ctx.company.id))

      # Missing required "date" and "description" fields
      entry_attrs = %{"company_id" => ctx.company.id}

      lines_attrs = [
        %{"account_id" => ctx.cash_acct.id, "debit" => 100.0, "credit" => 0.0},
        %{"account_id" => ctx.revenue_acct.id, "debit" => 0.0, "credit" => 100.0}
      ]

      assert {:error, {:entry_error, _changeset}} =
               Finance.create_journal_entry_with_lines(entry_attrs, lines_attrs)

      entries_after = length(Finance.list_journal_entries(ctx.company.id))
      assert entries_before == entries_after
    end

    test "does not persist entry when a line has invalid data", ctx do
      entries_before = length(Finance.list_journal_entries(ctx.company.id))

      entry_attrs = %{
        "company_id" => ctx.company.id,
        "date" => "2024-10-01",
        "description" => "Invalid line test"
      }

      # Second line is missing required account_id
      lines_attrs = [
        %{"account_id" => ctx.cash_acct.id, "debit" => 200.0, "credit" => 0.0},
        %{"debit" => 0.0, "credit" => 200.0}
      ]

      assert {:error, {:line_error, _changeset}} =
               Finance.create_journal_entry_with_lines(entry_attrs, lines_attrs)

      entries_after = length(Finance.list_journal_entries(ctx.company.id))
      assert entries_before == entries_after
    end

    test "each line references the created entry's id", ctx do
      entry_attrs = %{
        "company_id" => ctx.company.id,
        "date" => "2024-11-01",
        "description" => "FK reference test"
      }

      lines_attrs = [
        %{"account_id" => ctx.cash_acct.id, "debit" => 400.0, "credit" => 0.0},
        %{"account_id" => ctx.revenue_acct.id, "debit" => 0.0, "credit" => 400.0}
      ]

      {:ok, entry} = Finance.create_journal_entry_with_lines(entry_attrs, lines_attrs)

      Enum.each(entry.lines, fn line ->
        assert line.entry_id == entry.id
      end)
    end
  end

  # ── Financial reports with data ──────────────────────────────

  describe "trial_balance with journal data" do
    test "reflects debits and credits per account" do
      company = company_fixture()

      {:ok, cash} =
        Finance.create_account(%{
          company_id: company.id,
          name: "Cash",
          account_type: "asset",
          code: "#{System.unique_integer([:positive])}"
        })

      {:ok, rev} =
        Finance.create_account(%{
          company_id: company.id,
          name: "Sales Revenue",
          account_type: "revenue",
          code: "#{System.unique_integer([:positive])}"
        })

      entry_attrs = %{
        "company_id" => company.id,
        "date" => "2024-01-15",
        "description" => "Sale"
      }

      lines_attrs = [
        %{"account_id" => cash.id, "debit" => 5000.0, "credit" => 0.0},
        %{"account_id" => rev.id, "debit" => 0.0, "credit" => 5000.0}
      ]

      {:ok, _entry} = Finance.create_journal_entry_with_lines(entry_attrs, lines_attrs)

      tb = Finance.trial_balance(company.id)
      assert is_list(tb)
      assert length(tb) >= 2

      cash_row = Enum.find(tb, &(&1.id == cash.id))
      assert cash_row != nil
      assert d(cash_row.total_debit) == 5000.0
      assert d(cash_row.total_credit) == 0.0
      assert d(cash_row.balance) == 5000.0

      rev_row = Enum.find(tb, &(&1.id == rev.id))
      assert rev_row != nil
      assert d(rev_row.total_debit) == 0.0
      assert d(rev_row.total_credit) == 5000.0
      assert d(rev_row.balance) == -5000.0
    end

    test "total debits equal total credits across all accounts" do
      company = company_fixture()

      {:ok, cash} =
        Finance.create_account(%{
          company_id: company.id,
          name: "Cash",
          account_type: "asset",
          code: "#{System.unique_integer([:positive])}"
        })

      {:ok, rev} =
        Finance.create_account(%{
          company_id: company.id,
          name: "Revenue",
          account_type: "revenue",
          code: "#{System.unique_integer([:positive])}"
        })

      entry_attrs = %{
        "company_id" => company.id,
        "date" => "2024-02-01",
        "description" => "Balance check"
      }

      lines_attrs = [
        %{"account_id" => cash.id, "debit" => 3000.0, "credit" => 0.0},
        %{"account_id" => rev.id, "debit" => 0.0, "credit" => 3000.0}
      ]

      {:ok, _} = Finance.create_journal_entry_with_lines(entry_attrs, lines_attrs)

      tb = Finance.trial_balance(company.id)
      sum_debit = Enum.reduce(tb, 0.0, &(d(&1.total_debit) + &2))
      sum_credit = Enum.reduce(tb, 0.0, &(d(&1.total_credit) + &2))
      assert abs(sum_debit - sum_credit) < 0.01
    end
  end

  describe "balance_sheet with journal data" do
    test "classifies asset, liability, and equity accounts correctly" do
      company = company_fixture()

      {:ok, cash} =
        Finance.create_account(%{
          company_id: company.id,
          name: "Cash",
          account_type: "asset",
          code: "#{System.unique_integer([:positive])}"
        })

      {:ok, equity} =
        Finance.create_account(%{
          company_id: company.id,
          name: "Retained Earnings",
          account_type: "equity",
          code: "#{System.unique_integer([:positive])}"
        })

      entry_attrs = %{
        "company_id" => company.id,
        "date" => "2024-01-01",
        "description" => "Capital injection"
      }

      lines_attrs = [
        %{"account_id" => cash.id, "debit" => 10_000.0, "credit" => 0.0},
        %{"account_id" => equity.id, "debit" => 0.0, "credit" => 10_000.0}
      ]

      {:ok, _} = Finance.create_journal_entry_with_lines(entry_attrs, lines_attrs)

      bs = Finance.balance_sheet(company.id)

      assert length(bs.assets) >= 1
      assert length(bs.equity) >= 1

      cash_entry = Enum.find(bs.assets, &(&1.id == cash.id))
      assert cash_entry != nil
      assert d(cash_entry.balance) == 10_000.0

      equity_entry = Enum.find(bs.equity, &(&1.id == equity.id))
      assert equity_entry != nil
      assert d(equity_entry.balance) == 10_000.0

      assert d(bs.total_assets) == d(bs.total_liabilities) + d(bs.total_equity)
    end
  end

  describe "income_statement with journal data" do
    test "computes revenue, expenses, and net income" do
      company = company_fixture()

      {:ok, cash} =
        Finance.create_account(%{
          company_id: company.id,
          name: "Cash",
          account_type: "asset",
          code: "#{System.unique_integer([:positive])}"
        })

      {:ok, rev} =
        Finance.create_account(%{
          company_id: company.id,
          name: "Service Revenue",
          account_type: "revenue",
          code: "#{System.unique_integer([:positive])}"
        })

      {:ok, exp} =
        Finance.create_account(%{
          company_id: company.id,
          name: "Salaries Expense",
          account_type: "expense",
          code: "#{System.unique_integer([:positive])}"
        })

      # Revenue entry: debit Cash, credit Revenue
      {:ok, _} =
        Finance.create_journal_entry_with_lines(
          %{"company_id" => company.id, "date" => "2024-06-01", "description" => "Client payment"},
          [
            %{"account_id" => cash.id, "debit" => 8000.0, "credit" => 0.0},
            %{"account_id" => rev.id, "debit" => 0.0, "credit" => 8000.0}
          ]
        )

      # Expense entry: debit Expense, credit Cash
      {:ok, _} =
        Finance.create_journal_entry_with_lines(
          %{"company_id" => company.id, "date" => "2024-06-15", "description" => "Salary payment"},
          [
            %{"account_id" => exp.id, "debit" => 3000.0, "credit" => 0.0},
            %{"account_id" => cash.id, "debit" => 0.0, "credit" => 3000.0}
          ]
        )

      is = Finance.income_statement(company.id, "2024-01-01", "2024-12-31")

      assert d(is.total_revenue) == 8000.0
      assert d(is.total_expenses) == 3000.0
      assert d(is.net_income) == 5000.0

      assert length(is.revenue) == 1
      assert length(is.expenses) == 1
    end

    test "filters by date range" do
      company = company_fixture()

      {:ok, cash} =
        Finance.create_account(%{
          company_id: company.id,
          name: "Cash",
          account_type: "asset",
          code: "#{System.unique_integer([:positive])}"
        })

      {:ok, rev} =
        Finance.create_account(%{
          company_id: company.id,
          name: "Revenue",
          account_type: "revenue",
          code: "#{System.unique_integer([:positive])}"
        })

      # Entry in Q1
      {:ok, _} =
        Finance.create_journal_entry_with_lines(
          %{"company_id" => company.id, "date" => "2024-02-01", "description" => "Q1 sale"},
          [
            %{"account_id" => cash.id, "debit" => 2000.0, "credit" => 0.0},
            %{"account_id" => rev.id, "debit" => 0.0, "credit" => 2000.0}
          ]
        )

      # Entry in Q3
      {:ok, _} =
        Finance.create_journal_entry_with_lines(
          %{"company_id" => company.id, "date" => "2024-08-01", "description" => "Q3 sale"},
          [
            %{"account_id" => cash.id, "debit" => 5000.0, "credit" => 0.0},
            %{"account_id" => rev.id, "debit" => 0.0, "credit" => 5000.0}
          ]
        )

      # Only Q1
      q1_is = Finance.income_statement(company.id, "2024-01-01", "2024-03-31")
      assert d(q1_is.total_revenue) == 2000.0

      # Only Q3
      q3_is = Finance.income_statement(company.id, "2024-07-01", "2024-09-30")
      assert d(q3_is.total_revenue) == 5000.0

      # Full year
      full_is = Finance.income_statement(company.id, "2024-01-01", "2024-12-31")
      assert d(full_is.total_revenue) == 7000.0
    end
  end

  # ── Aggregation functions with data ──────────────────────────

  describe "aggregations with data" do
    test "total_revenue/0 sums all financial records' revenue" do
      company = company_fixture()
      {:ok, _} = Finance.create_financial(%{company_id: company.id, period: "2024-Q1", revenue: 10_000.0, expenses: 5_000.0})
      {:ok, _} = Finance.create_financial(%{company_id: company.id, period: "2024-Q2", revenue: 20_000.0, expenses: 8_000.0})

      total = Finance.total_revenue()
      assert d(total) >= 30_000.0
    end

    test "total_expenses/0 sums all financial records' expenses" do
      company = company_fixture()
      {:ok, _} = Finance.create_financial(%{company_id: company.id, period: "2024-Q1", revenue: 10_000.0, expenses: 5_000.0})
      {:ok, _} = Finance.create_financial(%{company_id: company.id, period: "2024-Q2", revenue: 20_000.0, expenses: 8_000.0})

      total = Finance.total_expenses()
      assert d(total) >= 13_000.0
    end

    test "total_liabilities/0 sums all liability principals" do
      company = company_fixture()
      {:ok, _} = Finance.create_liability(%{company_id: company.id, liability_type: "loan", creditor: "Bank A", principal: 50_000.0})
      {:ok, _} = Finance.create_liability(%{company_id: company.id, liability_type: "bond", creditor: "Bank B", principal: 30_000.0})

      total = Finance.total_liabilities()
      assert d(total) >= 80_000.0
    end
  end
end
