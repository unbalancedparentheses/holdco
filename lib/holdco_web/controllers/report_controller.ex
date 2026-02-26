defmodule HoldcoWeb.ReportController do
  use HoldcoWeb, :controller

  alias Holdco.{Portfolio, Finance, Corporate, Compliance}

  def portfolio(conn, _params) do
    nav = Portfolio.calculate_nav()
    allocation = Portfolio.asset_allocation()
    fx_exposure = Portfolio.fx_exposure()
    gains = Portfolio.calculate_gains()

    conn
    |> put_layout(false)
    |> put_root_layout(false)
    |> render(:portfolio,
      nav: nav,
      allocation: allocation,
      fx_exposure: fx_exposure,
      gains: gains,
      generated_at: DateTime.utc_now()
    )
  end

  def financial(conn, _params) do
    financials = Finance.list_financials()
    liabilities = Finance.list_liabilities()
    total_revenue = Finance.total_revenue()
    total_expenses = Finance.total_expenses()
    total_liabilities = Finance.total_liabilities()
    companies = Corporate.list_companies()

    # Group financials by company for P&L breakdown
    financials_by_company =
      financials
      |> Enum.group_by(fn f -> if f.company, do: f.company.name, else: "Unassigned" end)
      |> Enum.sort_by(fn {name, _} -> name end)

    conn
    |> put_layout(false)
    |> put_root_layout(false)
    |> render(:financial,
      financials: financials,
      financials_by_company: financials_by_company,
      liabilities: liabilities,
      total_revenue: total_revenue,
      total_expenses: total_expenses,
      total_liabilities: total_liabilities,
      companies: companies,
      generated_at: DateTime.utc_now()
    )
  end

  def compliance(conn, _params) do
    tax_deadlines = Compliance.list_tax_deadlines()
    regulatory_filings = Compliance.list_regulatory_filings()
    insurance_policies = Compliance.list_insurance_policies()

    conn
    |> put_layout(false)
    |> put_root_layout(false)
    |> render(:compliance,
      tax_deadlines: tax_deadlines,
      regulatory_filings: regulatory_filings,
      insurance_policies: insurance_policies,
      generated_at: DateTime.utc_now()
    )
  end
end
