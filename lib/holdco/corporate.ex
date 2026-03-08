defmodule Holdco.Corporate do
  import Ecto.Query
  alias Holdco.Repo

  alias Holdco.Corporate.{
    Company,
    BeneficialOwner,
    KeyPersonnel,
    Contract
  }

  # Companies
  def list_companies(filters \\ %{}) do
    Company
    |> Holdco.QueryHelpers.apply_filters(filters)
    |> order_by([c], asc: c.name)
    |> Repo.all()
  end

  def get_company!(id) do
    Company
    |> Repo.get!(id)
    |> Repo.preload([
      :subsidiaries,
      :parent,
      :beneficial_owners,
      :key_personnel,
      :service_providers,
      :ownership_changes
    ])
  end

  def create_company(attrs) do
    %Company{}
    |> Company.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("companies", "create")
  end

  def update_company(%Company{} = company, attrs) do
    company
    |> Company.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("companies", "update")
  end

  def delete_company(%Company{} = company) do
    Repo.delete(company)
    |> audit_and_broadcast("companies", "delete")
  end

  def list_subsidiaries(company_id) do
    from(c in Company, where: c.parent_id == ^company_id, order_by: c.name)
    |> Repo.all()
  end

  def company_tree do
    companies = Repo.all(from c in Company, order_by: c.name)
    roots = Enum.filter(companies, &is_nil(&1.parent_id))
    by_parent = Enum.group_by(companies, & &1.parent_id)
    Enum.map(roots, &build_tree_node(&1, by_parent))
  end

  defp build_tree_node(company, by_parent) do
    children = Map.get(by_parent, company.id, [])

    %{
      company: company,
      children: Enum.map(children, &build_tree_node(&1, by_parent))
    }
  end

  # Beneficial Owners
  def list_beneficial_owners(company_id) do
    from(bo in BeneficialOwner, where: bo.company_id == ^company_id, order_by: bo.name)
    |> Repo.all()
  end

  def get_beneficial_owner!(id), do: Repo.get!(BeneficialOwner, id)

  def create_beneficial_owner(attrs) do
    %BeneficialOwner{}
    |> BeneficialOwner.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("beneficial_owners", "create")
  end

  def update_beneficial_owner(%BeneficialOwner{} = bo, attrs) do
    bo
    |> BeneficialOwner.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("beneficial_owners", "update")
  end

  def delete_beneficial_owner(%BeneficialOwner{} = bo) do
    Repo.delete(bo)
    |> audit_and_broadcast("beneficial_owners", "delete")
  end

  # Key Personnel
  def list_key_personnel(company_id) do
    from(kp in KeyPersonnel, where: kp.company_id == ^company_id, order_by: kp.name)
    |> Repo.all()
  end

  def get_key_personnel!(id), do: Repo.get!(KeyPersonnel, id)

  def create_key_personnel(attrs) do
    %KeyPersonnel{}
    |> KeyPersonnel.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("key_personnel", "create")
  end

  def update_key_personnel(%KeyPersonnel{} = kp, attrs) do
    kp
    |> KeyPersonnel.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("key_personnel", "update")
  end

  def delete_key_personnel(%KeyPersonnel{} = kp) do
    Repo.delete(kp)
    |> audit_and_broadcast("key_personnel", "delete")
  end

  # Bulk Operations
  def bulk_update_companies(ids, attrs) when is_list(ids) do
    results =
      Enum.map(ids, fn id ->
        company = get_company!(id)
        update_company(company, attrs)
      end)

    {Enum.count(results, &match?({:ok, _}, &1)),
     Enum.count(results, &match?({:error, _}, &1))}
  end

  def bulk_delete_companies(ids) when is_list(ids) do
    results =
      Enum.map(ids, fn id ->
        company = get_company!(id)
        delete_company(company)
      end)

    {Enum.count(results, &match?({:ok, _}, &1)),
     Enum.count(results, &match?({:error, _}, &1))}
  end

  # Change Company
  def change_company(%Company{} = company, attrs \\ %{}) do
    Company.changeset(company, attrs)
  end

  def get_company_consolidated!(id) do
    company = get_company_with_preloads!(id)

    sub_companies =
      from(c in Company, where: c.parent_id == ^id, order_by: c.name)
      |> Repo.all()
      |> Repo.preload(company_preloads())

    {company, sub_companies}
  end

  def get_company_with_preloads!(id) do
    Company
    |> Repo.get!(id)
    |> Repo.preload(company_preloads())
  end

  defp company_preloads do
    [
      :subsidiaries,
      :parent,
      :beneficial_owners,
      :key_personnel,
      :service_providers,
      :ownership_changes,
      :accounts,
      [journal_entries: :lines],
      :asset_holdings,
      :bank_accounts,
      :transactions,
      :documents,
      :tax_deadlines,
      :financials,
      :board_meetings,
      :insurance_policies,
      :liabilities,
      :dividends,
      :deals,
      :joint_ventures,
      :cap_table,
      :resolutions,
      :equity_plans,
      :powers_of_attorney,
      :real_estate_properties,
      :fund_investments,
      :budgets,
      :regulatory_filings,
      :regulatory_licenses,
      :compliance_checklists,
      :annual_filings,
      :esg_scores,
      :sanctions_checks,
      :fatca_reports,
      :withholding_taxes
    ]
  end

  # ── Contracts ──────────────────────────────────────────

  def list_contracts(company_id \\ nil) do
    query = from(c in Contract, order_by: [desc: c.inserted_at], preload: [:company])
    query = if company_id, do: where(query, [c], c.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_contract!(id), do: Repo.get!(Contract, id) |> Repo.preload(:company)

  def create_contract(attrs) do
    %Contract{}
    |> Contract.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("contracts", "create")
  end

  def update_contract(%Contract{} = contract, attrs) do
    contract
    |> Contract.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("contracts", "update")
  end

  def delete_contract(%Contract{} = contract) do
    Repo.delete(contract)
    |> audit_and_broadcast("contracts", "delete")
  end

  def expiring_contracts(days \\ 30) do
    cutoff = Date.add(Date.utc_today(), days)

    from(c in Contract,
      where: c.end_date <= ^cutoff and c.end_date >= ^Date.utc_today(),
      where: c.status in ["active", "expiring"],
      order_by: c.end_date,
      preload: [:company]
    )
    |> Repo.all()
  end

  def contracts_by_counterparty(company_id \\ nil) do
    query = from(c in Contract)
    query = if company_id, do: where(query, [c], c.company_id == ^company_id), else: query

    from(c in query,
      group_by: c.counterparty,
      select: %{counterparty: c.counterparty, count: count(c.id), total_value: sum(c.value)},
      order_by: [desc: count(c.id)]
    )
    |> Repo.all()
  end

  def contract_summary(company_id \\ nil) do
    query = from(c in Contract)
    query = if company_id, do: where(query, [c], c.company_id == ^company_id), else: query

    by_status =
      from(c in query,
        group_by: c.status,
        select: %{status: c.status, count: count(c.id)}
      )
      |> Repo.all()

    by_type =
      from(c in query,
        group_by: c.contract_type,
        select: %{contract_type: c.contract_type, count: count(c.id), total_value: sum(c.value)}
      )
      |> Repo.all()

    total_value =
      from(c in query, select: sum(c.value))
      |> Repo.one() || Decimal.new(0)

    %{
      by_status: by_status,
      by_type: by_type,
      total_value: total_value
    }
  end

  # PubSub
  def subscribe, do: Phoenix.PubSub.subscribe(Holdco.PubSub, "corporate")
  defp broadcast(message), do: Phoenix.PubSub.broadcast(Holdco.PubSub, "corporate", message)

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
