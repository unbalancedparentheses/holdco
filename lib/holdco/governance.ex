defmodule Holdco.Governance do
  import Ecto.Query
  alias Holdco.Repo

  alias Holdco.Governance.{
    BoardMeeting,
    CapTableEntry,
    ShareholderResolution,
    PowerOfAttorney,
    EquityIncentivePlan,
    EquityGrant,
    Deal,
    JointVenture,
    InvestorAccess,
    ConflictOfInterest,
    ShareholderCommunication,
    EthicsReport,
    FamilyCharter,
    FamilyMember,
    EstatePlan,
    SuccessionPlan
  }

  # Board Meetings
  def list_board_meetings(company_id \\ nil) do
    query = from(bm in BoardMeeting, order_by: [desc: bm.scheduled_date], preload: [:company])
    query = if company_id, do: where(query, [bm], bm.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_board_meeting!(id), do: Repo.get!(BoardMeeting, id) |> Repo.preload(:company)

  def create_board_meeting(attrs) do
    %BoardMeeting{}
    |> BoardMeeting.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("board_meetings", "create")
  end

  def update_board_meeting(%BoardMeeting{} = bm, attrs) do
    bm
    |> BoardMeeting.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("board_meetings", "update")
  end

  def delete_board_meeting(%BoardMeeting{} = bm) do
    Repo.delete(bm)
    |> audit_and_broadcast("board_meetings", "delete")
  end

  # Cap Table Entries
  def list_cap_table_entries(company_id \\ nil) do
    query = from(ct in CapTableEntry, order_by: [desc: ct.date], preload: [:company])
    query = if company_id, do: where(query, [ct], ct.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_cap_table_entry!(id), do: Repo.get!(CapTableEntry, id) |> Repo.preload(:company)

  def create_cap_table_entry(attrs) do
    %CapTableEntry{}
    |> CapTableEntry.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("cap_table_entries", "create")
  end

  def update_cap_table_entry(%CapTableEntry{} = ct, attrs) do
    ct
    |> CapTableEntry.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("cap_table_entries", "update")
  end

  def delete_cap_table_entry(%CapTableEntry{} = ct) do
    Repo.delete(ct)
    |> audit_and_broadcast("cap_table_entries", "delete")
  end

  # Shareholder Resolutions
  def list_shareholder_resolutions(company_id \\ nil) do
    query = from(sr in ShareholderResolution, order_by: [desc: sr.date], preload: [:company])
    query = if company_id, do: where(query, [sr], sr.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_shareholder_resolution!(id),
    do: Repo.get!(ShareholderResolution, id) |> Repo.preload(:company)

  def create_shareholder_resolution(attrs) do
    %ShareholderResolution{}
    |> ShareholderResolution.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("shareholder_resolutions", "create")
  end

  def update_shareholder_resolution(%ShareholderResolution{} = sr, attrs) do
    sr
    |> ShareholderResolution.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("shareholder_resolutions", "update")
  end

  def delete_shareholder_resolution(%ShareholderResolution{} = sr) do
    Repo.delete(sr)
    |> audit_and_broadcast("shareholder_resolutions", "delete")
  end

  # Powers of Attorney
  def list_powers_of_attorney(company_id \\ nil) do
    query = from(poa in PowerOfAttorney, order_by: [desc: poa.start_date], preload: [:company])
    query = if company_id, do: where(query, [poa], poa.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_power_of_attorney!(id), do: Repo.get!(PowerOfAttorney, id) |> Repo.preload(:company)

  def create_power_of_attorney(attrs) do
    %PowerOfAttorney{}
    |> PowerOfAttorney.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("powers_of_attorney", "create")
  end

  def update_power_of_attorney(%PowerOfAttorney{} = poa, attrs) do
    poa
    |> PowerOfAttorney.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("powers_of_attorney", "update")
  end

  def delete_power_of_attorney(%PowerOfAttorney{} = poa) do
    Repo.delete(poa)
    |> audit_and_broadcast("powers_of_attorney", "delete")
  end

  # Equity Incentive Plans
  def list_equity_incentive_plans(company_id \\ nil) do
    query =
      from(eip in EquityIncentivePlan, order_by: eip.plan_name, preload: [:company, :grants])

    query = if company_id, do: where(query, [eip], eip.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_equity_incentive_plan!(id),
    do: Repo.get!(EquityIncentivePlan, id) |> Repo.preload([:company, :grants])

  def create_equity_incentive_plan(attrs) do
    %EquityIncentivePlan{}
    |> EquityIncentivePlan.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("equity_incentive_plans", "create")
  end

  def update_equity_incentive_plan(%EquityIncentivePlan{} = eip, attrs) do
    eip
    |> EquityIncentivePlan.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("equity_incentive_plans", "update")
  end

  def delete_equity_incentive_plan(%EquityIncentivePlan{} = eip) do
    Repo.delete(eip)
    |> audit_and_broadcast("equity_incentive_plans", "delete")
  end

  # Equity Grants
  def list_equity_grants(plan_id \\ nil) do
    query = from(eg in EquityGrant, order_by: [desc: eg.grant_date], preload: [:plan])
    query = if plan_id, do: where(query, [eg], eg.plan_id == ^plan_id), else: query
    Repo.all(query)
  end

  def get_equity_grant!(id), do: Repo.get!(EquityGrant, id) |> Repo.preload(:plan)

  def create_equity_grant(attrs) do
    %EquityGrant{}
    |> EquityGrant.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("equity_grants", "create")
  end

  def update_equity_grant(%EquityGrant{} = eg, attrs) do
    eg
    |> EquityGrant.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("equity_grants", "update")
  end

  def delete_equity_grant(%EquityGrant{} = eg) do
    Repo.delete(eg)
    |> audit_and_broadcast("equity_grants", "delete")
  end

  # Deals
  def list_deals(company_id \\ nil) do
    query = from(d in Deal, order_by: [desc: d.inserted_at], preload: [:company])
    query = if company_id, do: where(query, [d], d.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_deal!(id), do: Repo.get!(Deal, id) |> Repo.preload(:company)

  def create_deal(attrs) do
    %Deal{}
    |> Deal.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("deals", "create")
  end

  def update_deal(%Deal{} = d, attrs) do
    d
    |> Deal.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("deals", "update")
  end

  def delete_deal(%Deal{} = d) do
    Repo.delete(d)
    |> audit_and_broadcast("deals", "delete")
  end

  # Joint Ventures
  def list_joint_ventures(company_id \\ nil) do
    query = from(jv in JointVenture, order_by: jv.name, preload: [:company])
    query = if company_id, do: where(query, [jv], jv.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_joint_venture!(id), do: Repo.get!(JointVenture, id) |> Repo.preload(:company)

  def create_joint_venture(attrs) do
    %JointVenture{}
    |> JointVenture.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("joint_ventures", "create")
  end

  def update_joint_venture(%JointVenture{} = jv, attrs) do
    jv
    |> JointVenture.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("joint_ventures", "update")
  end

  def delete_joint_venture(%JointVenture{} = jv) do
    Repo.delete(jv)
    |> audit_and_broadcast("joint_ventures", "delete")
  end

  # Investor Access
  def list_investor_accesses(company_id \\ nil) do
    query =
      from(ia in InvestorAccess, order_by: [desc: ia.inserted_at], preload: [:user, :company])

    query = if company_id, do: where(query, [ia], ia.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_investor_access!(id),
    do: Repo.get!(InvestorAccess, id) |> Repo.preload([:user, :company])

  def create_investor_access(attrs) do
    %InvestorAccess{}
    |> InvestorAccess.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("investor_accesses", "create")
  end

  def update_investor_access(%InvestorAccess{} = ia, attrs) do
    ia
    |> InvestorAccess.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("investor_accesses", "update")
  end

  def delete_investor_access(%InvestorAccess{} = ia) do
    Repo.delete(ia)
    |> audit_and_broadcast("investor_accesses", "delete")
  end

  # Investor Portal Queries

  def list_investor_accesses_for_user(user_id) do
    now = DateTime.utc_now()

    from(ia in InvestorAccess,
      where: ia.user_id == ^user_id,
      where: is_nil(ia.expires_at) or ia.expires_at > ^now,
      preload: [:company, :user]
    )
    |> Repo.all()
  end

  def get_investor_access_for_user_and_company(user_id, company_id) do
    now = DateTime.utc_now()

    from(ia in InvestorAccess,
      where: ia.user_id == ^user_id and ia.company_id == ^company_id,
      where: is_nil(ia.expires_at) or ia.expires_at > ^now,
      preload: [:company, :user]
    )
    |> Repo.one()
  end

  # ── Conflicts of Interest ──────────────────────────────

  def list_conflicts_of_interest(company_id \\ nil) do
    query = from(coi in ConflictOfInterest, order_by: [desc: coi.declared_date], preload: [:company])
    query = if company_id, do: where(query, [coi], coi.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_conflict_of_interest!(id), do: Repo.get!(ConflictOfInterest, id) |> Repo.preload(:company)

  def create_conflict_of_interest(attrs) do
    %ConflictOfInterest{}
    |> ConflictOfInterest.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("conflicts_of_interest", "create")
  end

  def update_conflict_of_interest(%ConflictOfInterest{} = coi, attrs) do
    coi
    |> ConflictOfInterest.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("conflicts_of_interest", "update")
  end

  def delete_conflict_of_interest(%ConflictOfInterest{} = coi) do
    Repo.delete(coi)
    |> audit_and_broadcast("conflicts_of_interest", "delete")
  end

  def active_conflicts(company_id \\ nil) do
    query = from(coi in ConflictOfInterest,
      where: coi.status in ["declared", "under_review", "ongoing"],
      order_by: [desc: coi.declared_date],
      preload: [:company]
    )
    query = if company_id, do: where(query, [coi], coi.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def conflict_summary(company_id \\ nil) do
    query = from(coi in ConflictOfInterest)
    query = if company_id, do: where(query, [coi], coi.company_id == ^company_id), else: query

    by_status =
      from(coi in query,
        group_by: coi.status,
        select: %{status: coi.status, count: count(coi.id)}
      )
      |> Repo.all()

    by_type =
      from(coi in query,
        group_by: coi.conflict_type,
        select: %{conflict_type: coi.conflict_type, count: count(coi.id)}
      )
      |> Repo.all()

    by_role =
      from(coi in query,
        group_by: coi.declarant_role,
        select: %{declarant_role: coi.declarant_role, count: count(coi.id)}
      )
      |> Repo.all()

    %{
      by_status: by_status,
      by_type: by_type,
      by_role: by_role
    }
  end


  # Board Meeting Calendar Queries
  def upcoming_meetings(company_id) do
    today = Date.utc_today()

    from(bm in BoardMeeting,
      where: bm.company_id == ^company_id,
      where: bm.meeting_date >= ^today,
      where: bm.status in ["scheduled", "in_progress"],
      order_by: [asc: bm.meeting_date],
      preload: [:company]
    )
    |> Repo.all()
  end

  def meeting_calendar(company_id, %Date.Range{first: start_date, last: end_date}) do
    from(bm in BoardMeeting,
      where: bm.company_id == ^company_id,
      where: bm.meeting_date >= ^start_date,
      where: bm.meeting_date <= ^end_date,
      order_by: [asc: bm.meeting_date],
      preload: [:company]
    )
    |> Repo.all()
  end

  # Shareholder Communications
  def list_shareholder_communications(company_id \\ nil) do
    query = from(sc in ShareholderCommunication,
      order_by: [desc: sc.inserted_at],
      preload: [:company]
    )
    query = if company_id, do: where(query, [sc], sc.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_shareholder_communication!(id),
    do: Repo.get!(ShareholderCommunication, id) |> Repo.preload(:company)

  def create_shareholder_communication(attrs) do
    %ShareholderCommunication{}
    |> ShareholderCommunication.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("shareholder_communications", "create")
  end

  def update_shareholder_communication(%ShareholderCommunication{} = sc, attrs) do
    sc
    |> ShareholderCommunication.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("shareholder_communications", "update")
  end

  def delete_shareholder_communication(%ShareholderCommunication{} = sc) do
    Repo.delete(sc)
    |> audit_and_broadcast("shareholder_communications", "delete")
  end

  def pending_communications(company_id) do
    from(sc in ShareholderCommunication,
      where: sc.company_id == ^company_id,
      where: sc.status in ["draft", "approved"],
      order_by: [asc: sc.distribution_date],
      preload: [:company]
    )
    |> Repo.all()
  end

  def communication_summary(company_id) do
    from(sc in ShareholderCommunication,
      where: sc.company_id == ^company_id,
      group_by: sc.status,
      select: {sc.status, count(sc.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  # PubSub
  def subscribe, do: Phoenix.PubSub.subscribe(Holdco.PubSub, "governance")
  defp broadcast(message), do: Phoenix.PubSub.broadcast(Holdco.PubSub, "governance", message)

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

  # ── Ethics Reports ──────────────────────────────────────

  def list_ethics_reports(company_id \\ nil) do
    query = from(er in EthicsReport, order_by: [desc: er.reported_date], preload: [:company])
    query = if company_id, do: where(query, [er], er.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_ethics_report!(id), do: Repo.get!(EthicsReport, id) |> Repo.preload(:company)

  def create_ethics_report(attrs) do
    %EthicsReport{}
    |> EthicsReport.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("ethics_reports", "create")
  end

  def update_ethics_report(%EthicsReport{} = er, attrs) do
    er
    |> EthicsReport.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("ethics_reports", "update")
  end

  def delete_ethics_report(%EthicsReport{} = er) do
    Repo.delete(er)
    |> audit_and_broadcast("ethics_reports", "delete")
  end

  def open_ethics_reports(company_id) do
    from(er in EthicsReport,
      where: er.company_id == ^company_id,
      where: er.status in ["received", "under_investigation", "escalated"],
      order_by: [desc: er.severity, desc: er.reported_date],
      preload: [:company]
    )
    |> Repo.all()
  end

  def ethics_summary(company_id \\ nil) do
    query = from(er in EthicsReport)
    query = if company_id, do: where(query, [er], er.company_id == ^company_id), else: query

    by_status =
      from(er in query,
        group_by: er.status,
        select: %{status: er.status, count: count(er.id)}
      )
      |> Repo.all()

    by_severity =
      from(er in query,
        group_by: er.severity,
        select: %{severity: er.severity, count: count(er.id)}
      )
      |> Repo.all()

    by_type =
      from(er in query,
        group_by: er.report_type,
        select: %{report_type: er.report_type, count: count(er.id)}
      )
      |> Repo.all()

    %{by_status: by_status, by_severity: by_severity, by_type: by_type}
  end

  # ── Family Charters ────────────────────────────────────

  def list_family_charters do
    from(fc in FamilyCharter, order_by: [desc: fc.inserted_at])
    |> Repo.all()
  end

  def get_family_charter!(id),
    do: Repo.get!(FamilyCharter, id) |> Repo.preload(:family_members)

  def create_family_charter(attrs) do
    %FamilyCharter{}
    |> FamilyCharter.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("family_charters", "create")
  end

  def update_family_charter(%FamilyCharter{} = fc, attrs) do
    fc
    |> FamilyCharter.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("family_charters", "update")
  end

  # ── Family Members ─────────────────────────────────────

  def list_family_members(charter_id \\ nil) do
    query = from(fm in FamilyMember, order_by: [asc: fm.generation, asc: fm.full_name], preload: [:family_charter])
    query = if charter_id, do: where(query, [fm], fm.family_charter_id == ^charter_id), else: query
    Repo.all(query)
  end

  def get_family_member!(id), do: Repo.get!(FamilyMember, id) |> Repo.preload(:family_charter)

  def create_family_member(attrs) do
    %FamilyMember{}
    |> FamilyMember.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("family_members", "create")
  end

  def update_family_member(%FamilyMember{} = fm, attrs) do
    fm
    |> FamilyMember.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("family_members", "update")
  end

  def delete_family_member(%FamilyMember{} = fm) do
    Repo.delete(fm)
    |> audit_and_broadcast("family_members", "delete")
  end

  def voting_members(charter_id) do
    from(fm in FamilyMember,
      where: fm.family_charter_id == ^charter_id,
      where: fm.voting_rights == true,
      order_by: [asc: fm.generation, asc: fm.full_name]
    )
    |> Repo.all()
  end

  def members_by_generation(charter_id) do
    from(fm in FamilyMember,
      where: fm.family_charter_id == ^charter_id,
      order_by: [asc: fm.generation, asc: fm.full_name]
    )
    |> Repo.all()
    |> Enum.group_by(& &1.generation)
  end

  # ── Estate Plans ───────────────────────────────────────

  def list_estate_plans do
    from(ep in EstatePlan, order_by: [desc: ep.inserted_at], preload: [:family_charter])
    |> Repo.all()
  end

  def get_estate_plan!(id), do: Repo.get!(EstatePlan, id) |> Repo.preload(:family_charter)

  def create_estate_plan(attrs) do
    %EstatePlan{}
    |> EstatePlan.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("estate_plans", "create")
  end

  def update_estate_plan(%EstatePlan{} = ep, attrs) do
    ep
    |> EstatePlan.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("estate_plans", "update")
  end

  def delete_estate_plan(%EstatePlan{} = ep) do
    Repo.delete(ep)
    |> audit_and_broadcast("estate_plans", "delete")
  end

  def plans_due_for_review do
    today = Date.utc_today()

    from(ep in EstatePlan,
      where: not is_nil(ep.next_review_date),
      where: ep.next_review_date <= ^today,
      where: ep.status not in ["revoked", "superseded"],
      order_by: [asc: ep.next_review_date],
      preload: [:family_charter]
    )
    |> Repo.all()
  end

  # ── Succession Plans ───────────────────────────────────

  def list_succession_plans(company_id \\ nil) do
    query = from(sp in SuccessionPlan, order_by: [desc: sp.inserted_at], preload: [:company])
    query = if company_id, do: where(query, [sp], sp.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_succession_plan!(id), do: Repo.get!(SuccessionPlan, id) |> Repo.preload(:company)

  def create_succession_plan(attrs) do
    %SuccessionPlan{}
    |> SuccessionPlan.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("succession_plans", "create")
  end

  def update_succession_plan(%SuccessionPlan{} = sp, attrs) do
    sp
    |> SuccessionPlan.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("succession_plans", "update")
  end

  def delete_succession_plan(%SuccessionPlan{} = sp) do
    Repo.delete(sp)
    |> audit_and_broadcast("succession_plans", "delete")
  end

  def active_succession_plans(company_id) do
    from(sp in SuccessionPlan,
      where: sp.company_id == ^company_id,
      where: sp.status == "active",
      order_by: [asc: sp.position_title],
      preload: [:company]
    )
    |> Repo.all()
  end
end
