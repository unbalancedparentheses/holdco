defmodule Holdco.Finance do
  import Ecto.Query
  alias Holdco.Repo
  alias Holdco.Finance.{Financial, Account, JournalEntry, JournalLine,
                         InterCompanyTransfer, Dividend, CapitalContribution,
                         TaxPayment, Budget, Liability}

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
  def list_accounts do
    from(a in Account, order_by: a.code, preload: [:parent, :children])
    |> Repo.all()
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
  def list_journal_entries do
    from(je in JournalEntry, order_by: [desc: je.date], preload: [:lines])
    |> Repo.all()
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
    from(ict in InterCompanyTransfer, order_by: [desc: ict.date],
         preload: [:from_company, :to_company])
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

  def get_capital_contribution!(id), do: Repo.get!(CapitalContribution, id) |> Repo.preload(:company)

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

  # PubSub
  def subscribe, do: Phoenix.PubSub.subscribe(Holdco.PubSub, "finance")
  defp broadcast(message), do: Phoenix.PubSub.broadcast(Holdco.PubSub, "finance", message)

  defp audit_and_broadcast(result, table, action) do
    case result do
      {:ok, record} ->
        Holdco.Platform.log_action(action, table, record.id)
        broadcast({String.to_atom("#{table}_#{action}d"), record})
        {:ok, record}
      error -> error
    end
  end
end
