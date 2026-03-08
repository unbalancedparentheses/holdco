defmodule Holdco.Governance do
  import Ecto.Query
  alias Holdco.Repo

  alias Holdco.Governance.{
    BoardMeeting,
    CapTableEntry,
    ShareholderResolution,
    PowerOfAttorney,
    EquityIncentivePlan,
    Deal,
    JointVenture
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
end
