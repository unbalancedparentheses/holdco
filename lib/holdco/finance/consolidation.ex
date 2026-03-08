defmodule Holdco.Finance.Consolidation do
  @moduledoc """
  Builds consolidated financial statements across all entities,
  including intercompany eliminations and non-controlling interest.
  """

  alias Holdco.{Corporate, Finance}
  alias Holdco.Money

  @doc """
  Builds consolidated financial data for all companies.

  Returns a map with:
  - `:companies` — the list of companies
  - `:entity_data` — per-entity balance sheet and income statement
  - `:transfers` — intercompany transfers
  - `:eliminations` — elimination data
  - `:balance_sheet` — consolidated balance sheet
  - `:income_statement` — consolidated income statement
  """
  def build do
    companies = Corporate.list_companies()
    build(companies)
  end

  def build(companies) do
    transfers = Finance.list_inter_company_transfers()
    entity_data = load_entity_data(companies)
    eliminations = build_eliminations(transfers)
    balance_sheet = build_consolidated_balance_sheet(entity_data, eliminations, companies)
    income_statement = build_consolidated_income_statement(entity_data, eliminations, companies)

    %{
      companies: companies,
      entity_data: entity_data,
      transfers: transfers,
      eliminations: eliminations,
      balance_sheet: balance_sheet,
      income_statement: income_statement
    }
  end

  # -- Data Loading --

  defp load_entity_data(companies) do
    Map.new(companies, fn c ->
      bs = Finance.balance_sheet(c.id)
      is = Finance.income_statement(c.id)
      {c.id, %{balance_sheet: bs, income_statement: is}}
    end)
  end

  # -- Eliminations --

  defp build_eliminations(transfers) do
    zero = Decimal.new(0)

    Enum.reduce(transfers, %{total: zero, by_entity: %{}}, fn t, acc ->
      amount = Money.to_decimal(t.amount)
      from_id = t.from_company_id
      to_id = t.to_company_id

      by_entity =
        acc.by_entity
        |> Map.update(from_id, %{assets: amount, liabilities: zero}, fn e ->
          %{e | assets: Money.add(e.assets, amount)}
        end)
        |> Map.update(to_id, %{assets: zero, liabilities: amount}, fn e ->
          %{e | liabilities: Money.add(e.liabilities, amount)}
        end)

      %{acc | total: Money.add(acc.total, amount), by_entity: by_entity}
    end)
  end

  # -- Consolidated Balance Sheet --

  defp build_consolidated_balance_sheet(entity_data, eliminations, companies) do
    ownership_map = Map.new(companies, fn c -> {c.id, c.ownership_pct || 100} end)

    assets = merge_consolidated_rows(entity_data, companies, :balance_sheet, :assets, ownership_map, eliminations)
    liabilities = merge_consolidated_rows(entity_data, companies, :balance_sheet, :liabilities, ownership_map, eliminations)
    equity = merge_consolidated_rows(entity_data, companies, :balance_sheet, :equity, ownership_map, eliminations)

    total_assets = Enum.reduce(assets, Decimal.new(0), fn r, acc -> Money.add(acc, r.consolidated) end)
    total_liabilities = Enum.reduce(liabilities, Decimal.new(0), fn r, acc -> Money.add(acc, r.consolidated) end)
    total_equity = Enum.reduce(equity, Decimal.new(0), fn r, acc -> Money.add(acc, r.consolidated) end)

    total_nci =
      Enum.reduce(companies, Decimal.new(0), fn c, acc ->
        nci_pct = max(100 - (c.ownership_pct || 100), 0)
        entity_eq = entity_bs_total(entity_data, c.id, :equity)
        Money.add(acc, Money.div(Money.mult(entity_eq, nci_pct), 100))
      end)

    total_eliminations =
      Enum.reduce(assets ++ liabilities ++ equity, Decimal.new(0), fn r, acc -> Money.add(acc, r.elimination) end)

    %{
      assets: assets,
      liabilities: liabilities,
      equity: equity,
      total_assets: total_assets,
      total_liabilities: total_liabilities,
      total_equity: total_equity,
      total_nci: total_nci,
      total_eliminations: total_eliminations
    }
  end

  # -- Consolidated Income Statement --

  defp build_consolidated_income_statement(entity_data, eliminations, companies) do
    ownership_map = Map.new(companies, fn c -> {c.id, c.ownership_pct || 100} end)

    revenue = merge_consolidated_is_rows(entity_data, companies, :revenue, ownership_map, eliminations)
    expenses = merge_consolidated_is_rows(entity_data, companies, :expenses, ownership_map, eliminations)

    total_revenue = Enum.reduce(revenue, Decimal.new(0), fn r, acc -> Money.add(acc, r.consolidated) end)
    total_expenses = Enum.reduce(expenses, Decimal.new(0), fn r, acc -> Money.add(acc, r.consolidated) end)
    net_income = Money.sub(total_revenue, total_expenses)

    nci_share =
      Enum.reduce(companies, Decimal.new(0), fn c, acc ->
        nci_pct = max(100 - (c.ownership_pct || 100), 0)
        entity_net = Money.sub(entity_is_total(entity_data, c.id, :total_revenue), entity_is_total(entity_data, c.id, :total_expenses))
        Money.add(acc, Money.div(Money.mult(entity_net, nci_pct), 100))
      end)

    %{
      revenue: revenue,
      expenses: expenses,
      total_revenue: total_revenue,
      total_expenses: total_expenses,
      net_income: net_income,
      nci_share: nci_share
    }
  end

  # -- Row Merging (Balance Sheet) --

  defp merge_consolidated_rows(entity_data, companies, statement, section, ownership_map, eliminations) do
    all_accounts =
      companies
      |> Enum.flat_map(fn c ->
        data = Map.get(entity_data, c.id, %{})
        bs = Map.get(data, statement, %{})
        accounts = Map.get(bs, section, [])
        Enum.map(accounts, fn a -> {a.code, a.name} end)
      end)
      |> Enum.uniq_by(fn {code, _} -> code end)
      |> Enum.sort_by(fn {code, _} -> code end)

    section_elim_total = compute_section_elimination(eliminations, companies, section)

    Enum.map(all_accounts, fn {code, name} ->
      by_entity =
        Map.new(companies, fn c ->
          data = Map.get(entity_data, c.id, %{})
          bs = Map.get(data, statement, %{})
          accounts = Map.get(bs, section, [])
          account = Enum.find(accounts, fn a -> a.code == code end)
          {c.id, if(account, do: account.balance, else: 0)}
        end)

      raw_sum = Enum.reduce(by_entity, Decimal.new(0), fn {_id, val}, acc -> Money.add(acc, val) end)

      elimination =
        if not Money.zero?(raw_sum) and not Money.zero?(section_elim_total) do
          Money.mult(Money.div(Money.abs(raw_sum), section_total_abs(entity_data, companies, statement, section)), section_elim_total)
        else
          Decimal.new(0)
        end

      nci =
        Enum.reduce(companies, Decimal.new(0), fn c, acc ->
          nci_pct = max(100 - Map.get(ownership_map, c.id, 100), 0)
          entity_val = Map.get(by_entity, c.id, 0)
          Money.add(acc, Money.div(Money.mult(entity_val, nci_pct), 100))
        end)

      consolidated = Money.sub(Money.sub(raw_sum, elimination), nci)

      %{
        code: code,
        name: "#{code} - #{name}",
        by_entity: by_entity,
        elimination: elimination,
        nci: nci,
        consolidated: consolidated
      }
    end)
  end

  defp compute_section_elimination(eliminations, companies, section) do
    elim_key = case section do
      :assets -> :assets
      :liabilities -> :liabilities
      :equity -> :equity
    end

    Enum.reduce(companies, Decimal.new(0), fn c, acc ->
      entity_elim = get_in(eliminations, [:by_entity, c.id]) || %{assets: Decimal.new(0), liabilities: Decimal.new(0)}
      Money.add(acc, Money.to_decimal(Map.get(entity_elim, elim_key, 0)))
    end)
  end

  defp section_total_abs(entity_data, companies, statement, section) do
    companies
    |> Enum.flat_map(fn c ->
      data = Map.get(entity_data, c.id, %{})
      bs = Map.get(data, statement, %{})
      Map.get(bs, section, [])
    end)
    |> Enum.reduce(Decimal.new(0), fn a, acc -> Money.add(acc, Money.abs(a.balance)) end)
    |> Money.max(1)
  end

  # -- Row Merging (Income Statement) --

  defp merge_consolidated_is_rows(entity_data, companies, section, ownership_map, eliminations) do
    all_accounts =
      companies
      |> Enum.flat_map(fn c ->
        data = Map.get(entity_data, c.id, %{})
        is = Map.get(data, :income_statement, %{})
        accounts = Map.get(is, section, [])
        Enum.map(accounts, fn a -> {a.code, a.name} end)
      end)
      |> Enum.uniq_by(fn {code, _} -> code end)
      |> Enum.sort_by(fn {code, _} -> code end)

    is_elim_total = eliminations.total

    Enum.map(all_accounts, fn {code, name} ->
      by_entity =
        Map.new(companies, fn c ->
          data = Map.get(entity_data, c.id, %{})
          is = Map.get(data, :income_statement, %{})
          accounts = Map.get(is, section, [])
          account = Enum.find(accounts, fn a -> a.code == code end)
          {c.id, if(account, do: account.amount, else: 0)}
        end)

      raw_sum = Enum.reduce(by_entity, Decimal.new(0), fn {_id, val}, acc -> Money.add(acc, val) end)

      is_section_total =
        companies
        |> Enum.flat_map(fn c ->
          data = Map.get(entity_data, c.id, %{})
          is = Map.get(data, :income_statement, %{})
          Map.get(is, section, [])
        end)
        |> Enum.reduce(Decimal.new(0), fn a, acc -> Money.add(acc, Money.abs(a.amount)) end)
        |> Money.max(1)

      elimination =
        if not Money.zero?(raw_sum) and not Money.zero?(is_elim_total) do
          Money.mult(Money.div(Money.abs(raw_sum), is_section_total), is_elim_total)
        else
          Decimal.new(0)
        end

      nci =
        Enum.reduce(companies, Decimal.new(0), fn c, acc ->
          nci_pct = max(100 - Map.get(ownership_map, c.id, 100), 0)
          entity_val = Map.get(by_entity, c.id, 0)
          Money.add(acc, Money.div(Money.mult(entity_val, nci_pct), 100))
        end)

      consolidated = Money.sub(Money.sub(raw_sum, elimination), nci)

      %{
        code: code,
        name: "#{code} - #{name}",
        by_entity: by_entity,
        elimination: elimination,
        nci: nci,
        consolidated: consolidated
      }
    end)
  end

  # -- Public helpers for entity-level totals (used by LiveView render) --

  def entity_bs_total(entity_data, company_id, section) do
    data = Map.get(entity_data, company_id, %{})
    bs = Map.get(data, :balance_sheet, %{})
    total_key = :"total_#{section}"
    Money.to_decimal(Map.get(bs, total_key, 0))
  end

  def entity_is_total(entity_data, company_id, field) do
    data = Map.get(entity_data, company_id, %{})
    is = Map.get(data, :income_statement, %{})
    Money.to_decimal(Map.get(is, field, 0))
  end

  def sum_field_list(rows, field) do
    Enum.reduce(rows, Decimal.new(0), fn r, acc -> Money.add(acc, Money.to_decimal(Map.get(r, field, 0))) end)
  end
end
