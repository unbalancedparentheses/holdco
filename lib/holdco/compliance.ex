defmodule Holdco.Compliance do
  import Ecto.Query
  alias Holdco.Repo

  alias Holdco.Compliance.{
    TaxDeadline,
    AnnualFiling,
    RegulatoryFiling,
    RegulatoryLicense,
    ComplianceChecklist,
    InsurancePolicy,
    TransferPricingDoc,
    WithholdingTax,
    FatcaReport,
    EsgScore,
    SanctionsList,
    SanctionsEntry,
    SanctionsCheck,
    TransferPricingStudy,
    EsgReport,
    EmissionsRecord,
    RegulatoryCapital,
    BcpPlan,
    InsuranceClaim,
    Litigation,
    RegulatoryChange,
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

  # Compliance Checklists
  def list_compliance_checklists(company_id \\ nil) do
    query = from(cc in ComplianceChecklist, order_by: cc.item, preload: [:company])
    query = if company_id, do: where(query, [cc], cc.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_compliance_checklist!(id),
    do: Repo.get!(ComplianceChecklist, id) |> Repo.preload(:company)

  def create_compliance_checklist(attrs) do
    %ComplianceChecklist{}
    |> ComplianceChecklist.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("compliance_checklists", "create")
  end

  def update_compliance_checklist(%ComplianceChecklist{} = cc, attrs) do
    cc
    |> ComplianceChecklist.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("compliance_checklists", "update")
  end

  def delete_compliance_checklist(%ComplianceChecklist{} = cc) do
    Repo.delete(cc)
    |> audit_and_broadcast("compliance_checklists", "delete")
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

  # Transfer Pricing Docs
  def list_transfer_pricing_docs do
    from(tp in TransferPricingDoc,
      order_by: [desc: tp.inserted_at],
      preload: [:from_company, :to_company]
    )
    |> Repo.all()
  end

  def get_transfer_pricing_doc!(id) do
    Repo.get!(TransferPricingDoc, id) |> Repo.preload([:from_company, :to_company])
  end

  def create_transfer_pricing_doc(attrs) do
    %TransferPricingDoc{}
    |> TransferPricingDoc.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("transfer_pricing_docs", "create")
  end

  def update_transfer_pricing_doc(%TransferPricingDoc{} = tp, attrs) do
    tp
    |> TransferPricingDoc.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("transfer_pricing_docs", "update")
  end

  def delete_transfer_pricing_doc(%TransferPricingDoc{} = tp) do
    Repo.delete(tp)
    |> audit_and_broadcast("transfer_pricing_docs", "delete")
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

  # Sanctions Entries
  def list_sanctions_entries(list_id) do
    from(se in SanctionsEntry, where: se.sanctions_list_id == ^list_id, order_by: se.name)
    |> Repo.all()
  end

  def get_sanctions_entry!(id), do: Repo.get!(SanctionsEntry, id)

  def create_sanctions_entry(attrs) do
    %SanctionsEntry{}
    |> SanctionsEntry.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("sanctions_entries", "create")
  end

  def update_sanctions_entry(%SanctionsEntry{} = se, attrs) do
    se
    |> SanctionsEntry.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("sanctions_entries", "update")
  end

  def delete_sanctions_entry(%SanctionsEntry{} = se) do
    Repo.delete(se)
    |> audit_and_broadcast("sanctions_entries", "delete")
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


  # Transfer Pricing Studies
  def list_transfer_pricing_studies(company_id \\ nil) do
    query = from(tps in TransferPricingStudy, order_by: [desc: tps.fiscal_year], preload: [:company])
    query = if company_id, do: where(query, [tps], tps.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_transfer_pricing_study!(id), do: Repo.get!(TransferPricingStudy, id) |> Repo.preload(:company)

  def create_transfer_pricing_study(attrs) do
    %TransferPricingStudy{}
    |> TransferPricingStudy.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("transfer_pricing_studies", "create")
  end

  def update_transfer_pricing_study(%TransferPricingStudy{} = tps, attrs) do
    tps
    |> TransferPricingStudy.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("transfer_pricing_studies", "update")
  end

  def delete_transfer_pricing_study(%TransferPricingStudy{} = tps) do
    Repo.delete(tps)
    |> audit_and_broadcast("transfer_pricing_studies", "delete")
  end

  def transfer_pricing_summary(company_id \\ nil) do
    query = from(tps in TransferPricingStudy)
    query = if company_id, do: where(query, [tps], tps.company_id == ^company_id), else: query

    by_method =
      from(tps in query,
        group_by: tps.method,
        select: %{method: tps.method, count: count(tps.id), total_amount: sum(tps.transaction_amount)}
      )
      |> Repo.all()

    needing_adjustment =
      from(tps in query,
        where: tps.adjustment_needed > 0,
        select: %{count: count(tps.id), total_adjustment: sum(tps.adjustment_needed)}
      )
      |> Repo.one()

    %{
      by_method: by_method,
      needing_adjustment_count: needing_adjustment.count || 0,
      total_adjustment_amount: needing_adjustment.total_adjustment || Decimal.new(0)
    }
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
  # ── KYC Records ─────────────────────────────────────────

  alias Holdco.Compliance.KycRecord

  def list_kyc_records(company_id \\ nil) do
    query = from(k in KycRecord, order_by: [desc: k.inserted_at], preload: [:company])
    query = if company_id, do: where(query, [k], k.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_kyc_record!(id), do: Repo.get!(KycRecord, id) |> Repo.preload(:company)

  def create_kyc_record(attrs) do
    %KycRecord{}
    |> KycRecord.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("kyc_records", "create")
  end

  def update_kyc_record(%KycRecord{} = record, attrs) do
    record
    |> KycRecord.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("kyc_records", "update")
  end

  def delete_kyc_record(%KycRecord{} = record) do
    Repo.delete(record)
    |> audit_and_broadcast("kyc_records", "delete")
  end

  def kyc_due_for_review do
    today = Date.utc_today()

    from(k in KycRecord,
      where: k.next_review_date <= ^today,
      order_by: k.next_review_date,
      preload: [:company]
    )
    |> Repo.all()
  end

  def kyc_summary do
    by_status =
      from(k in KycRecord,
        group_by: k.verification_status,
        select: %{status: k.verification_status, count: count(k.id)}
      )
      |> Repo.all()

    by_risk =
      from(k in KycRecord,
        group_by: k.risk_level,
        select: %{risk_level: k.risk_level, count: count(k.id)}
      )
      |> Repo.all()

    %{by_status: by_status, by_risk: by_risk}
  end

  # ── Reporting Templates ─────────────────────────────────

  alias Holdco.Compliance.ReportingTemplate

  def list_reporting_templates do
    from(rt in ReportingTemplate, order_by: rt.name)
    |> Repo.all()
  end

  def get_reporting_template!(id), do: Repo.get!(ReportingTemplate, id)

  def create_reporting_template(attrs) do
    %ReportingTemplate{}
    |> ReportingTemplate.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("reporting_templates", "create")
  end

  def update_reporting_template(%ReportingTemplate{} = template, attrs) do
    template
    |> ReportingTemplate.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("reporting_templates", "update")
  end

  def delete_reporting_template(%ReportingTemplate{} = template) do
    Repo.delete(template)
    |> audit_and_broadcast("reporting_templates", "delete")
  end

  def generate_report(template_id, params \\ %{}) do
    template = get_reporting_template!(template_id)

    data =
      case template.template_type do
        "crs" ->
          %{
            template: template,
            type: "crs",
            jurisdiction: template.jurisdiction,
            generated_at: DateTime.utc_now(),
            params: params,
            records: list_kyc_records() |> Enum.filter(&(&1.country_of_residence != nil))
          }

        "fatca" ->
          %{
            template: template,
            type: "fatca",
            jurisdiction: template.jurisdiction,
            generated_at: DateTime.utc_now(),
            params: params,
            records: list_fatca_reports()
          }

        "bo_register" ->
          %{
            template: template,
            type: "bo_register",
            jurisdiction: template.jurisdiction,
            generated_at: DateTime.utc_now(),
            params: params,
            records: Holdco.Corporate.list_companies() |> Enum.map(fn c ->
              %{company: c, owners: Holdco.Corporate.list_beneficial_owners(c.id)}
            end)
          }

        "aml_report" ->
          %{
            template: template,
            type: "aml_report",
            jurisdiction: template.jurisdiction,
            generated_at: DateTime.utc_now(),
            params: params,
            records: list_aml_alerts()
          }

        _ ->
          %{
            template: template,
            type: template.template_type,
            jurisdiction: template.jurisdiction,
            generated_at: DateTime.utc_now(),
            params: params,
            records: []
          }
      end

    {:ok, data}
  end

  # ── AML Alerts ──────────────────────────────────────────

  alias Holdco.Compliance.AmlAlert

  def list_aml_alerts(company_id \\ nil) do
    query = from(a in AmlAlert, order_by: [desc: a.inserted_at], preload: [:company])
    query = if company_id, do: where(query, [a], a.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_aml_alert!(id), do: Repo.get!(AmlAlert, id) |> Repo.preload(:company)

  def create_aml_alert(attrs) do
    %AmlAlert{}
    |> AmlAlert.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("aml_alerts", "create")
  end

  def update_aml_alert(%AmlAlert{} = alert, attrs) do
    alert
    |> AmlAlert.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("aml_alerts", "update")
  end

  def delete_aml_alert(%AmlAlert{} = alert) do
    Repo.delete(alert)
    |> audit_and_broadcast("aml_alerts", "delete")
  end

  def open_aml_alerts do
    from(a in AmlAlert,
      where: a.status in ["open", "investigating", "escalated"],
      order_by: [desc: a.severity, desc: a.inserted_at],
      preload: [:company]
    )
    |> Repo.all()
  end

  def aml_alert_summary do
    by_status =
      from(a in AmlAlert,
        group_by: a.status,
        select: %{status: a.status, count: count(a.id)}
      )
      |> Repo.all()

    by_severity =
      from(a in AmlAlert,
        group_by: a.severity,
        select: %{severity: a.severity, count: count(a.id)}
      )
      |> Repo.all()

    by_type =
      from(a in AmlAlert,
        group_by: a.alert_type,
        select: %{alert_type: a.alert_type, count: count(a.id)}
      )
      |> Repo.all()

    %{by_status: by_status, by_severity: by_severity, by_type: by_type}
  end


  # ── ESG Reports ──────────────────────────────────────────

  def list_esg_reports(company_id \\ nil) do
    query = from(er in EsgReport, order_by: [desc: er.reporting_period_end], preload: [:company])
    query = if company_id, do: where(query, [er], er.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_esg_report!(id), do: Repo.get!(EsgReport, id) |> Repo.preload(:company)

  def create_esg_report(attrs) do
    %EsgReport{}
    |> EsgReport.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("esg_reports", "create")
  end

  def update_esg_report(%EsgReport{} = er, attrs) do
    er
    |> EsgReport.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("esg_reports", "update")
  end

  def delete_esg_report(%EsgReport{} = er) do
    Repo.delete(er)
    |> audit_and_broadcast("esg_reports", "delete")
  end

  def latest_esg_report(company_id) do
    from(er in EsgReport,
      where: er.company_id == ^company_id,
      order_by: [desc: er.reporting_period_end],
      limit: 1,
      preload: [:company]
    )
    |> Repo.one()
  end

  def esg_trend(company_id) do
    from(er in EsgReport,
      where: er.company_id == ^company_id,
      where: not is_nil(er.score),
      order_by: [asc: er.reporting_period_end],
      select: %{
        title: er.title,
        framework: er.framework,
        score: er.score,
        period_end: er.reporting_period_end,
        status: er.status
      }
    )
    |> Repo.all()
  end

  # ── Emissions Records ───────────────────────────────────

  def list_emissions_records(company_id \\ nil) do
    query = from(em in EmissionsRecord, order_by: [desc: em.reporting_year], preload: [:company])
    query = if company_id, do: where(query, [em], em.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_emissions_record!(id), do: Repo.get!(EmissionsRecord, id) |> Repo.preload(:company)

  def create_emissions_record(attrs) do
    %EmissionsRecord{}
    |> EmissionsRecord.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("emissions_records", "create")
  end

  def update_emissions_record(%EmissionsRecord{} = em, attrs) do
    em
    |> EmissionsRecord.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("emissions_records", "update")
  end

  def delete_emissions_record(%EmissionsRecord{} = em) do
    Repo.delete(em)
    |> audit_and_broadcast("emissions_records", "delete")
  end

  def emissions_by_scope(company_id) do
    from(em in EmissionsRecord,
      where: em.company_id == ^company_id,
      group_by: em.scope,
      select: %{scope: em.scope, total_co2e: sum(em.co2_equivalent), count: count(em.id)}
    )
    |> Repo.all()
  end

  def total_emissions(company_id, year) do
    from(em in EmissionsRecord,
      where: em.company_id == ^company_id and em.reporting_year == ^year,
      select: %{total_co2e: sum(em.co2_equivalent), count: count(em.id)}
    )
    |> Repo.one()
  end

  # ── Regulatory Capital ──────────────────────────────────

  def list_regulatory_capital_records(company_id \\ nil) do
    query = from(rc in RegulatoryCapital, order_by: [desc: rc.reporting_date], preload: [:company])
    query = if company_id, do: where(query, [rc], rc.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_regulatory_capital!(id), do: Repo.get!(RegulatoryCapital, id) |> Repo.preload(:company)

  def create_regulatory_capital(attrs) do
    %RegulatoryCapital{}
    |> RegulatoryCapital.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("regulatory_capital", "create")
  end

  def update_regulatory_capital(%RegulatoryCapital{} = rc, attrs) do
    rc
    |> RegulatoryCapital.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("regulatory_capital", "update")
  end

  def delete_regulatory_capital(%RegulatoryCapital{} = rc) do
    Repo.delete(rc)
    |> audit_and_broadcast("regulatory_capital", "delete")
  end

  def latest_capital_position(company_id) do
    from(rc in RegulatoryCapital,
      where: rc.company_id == ^company_id,
      order_by: [desc: rc.reporting_date],
      limit: 1,
      preload: [:company]
    )
    |> Repo.one()
  end

  def capital_trend(company_id) do
    from(rc in RegulatoryCapital,
      where: rc.company_id == ^company_id,
      order_by: [asc: rc.reporting_date],
      select: %{
        reporting_date: rc.reporting_date,
        framework: rc.framework,
        capital_ratio: rc.capital_ratio,
        minimum_required_ratio: rc.minimum_required_ratio,
        status: rc.status
      }
    )
    |> Repo.all()
  end

  # ── BCP Plans ───────────────────────────────────────────

  def list_bcp_plans(company_id \\ nil) do
    query = from(bp in BcpPlan, order_by: bp.plan_name, preload: [:company])
    query = if company_id, do: where(query, [bp], bp.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_bcp_plan!(id), do: Repo.get!(BcpPlan, id) |> Repo.preload(:company)

  def create_bcp_plan(attrs) do
    %BcpPlan{}
    |> BcpPlan.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("bcp_plans", "create")
  end

  def update_bcp_plan(%BcpPlan{} = bp, attrs) do
    bp
    |> BcpPlan.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("bcp_plans", "update")
  end

  def delete_bcp_plan(%BcpPlan{} = bp) do
    Repo.delete(bp)
    |> audit_and_broadcast("bcp_plans", "delete")
  end

  def active_bcp_plans(company_id) do
    from(bp in BcpPlan,
      where: bp.company_id == ^company_id,
      where: bp.status in ["approved", "active"],
      order_by: bp.plan_name,
      preload: [:company]
    )
    |> Repo.all()
  end

  def plans_due_for_testing do
    today = Date.utc_today()

    from(bp in BcpPlan,
      where: bp.status in ["approved", "active"],
      where: bp.next_test_date <= ^today,
      order_by: bp.next_test_date,
      preload: [:company]
    )
    |> Repo.all()
  end

  # ── Insurance Claims ──────────────────────────────────

  def list_insurance_claims(company_id \\ nil) do
    query = from(ic in InsuranceClaim, order_by: [desc: ic.filing_date], preload: [:company, :insurance_policy])
    query = if company_id, do: where(query, [ic], ic.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_insurance_claim!(id), do: Repo.get!(InsuranceClaim, id) |> Repo.preload([:company, :insurance_policy])

  def create_insurance_claim(attrs) do
    %InsuranceClaim{}
    |> InsuranceClaim.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("insurance_claims", "create")
  end

  def update_insurance_claim(%InsuranceClaim{} = ic, attrs) do
    ic
    |> InsuranceClaim.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("insurance_claims", "update")
  end

  def delete_insurance_claim(%InsuranceClaim{} = ic) do
    Repo.delete(ic)
    |> audit_and_broadcast("insurance_claims", "delete")
  end

  def open_claims(company_id \\ nil) do
    query = from(ic in InsuranceClaim,
      where: ic.status in ["filed", "under_review", "approved"],
      order_by: [desc: ic.filing_date],
      preload: [:company, :insurance_policy]
    )
    query = if company_id, do: where(query, [ic], ic.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def claims_summary(company_id \\ nil) do
    query = from(ic in InsuranceClaim)
    query = if company_id, do: where(query, [ic], ic.company_id == ^company_id), else: query

    by_status =
      from(ic in query,
        group_by: ic.status,
        select: %{status: ic.status, count: count(ic.id), total_claimed: sum(ic.claimed_amount)}
      )
      |> Repo.all()

    by_type =
      from(ic in query,
        group_by: ic.claim_type,
        select: %{claim_type: ic.claim_type, count: count(ic.id), total_claimed: sum(ic.claimed_amount)}
      )
      |> Repo.all()

    total_claimed = from(ic in query, select: sum(ic.claimed_amount)) |> Repo.one() || Decimal.new(0)
    total_settled = from(ic in query, select: sum(ic.settled_amount)) |> Repo.one() || Decimal.new(0)

    %{by_status: by_status, by_type: by_type, total_claimed: total_claimed, total_settled: total_settled}
  end

  # ── Litigation ──────────────────────────────────────────

  def list_litigations(company_id \\ nil) do
    query = from(l in Litigation, order_by: [desc: l.filing_date], preload: [:company])
    query = if company_id, do: where(query, [l], l.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_litigation!(id), do: Repo.get!(Litigation, id) |> Repo.preload(:company)

  def create_litigation(attrs) do
    %Litigation{}
    |> Litigation.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("litigations", "create")
  end

  def update_litigation(%Litigation{} = l, attrs) do
    l
    |> Litigation.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("litigations", "update")
  end

  def delete_litigation(%Litigation{} = l) do
    Repo.delete(l)
    |> audit_and_broadcast("litigations", "delete")
  end

  def active_litigation(company_id \\ nil) do
    query = from(l in Litigation,
      where: l.status in ["pre_filing", "active", "discovery", "trial", "appeal"],
      order_by: [desc: l.filing_date],
      preload: [:company]
    )
    query = if company_id, do: where(query, [l], l.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def litigation_exposure(company_id \\ nil) do
    query = from(l in Litigation,
      where: l.status in ["pre_filing", "active", "discovery", "trial", "appeal"]
    )
    query = if company_id, do: where(query, [l], l.company_id == ^company_id), else: query
    from(l in query, select: sum(l.estimated_exposure)) |> Repo.one() || Decimal.new(0)
  end


  # ── Regulatory Changes ──────────────────────────────────

  def list_regulatory_changes do
    from(rc in RegulatoryChange, order_by: [desc: rc.inserted_at])
    |> Repo.all()
  end

  def get_regulatory_change!(id), do: Repo.get!(RegulatoryChange, id)

  def create_regulatory_change(attrs) do
    %RegulatoryChange{}
    |> RegulatoryChange.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("regulatory_changes", "create")
  end

  def update_regulatory_change(%RegulatoryChange{} = rc, attrs) do
    rc
    |> RegulatoryChange.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("regulatory_changes", "update")
  end

  def delete_regulatory_change(%RegulatoryChange{} = rc) do
    Repo.delete(rc)
    |> audit_and_broadcast("regulatory_changes", "delete")
  end

  def pending_regulatory_changes do
    from(rc in RegulatoryChange,
      where: rc.status in ["monitoring", "assessment"],
      order_by: [asc: rc.effective_date]
    )
    |> Repo.all()
  end

  def high_impact_changes do
    from(rc in RegulatoryChange,
      where: rc.impact_assessment in ["high", "critical"],
      order_by: [desc: rc.inserted_at]
    )
    |> Repo.all()
  end
end
