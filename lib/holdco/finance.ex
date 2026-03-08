defmodule Holdco.Finance do
  import Ecto.Query
  alias Holdco.Repo
  alias Holdco.Money

  alias Holdco.Finance.{
    Financial,
    Account,
    JournalEntry,
    JournalLine,
    InterCompanyTransfer,
    Dividend,
    CapitalContribution,
    TaxPayment,
    Budget,
    Liability,
    Segment,
    Lease,
    PeriodLock,
    RecurringTransaction
  }

  alias Holdco.Fund.{AccountingBook, BookAdjustment}

  # Financials
  def list_financials(company_id \\ nil) do
    query = from(f in Financial, order_by: [desc: f.period], preload: [:company])
    query = if company_id, do: where(query, [f], f.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_financial!(id), do: Repo.get!(Financial, id) |> Repo.preload(:company)

  def create_financial(attrs) do
    %Financial{}
    |> Financial.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("financials", "create")
  end

  def update_financial(%Financial{} = f, attrs) do
    f
    |> Financial.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("financials", "update")
  end

  def delete_financial(%Financial{} = f) do
    Repo.delete(f)
    |> audit_and_broadcast("financials", "delete")
  end

  # Accounts (Chart of Accounts)
  def list_accounts(company_id \\ nil) do
    query = from(a in Account, order_by: a.code, preload: [:parent, :children, :company])
    query = if company_id, do: where(query, [a], a.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_account!(id), do: Repo.get!(Account, id) |> Repo.preload([:parent, :children])

  def create_account(attrs) do
    %Account{}
    |> Account.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("accounts", "create")
  end

  def update_account(%Account{} = a, attrs) do
    a
    |> Account.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("accounts", "update")
  end

  def delete_account(%Account{} = a) do
    Repo.delete(a)
    |> audit_and_broadcast("accounts", "delete")
  end

  # Journal Entries
  def list_journal_entries(company_id \\ nil) do
    query = from(je in JournalEntry, order_by: [desc: je.date], preload: [:company, lines: :account])
    query = if company_id, do: where(query, [je], je.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_journal_entry!(id), do: Repo.get!(JournalEntry, id) |> Repo.preload(lines: :account)

  def create_journal_entry(attrs) do
    company_id = attrs[:company_id] || attrs["company_id"]
    date = attrs[:date] || attrs["date"]

    if company_id && date && is_period_locked?(company_id, date) do
      {:error, :period_locked}
    else
      %JournalEntry{}
      |> JournalEntry.changeset(attrs)
      |> Repo.insert()
      |> audit_and_broadcast("journal_entries", "create")
    end
  end

  @doc """
  Creates a journal entry with its lines atomically in a single transaction.
  Validates that debits equal credits before inserting.
  Returns {:ok, entry_with_lines} or {:error, reason}.
  """
  def create_journal_entry_with_lines(entry_attrs, lines_attrs) when is_list(lines_attrs) do
    company_id = entry_attrs[:company_id] || entry_attrs["company_id"]
    date = entry_attrs[:date] || entry_attrs["date"]

    if company_id && date && is_period_locked?(company_id, date) do
      {:error, :period_locked}
    else
      create_journal_entry_with_lines_inner(entry_attrs, lines_attrs)
    end
  end

  defp create_journal_entry_with_lines_inner(entry_attrs, lines_attrs) do
    total_debit = Enum.reduce(lines_attrs, Decimal.new(0), fn l, acc -> Money.add(acc, parse_line_amount(l, "debit")) end)
    total_credit = Enum.reduce(lines_attrs, Decimal.new(0), fn l, acc -> Money.add(acc, parse_line_amount(l, "credit")) end)

    cond do
      length(lines_attrs) < 2 ->
        {:error, :insufficient_lines}

      Money.gt?(Money.abs(Money.sub(total_debit, total_credit)), "0.01") ->
        {:error, :unbalanced}

      true ->
        Repo.transaction(fn ->
          case %JournalEntry{} |> JournalEntry.changeset(entry_attrs) |> Repo.insert() do
            {:ok, entry} ->
              lines =
                Enum.map(lines_attrs, fn l ->
                  line_attrs = Map.put(l, "entry_id", entry.id)

                  case %JournalLine{} |> JournalLine.changeset(line_attrs) |> Repo.insert() do
                    {:ok, line} -> line
                    {:error, changeset} -> Repo.rollback({:line_error, changeset})
                  end
                end)

              Holdco.Platform.log_action("create", "journal_entries", entry.id)
              broadcast({:journal_entries_created, entry})
              %{entry | lines: lines}

            {:error, changeset} ->
              Repo.rollback({:entry_error, changeset})
          end
        end)
    end
  end

  defp parse_line_amount(attrs, key) do
    val = Map.get(attrs, key) || Map.get(attrs, String.to_atom(key))
    Money.to_decimal(val)
  end

  def update_journal_entry(%JournalEntry{} = je, attrs) do
    if je.company_id && je.date && is_period_locked?(je.company_id, je.date) do
      {:error, :period_locked}
    else
      je
      |> JournalEntry.changeset(attrs)
      |> Repo.update()
      |> audit_and_broadcast("journal_entries", "update")
    end
  end

  def delete_journal_entry(%JournalEntry{} = je) do
    if je.company_id && je.date && is_period_locked?(je.company_id, je.date) do
      {:error, :period_locked}
    else
      Repo.delete(je)
      |> audit_and_broadcast("journal_entries", "delete")
    end
  end

  # Journal Lines
  def list_journal_lines(entry_id) do
    from(jl in JournalLine, where: jl.entry_id == ^entry_id, preload: [:account])
    |> Repo.all()
  end

  def get_journal_line!(id), do: Repo.get!(JournalLine, id) |> Repo.preload(:account)

  def create_journal_line(attrs) do
    %JournalLine{}
    |> JournalLine.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("journal_lines", "create")
  end

  def update_journal_line(%JournalLine{} = jl, attrs) do
    jl
    |> JournalLine.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("journal_lines", "update")
  end

  def delete_journal_line(%JournalLine{} = jl) do
    Repo.delete(jl)
    |> audit_and_broadcast("journal_lines", "delete")
  end

  # Inter-Company Transfers
  def list_inter_company_transfers do
    from(ict in InterCompanyTransfer,
      order_by: [desc: ict.date],
      preload: [:from_company, :to_company]
    )
    |> Repo.all()
  end

  def get_inter_company_transfer!(id) do
    Repo.get!(InterCompanyTransfer, id) |> Repo.preload([:from_company, :to_company])
  end

  def create_inter_company_transfer(attrs) do
    %InterCompanyTransfer{}
    |> InterCompanyTransfer.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("inter_company_transfers", "create")
  end

  def update_inter_company_transfer(%InterCompanyTransfer{} = ict, attrs) do
    ict
    |> InterCompanyTransfer.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("inter_company_transfers", "update")
  end

  def delete_inter_company_transfer(%InterCompanyTransfer{} = ict) do
    Repo.delete(ict)
    |> audit_and_broadcast("inter_company_transfers", "delete")
  end

  # Dividends
  def list_dividends(company_id \\ nil) do
    query = from(d in Dividend, order_by: [desc: d.date], preload: [:company])
    query = if company_id, do: where(query, [d], d.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_dividend!(id), do: Repo.get!(Dividend, id) |> Repo.preload(:company)

  def create_dividend(attrs) do
    %Dividend{}
    |> Dividend.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("dividends", "create")
  end

  def update_dividend(%Dividend{} = d, attrs) do
    d
    |> Dividend.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("dividends", "update")
  end

  def delete_dividend(%Dividend{} = d) do
    Repo.delete(d)
    |> audit_and_broadcast("dividends", "delete")
  end

  # Capital Contributions
  def list_capital_contributions(company_id \\ nil) do
    query = from(cc in CapitalContribution, order_by: [desc: cc.date], preload: [:company])
    query = if company_id, do: where(query, [cc], cc.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_capital_contribution!(id),
    do: Repo.get!(CapitalContribution, id) |> Repo.preload(:company)

  def create_capital_contribution(attrs) do
    %CapitalContribution{}
    |> CapitalContribution.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("capital_contributions", "create")
  end

  def update_capital_contribution(%CapitalContribution{} = cc, attrs) do
    cc
    |> CapitalContribution.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("capital_contributions", "update")
  end

  def delete_capital_contribution(%CapitalContribution{} = cc) do
    Repo.delete(cc)
    |> audit_and_broadcast("capital_contributions", "delete")
  end

  # Tax Payments
  def list_tax_payments(company_id \\ nil) do
    query = from(tp in TaxPayment, order_by: [desc: tp.date], preload: [:company])
    query = if company_id, do: where(query, [tp], tp.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_tax_payment!(id), do: Repo.get!(TaxPayment, id) |> Repo.preload(:company)

  def create_tax_payment(attrs) do
    %TaxPayment{}
    |> TaxPayment.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("tax_payments", "create")
  end

  def update_tax_payment(%TaxPayment{} = tp, attrs) do
    tp
    |> TaxPayment.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("tax_payments", "update")
  end

  def delete_tax_payment(%TaxPayment{} = tp) do
    Repo.delete(tp)
    |> audit_and_broadcast("tax_payments", "delete")
  end

  # Budgets
  def list_budgets(company_id \\ nil) do
    query = from(b in Budget, order_by: [desc: b.period], preload: [:company])
    query = if company_id, do: where(query, [b], b.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_budget!(id), do: Repo.get!(Budget, id) |> Repo.preload(:company)

  def create_budget(attrs) do
    %Budget{}
    |> Budget.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("budgets", "create")
  end

  def update_budget(%Budget{} = b, attrs) do
    b
    |> Budget.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("budgets", "update")
  end

  def delete_budget(%Budget{} = b) do
    Repo.delete(b)
    |> audit_and_broadcast("budgets", "delete")
  end

  # Liabilities
  def list_liabilities(company_id \\ nil) do
    query = from(l in Liability, order_by: l.creditor, preload: [:company])
    query = if company_id, do: where(query, [l], l.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_liability!(id), do: Repo.get!(Liability, id) |> Repo.preload(:company)

  def create_liability(attrs) do
    %Liability{}
    |> Liability.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("liabilities", "create")
  end

  def update_liability(%Liability{} = l, attrs) do
    l
    |> Liability.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("liabilities", "update")
  end

  def delete_liability(%Liability{} = l) do
    Repo.delete(l)
    |> audit_and_broadcast("liabilities", "delete")
  end

  # Report Queries

  def trial_balance(company_id \\ nil) do
    query =
      from(a in Account,
        left_join: jl in JournalLine,
        on: jl.account_id == a.id,
        group_by: [a.id, a.name, a.code, a.account_type],
        select: %{
          id: a.id,
          name: a.name,
          code: a.code,
          account_type: a.account_type,
          total_debit: coalesce(sum(jl.debit), 0.0),
          total_credit: coalesce(sum(jl.credit), 0.0),
          balance: coalesce(sum(jl.debit), 0.0) - coalesce(sum(jl.credit), 0.0)
        },
        order_by: a.code
      )

    query = if company_id, do: where(query, [a], a.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def balance_sheet(company_id \\ nil) do
    accounts = trial_balance(company_id)

    assets =
      accounts
      |> Enum.filter(&(&1.account_type == "asset"))
      |> Enum.map(&Map.put(&1, :balance, Money.sub(&1.total_debit, &1.total_credit)))

    liabilities =
      accounts
      |> Enum.filter(&(&1.account_type == "liability"))
      |> Enum.map(&Map.put(&1, :balance, Money.sub(&1.total_credit, &1.total_debit)))

    equity =
      accounts
      |> Enum.filter(&(&1.account_type == "equity"))
      |> Enum.map(&Map.put(&1, :balance, Money.sub(&1.total_credit, &1.total_debit)))

    total_assets = Enum.reduce(assets, Decimal.new(0), &Money.add(&1.balance, &2))
    total_liabilities = Enum.reduce(liabilities, Decimal.new(0), &Money.add(&1.balance, &2))
    total_equity = Enum.reduce(equity, Decimal.new(0), &Money.add(&1.balance, &2))

    %{
      assets: assets,
      liabilities: liabilities,
      equity: equity,
      total_assets: total_assets,
      total_liabilities: total_liabilities,
      total_equity: total_equity
    }
  end

  def income_statement(company_id \\ nil, date_from \\ nil, date_to \\ nil) do
    base_query =
      from(jl in JournalLine,
        join: a in Account,
        on: jl.account_id == a.id,
        join: je in JournalEntry,
        on: jl.entry_id == je.id
      )

    base_query =
      if company_id,
        do: where(base_query, [_jl, a, _je], a.company_id == ^company_id),
        else: base_query

    base_query =
      if date_from,
        do: where(base_query, [_jl, _a, je], je.date >= ^date_from),
        else: base_query

    base_query =
      if date_to,
        do: where(base_query, [_jl, _a, je], je.date <= ^date_to),
        else: base_query

    revenue_query =
      base_query
      |> where([_jl, a, _je], a.account_type == "revenue")
      |> group_by([_jl, a, _je], [a.id, a.name, a.code])
      |> select([jl, a, _je], %{
        id: a.id,
        name: a.name,
        code: a.code,
        amount: coalesce(sum(jl.credit), 0.0) - coalesce(sum(jl.debit), 0.0)
      })
      |> order_by([_jl, a, _je], a.code)

    expense_query =
      base_query
      |> where([_jl, a, _je], a.account_type == "expense")
      |> group_by([_jl, a, _je], [a.id, a.name, a.code])
      |> select([jl, a, _je], %{
        id: a.id,
        name: a.name,
        code: a.code,
        amount: coalesce(sum(jl.debit), 0.0) - coalesce(sum(jl.credit), 0.0)
      })
      |> order_by([_jl, a, _je], a.code)

    revenue = Repo.all(revenue_query)
    expenses = Repo.all(expense_query)
    total_revenue = Enum.reduce(revenue, Decimal.new(0), &Money.add(&1.amount, &2))
    total_expenses = Enum.reduce(expenses, Decimal.new(0), &Money.add(&1.amount, &2))

    %{
      revenue: revenue,
      expenses: expenses,
      total_revenue: total_revenue,
      total_expenses: total_expenses,
      net_income: Money.sub(total_revenue, total_expenses)
    }
  end

  # Aggregations
  def total_revenue do
    Repo.one(from f in Financial, select: sum(f.revenue)) || Decimal.new(0)
  end

  def total_expenses do
    Repo.one(from f in Financial, select: sum(f.expenses)) || Decimal.new(0)
  end

  def total_liabilities do
    Repo.one(from l in Liability, select: sum(l.principal)) || Decimal.new(0)
  end

  # Segments
  def list_segments(company_id \\ nil) do
    query = from(s in Segment, order_by: s.name, preload: [:company])
    query = if company_id, do: where(query, [s], s.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_segment!(id), do: Repo.get!(Segment, id) |> Repo.preload(:company)

  def create_segment(attrs) do
    %Segment{}
    |> Segment.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("segments", "create")
  end

  def update_segment(%Segment{} = s, attrs) do
    s
    |> Segment.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("segments", "update")
  end

  def delete_segment(%Segment{} = s) do
    Repo.delete(s)
    |> audit_and_broadcast("segments", "delete")
  end

  # Leases
  def list_leases(company_id \\ nil) do
    query = from(l in Lease, order_by: l.lessor, preload: [:company])
    query = if company_id, do: where(query, [l], l.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_lease!(id), do: Repo.get!(Lease, id) |> Repo.preload(:company)

  def create_lease(attrs) do
    %Lease{}
    |> Lease.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("leases", "create")
  end

  def update_lease(%Lease{} = l, attrs) do
    l
    |> Lease.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("leases", "update")
  end

  def delete_lease(%Lease{} = l) do
    Repo.delete(l)
    |> audit_and_broadcast("leases", "delete")
  end

  # Segment-filtered trial balance
  def trial_balance_by_segment(segment_id) do
    from(a in Account,
      left_join: jl in JournalLine,
      on: jl.account_id == a.id,
      where: jl.segment_id == ^segment_id or a.segment_id == ^segment_id,
      group_by: [a.id, a.name, a.code, a.account_type],
      select: %{
        id: a.id,
        name: a.name,
        code: a.code,
        account_type: a.account_type,
        total_debit: coalesce(sum(jl.debit), 0.0),
        total_credit: coalesce(sum(jl.credit), 0.0),
        balance: coalesce(sum(jl.debit), 0.0) - coalesce(sum(jl.credit), 0.0)
      },
      order_by: a.code
    )
    |> Repo.all()
  end

  # Period Locks
  def list_period_locks(company_id \\ nil) do
    query = from(pl in PeriodLock, order_by: [desc: pl.period_start], preload: [:company])
    query = if company_id, do: where(query, [pl], pl.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_period_lock!(id), do: Repo.get!(PeriodLock, id) |> Repo.preload(:company)

  def lock_period(company_id, period_start, period_end, period_type, user_id) do
    %PeriodLock{}
    |> PeriodLock.changeset(%{
      company_id: company_id,
      period_start: period_start,
      period_end: period_end,
      period_type: period_type,
      status: "locked",
      locked_at: DateTime.utc_now() |> DateTime.truncate(:second),
      locked_by_id: user_id
    })
    |> Repo.insert()
    |> audit_and_broadcast("period_locks", "create")
  end

  def unlock_period(period_lock_id, user_id, reason) do
    lock = get_period_lock!(period_lock_id)

    lock
    |> PeriodLock.changeset(%{
      status: "unlocked",
      unlocked_at: DateTime.utc_now() |> DateTime.truncate(:second),
      unlocked_by_id: user_id,
      unlock_reason: reason
    })
    |> Repo.update()
    |> audit_and_broadcast("period_locks", "update")
  end

  def delete_period_lock(%PeriodLock{} = pl) do
    Repo.delete(pl)
    |> audit_and_broadcast("period_locks", "delete")
  end

  def is_period_locked?(company_id, date) do
    date = if is_binary(date), do: Date.from_iso8601!(date), else: date

    from(pl in PeriodLock,
      where:
        pl.company_id == ^company_id and
          pl.status == "locked" and
          pl.period_start <= ^date and
          pl.period_end >= ^date
    )
    |> Repo.exists?()
  end

  # Recurring Transactions
  def list_recurring_transactions(company_id \\ nil) do
    query =
      from(rt in RecurringTransaction,
        order_by: [desc: rt.next_run_date],
        preload: [:company, :debit_account, :credit_account]
      )

    query = if company_id, do: where(query, [rt], rt.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_recurring_transaction!(id) do
    Repo.get!(RecurringTransaction, id)
    |> Repo.preload([:company, :debit_account, :credit_account])
  end

  def create_recurring_transaction(attrs) do
    %RecurringTransaction{}
    |> RecurringTransaction.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("recurring_transactions", "create")
  end

  def update_recurring_transaction(%RecurringTransaction{} = rt, attrs) do
    rt
    |> RecurringTransaction.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("recurring_transactions", "update")
  end

  def delete_recurring_transaction(%RecurringTransaction{} = rt) do
    Repo.delete(rt)
    |> audit_and_broadcast("recurring_transactions", "delete")
  end

  def list_due_recurring_transactions do
    today = Date.utc_today() |> Date.to_iso8601()

    from(rt in RecurringTransaction,
      where: rt.is_active == true and rt.next_run_date <= ^today,
      preload: [:company, :debit_account, :credit_account]
    )
    |> Repo.all()
  end

  def advance_next_run_date(%RecurringTransaction{} = rt) do
    current = Date.from_iso8601!(rt.next_run_date)

    next =
      case rt.frequency do
        "daily" -> Date.add(current, 1)
        "weekly" -> Date.add(current, 7)
        "monthly" -> Date.add(current, 30)
        "quarterly" -> Date.add(current, 91)
        "yearly" -> Date.add(current, 365)
      end

    is_active =
      if rt.end_date && rt.end_date != "" do
        end_date = Date.from_iso8601!(rt.end_date)
        Date.compare(next, end_date) != :gt
      else
        true
      end

    update_recurring_transaction(rt, %{
      next_run_date: Date.to_iso8601(next),
      last_run_date: Date.to_iso8601(current),
      is_active: is_active
    })
  end

  # PubSub
  def subscribe, do: Phoenix.PubSub.subscribe(Holdco.PubSub, "finance")
  defp broadcast(message), do: Phoenix.PubSub.broadcast(Holdco.PubSub, "finance", message)

  defp audit_and_broadcast(result, table, action) do
    case result do
      {:ok, record} ->
        Holdco.Platform.log_action(action, table, record.id)
        broadcast({String.to_atom("#{table}_#{action}d"), record})
        {:ok, record}

      error ->
        error
    end
  end

  # ── Accounting Books ───────────────────────────────────

  def list_accounting_books(company_id \\ nil) do
    query = from(b in AccountingBook, order_by: [asc: b.name], preload: [:company])
    query = if company_id, do: where(query, [b], b.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_accounting_book!(id), do: Repo.get!(AccountingBook, id) |> Repo.preload([:company, :adjustments])

  def create_accounting_book(attrs) do
    %AccountingBook{}
    |> AccountingBook.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("accounting_books", "create")
  end

  def update_accounting_book(%AccountingBook{} = book, attrs) do
    book
    |> AccountingBook.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("accounting_books", "update")
  end

  def delete_accounting_book(%AccountingBook{} = book) do
    Repo.delete(book)
    |> audit_and_broadcast("accounting_books", "delete")
  end

  # ── Book Adjustments ───────────────────────────────────

  def list_book_adjustments(book_id) do
    from(a in BookAdjustment,
      where: a.book_id == ^book_id,
      order_by: [desc: a.effective_date],
      preload: [:debit_account, :credit_account, :journal_entry]
    )
    |> Repo.all()
  end

  def get_book_adjustment!(id), do: Repo.get!(BookAdjustment, id) |> Repo.preload([:accounting_book, :debit_account, :credit_account, :journal_entry])

  def create_book_adjustment(attrs) do
    %BookAdjustment{}
    |> BookAdjustment.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("book_adjustments", "create")
  end

  def update_book_adjustment(%BookAdjustment{} = adjustment, attrs) do
    adjustment
    |> BookAdjustment.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("book_adjustments", "update")
  end

  def delete_book_adjustment(%BookAdjustment{} = adjustment) do
    Repo.delete(adjustment)
    |> audit_and_broadcast("book_adjustments", "delete")
  end

  @doc """
  Computes a trial balance for a specific accounting book by taking the base
  trial balance and applying all adjustments for that book up to the given date.

  Returns a list of account maps with adjusted debit/credit/balance values.
  """
  def book_trial_balance(book_id, date) do
    book = get_accounting_book!(book_id)

    # Get the base trial balance for the book's company
    base_tb = trial_balance(book.company_id)

    # Get all adjustments for this book up to the given date
    adjustments =
      from(a in BookAdjustment,
        where: a.book_id == ^book_id and a.effective_date <= ^date,
        preload: [:debit_account, :credit_account]
      )
      |> Repo.all()

    # Build adjustment maps: account_id -> {debit_delta, credit_delta}
    adj_map =
      Enum.reduce(adjustments, %{}, fn adj, acc ->
        amount = adj.amount || Decimal.new(0)

        acc =
          if adj.debit_account_id do
            Map.update(acc, adj.debit_account_id, {amount, Decimal.new(0)}, fn {d, c} ->
              {Decimal.add(d, amount), c}
            end)
          else
            acc
          end

        if adj.credit_account_id do
          Map.update(acc, adj.credit_account_id, {Decimal.new(0), amount}, fn {d, c} ->
            {d, Decimal.add(c, amount)}
          end)
        else
          acc
        end
      end)

    # Apply adjustments to each account in the base trial balance
    Enum.map(base_tb, fn acct ->
      {debit_adj, credit_adj} = Map.get(adj_map, acct.id, {Decimal.new(0), Decimal.new(0)})

      adjusted_debit = Decimal.add(to_decimal(acct.total_debit), debit_adj)
      adjusted_credit = Decimal.add(to_decimal(acct.total_credit), credit_adj)
      adjusted_balance = Decimal.sub(adjusted_debit, adjusted_credit)

      Map.merge(acct, %{
        total_debit: adjusted_debit,
        total_credit: adjusted_credit,
        balance: adjusted_balance,
        debit_adjustment: debit_adj,
        credit_adjustment: credit_adj
      })
    end)
  end

  defp to_decimal(%Decimal{} = d), do: d
  defp to_decimal(f) when is_float(f), do: Decimal.from_float(f)
  defp to_decimal(i) when is_integer(i), do: Decimal.new(i)
  defp to_decimal(nil), do: Decimal.new(0)
end
