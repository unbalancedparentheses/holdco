defmodule Holdco.Tax do
  @moduledoc """
  Context for tax provisions, deferred taxes, and tax calculations.
  """

  import Ecto.Query
  alias Holdco.Repo
  alias Holdco.Money
  alias Holdco.Tax.{TaxProvision, DeferredTax}

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
