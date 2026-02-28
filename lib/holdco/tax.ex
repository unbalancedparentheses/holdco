defmodule Holdco.Tax do
  @moduledoc """
  Context for tax provisions, deferred taxes, jurisdictions, withholding reclaims,
  repatriation planning, and tax calculations.
  """

  import Ecto.Query
  alias Holdco.Repo
  alias Holdco.Money
  alias Holdco.Tax.{TaxProvision, DeferredTax, Jurisdiction, WithholdingReclaim, RepatriationPlan}

  # ── Tax Provisions ────────────────────────────────────────

  def list_tax_provisions(opts \\ []) do
    query = from(tp in TaxProvision, order_by: [desc: tp.tax_year, asc: tp.jurisdiction], preload: [:company])

    query = if opts[:company_id], do: where(query, [tp], tp.company_id == ^opts[:company_id]), else: query
    query = if opts[:tax_year], do: where(query, [tp], tp.tax_year == ^opts[:tax_year]), else: query
    query = if opts[:status], do: where(query, [tp], tp.status == ^opts[:status]), else: query
    query = if opts[:jurisdiction], do: where(query, [tp], tp.jurisdiction == ^opts[:jurisdiction]), else: query

    Repo.all(query)
  end

  def get_tax_provision!(id), do: Repo.get!(TaxProvision, id) |> Repo.preload(:company)

  def create_tax_provision(attrs) do
    %TaxProvision{}
    |> TaxProvision.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("tax_provisions", "create")
  end

  def update_tax_provision(%TaxProvision{} = provision, attrs) do
    provision
    |> TaxProvision.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("tax_provisions", "update")
  end

  def delete_tax_provision(%TaxProvision{} = provision) do
    Repo.delete(provision)
    |> audit_and_broadcast("tax_provisions", "delete")
  end

  @doc """
  Calculate a tax provision for a company, year, jurisdiction, and tax rate.
  Uses financial data to determine taxable income and compute the tax amount.

  Returns {:ok, %{taxable_income: ..., tax_amount: ...}}.
  """
  def calculate_provision(company_id, tax_year, jurisdiction, tax_rate) do
    financials = Holdco.Finance.list_financials(company_id)

    # Filter financials that match the tax year (period contains the year)
    year_str = to_string(tax_year)

    year_financials =
      Enum.filter(financials, fn f ->
        f.period && String.contains?(f.period, year_str)
      end)

    total_revenue =
      Enum.reduce(year_financials, Decimal.new(0), fn f, acc ->
        Money.add(acc, f.revenue)
      end)

    total_expenses =
      Enum.reduce(year_financials, Decimal.new(0), fn f, acc ->
        Money.add(acc, f.expenses)
      end)

    taxable_income = Money.sub(total_revenue, total_expenses)
    tax_rate_decimal = Money.div(Money.to_decimal(tax_rate), 100)
    tax_amount = Money.mult(taxable_income, tax_rate_decimal)

    {:ok,
     %{
       taxable_income: Money.round(taxable_income, 2),
       tax_amount: Money.round(Money.abs(tax_amount), 2),
       jurisdiction: jurisdiction,
       tax_year: tax_year,
       tax_rate: Money.to_decimal(tax_rate)
     }}
  end

  # ── Deferred Taxes ────────────────────────────────────────

  def list_deferred_taxes(opts \\ []) do
    query = from(dt in DeferredTax, order_by: [desc: dt.tax_year, asc: dt.description], preload: [:company])

    query = if opts[:company_id], do: where(query, [dt], dt.company_id == ^opts[:company_id]), else: query
    query = if opts[:tax_year], do: where(query, [dt], dt.tax_year == ^opts[:tax_year]), else: query
    query = if opts[:deferred_type], do: where(query, [dt], dt.deferred_type == ^opts[:deferred_type]), else: query

    Repo.all(query)
  end

  def get_deferred_tax!(id), do: Repo.get!(DeferredTax, id) |> Repo.preload(:company)

  def create_deferred_tax(attrs) do
    %DeferredTax{}
    |> DeferredTax.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("deferred_taxes", "create")
  end

  def update_deferred_tax(%DeferredTax{} = dt, attrs) do
    dt
    |> DeferredTax.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("deferred_taxes", "update")
  end

  def delete_deferred_tax(%DeferredTax{} = dt) do
    Repo.delete(dt)
    |> audit_and_broadcast("deferred_taxes", "delete")
  end

  @doc """
  Calculate deferred tax from temporary differences between book and tax basis.

  Returns a map with:
    - temporary_difference: book_basis - tax_basis
    - deferred_amount: |temporary_difference * tax_rate / 100|
    - deferred_type: "liability" if book > tax, "asset" if tax > book
  """
  def calculate_deferred_tax(book_basis, tax_basis, tax_rate) do
    book = Money.to_decimal(book_basis)
    tax = Money.to_decimal(tax_basis)
    rate = Money.to_decimal(tax_rate)

    difference = Money.sub(book, tax)
    amount = Money.mult(difference, Money.div(rate, 100))

    deferred_type =
      case Decimal.compare(difference, Decimal.new(0)) do
        :gt -> "liability"
        :lt -> "asset"
        :eq -> "asset"
      end

    %{
      temporary_difference: difference,
      deferred_amount: Money.abs(amount),
      deferred_type: deferred_type
    }
  end

  @doc """
  Get a tax summary for a company and tax year.

  Returns total current provision, total deferred assets, total deferred liabilities,
  and effective tax rate.
  """
  def tax_summary(company_id, tax_year) do
    provisions = list_tax_provisions(company_id: company_id, tax_year: tax_year)
    deferred = list_deferred_taxes(company_id: company_id, tax_year: tax_year)

    current_provisions =
      provisions
      |> Enum.filter(&(&1.provision_type == "current"))

    total_current =
      Enum.reduce(current_provisions, Decimal.new(0), fn p, acc ->
        Money.add(acc, p.tax_amount)
      end)

    total_taxable_income =
      Enum.reduce(current_provisions, Decimal.new(0), fn p, acc ->
        Money.add(acc, p.taxable_income)
      end)

    deferred_assets =
      deferred
      |> Enum.filter(&(&1.deferred_type == "asset"))
      |> Enum.reduce(Decimal.new(0), fn dt, acc -> Money.add(acc, dt.deferred_amount) end)

    deferred_liabilities =
      deferred
      |> Enum.filter(&(&1.deferred_type == "liability"))
      |> Enum.reduce(Decimal.new(0), fn dt, acc -> Money.add(acc, dt.deferred_amount) end)

    total_tax = Money.add(total_current, Money.sub(deferred_liabilities, deferred_assets))

    effective_rate =
      if Money.gt?(total_taxable_income, 0) do
        Money.round(Money.mult(Money.div(total_tax, total_taxable_income), 100), 2)
      else
        Decimal.new(0)
      end

    %{
      total_current_provision: Money.round(total_current, 2),
      total_deferred_assets: Money.round(deferred_assets, 2),
      total_deferred_liabilities: Money.round(deferred_liabilities, 2),
      total_tax_expense: Money.round(total_tax, 2),
      effective_tax_rate: effective_rate
    }
  end

  # ── Jurisdictions ──────────────────────────────────────

  def list_jurisdictions do
    from(j in Jurisdiction, order_by: [asc: j.name])
    |> Repo.all()
  end

  def get_jurisdiction!(id), do: Repo.get!(Jurisdiction, id)

  def create_jurisdiction(attrs) do
    %Jurisdiction{}
    |> Jurisdiction.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("jurisdictions", "create")
  end

  def update_jurisdiction(%Jurisdiction{} = jurisdiction, attrs) do
    jurisdiction
    |> Jurisdiction.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("jurisdictions", "update")
  end

  def delete_jurisdiction(%Jurisdiction{} = jurisdiction) do
    Repo.delete(jurisdiction)
    |> audit_and_broadcast("jurisdictions", "delete")
  end

  @doc """
  Optimizes tax structure for a given company.
  Finds all holdings for the company, looks up applicable jurisdiction tax rates,
  and computes tax liability per jurisdiction with suggestions for optimal allocation.
  """
  def optimize_tax_structure(company_id) do
    holdings =
      Holdco.Assets.list_holdings(%{company_id: company_id})

    jurisdictions =
      from(j in Jurisdiction, where: j.is_active == true, order_by: j.tax_rate)
      |> Repo.all()

    company = Holdco.Corporate.get_company!(company_id)
    company_country = company.country || "US"

    # Group holdings by value and compute tax per jurisdiction
    total_value =
      holdings
      |> Enum.reduce(Decimal.new(0), fn h, acc ->
        qty = Money.to_decimal(h.quantity)
        # Use cost basis as a proxy for value
        cost =
          case h.cost_basis_lots do
            lots when is_list(lots) and lots != [] ->
              Enum.reduce(lots, Decimal.new(0), fn lot, lot_acc ->
                Money.add(lot_acc, Money.mult(lot.quantity, lot.price_per_unit))
              end)

            _ ->
              qty
          end

        Money.add(acc, cost)
      end)

    # Build jurisdiction analysis
    jurisdiction_analysis =
      jurisdictions
      |> Enum.map(fn j ->
        tax_liability = Money.mult(total_value, j.tax_rate)

        %{
          jurisdiction_id: j.id,
          jurisdiction_name: j.name,
          country_code: j.country_code,
          tax_type: j.tax_type,
          tax_rate: j.tax_rate,
          estimated_liability: tax_liability
        }
      end)

    # Find lowest rate jurisdiction per tax type
    suggestions =
      jurisdiction_analysis
      |> Enum.group_by(& &1.tax_type)
      |> Enum.map(fn {tax_type, entries} ->
        best = Enum.min_by(entries, &Money.to_float(&1.tax_rate))

        %{
          tax_type: tax_type,
          recommended_jurisdiction: best.jurisdiction_name,
          recommended_country: best.country_code,
          tax_rate: best.tax_rate,
          potential_savings:
            case Enum.find(entries, &(&1.country_code == company_country)) do
              nil -> Decimal.new(0)
              current -> Money.sub(current.estimated_liability, best.estimated_liability)
            end
        }
      end)

    %{
      company_id: company_id,
      total_portfolio_value: total_value,
      holdings_count: length(holdings),
      jurisdiction_analysis: jurisdiction_analysis,
      suggestions: suggestions
    }
  end

  # ── Withholding Reclaims ───────────────────────────────

  def list_withholding_reclaims(company_id) do
    from(wr in WithholdingReclaim,
      where: wr.company_id == ^company_id,
      order_by: [desc: wr.tax_year],
      preload: [:company]
    )
    |> Repo.all()
  end

  def get_withholding_reclaim!(id) do
    Repo.get!(WithholdingReclaim, id) |> Repo.preload(:company)
  end

  def create_withholding_reclaim(attrs) do
    %WithholdingReclaim{}
    |> WithholdingReclaim.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("withholding_reclaims", "create")
  end

  def update_withholding_reclaim(%WithholdingReclaim{} = reclaim, attrs) do
    reclaim
    |> WithholdingReclaim.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("withholding_reclaims", "update")
  end

  def delete_withholding_reclaim(%WithholdingReclaim{} = reclaim) do
    Repo.delete(reclaim)
    |> audit_and_broadcast("withholding_reclaims", "delete")
  end

  @doc """
  Returns aggregate reclaim summary grouped by status and jurisdiction.
  """
  def reclaim_summary(company_id) do
    reclaims = list_withholding_reclaims(company_id)

    by_status =
      reclaims
      |> Enum.group_by(& &1.status)
      |> Enum.map(fn {status, items} ->
        %{
          status: status,
          count: length(items),
          total_withheld: Enum.reduce(items, Decimal.new(0), &Money.add(&1.amount_withheld, &2)),
          total_reclaimable: Enum.reduce(items, Decimal.new(0), &Money.add(&1.reclaimable_amount, &2)),
          total_reclaimed: Enum.reduce(items, Decimal.new(0), &Money.add(&1.reclaimed_amount, &2))
        }
      end)

    by_jurisdiction =
      reclaims
      |> Enum.group_by(& &1.jurisdiction)
      |> Enum.map(fn {jurisdiction, items} ->
        %{
          jurisdiction: jurisdiction,
          count: length(items),
          total_withheld: Enum.reduce(items, Decimal.new(0), &Money.add(&1.amount_withheld, &2)),
          total_reclaimable: Enum.reduce(items, Decimal.new(0), &Money.add(&1.reclaimable_amount, &2)),
          total_reclaimed: Enum.reduce(items, Decimal.new(0), &Money.add(&1.reclaimed_amount, &2))
        }
      end)

    total_withheld = Enum.reduce(reclaims, Decimal.new(0), &Money.add(&1.amount_withheld, &2))
    total_reclaimable = Enum.reduce(reclaims, Decimal.new(0), &Money.add(&1.reclaimable_amount, &2))
    total_reclaimed = Enum.reduce(reclaims, Decimal.new(0), &Money.add(&1.reclaimed_amount, &2))

    recovery_rate =
      if Money.gt?(total_reclaimable, 0),
        do: Money.div(total_reclaimed, total_reclaimable),
        else: Decimal.new(0)

    %{
      by_status: by_status,
      by_jurisdiction: by_jurisdiction,
      total_withheld: total_withheld,
      total_reclaimable: total_reclaimable,
      total_reclaimed: total_reclaimed,
      recovery_rate: recovery_rate
    }
  end

  # ── Repatriation Plans ────────────────────────────────

  def list_repatriation_plans(company_id) do
    from(rp in RepatriationPlan,
      where: rp.company_id == ^company_id,
      order_by: [desc: rp.planned_date],
      preload: [:company]
    )
    |> Repo.all()
  end

  def get_repatriation_plan!(id) do
    Repo.get!(RepatriationPlan, id) |> Repo.preload(:company)
  end

  def create_repatriation_plan(attrs) do
    attrs = maybe_calculate_repatriation_fields(attrs)

    %RepatriationPlan{}
    |> RepatriationPlan.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("repatriation_plans", "create")
  end

  def update_repatriation_plan(%RepatriationPlan{} = plan, attrs) do
    attrs = maybe_calculate_repatriation_fields(attrs)

    plan
    |> RepatriationPlan.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("repatriation_plans", "update")
  end

  def delete_repatriation_plan(%RepatriationPlan{} = plan) do
    Repo.delete(plan)
    |> audit_and_broadcast("repatriation_plans", "delete")
  end

  @doc """
  Calculates net repatriation amount after withholding tax.
  Takes a map with :amount and :withholding_tax_rate, returns a map with
  computed :withholding_tax_amount, :net_amount, and :effective_tax_rate.
  """
  def calculate_repatriation(params) do
    amount = Money.to_decimal(params[:amount] || params["amount"] || 0)
    rate = Money.to_decimal(params[:withholding_tax_rate] || params["withholding_tax_rate"] || 0)

    withholding_tax_amount = Money.mult(amount, rate)
    net_amount = Money.sub(amount, withholding_tax_amount)

    effective_tax_rate =
      if Money.gt?(amount, 0),
        do: Money.div(withholding_tax_amount, amount),
        else: Decimal.new(0)

    %{
      amount: amount,
      withholding_tax_rate: rate,
      withholding_tax_amount: withholding_tax_amount,
      net_amount: net_amount,
      effective_tax_rate: effective_tax_rate
    }
  end

  # ── Private ────────────────────────────────────────────

  defp maybe_calculate_repatriation_fields(attrs) do
    amount = attrs[:amount] || attrs["amount"]
    rate = attrs[:withholding_tax_rate] || attrs["withholding_tax_rate"]

    if amount && rate do
      calc = calculate_repatriation(%{amount: amount, withholding_tax_rate: rate})

      attrs
      |> put_field(:withholding_tax_amount, calc.withholding_tax_amount)
      |> put_field(:net_amount, calc.net_amount)
      |> put_field(:effective_tax_rate, calc.effective_tax_rate)
    else
      attrs
    end
  end

  defp put_field(attrs, key, value) when is_map(attrs) do
    # Support both atom and string keys
    if Enum.any?(Map.keys(attrs), &is_atom/1) do
      Map.put(attrs, key, value)
    else
      Map.put(attrs, to_string(key), value)
    end
  end

  # PubSub
  def subscribe, do: Phoenix.PubSub.subscribe(Holdco.PubSub, "tax")
  defp broadcast(message), do: Phoenix.PubSub.broadcast(Holdco.PubSub, "tax", message)

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
