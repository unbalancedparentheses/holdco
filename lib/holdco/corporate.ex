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
    EntityPermission
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

  # Change Company
  def change_company(%Company{} = company, attrs \\ %{}) do
    Company.changeset(company, attrs)
  end

  def get_company_with_preloads!(id) do
    Company
    |> Repo.get!(id)
    |> Repo.preload([
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
    ])
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
