defmodule Holdco.Fund do
  @moduledoc """
  Context for fund management operations including dividend policies.
  """

  import Ecto.Query
  alias Holdco.Repo
  alias Holdco.Money
  alias Holdco.Fund.DividendPolicy

  # ── Dividend Policies ─────────────────────────────────────

  def list_dividend_policies(company_id \\ nil) do
    query = from(dp in DividendPolicy, order_by: [desc: dp.inserted_at], preload: [:company])
    query = if company_id, do: where(query, [dp], dp.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_dividend_policy!(id), do: Repo.get!(DividendPolicy, id) |> Repo.preload(:company)

  def create_dividend_policy(attrs) do
    %DividendPolicy{}
    |> DividendPolicy.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("dividend_policies", "create")
  end

  def update_dividend_policy(%DividendPolicy{} = policy, attrs) do
    policy
    |> DividendPolicy.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("dividend_policies", "update")
  end

  def delete_dividend_policy(%DividendPolicy{} = policy) do
    Repo.delete(policy)
    |> audit_and_broadcast("dividend_policies", "delete")
  end

  @doc """
  Calculate recommended dividend based on the policy type and company financials.

  Returns a map with:
    - recommended_amount: the suggested dividend amount
    - payout_ratio: the effective payout ratio as a percentage
    - retained_earnings: earnings remaining after dividend
  """
  def calculate_dividend(%DividendPolicy{} = policy, company_id) do
    financials = Holdco.Finance.list_financials(company_id)

    latest_financial = List.first(financials)

    net_income =
      if latest_financial do
        Money.sub(latest_financial.revenue, latest_financial.expenses)
      else
        Decimal.new(0)
      end

    # Get last dividend amount for stable_growth
    last_dividends = Holdco.Finance.list_dividends(company_id)
    last_dividend_amount =
      case List.first(last_dividends) do
        nil -> Decimal.new(0)
        d -> Money.to_decimal(d.amount)
      end

    raw_amount = calculate_raw_amount(policy, net_income, last_dividend_amount)

    # Apply constraints
    amount = apply_constraints(raw_amount, policy, net_income)

    payout_ratio =
      if Money.gt?(net_income, 0) do
        Money.mult(Money.div(amount, net_income), 100)
      else
        Decimal.new(0)
      end

    retained = Money.sub(net_income, amount)

    %{
      recommended_amount: Money.round(amount, 2),
      payout_ratio: Money.round(payout_ratio, 2),
      retained_earnings: Money.round(retained, 2)
    }
  end

  defp calculate_raw_amount(%{policy_type: "fixed_amount"} = policy, _net_income, _last_dividend) do
    Money.to_decimal(policy.fixed_amount)
  end

  defp calculate_raw_amount(%{policy_type: "payout_ratio"} = policy, net_income, _last_dividend) do
    ratio = Money.div(Money.to_decimal(policy.target_payout_ratio), 100)
    Money.mult(net_income, ratio)
  end

  defp calculate_raw_amount(%{policy_type: "stable_growth"} = policy, _net_income, last_dividend) do
    growth = Money.div(Money.to_decimal(policy.growth_rate), 100)
    Money.mult(last_dividend, Money.add(Decimal.new(1), growth))
  end

  defp calculate_raw_amount(%{policy_type: "residual"}, net_income, _last_dividend) do
    # Residual: pay out 50% of net income as a simplified approach
    Money.div(net_income, 2)
  end

  defp calculate_raw_amount(_policy, _net_income, _last_dividend), do: Decimal.new(0)

  defp apply_constraints(amount, policy, net_income) do
    amount = Decimal.max(amount, Decimal.new(0))

    # Apply max payout ratio constraint
    amount =
      if policy.max_payout_ratio && Money.gt?(net_income, 0) do
        max_amount = Money.mult(net_income, Money.div(Money.to_decimal(policy.max_payout_ratio), 100))
        Money.min(amount, max_amount)
      else
        amount
      end

    # Apply min retained earnings constraint
    amount =
      if policy.min_retained_earnings do
        min_retained = Money.to_decimal(policy.min_retained_earnings)
        max_distributable = Money.sub(net_income, min_retained)

        if Money.gt?(max_distributable, 0) do
          Money.min(amount, max_distributable)
        else
          Decimal.new(0)
        end
      else
        amount
      end

    amount
  end

  @doc """
  Advance the dividend date based on the policy's frequency.
  Updates last_dividend_date to today and calculates next_dividend_date.
  """
  def advance_dividend_date(%DividendPolicy{} = policy) do
    today = Date.utc_today()

    next_date =
      case policy.frequency do
        "monthly" -> Date.add(today, 30)
        "quarterly" -> Date.add(today, 91)
        "semi_annual" -> Date.add(today, 182)
        "annual" -> Date.add(today, 365)
        _ -> Date.add(today, 91)
      end

    update_dividend_policy(policy, %{
      last_dividend_date: today,
      next_dividend_date: next_date
    })
  end

  # PubSub
  def subscribe, do: Phoenix.PubSub.subscribe(Holdco.PubSub, "fund")
  defp broadcast(message), do: Phoenix.PubSub.broadcast(Holdco.PubSub, "fund", message)

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
