defmodule Holdco.Integration.AccountingCycleTest do
  @moduledoc """
  Integration tests for the full accounting cycle:
  chart of accounts -> journal entries -> trial balance -> period locks ->
  bank reconciliation -> recurring transactions -> financial reports ->
  multi-book accounting.
  """
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Finance
  alias Holdco.Money

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp setup_accounting_company do
    company_fixture(%{name: "Accounting Co", country: "US"})
  end

  defp create_chart_of_accounts(company) do
    {:ok, cash} =
      Finance.create_account(%{
        company_id: company.id,
        name: "Cash",
        account_type: "asset",
        code: "1000-#{System.unique_integer([:positive])}"
      })

    {:ok, ar} =
      Finance.create_account(%{
        company_id: company.id,
        name: "Accounts Receivable",
        account_type: "asset",
        code: "1100-#{System.unique_integer([:positive])}"
      })

    {:ok, revenue} =
      Finance.create_account(%{
        company_id: company.id,
        name: "Revenue",
        account_type: "revenue",
        code: "4000-#{System.unique_integer([:positive])}"
      })

    {:ok, expenses} =
      Finance.create_account(%{
        company_id: company.id,
        name: "Operating Expenses",
        account_type: "expense",
        code: "5000-#{System.unique_integer([:positive])}"
      })

    {:ok, liabilities} =
      Finance.create_account(%{
        company_id: company.id,
        name: "Accounts Payable",
        account_type: "liability",
        code: "2000-#{System.unique_integer([:positive])}"
      })

    {:ok, equity} =
      Finance.create_account(%{
        company_id: company.id,
        name: "Retained Earnings",
        account_type: "equity",
        code: "3000-#{System.unique_integer([:positive])}"
      })

    %{
      cash: cash,
      ar: ar,
      revenue: revenue,
      expenses: expenses,
      liabilities: liabilities,
      equity: equity
    }
  end

  # ===========================================================================
  # 1. Chart of Accounts + Journal Entries
  # ===========================================================================

  describe "chart of accounts and journal entries" do
    test "create accounts and post balanced journal entries" do
      company = setup_accounting_company()
      accounts = create_chart_of_accounts(company)

      {:ok, je} =
        Finance.create_journal_entry(%{
          company_id: company.id,
          date: "2025-03-15",
          description: "Sale to customer"
        })

      {:ok, _debit} =
        Finance.create_journal_line(%{
          entry_id: je.id,
          account_id: accounts.ar.id,
          debit: 10_000.0
        })

      {:ok, _credit} =
        Finance.create_journal_line(%{
          entry_id: je.id,
          account_id: accounts.revenue.id,
          credit: 10_000.0
        })

      lines = Finance.list_journal_lines(je.id)
      assert length(lines) == 2

      total_debits = Enum.reduce(lines, Decimal.new(0), &Decimal.add(&2, &1.debit || Decimal.new(0)))
      total_credits = Enum.reduce(lines, Decimal.new(0), &Decimal.add(&2, &1.credit || Decimal.new(0)))
      assert Decimal.equal?(total_debits, total_credits)
    end

    test "create_journal_entry_with_lines atomically creates entry and lines" do
      company = setup_accounting_company()
      accounts = create_chart_of_accounts(company)

      {:ok, je} =
        Finance.create_journal_entry_with_lines(
          %{
            company_id: company.id,
            date: "2025-04-01",
            description: "Rent payment"
          },
          [
            %{"account_id" => accounts.expenses.id, "debit" => 5000.0},
            %{"account_id" => accounts.cash.id, "credit" => 5000.0}
          ]
        )

      entry = Finance.get_journal_entry!(je.id)
      assert length(entry.lines) == 2
    end

    test "multiple journal entries maintain running balances in trial balance" do
      company = setup_accounting_company()
      accounts = create_chart_of_accounts(company)

      {:ok, _} =
        Finance.create_journal_entry_with_lines(
          %{company_id: company.id, date: "2025-01-01", description: "Capital contribution"},
          [
            %{"account_id" => accounts.cash.id, "debit" => 100_000.0},
            %{"account_id" => accounts.equity.id, "credit" => 100_000.0}
          ]
        )

      {:ok, _} =
        Finance.create_journal_entry_with_lines(
          %{company_id: company.id, date: "2025-02-01", description: "Service revenue"},
          [
            %{"account_id" => accounts.ar.id, "debit" => 25_000.0},
            %{"account_id" => accounts.revenue.id, "credit" => 25_000.0}
          ]
        )

      {:ok, _} =
        Finance.create_journal_entry_with_lines(
          %{company_id: company.id, date: "2025-02-15", description: "Office rent"},
          [
            %{"account_id" => accounts.expenses.id, "debit" => 5_000.0},
            %{"account_id" => accounts.cash.id, "credit" => 5_000.0}
          ]
        )

      trial = Finance.trial_balance(company.id)
      assert is_list(trial)
      assert length(trial) > 0

      total_debits = Enum.reduce(trial, Decimal.new(0), fn row, acc -> Decimal.add(acc, Money.to_decimal(row.total_debit)) end)
      total_credits = Enum.reduce(trial, Decimal.new(0), fn row, acc -> Decimal.add(acc, Money.to_decimal(row.total_credit)) end)
      assert Decimal.equal?(total_debits, total_credits)
    end
  end

  # ===========================================================================
  # 2. Period Locking
  # ===========================================================================

  describe "period locking" do
    test "lock period and verify it is detected as locked" do
      company = setup_accounting_company()
      user = Holdco.AccountsFixtures.user_fixture()

      {:ok, lock} =
        Finance.lock_period(company.id, ~D[2025-01-01], ~D[2025-03-31], "quarter", user.id)

      assert lock.status == "locked"
      assert lock.locked_by_id == user.id
      assert Finance.is_period_locked?(company.id, ~D[2025-02-15])
      refute Finance.is_period_locked?(company.id, ~D[2025-04-15])
    end

    test "unlock period with reason" do
      company = setup_accounting_company()
      user = Holdco.AccountsFixtures.user_fixture()

      {:ok, lock} =
        Finance.lock_period(company.id, ~D[2025-01-01], ~D[2025-03-31], "quarter", user.id)

      assert Finance.is_period_locked?(company.id, ~D[2025-02-15])

      {:ok, unlocked} =
        Finance.unlock_period(lock.id, user.id, "Correction needed for Q1 entries")

      assert unlocked.status == "unlocked"
      assert unlocked.unlocked_by_id == user.id
      assert unlocked.unlock_reason == "Correction needed for Q1 entries"
      refute Finance.is_period_locked?(company.id, ~D[2025-02-15])
    end

    test "multiple period locks for different periods" do
      company = setup_accounting_company()
      user = Holdco.AccountsFixtures.user_fixture()

      {:ok, _q1} = Finance.lock_period(company.id, ~D[2025-01-01], ~D[2025-03-31], "quarter", user.id)
      {:ok, _q2} = Finance.lock_period(company.id, ~D[2025-04-01], ~D[2025-06-30], "quarter", user.id)

      assert Finance.is_period_locked?(company.id, ~D[2025-02-15])
      assert Finance.is_period_locked?(company.id, ~D[2025-05-15])
      refute Finance.is_period_locked?(company.id, ~D[2025-07-15])

      locks = Finance.list_period_locks(company.id)
      assert length(locks) == 2
    end

    test "period lock prevents detecting date outside range as locked" do
      company = setup_accounting_company()
      user = Holdco.AccountsFixtures.user_fixture()

      {:ok, _} = Finance.lock_period(company.id, ~D[2025-01-01], ~D[2025-01-31], "month", user.id)

      assert Finance.is_period_locked?(company.id, ~D[2025-01-15])
      assert Finance.is_period_locked?(company.id, ~D[2025-01-01])
      assert Finance.is_period_locked?(company.id, ~D[2025-01-31])
      refute Finance.is_period_locked?(company.id, ~D[2024-12-31])
      refute Finance.is_period_locked?(company.id, ~D[2025-02-01])
    end

    test "lock, unlock, and re-lock workflow" do
      company = setup_accounting_company()
      user = Holdco.AccountsFixtures.user_fixture()

      {:ok, lock} = Finance.lock_period(company.id, ~D[2025-01-01], ~D[2025-03-31], "quarter", user.id)
      assert Finance.is_period_locked?(company.id, ~D[2025-02-01])

      {:ok, _} = Finance.unlock_period(lock.id, user.id, "Need adjustments")
      refute Finance.is_period_locked?(company.id, ~D[2025-02-01])

      {:ok, _relock} = Finance.lock_period(company.id, ~D[2025-01-01], ~D[2025-03-31], "quarter", user.id)
      assert Finance.is_period_locked?(company.id, ~D[2025-02-01])
    end

    test "create_journal_entry_with_lines rejects entries in locked periods" do
      company = setup_accounting_company()
      accounts = create_chart_of_accounts(company)
      user = Holdco.AccountsFixtures.user_fixture()

      {:ok, _} = Finance.lock_period(company.id, ~D[2025-01-01], ~D[2025-03-31], "quarter", user.id)

      result =
        Finance.create_journal_entry_with_lines(
          %{company_id: company.id, date: "2025-02-15", description: "Locked period entry"},
          [
            %{"account_id" => accounts.cash.id, "debit" => 1000.0},
            %{"account_id" => accounts.equity.id, "credit" => 1000.0}
          ]
        )

      assert result == {:error, :period_locked}
    end
  end

  # ===========================================================================
  # 3. Recurring Transactions
  # ===========================================================================

  describe "recurring transactions" do
    test "create recurring transaction and advance next run date" do
      company = setup_accounting_company()

      {:ok, rt} =
        Finance.create_recurring_transaction(%{
          company_id: company.id,
          description: "Monthly rent payment",
          amount: 5_000.0,
          frequency: "monthly",
          start_date: "2025-01-01",
          next_run_date: "2025-01-01",
          transaction_type: "expense",
          counterparty: "Landlord Corp"
        })

      assert rt.is_active == true
      assert rt.next_run_date == "2025-01-01"

      {:ok, advanced} = Finance.advance_next_run_date(rt)
      assert advanced.last_run_date == "2025-01-01"
      next = Date.from_iso8601!(advanced.next_run_date)
      assert Date.diff(next, ~D[2025-01-01]) == 30
    end

    test "recurring transaction deactivates when end_date passed" do
      company = setup_accounting_company()

      {:ok, rt} =
        Finance.create_recurring_transaction(%{
          company_id: company.id,
          description: "Temporary subscription",
          amount: 100.0,
          frequency: "monthly",
          start_date: "2025-01-01",
          next_run_date: "2025-02-01",
          end_date: "2025-02-15"
        })

      assert rt.is_active == true
      {:ok, advanced} = Finance.advance_next_run_date(rt)
      assert advanced.is_active == false
    end

    test "list_due_recurring_transactions returns only active due items" do
      company = setup_accounting_company()

      {:ok, _due} =
        Finance.create_recurring_transaction(%{
          company_id: company.id,
          description: "Due today",
          amount: 100.0,
          frequency: "monthly",
          start_date: "2025-01-01",
          next_run_date: Date.utc_today() |> Date.to_iso8601()
        })

      {:ok, _future} =
        Finance.create_recurring_transaction(%{
          company_id: company.id,
          description: "Future payment",
          amount: 200.0,
          frequency: "monthly",
          start_date: "2025-01-01",
          next_run_date: Date.add(Date.utc_today(), 30) |> Date.to_iso8601()
        })

      due = Finance.list_due_recurring_transactions()
      assert Enum.any?(due, &(&1.description == "Due today"))
      refute Enum.any?(due, &(&1.description == "Future payment"))
    end

    test "all recurring transaction frequencies are valid" do
      company = setup_accounting_company()

      for freq <- ~w(daily weekly monthly quarterly yearly) do
        {:ok, rt} =
          Finance.create_recurring_transaction(%{
            company_id: company.id,
            description: "Frequency test #{freq}",
            amount: 100.0,
            frequency: freq,
            start_date: "2025-01-01",
            next_run_date: "2025-01-01"
          })

        assert rt.frequency == freq
      end
    end

    test "advance_next_run_date correctly calculates next date for each frequency" do
      company = setup_accounting_company()

      expected = %{
        "daily" => 1,
        "weekly" => 7,
        "monthly" => 30,
        "quarterly" => 91,
        "yearly" => 365
      }

      for {freq, days} <- expected do
        {:ok, rt} =
          Finance.create_recurring_transaction(%{
            company_id: company.id,
            description: "#{freq} advance test",
            amount: 100.0,
            frequency: freq,
            start_date: "2025-06-01",
            next_run_date: "2025-06-01"
          })

        {:ok, advanced} = Finance.advance_next_run_date(rt)
        next = Date.from_iso8601!(advanced.next_run_date)
        assert Date.diff(next, ~D[2025-06-01]) == days
      end
    end
  end

  # ===========================================================================
  # 4. Financial Statements
  # ===========================================================================

  describe "financial statements" do
    test "balance sheet groups accounts by type" do
      company = setup_accounting_company()
      accounts = create_chart_of_accounts(company)

      {:ok, _} =
        Finance.create_journal_entry_with_lines(
          %{company_id: company.id, date: "2025-03-31", description: "Year-end balances"},
          [
            %{"account_id" => accounts.cash.id, "debit" => 200_000.0},
            %{"account_id" => accounts.equity.id, "credit" => 200_000.0}
          ]
        )

      bs = Finance.balance_sheet(company.id)
      assert Map.has_key?(bs, :assets)
      assert Map.has_key?(bs, :liabilities)
      assert Map.has_key?(bs, :equity)
    end

    test "income statement shows revenue and expenses" do
      company = setup_accounting_company()
      accounts = create_chart_of_accounts(company)

      {:ok, _} =
        Finance.create_journal_entry_with_lines(
          %{company_id: company.id, date: "2025-06-15", description: "Revenue recognized"},
          [
            %{"account_id" => accounts.ar.id, "debit" => 50_000.0},
            %{"account_id" => accounts.revenue.id, "credit" => 50_000.0}
          ]
        )

      {:ok, _} =
        Finance.create_journal_entry_with_lines(
          %{company_id: company.id, date: "2025-06-20", description: "Expenses incurred"},
          [
            %{"account_id" => accounts.expenses.id, "debit" => 20_000.0},
            %{"account_id" => accounts.cash.id, "credit" => 20_000.0}
          ]
        )

      is_result = Finance.income_statement(company.id)
      assert Map.has_key?(is_result, :revenue)
      assert Map.has_key?(is_result, :expenses)
      assert Map.has_key?(is_result, :net_income)
    end

    test "financials CRUD tracks company financial periods" do
      company = setup_accounting_company()

      {:ok, _q1} =
        Finance.create_financial(%{
          company_id: company.id,
          period: "2025-Q1",
          revenue: 500_000.0,
          expenses: 300_000.0
        })

      {:ok, _q2} =
        Finance.create_financial(%{
          company_id: company.id,
          period: "2025-Q2",
          revenue: 600_000.0,
          expenses: 350_000.0
        })

      financials = Finance.list_financials(company.id)
      assert length(financials) == 2
      periods = Enum.map(financials, & &1.period)
      assert "2025-Q1" in periods
      assert "2025-Q2" in periods
    end
  end

  # ===========================================================================
  # 5. Inter-Company Transfers
  # ===========================================================================

  describe "inter-company transfers" do
    test "transfer between two companies" do
      from_co = company_fixture(%{name: "Parent Corp"})
      to_co = company_fixture(%{name: "Subsidiary Corp"})

      {:ok, transfer} =
        Finance.create_inter_company_transfer(%{
          from_company_id: from_co.id,
          to_company_id: to_co.id,
          amount: 250_000.0,
          date: "2025-03-01",
          description: "Management fee allocation"
        })

      assert transfer.from_company_id == from_co.id
      assert transfer.to_company_id == to_co.id
      assert Decimal.equal?(transfer.amount, Decimal.from_float(250_000.0))
    end

    test "inter-company transfers are listed correctly" do
      from_co = company_fixture(%{name: "Parent"})
      to_co = company_fixture(%{name: "Sub"})

      {:ok, _} =
        Finance.create_inter_company_transfer(%{
          from_company_id: from_co.id,
          to_company_id: to_co.id,
          amount: 100_000.0,
          date: "2025-01-01"
        })

      {:ok, _} =
        Finance.create_inter_company_transfer(%{
          from_company_id: to_co.id,
          to_company_id: from_co.id,
          amount: 50_000.0,
          date: "2025-06-01"
        })

      transfers = Finance.list_inter_company_transfers()
      assert length(transfers) >= 2
    end
  end

  # ===========================================================================
  # 6. Multi-Book Accounting
  # ===========================================================================

  describe "multi-book accounting" do
    test "create accounting books with adjustments" do
      company = setup_accounting_company()

      {:ok, tax_book} =
        Finance.create_accounting_book(%{
          company_id: company.id,
          name: "Tax Book",
          book_type: "tax"
        })

      {:ok, gaap_book} =
        Finance.create_accounting_book(%{
          company_id: company.id,
          name: "GAAP Book",
          book_type: "us_gaap"
        })

      assert tax_book.book_type == "tax"
      assert gaap_book.book_type == "us_gaap"

      accounts = create_chart_of_accounts(company)

      {:ok, adj} =
        Finance.create_book_adjustment(%{
          book_id: tax_book.id,
          adjustment_type: "reclassification",
          description: "Depreciation difference",
          amount: 10_000.0,
          effective_date: "2025-12-31",
          debit_account_id: accounts.expenses.id,
          credit_account_id: accounts.cash.id
        })

      assert adj.description == "Depreciation difference"

      adjs = Finance.list_book_adjustments(tax_book.id)
      assert length(adjs) >= 1
    end
  end

  # ===========================================================================
  # 7. Cross-Context Accounting Flow
  # ===========================================================================

  describe "cross-context accounting flow" do
    test "full cycle: create accounts -> post entries -> lock period -> verify locked -> report" do
      company = setup_accounting_company()
      accounts = create_chart_of_accounts(company)
      user = Holdco.AccountsFixtures.user_fixture()

      {:ok, _} =
        Finance.create_journal_entry_with_lines(
          %{company_id: company.id, date: "2025-01-15", description: "Initial funding"},
          [
            %{"account_id" => accounts.cash.id, "debit" => 1_000_000.0},
            %{"account_id" => accounts.equity.id, "credit" => 1_000_000.0}
          ]
        )

      {:ok, _} =
        Finance.create_journal_entry_with_lines(
          %{company_id: company.id, date: "2025-03-01", description: "Q1 Revenue"},
          [
            %{"account_id" => accounts.ar.id, "debit" => 100_000.0},
            %{"account_id" => accounts.revenue.id, "credit" => 100_000.0}
          ]
        )

      trial = Finance.trial_balance(company.id)
      assert length(trial) > 0

      {:ok, _lock} = Finance.lock_period(company.id, ~D[2025-01-01], ~D[2025-03-31], "quarter", user.id)
      assert Finance.is_period_locked?(company.id, ~D[2025-02-15])
      refute Finance.is_period_locked?(company.id, ~D[2025-04-15])

      {:ok, _} =
        Finance.create_journal_entry_with_lines(
          %{company_id: company.id, date: "2025-04-15", description: "Q2 Revenue"},
          [
            %{"account_id" => accounts.ar.id, "debit" => 80_000.0},
            %{"account_id" => accounts.revenue.id, "credit" => 80_000.0}
          ]
        )

      bs = Finance.balance_sheet(company.id)
      assert Map.has_key?(bs, :assets)
    end

    test "dividends, contributions, and tax payments form complete capital flow" do
      company = setup_accounting_company()

      {:ok, _contrib} =
        Finance.create_capital_contribution(%{
          company_id: company.id,
          contributor: "Founder",
          amount: 500_000.0,
          date: "2025-01-01"
        })

      {:ok, _div} =
        Finance.create_dividend(%{
          company_id: company.id,
          amount: 50_000.0,
          date: "2025-06-15"
        })

      {:ok, _tax} =
        Finance.create_tax_payment(%{
          company_id: company.id,
          jurisdiction: "US",
          tax_type: "income",
          amount: 25_000.0,
          date: "2025-04-15"
        })

      contributions = Finance.list_capital_contributions(company.id)
      dividends = Finance.list_dividends(company.id)
      tax_payments = Finance.list_tax_payments(company.id)

      assert length(contributions) >= 1
      assert length(dividends) >= 1
      assert length(tax_payments) >= 1
    end

    test "liabilities and budgets linked to same company" do
      company = setup_accounting_company()

      {:ok, liability} =
        Finance.create_liability(%{
          company_id: company.id,
          liability_type: "loan",
          creditor: "Big Bank",
          principal: 1_000_000.0,
          status: "active"
        })

      {:ok, budget} =
        Finance.create_budget(%{
          company_id: company.id,
          period: "2025",
          category: "Operations",
          budgeted_amount: 500_000.0
        })

      liabilities = Finance.list_liabilities(company.id)
      budgets = Finance.list_budgets(company.id)

      assert Enum.any?(liabilities, &(&1.id == liability.id))
      assert Enum.any?(budgets, &(&1.id == budget.id))
    end
  end

end
