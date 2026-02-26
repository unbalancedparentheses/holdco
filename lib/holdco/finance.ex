defmodule Holdco.Finance do
  import Ecto.Query
  alias Holdco.Repo

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
    Lease
  }

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
    %JournalEntry{}
    |> JournalEntry.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("journal_entries", "create")
  end

  def update_journal_entry(%JournalEntry{} = je, attrs) do
    je
    |> JournalEntry.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("journal_entries", "update")
  end

  def delete_journal_entry(%JournalEntry{} = je) do
    Repo.delete(je)
    |> audit_and_broadcast("journal_entries", "delete")
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
      |> Enum.map(&Map.put(&1, :balance, &1.total_debit - &1.total_credit))

    liabilities =
      accounts
      |> Enum.filter(&(&1.account_type == "liability"))
      |> Enum.map(&Map.put(&1, :balance, &1.total_credit - &1.total_debit))

    equity =
      accounts
      |> Enum.filter(&(&1.account_type == "equity"))
      |> Enum.map(&Map.put(&1, :balance, &1.total_credit - &1.total_debit))

    total_assets = Enum.reduce(assets, 0.0, &(&1.balance + &2))
    total_liabilities = Enum.reduce(liabilities, 0.0, &(&1.balance + &2))
    total_equity = Enum.reduce(equity, 0.0, &(&1.balance + &2))

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
    total_revenue = Enum.reduce(revenue, 0.0, &(&1.amount + &2))
    total_expenses = Enum.reduce(expenses, 0.0, &(&1.amount + &2))

    %{
      revenue: revenue,
      expenses: expenses,
      total_revenue: total_revenue,
      total_expenses: total_expenses,
      net_income: total_revenue - total_expenses
    }
  end

  # Aggregations
  def total_revenue do
    Repo.one(from f in Financial, select: sum(f.revenue)) || 0.0
  end

  def total_expenses do
    Repo.one(from f in Financial, select: sum(f.expenses)) || 0.0
  end

  def total_liabilities do
    Repo.one(from l in Liability, select: sum(l.principal)) || 0.0
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
end
