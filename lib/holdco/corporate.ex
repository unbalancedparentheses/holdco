defmodule Holdco.Corporate do
  import Ecto.Query
  alias Holdco.Repo

  alias Holdco.Corporate.{
    Company,
    BeneficialOwner,
    KeyPersonnel,
    OwnershipChange,
    ServiceProvider,
    TenantGroup,
    TenantMembership,
    EntityPermission,
    EntityLifecycle,
    RegisterEntry,
    CorporateAction,
    IpAsset,
    Contract,
    LeiRecord,
    RelatedPartyTransaction,
    ShareClass
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

  # Ownership Changes
  def list_ownership_changes(company_id) do
    from(oc in OwnershipChange, where: oc.company_id == ^company_id, order_by: [desc: oc.date])
    |> Repo.all()
  end

  def get_ownership_change!(id), do: Repo.get!(OwnershipChange, id)

  def create_ownership_change(attrs) do
    %OwnershipChange{}
    |> OwnershipChange.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("ownership_changes", "create")
  end

  def update_ownership_change(%OwnershipChange{} = oc, attrs) do
    oc
    |> OwnershipChange.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("ownership_changes", "update")
  end

  def delete_ownership_change(%OwnershipChange{} = oc) do
    Repo.delete(oc)
    |> audit_and_broadcast("ownership_changes", "delete")
  end

  # Service Providers
  def list_service_providers(company_id) do
    from(sp in ServiceProvider, where: sp.company_id == ^company_id, order_by: sp.name)
    |> Repo.all()
  end

  def get_service_provider!(id), do: Repo.get!(ServiceProvider, id)

  def create_service_provider(attrs) do
    %ServiceProvider{}
    |> ServiceProvider.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("service_providers", "create")
  end

  def update_service_provider(%ServiceProvider{} = sp, attrs) do
    sp
    |> ServiceProvider.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("service_providers", "update")
  end

  def delete_service_provider(%ServiceProvider{} = sp) do
    Repo.delete(sp)
    |> audit_and_broadcast("service_providers", "delete")
  end

  # Tenant Groups
  def list_tenant_groups, do: Repo.all(from t in TenantGroup, order_by: t.name)
  def get_tenant_group!(id), do: Repo.get!(TenantGroup, id) |> Repo.preload(:tenant_memberships)

  def create_tenant_group(attrs) do
    %TenantGroup{}
    |> TenantGroup.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("tenant_groups", "create")
  end

  def update_tenant_group(%TenantGroup{} = tg, attrs) do
    tg
    |> TenantGroup.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("tenant_groups", "update")
  end

  def delete_tenant_group(%TenantGroup{} = tg) do
    Repo.delete(tg)
    |> audit_and_broadcast("tenant_groups", "delete")
  end

  # Tenant Memberships
  def list_tenant_memberships(tenant_id) do
    from(tm in TenantMembership, where: tm.tenant_id == ^tenant_id, preload: [:user])
    |> Repo.all()
  end

  def get_tenant_membership!(id), do: Repo.get!(TenantMembership, id)

  def create_tenant_membership(attrs) do
    %TenantMembership{}
    |> TenantMembership.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("tenant_memberships", "create")
  end

  def update_tenant_membership(%TenantMembership{} = tm, attrs) do
    tm
    |> TenantMembership.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("tenant_memberships", "update")
  end

  def delete_tenant_membership(%TenantMembership{} = tm) do
    Repo.delete(tm)
    |> audit_and_broadcast("tenant_memberships", "delete")
  end

  # Entity Permissions
  def list_entity_permissions(company_id) do
    from(ep in EntityPermission, where: ep.company_id == ^company_id, preload: [:user])
    |> Repo.all()
  end

  def list_user_permissions(user_id) do
    from(ep in EntityPermission, where: ep.user_id == ^user_id, preload: [:company])
    |> Repo.all()
  end

  def get_entity_permission!(id), do: Repo.get!(EntityPermission, id)

  def create_entity_permission(attrs) do
    %EntityPermission{}
    |> EntityPermission.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("entity_permissions", "create")
  end

  def update_entity_permission(%EntityPermission{} = ep, attrs) do
    ep
    |> EntityPermission.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("entity_permissions", "update")
  end

  def delete_entity_permission(%EntityPermission{} = ep) do
    Repo.delete(ep)
    |> audit_and_broadcast("entity_permissions", "delete")
  end

  # ── Entity Lifecycles ──────────────────────────────────

  def list_entity_lifecycles(company_id) do
    from(el in EntityLifecycle,
      where: el.company_id == ^company_id,
      order_by: [desc: el.event_date]
    )
    |> Repo.all()
  end

  def get_entity_lifecycle!(id), do: Repo.get!(EntityLifecycle, id)

  def create_entity_lifecycle(attrs) do
    %EntityLifecycle{}
    |> EntityLifecycle.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("entity_lifecycles", "create")
  end

  def update_entity_lifecycle(%EntityLifecycle{} = el, attrs) do
    el
    |> EntityLifecycle.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("entity_lifecycles", "update")
  end

  def delete_entity_lifecycle(%EntityLifecycle{} = el) do
    Repo.delete(el)
    |> audit_and_broadcast("entity_lifecycles", "delete")
  end

  def entity_timeline(company_id) do
    from(el in EntityLifecycle,
      where: el.company_id == ^company_id,
      order_by: [asc: el.event_date, asc: el.inserted_at]
    )
    |> Repo.all()
  end

  # ── Register Entries ───────────────────────────────────

  def list_register_entries(company_id) do
    from(re in RegisterEntry,
      where: re.company_id == ^company_id,
      order_by: [desc: re.entry_date]
    )
    |> Repo.all()
  end

  def get_register_entry!(id), do: Repo.get!(RegisterEntry, id)

  def create_register_entry(attrs) do
    %RegisterEntry{}
    |> RegisterEntry.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("register_entries", "create")
  end

  def update_register_entry(%RegisterEntry{} = re, attrs) do
    re
    |> RegisterEntry.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("register_entries", "update")
  end

  def delete_register_entry(%RegisterEntry{} = re) do
    Repo.delete(re)
    |> audit_and_broadcast("register_entries", "delete")
  end

  def current_register(company_id, register_type) do
    from(re in RegisterEntry,
      where: re.company_id == ^company_id and re.register_type == ^register_type and re.status == "current",
      order_by: [desc: re.entry_date]
    )
    |> Repo.all()
  end

  def register_summary(company_id) do
    from(re in RegisterEntry,
      where: re.company_id == ^company_id,
      group_by: re.register_type,
      select: {re.register_type, count(re.id)}
    )
    |> Repo.all()
    |> Enum.into(%{})
  end

  # ── Corporate Actions ──────────────────────────────────

  def list_corporate_actions(company_id) do
    from(ca in CorporateAction,
      where: ca.company_id == ^company_id,
      order_by: [desc: ca.inserted_at]
    )
    |> Repo.all()
  end

  def get_corporate_action!(id), do: Repo.get!(CorporateAction, id)

  def create_corporate_action(attrs) do
    %CorporateAction{}
    |> CorporateAction.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("corporate_actions", "create")
  end

  def update_corporate_action(%CorporateAction{} = ca, attrs) do
    ca
    |> CorporateAction.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("corporate_actions", "update")
  end

  def delete_corporate_action(%CorporateAction{} = ca) do
    Repo.delete(ca)
    |> audit_and_broadcast("corporate_actions", "delete")
  end

  def pending_actions(company_id) do
    from(ca in CorporateAction,
      where: ca.company_id == ^company_id and ca.status not in ["completed", "cancelled"],
      order_by: [asc: ca.effective_date, asc: ca.inserted_at]
    )
    |> Repo.all()
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

  # ── IP Assets ───────────────────────────────────────────

  def list_ip_assets(company_id \\ nil) do
    query = from(ip in IpAsset, order_by: ip.name, preload: [:company])
    query = if company_id, do: where(query, [ip], ip.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_ip_asset!(id), do: Repo.get!(IpAsset, id) |> Repo.preload(:company)

  def create_ip_asset(attrs) do
    %IpAsset{}
    |> IpAsset.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("ip_assets", "create")
  end

  def update_ip_asset(%IpAsset{} = ip, attrs) do
    ip
    |> IpAsset.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("ip_assets", "update")
  end

  def delete_ip_asset(%IpAsset{} = ip) do
    Repo.delete(ip)
    |> audit_and_broadcast("ip_assets", "delete")
  end

  def expiring_ip_assets(days \\ 90) do
    cutoff = Date.add(Date.utc_today(), days)

    from(ip in IpAsset,
      where: ip.expiry_date <= ^cutoff and ip.expiry_date >= ^Date.utc_today(),
      where: ip.status in ["pending", "active"],
      order_by: ip.expiry_date,
      preload: [:company]
    )
    |> Repo.all()
  end

  def ip_portfolio_summary(company_id \\ nil) do
    query = from(ip in IpAsset)
    query = if company_id, do: where(query, [ip], ip.company_id == ^company_id), else: query

    by_type =
      from(ip in query,
        group_by: ip.asset_type,
        select: %{asset_type: ip.asset_type, count: count(ip.id), total_valuation: sum(ip.valuation)}
      )
      |> Repo.all()

    by_status =
      from(ip in query,
        group_by: ip.status,
        select: %{status: ip.status, count: count(ip.id)}
      )
      |> Repo.all()

    total_cost =
      from(ip in query, select: sum(ip.annual_cost))
      |> Repo.one() || Decimal.new(0)

    total_valuation =
      from(ip in query, select: sum(ip.valuation))
      |> Repo.one() || Decimal.new(0)

    %{
      by_type: by_type,
      by_status: by_status,
      total_annual_cost: total_cost,
      total_valuation: total_valuation
    }
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

  # ── LEI Records ────────────────────────────────────────

  def list_lei_records(company_id \\ nil) do
    query = from(l in LeiRecord, order_by: l.lei_code, preload: [:company])
    query = if company_id, do: where(query, [l], l.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_lei_record!(id), do: Repo.get!(LeiRecord, id) |> Repo.preload(:company)

  def create_lei_record(attrs) do
    %LeiRecord{}
    |> LeiRecord.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("lei_records", "create")
  end

  def update_lei_record(%LeiRecord{} = lei, attrs) do
    lei
    |> LeiRecord.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("lei_records", "update")
  end

  def delete_lei_record(%LeiRecord{} = lei) do
    Repo.delete(lei)
    |> audit_and_broadcast("lei_records", "delete")
  end

  def lei_due_for_renewal do
    cutoff = Date.add(Date.utc_today(), 30)

    from(l in LeiRecord,
      where: l.next_renewal_date <= ^cutoff and l.next_renewal_date >= ^Date.utc_today(),
      where: l.registration_status in ["issued", "pending"],
      order_by: l.next_renewal_date,
      preload: [:company]
    )
    |> Repo.all()
  end

  # ── Related Party Transactions ─────────────────────────

  def list_related_party_transactions(company_id \\ nil) do
    query = from(rpt in RelatedPartyTransaction, order_by: [desc: rpt.transaction_date], preload: [:company])
    query = if company_id, do: where(query, [rpt], rpt.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_related_party_transaction!(id), do: Repo.get!(RelatedPartyTransaction, id) |> Repo.preload(:company)

  def create_related_party_transaction(attrs) do
    %RelatedPartyTransaction{}
    |> RelatedPartyTransaction.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("related_party_transactions", "create")
  end

  def update_related_party_transaction(%RelatedPartyTransaction{} = rpt, attrs) do
    rpt
    |> RelatedPartyTransaction.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("related_party_transactions", "update")
  end

  def delete_related_party_transaction(%RelatedPartyTransaction{} = rpt) do
    Repo.delete(rpt)
    |> audit_and_broadcast("related_party_transactions", "delete")
  end

  def related_party_summary(company_id \\ nil) do
    query = from(rpt in RelatedPartyTransaction)
    query = if company_id, do: where(query, [rpt], rpt.company_id == ^company_id), else: query

    by_relationship =
      from(rpt in query,
        group_by: rpt.relationship,
        select: %{relationship: rpt.relationship, count: count(rpt.id), total_amount: sum(rpt.amount)},
        order_by: [desc: sum(rpt.amount)]
      )
      |> Repo.all()

    by_type =
      from(rpt in query,
        group_by: rpt.transaction_type,
        select: %{transaction_type: rpt.transaction_type, count: count(rpt.id), total_amount: sum(rpt.amount)}
      )
      |> Repo.all()

    total_amount =
      from(rpt in query, select: sum(rpt.amount))
      |> Repo.one() || Decimal.new(0)

    %{
      by_relationship: by_relationship,
      by_type: by_type,
      total_amount: total_amount
    }
  end


  # ── Share Classes ──────────────────────────────────────

  def list_share_classes(company_id \\ nil) do
    query = from(sc in ShareClass, order_by: sc.class_code, preload: [:company])
    query = if company_id, do: where(query, [sc], sc.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_share_class!(id), do: Repo.get!(ShareClass, id) |> Repo.preload(:company)

  def create_share_class(attrs) do
    %ShareClass{}
    |> ShareClass.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("share_classes", "create")
  end

  def update_share_class(%ShareClass{} = sc, attrs) do
    sc
    |> ShareClass.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("share_classes", "update")
  end

  def delete_share_class(%ShareClass{} = sc) do
    Repo.delete(sc)
    |> audit_and_broadcast("share_classes", "delete")
  end

  def cap_table(company_id) do
    classes = list_share_classes(company_id)

    total_outstanding =
      Enum.reduce(classes, Decimal.new(0), fn sc, acc ->
        Decimal.add(acc, sc.shares_outstanding || Decimal.new(0))
      end)

    Enum.map(classes, fn sc ->
      outstanding = sc.shares_outstanding || Decimal.new(0)

      pct =
        if Decimal.gt?(total_outstanding, Decimal.new(0)),
          do: Decimal.div(outstanding, total_outstanding) |> Decimal.mult(100) |> Decimal.round(2),
          else: Decimal.new(0)

      %{share_class: sc, ownership_pct: pct}
    end)
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
