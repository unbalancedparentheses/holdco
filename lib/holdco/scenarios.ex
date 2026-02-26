defmodule Holdco.Scenarios do
  import Ecto.Query
  alias Holdco.Repo
  alias Holdco.Scenarios.{Scenario, ScenarioItem}

  # Scenarios
  def list_scenarios do
    from(s in Scenario, order_by: [desc: s.inserted_at], preload: [:company])
    |> Repo.all()
  end

  def get_scenario!(id) do
    Repo.get!(Scenario, id) |> Repo.preload([:company, :items])
  end

  def create_scenario(attrs) do
    %Scenario{}
    |> Scenario.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("scenarios", "create")
  end

  def update_scenario(%Scenario{} = scenario, attrs) do
    scenario
    |> Scenario.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("scenarios", "update")
  end

  def delete_scenario(%Scenario{} = scenario) do
    Repo.delete(scenario)
    |> audit_and_broadcast("scenarios", "delete")
  end

  # Scenario Items
  def list_scenario_items(scenario_id) do
    from(si in ScenarioItem, where: si.scenario_id == ^scenario_id, order_by: si.name)
    |> Repo.all()
  end

  def get_scenario_item!(id), do: Repo.get!(ScenarioItem, id)

  def create_scenario_item(attrs) do
    %ScenarioItem{}
    |> ScenarioItem.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("scenario_items", "create")
  end

  def update_scenario_item(%ScenarioItem{} = si, attrs) do
    si
    |> ScenarioItem.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("scenario_items", "update")
  end

  def delete_scenario_item(%ScenarioItem{} = si) do
    Repo.delete(si)
    |> audit_and_broadcast("scenario_items", "delete")
  end

  # Projection Engine
  def project(%Scenario{} = scenario) do
    scenario = Repo.preload(scenario, :items)
    months = scenario.projection_months || 12

    Enum.map(1..months, fn month ->
      {revenue, expenses} =
        Enum.reduce(scenario.items, {0.0, 0.0}, fn item, {rev, exp} ->
          amount = calculate_item_amount(item, month)

          case item.item_type do
            "revenue" -> {rev + amount, exp}
            "expense" -> {rev, exp + amount}
            _ -> {rev, exp + amount}
          end
        end)

      %{month: month, revenue: revenue, expenses: expenses, net: revenue - expenses}
    end)
  end

  defp calculate_item_amount(item, month) do
    base_amount = item.amount || 0.0
    growth_rate = item.growth_rate || 0.0
    probability = item.probability || 1.0

    # Apply recurrence filter
    active =
      case item.recurrence do
        "monthly" -> true
        "quarterly" -> rem(month, 3) == 0
        "annually" -> month == 12
        _ -> true
      end

    if active do
      grown_amount =
        case item.growth_type do
          "compound" ->
            base_amount * :math.pow(1 + growth_rate / 100, month - 1)

          "linear" ->
            base_amount + base_amount * (growth_rate / 100) * (month - 1)

          _ ->
            base_amount
        end

      grown_amount * probability
    else
      0.0
    end
  end

  # PubSub
  def subscribe, do: Phoenix.PubSub.subscribe(Holdco.PubSub, "scenarios")
  defp broadcast(message), do: Phoenix.PubSub.broadcast(Holdco.PubSub, "scenarios", message)

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
