defmodule Holdco.Compliance do
  import Ecto.Query
  alias Holdco.Repo

  alias Holdco.Compliance.{
    TaxDeadline,
    AnnualFiling,
    RegulatoryFiling,
    RegulatoryLicense,
    InsurancePolicy,
    WithholdingTax,
    FatcaReport,
    EsgScore,
    SanctionsList,
    SanctionsCheck
  }

  # Tax Deadlines
  def list_tax_deadlines(company_id \\ nil) do
    query = from(td in TaxDeadline, order_by: td.due_date, preload: [:company])
    query = if company_id, do: where(query, [td], td.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_tax_deadline!(id), do: Repo.get!(TaxDeadline, id) |> Repo.preload(:company)

  def create_tax_deadline(attrs) do
    %TaxDeadline{}
    |> TaxDeadline.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("tax_deadlines", "create")
  end

  def update_tax_deadline(%TaxDeadline{} = td, attrs) do
    td
    |> TaxDeadline.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("tax_deadlines", "update")
  end

  def delete_tax_deadline(%TaxDeadline{} = td) do
    Repo.delete(td)
    |> audit_and_broadcast("tax_deadlines", "delete")
  end

  # Annual Filings
  def list_annual_filings(company_id \\ nil) do
    query = from(af in AnnualFiling, order_by: [desc: af.due_date], preload: [:company])
    query = if company_id, do: where(query, [af], af.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_annual_filing!(id), do: Repo.get!(AnnualFiling, id) |> Repo.preload(:company)

  def create_annual_filing(attrs) do
    %AnnualFiling{}
    |> AnnualFiling.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("annual_filings", "create")
  end

  def update_annual_filing(%AnnualFiling{} = af, attrs) do
    af
    |> AnnualFiling.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("annual_filings", "update")
  end

  def delete_annual_filing(%AnnualFiling{} = af) do
    Repo.delete(af)
    |> audit_and_broadcast("annual_filings", "delete")
  end

  # Regulatory Filings
  def list_regulatory_filings(company_id \\ nil) do
    query = from(rf in RegulatoryFiling, order_by: [desc: rf.due_date], preload: [:company])
    query = if company_id, do: where(query, [rf], rf.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_regulatory_filing!(id), do: Repo.get!(RegulatoryFiling, id) |> Repo.preload(:company)

  def create_regulatory_filing(attrs) do
    %RegulatoryFiling{}
    |> RegulatoryFiling.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("regulatory_filings", "create")
  end

  def update_regulatory_filing(%RegulatoryFiling{} = rf, attrs) do
    rf
    |> RegulatoryFiling.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("regulatory_filings", "update")
  end

  def delete_regulatory_filing(%RegulatoryFiling{} = rf) do
    Repo.delete(rf)
    |> audit_and_broadcast("regulatory_filings", "delete")
  end

  # Regulatory Licenses
  def list_regulatory_licenses(company_id \\ nil) do
    query = from(rl in RegulatoryLicense, order_by: rl.license_type, preload: [:company])
    query = if company_id, do: where(query, [rl], rl.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_regulatory_license!(id), do: Repo.get!(RegulatoryLicense, id) |> Repo.preload(:company)

  def create_regulatory_license(attrs) do
    %RegulatoryLicense{}
    |> RegulatoryLicense.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("regulatory_licenses", "create")
  end

  def update_regulatory_license(%RegulatoryLicense{} = rl, attrs) do
    rl
    |> RegulatoryLicense.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("regulatory_licenses", "update")
  end

  def delete_regulatory_license(%RegulatoryLicense{} = rl) do
    Repo.delete(rl)
    |> audit_and_broadcast("regulatory_licenses", "delete")
  end

  # Insurance Policies
  def list_insurance_policies(company_id \\ nil) do
    query = from(ip in InsurancePolicy, order_by: ip.policy_type, preload: [:company])
    query = if company_id, do: where(query, [ip], ip.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_insurance_policy!(id), do: Repo.get!(InsurancePolicy, id) |> Repo.preload(:company)

  def create_insurance_policy(attrs) do
    %InsurancePolicy{}
    |> InsurancePolicy.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("insurance_policies", "create")
  end

  def update_insurance_policy(%InsurancePolicy{} = ip, attrs) do
    ip
    |> InsurancePolicy.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("insurance_policies", "update")
  end

  def delete_insurance_policy(%InsurancePolicy{} = ip) do
    Repo.delete(ip)
    |> audit_and_broadcast("insurance_policies", "delete")
  end

  # Withholding Taxes
  def list_withholding_taxes(company_id \\ nil) do
    query = from(wt in WithholdingTax, order_by: [desc: wt.date], preload: [:company])
    query = if company_id, do: where(query, [wt], wt.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_withholding_tax!(id), do: Repo.get!(WithholdingTax, id) |> Repo.preload(:company)

  def create_withholding_tax(attrs) do
    %WithholdingTax{}
    |> WithholdingTax.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("withholding_taxes", "create")
  end

  def update_withholding_tax(%WithholdingTax{} = wt, attrs) do
    wt
    |> WithholdingTax.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("withholding_taxes", "update")
  end

  def delete_withholding_tax(%WithholdingTax{} = wt) do
    Repo.delete(wt)
    |> audit_and_broadcast("withholding_taxes", "delete")
  end

  # FATCA Reports
  def list_fatca_reports(company_id \\ nil) do
    query = from(fr in FatcaReport, order_by: [desc: fr.reporting_year], preload: [:company])
    query = if company_id, do: where(query, [fr], fr.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_fatca_report!(id), do: Repo.get!(FatcaReport, id) |> Repo.preload(:company)

  def create_fatca_report(attrs) do
    %FatcaReport{}
    |> FatcaReport.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("fatca_reports", "create")
  end

  def update_fatca_report(%FatcaReport{} = fr, attrs) do
    fr
    |> FatcaReport.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("fatca_reports", "update")
  end

  def delete_fatca_report(%FatcaReport{} = fr) do
    Repo.delete(fr)
    |> audit_and_broadcast("fatca_reports", "delete")
  end

  # ESG Scores
  def list_esg_scores(company_id \\ nil) do
    query = from(es in EsgScore, order_by: [desc: es.period], preload: [:company])
    query = if company_id, do: where(query, [es], es.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_esg_score!(id), do: Repo.get!(EsgScore, id) |> Repo.preload(:company)

  def create_esg_score(attrs) do
    %EsgScore{}
    |> EsgScore.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("esg_scores", "create")
  end

  def update_esg_score(%EsgScore{} = es, attrs) do
    es
    |> EsgScore.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("esg_scores", "update")
  end

  def delete_esg_score(%EsgScore{} = es) do
    Repo.delete(es)
    |> audit_and_broadcast("esg_scores", "delete")
  end

  # Sanctions Lists
  def list_sanctions_lists do
    from(sl in SanctionsList, order_by: sl.name, preload: [:entries])
    |> Repo.all()
  end

  def get_sanctions_list!(id), do: Repo.get!(SanctionsList, id) |> Repo.preload(:entries)

  def create_sanctions_list(attrs) do
    %SanctionsList{}
    |> SanctionsList.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("sanctions_lists", "create")
  end

  def update_sanctions_list(%SanctionsList{} = sl, attrs) do
    sl
    |> SanctionsList.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("sanctions_lists", "update")
  end

  def delete_sanctions_list(%SanctionsList{} = sl) do
    Repo.delete(sl)
    |> audit_and_broadcast("sanctions_lists", "delete")
  end

  # Sanctions Checks
  def list_sanctions_checks(company_id \\ nil) do
    query =
      from(sc in SanctionsCheck,
        order_by: [desc: sc.inserted_at],
        preload: [:company, :matched_entry]
      )

    query = if company_id, do: where(query, [sc], sc.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_sanctions_check!(id),
    do: Repo.get!(SanctionsCheck, id) |> Repo.preload([:company, :matched_entry])

  def create_sanctions_check(attrs) do
    %SanctionsCheck{}
    |> SanctionsCheck.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("sanctions_checks", "create")
  end

  def update_sanctions_check(%SanctionsCheck{} = sc, attrs) do
    sc
    |> SanctionsCheck.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("sanctions_checks", "update")
  end

  def delete_sanctions_check(%SanctionsCheck{} = sc) do
    Repo.delete(sc)
    |> audit_and_broadcast("sanctions_checks", "delete")
  end

  # PubSub
  def subscribe, do: Phoenix.PubSub.subscribe(Holdco.PubSub, "compliance")
  defp broadcast(message), do: Phoenix.PubSub.broadcast(Holdco.PubSub, "compliance", message)

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
