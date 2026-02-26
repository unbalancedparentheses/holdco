defmodule Holdco.HoldcoFixtures do
  @moduledoc """
  Fixtures for all Holdco contexts.
  """

  # ── Corporate ──────────────────────────────────────────

  def company_fixture(attrs \\ %{}) do
    {:ok, company} =
      Holdco.Corporate.create_company(
        Enum.into(attrs, %{
          name: "Company #{System.unique_integer([:positive])}",
          country: "US"
        })
      )

    company
  end

  def beneficial_owner_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, bo} =
      Holdco.Corporate.create_beneficial_owner(
        Enum.into(attrs, %{company_id: company.id, name: "Owner #{System.unique_integer([:positive])}"})
      )

    bo
  end

  def key_personnel_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, kp} =
      Holdco.Corporate.create_key_personnel(
        Enum.into(attrs, %{company_id: company.id, name: "Person #{System.unique_integer([:positive])}", title: "Director"})
      )

    kp
  end

  def ownership_change_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, oc} =
      Holdco.Corporate.create_ownership_change(
        Enum.into(attrs, %{company_id: company.id, date: "2024-01-01", from_owner: "Alice", to_owner: "Bob"})
      )

    oc
  end

  def service_provider_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, sp} =
      Holdco.Corporate.create_service_provider(
        Enum.into(attrs, %{company_id: company.id, role: "Legal", name: "Law Firm #{System.unique_integer([:positive])}"})
      )

    sp
  end

  def tenant_group_fixture(attrs \\ %{}) do
    slug = "slug-#{System.unique_integer([:positive])}"

    {:ok, tg} =
      Holdco.Corporate.create_tenant_group(
        Enum.into(attrs, %{name: "Tenant #{System.unique_integer([:positive])}", slug: slug})
      )

    tg
  end

  def tenant_membership_fixture(attrs \\ %{}) do
    tenant = Map.get_lazy(attrs, :tenant, fn -> tenant_group_fixture() end)
    user = Map.get_lazy(attrs, :user, fn -> Holdco.AccountsFixtures.user_fixture() end)

    {:ok, tm} =
      Holdco.Corporate.create_tenant_membership(
        Enum.into(attrs, %{tenant_id: tenant.id, user_id: user.id, role: "member"})
      )

    tm
  end

  def entity_permission_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)
    user = Map.get_lazy(attrs, :user, fn -> Holdco.AccountsFixtures.user_fixture() end)

    {:ok, ep} =
      Holdco.Corporate.create_entity_permission(
        Enum.into(attrs, %{company_id: company.id, user_id: user.id, permission_level: "view"})
      )

    ep
  end

  # ── Banking ────────────────────────────────────────────

  def bank_account_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, ba} =
      Holdco.Banking.create_bank_account(
        Enum.into(attrs, %{company_id: company.id, bank_name: "Bank #{System.unique_integer([:positive])}"})
      )

    ba
  end

  def transaction_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, t} =
      Holdco.Banking.create_transaction(
        Enum.into(attrs, %{
          company_id: company.id,
          transaction_type: "credit",
          description: "Test txn",
          amount: 100.0,
          date: "2024-01-15"
        })
      )

    t
  end

  # ── Assets ─────────────────────────────────────────────

  def holding_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, h} =
      Holdco.Assets.create_holding(
        Enum.into(attrs, %{company_id: company.id, asset: "AAPL"})
      )

    h
  end

  def custodian_account_fixture(attrs \\ %{}) do
    holding = Map.get_lazy(attrs, :holding, fn -> holding_fixture() end)

    {:ok, ca} =
      Holdco.Assets.create_custodian_account(
        Enum.into(attrs, %{asset_holding_id: holding.id, bank: "Custodian Bank"})
      )

    ca
  end

  def cost_basis_lot_fixture(attrs \\ %{}) do
    holding = Map.get_lazy(attrs, :holding, fn -> holding_fixture() end)

    {:ok, cbl} =
      Holdco.Assets.create_cost_basis_lot(
        Enum.into(attrs, %{holding_id: holding.id, purchase_date: "2024-01-01", quantity: 100.0, price_per_unit: 150.0})
      )

    cbl
  end

  def crypto_wallet_fixture(attrs \\ %{}) do
    holding = Map.get_lazy(attrs, :holding, fn -> holding_fixture() end)

    {:ok, cw} =
      Holdco.Assets.create_crypto_wallet(
        Enum.into(attrs, %{holding_id: holding.id, wallet_address: "0x#{System.unique_integer([:positive])}"})
      )

    cw
  end

  def real_estate_property_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, re} =
      Holdco.Assets.create_real_estate_property(
        Enum.into(attrs, %{company_id: company.id, name: "Property #{System.unique_integer([:positive])}"})
      )

    re
  end

  def fund_investment_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, fi} =
      Holdco.Assets.create_fund_investment(
        Enum.into(attrs, %{company_id: company.id, fund_name: "Fund #{System.unique_integer([:positive])}"})
      )

    fi
  end

  def portfolio_snapshot_fixture(attrs \\ %{}) do
    {:ok, ps} =
      Holdco.Assets.create_portfolio_snapshot(
        Enum.into(attrs, %{date: "2024-01-01", nav: 1_000_000.0})
      )

    ps
  end

  # ── Finance ────────────────────────────────────────────

  def financial_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, f} =
      Holdco.Finance.create_financial(
        Enum.into(attrs, %{company_id: company.id, period: "2024-Q1"})
      )

    f
  end

  def account_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, a} =
      Holdco.Finance.create_account(
        Enum.into(attrs, %{
          company_id: company.id,
          name: "Account #{System.unique_integer([:positive])}",
          account_type: "asset",
          code: "#{System.unique_integer([:positive])}"
        })
      )

    a
  end

  def journal_entry_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, je} =
      Holdco.Finance.create_journal_entry(
        Enum.into(attrs, %{company_id: company.id, date: "2024-01-01", description: "Test entry"})
      )

    je
  end

  def journal_line_fixture(attrs \\ %{}) do
    entry = Map.get_lazy(attrs, :entry, fn -> journal_entry_fixture() end)
    account = Map.get_lazy(attrs, :account, fn -> account_fixture() end)

    {:ok, jl} =
      Holdco.Finance.create_journal_line(
        Enum.into(attrs, %{entry_id: entry.id, account_id: account.id, debit: 100.0})
      )

    jl
  end

  def inter_company_transfer_fixture(attrs \\ %{}) do
    from_co = Map.get_lazy(attrs, :from_company, fn -> company_fixture() end)
    to_co = Map.get_lazy(attrs, :to_company, fn -> company_fixture() end)

    {:ok, ict} =
      Holdco.Finance.create_inter_company_transfer(
        Enum.into(attrs, %{from_company_id: from_co.id, to_company_id: to_co.id, amount: 5000.0, date: "2024-01-01"})
      )

    ict
  end

  def dividend_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, d} =
      Holdco.Finance.create_dividend(
        Enum.into(attrs, %{company_id: company.id, amount: 1000.0, date: "2024-01-15"})
      )

    d
  end

  def capital_contribution_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, cc} =
      Holdco.Finance.create_capital_contribution(
        Enum.into(attrs, %{company_id: company.id, contributor: "Investor A", amount: 50000.0, date: "2024-01-01"})
      )

    cc
  end

  def tax_payment_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, tp} =
      Holdco.Finance.create_tax_payment(
        Enum.into(attrs, %{company_id: company.id, jurisdiction: "US", tax_type: "income", amount: 2000.0, date: "2024-04-15"})
      )

    tp
  end

  def budget_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, b} =
      Holdco.Finance.create_budget(
        Enum.into(attrs, %{company_id: company.id, period: "2024", category: "Operations"})
      )

    b
  end

  def liability_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, l} =
      Holdco.Finance.create_liability(
        Enum.into(attrs, %{company_id: company.id, liability_type: "loan", creditor: "Bank Corp", principal: 100_000.0})
      )

    l
  end

  # ── Compliance ─────────────────────────────────────────

  def tax_deadline_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, td} =
      Holdco.Compliance.create_tax_deadline(
        Enum.into(attrs, %{company_id: company.id, jurisdiction: "US", description: "Annual filing", due_date: "2024-04-15"})
      )

    td
  end

  def annual_filing_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, af} =
      Holdco.Compliance.create_annual_filing(
        Enum.into(attrs, %{company_id: company.id, jurisdiction: "US", filing_type: "annual_return", due_date: "2024-03-31"})
      )

    af
  end

  def regulatory_filing_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, rf} =
      Holdco.Compliance.create_regulatory_filing(
        Enum.into(attrs, %{company_id: company.id, jurisdiction: "US", filing_type: "10-K", due_date: "2024-03-31"})
      )

    rf
  end

  def regulatory_license_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, rl} =
      Holdco.Compliance.create_regulatory_license(
        Enum.into(attrs, %{company_id: company.id, license_type: "broker-dealer", issuing_authority: "SEC"})
      )

    rl
  end

  def compliance_checklist_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, cc} =
      Holdco.Compliance.create_compliance_checklist(
        Enum.into(attrs, %{company_id: company.id, jurisdiction: "US", item: "KYC verification"})
      )

    cc
  end

  def insurance_policy_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, ip} =
      Holdco.Compliance.create_insurance_policy(
        Enum.into(attrs, %{company_id: company.id, policy_type: "D&O", provider: "Insurer Inc"})
      )

    ip
  end

  def transfer_pricing_doc_fixture(attrs \\ %{}) do
    from_co = Map.get_lazy(attrs, :from_company, fn -> company_fixture() end)
    to_co = Map.get_lazy(attrs, :to_company, fn -> company_fixture() end)

    {:ok, tp} =
      Holdco.Compliance.create_transfer_pricing_doc(
        Enum.into(attrs, %{from_company_id: from_co.id, to_company_id: to_co.id, description: "Management fees"})
      )

    tp
  end

  def withholding_tax_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, wt} =
      Holdco.Compliance.create_withholding_tax(
        Enum.into(attrs, %{
          company_id: company.id, payment_type: "dividend", country_from: "US", country_to: "UK",
          gross_amount: 10000.0, rate: 0.15, tax_amount: 1500.0, date: "2024-01-01"
        })
      )

    wt
  end

  def fatca_report_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, fr} =
      Holdco.Compliance.create_fatca_report(
        Enum.into(attrs, %{company_id: company.id, reporting_year: 2024, jurisdiction: "US"})
      )

    fr
  end

  def esg_score_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, es} =
      Holdco.Compliance.create_esg_score(
        Enum.into(attrs, %{company_id: company.id, period: "2024"})
      )

    es
  end

  def sanctions_list_fixture(attrs \\ %{}) do
    {:ok, sl} =
      Holdco.Compliance.create_sanctions_list(
        Enum.into(attrs, %{name: "OFAC SDN #{System.unique_integer([:positive])}", list_type: "SDN"})
      )

    sl
  end

  def sanctions_entry_fixture(attrs \\ %{}) do
    list = Map.get_lazy(attrs, :sanctions_list, fn -> sanctions_list_fixture() end)

    {:ok, se} =
      Holdco.Compliance.create_sanctions_entry(
        Enum.into(attrs, %{sanctions_list_id: list.id, name: "Sanctioned Entity #{System.unique_integer([:positive])}"})
      )

    se
  end

  def sanctions_check_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, sc} =
      Holdco.Compliance.create_sanctions_check(
        Enum.into(attrs, %{company_id: company.id, checked_name: "Test Entity"})
      )

    sc
  end

  # ── Governance ─────────────────────────────────────────

  def board_meeting_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, bm} =
      Holdco.Governance.create_board_meeting(
        Enum.into(attrs, %{company_id: company.id, scheduled_date: "2024-03-15"})
      )

    bm
  end

  def cap_table_entry_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, ct} =
      Holdco.Governance.create_cap_table_entry(
        Enum.into(attrs, %{company_id: company.id, investor: "Investor A", round_name: "Series A"})
      )

    ct
  end

  def shareholder_resolution_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, sr} =
      Holdco.Governance.create_shareholder_resolution(
        Enum.into(attrs, %{company_id: company.id, title: "Approve dividend", date: "2024-01-15"})
      )

    sr
  end

  def power_of_attorney_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, poa} =
      Holdco.Governance.create_power_of_attorney(
        Enum.into(attrs, %{company_id: company.id, grantor: "CEO", grantee: "CFO"})
      )

    poa
  end

  def equity_incentive_plan_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, eip} =
      Holdco.Governance.create_equity_incentive_plan(
        Enum.into(attrs, %{company_id: company.id, plan_name: "2024 ESOP"})
      )

    eip
  end

  def equity_grant_fixture(attrs \\ %{}) do
    plan = Map.get_lazy(attrs, :plan, fn -> equity_incentive_plan_fixture() end)

    {:ok, eg} =
      Holdco.Governance.create_equity_grant(
        Enum.into(attrs, %{plan_id: plan.id, recipient: "Employee A", grant_date: "2024-01-01"})
      )

    eg
  end

  def deal_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, d} =
      Holdco.Governance.create_deal(
        Enum.into(attrs, %{company_id: company.id, counterparty: "Target Corp"})
      )

    d
  end

  def joint_venture_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, jv} =
      Holdco.Governance.create_joint_venture(
        Enum.into(attrs, %{company_id: company.id, partner: "Partner Inc", name: "JV #{System.unique_integer([:positive])}"})
      )

    jv
  end

  def investor_access_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)
    user = Map.get_lazy(attrs, :user, fn -> Holdco.AccountsFixtures.user_fixture() end)

    {:ok, ia} =
      Holdco.Governance.create_investor_access(
        Enum.into(attrs, %{company_id: company.id, user_id: user.id})
      )

    ia
  end

  # ── Documents ──────────────────────────────────────────

  def document_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, d} =
      Holdco.Documents.create_document(
        Enum.into(attrs, %{company_id: company.id, name: "Doc #{System.unique_integer([:positive])}"})
      )

    d
  end

  def document_version_fixture(attrs \\ %{}) do
    doc = Map.get_lazy(attrs, :document, fn -> document_fixture() end)

    {:ok, dv} =
      Holdco.Documents.create_document_version(
        Enum.into(attrs, %{document_id: doc.id, version_number: 1})
      )

    dv
  end

  def document_upload_fixture(attrs \\ %{}) do
    doc = Map.get_lazy(attrs, :document, fn -> document_fixture() end)

    {:ok, du} =
      Holdco.Documents.create_document_upload(
        Enum.into(attrs, %{document_id: doc.id, file_path: "/tmp/test.pdf", file_name: "test.pdf"})
      )

    du
  end

  # ── Scenarios ──────────────────────────────────────────

  def scenario_fixture(attrs \\ %{}) do
    {:ok, s} =
      Holdco.Scenarios.create_scenario(
        Enum.into(attrs, %{name: "Scenario #{System.unique_integer([:positive])}"})
      )

    s
  end

  def scenario_item_fixture(attrs \\ %{}) do
    scenario = Map.get_lazy(attrs, :scenario, fn -> scenario_fixture() end)

    {:ok, si} =
      Holdco.Scenarios.create_scenario_item(
        Enum.into(attrs, %{scenario_id: scenario.id, name: "Revenue Stream", item_type: "revenue", amount: 10000.0})
      )

    si
  end

  # ── Platform ───────────────────────────────────────────

  def audit_log_fixture(attrs \\ %{}) do
    {:ok, al} =
      Holdco.Platform.create_audit_log(
        Enum.into(attrs, %{action: "create", table_name: "companies"})
      )

    al
  end

  def webhook_fixture(attrs \\ %{}) do
    {:ok, w} =
      Holdco.Platform.create_webhook(
        Enum.into(attrs, %{url: "https://example.com/webhook/#{System.unique_integer([:positive])}"})
      )

    w
  end

  def setting_fixture(attrs \\ %{}) do
    {:ok, s} = Holdco.Platform.upsert_setting(
      attrs[:key] || "key_#{System.unique_integer([:positive])}",
      attrs[:value] || "value"
    )

    s
  end

  def category_fixture(attrs \\ %{}) do
    {:ok, c} =
      Holdco.Platform.create_category(
        Enum.into(attrs, %{name: "Category #{System.unique_integer([:positive])}"})
      )

    c
  end

  def approval_request_fixture(attrs \\ %{}) do
    {:ok, a} =
      Holdco.Platform.create_approval_request(
        Enum.into(attrs, %{requested_by: "user@example.com", table_name: "companies", action: "create"})
      )

    a
  end

  def custom_field_fixture(attrs \\ %{}) do
    {:ok, cf} =
      Holdco.Platform.create_custom_field(
        Enum.into(attrs, %{name: "Field #{System.unique_integer([:positive])}"})
      )

    cf
  end

  def backup_config_fixture(attrs \\ %{}) do
    {:ok, bc} =
      Holdco.Platform.create_backup_config(
        Enum.into(attrs, %{name: "Daily Backup", destination_path: "/backups/daily"})
      )

    bc
  end

  # ── Notifications ──────────────────────────────────────

  def notification_fixture(attrs \\ %{}) do
    user = Map.get_lazy(attrs, :user, fn -> Holdco.AccountsFixtures.user_fixture() end)

    {:ok, n} =
      Holdco.Notifications.create_notification(
        Enum.into(attrs, %{user_id: user.id, title: "Test notification"})
      )

    n
  end

  # ── Collaboration ──────────────────────────────────────

  def comment_fixture(attrs \\ %{}) do
    user = Map.get_lazy(attrs, :user, fn -> Holdco.AccountsFixtures.user_fixture() end)

    {:ok, c} =
      Holdco.Collaboration.create_comment(
        Enum.into(attrs, %{user_id: user.id, entity_type: "company", entity_id: 1, body: "Test comment"})
      )

    c
  end

  # ── Treasury ───────────────────────────────────────────

  def cash_pool_fixture(attrs \\ %{}) do
    {:ok, cp} =
      Holdco.Treasury.create_cash_pool(
        Enum.into(attrs, %{name: "Pool #{System.unique_integer([:positive])}"})
      )

    cp
  end

  def cash_pool_entry_fixture(attrs \\ %{}) do
    pool = Map.get_lazy(attrs, :pool, fn -> cash_pool_fixture() end)
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, cpe} =
      Holdco.Treasury.create_cash_pool_entry(
        Enum.into(attrs, %{pool_id: pool.id, company_id: company.id, allocated_amount: 1000.0})
      )

    cpe
  end

  # ── Pricing ────────────────────────────────────────────

  def price_history_fixture(attrs \\ %{}) do
    {:ok, ph} =
      Holdco.Pricing.record_price(
        attrs[:ticker] || "AAPL",
        attrs[:price] || 150.0,
        attrs[:currency] || "USD"
      )

    ph
  end

  # ── Integrations ───────────────────────────────────────

  def accounting_sync_config_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, asc} =
      Holdco.Integrations.create_accounting_sync_config(
        Enum.into(attrs, %{company_id: company.id, provider: "quickbooks"})
      )

    asc
  end

  def bank_feed_config_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)
    ba = Map.get_lazy(attrs, :bank_account, fn -> bank_account_fixture(%{company: company}) end)

    {:ok, bfc} =
      Holdco.Integrations.create_bank_feed_config(
        Enum.into(attrs, %{company_id: company.id, bank_account_id: ba.id, provider: "plaid"})
      )

    bfc
  end

  def email_digest_config_fixture(attrs \\ %{}) do
    user = Map.get_lazy(attrs, :user, fn -> Holdco.AccountsFixtures.user_fixture() end)

    {:ok, edc} =
      Holdco.Integrations.create_email_digest_config(
        Enum.into(attrs, %{user_id: user.id})
      )

    edc
  end

  def integration_fixture(attrs \\ %{}) do
    provider = attrs[:provider] || "quickbooks_#{System.unique_integer([:positive])}"

    {:ok, i} =
      Holdco.Integrations.upsert_integration(provider, Enum.into(attrs, %{"status" => "connected"}))

    i
  end

  def contact_fixture(attrs \\ %{}) do
    {:ok, contact} =
      Holdco.Collaboration.create_contact(
        Enum.into(attrs, %{
          name: "Contact #{System.unique_integer([:positive])}",
          title: "Director",
          organization: "Acme Corp",
          email: "contact#{System.unique_integer([:positive])}@example.com",
          phone: "+1-555-0100",
          role_tag: "advisor"
        })
      )

    contact
  end

  def project_fixture(attrs \\ %{}) do
    {:ok, project} =
      Holdco.Collaboration.create_project(
        Enum.into(attrs, %{
          name: "Project #{System.unique_integer([:positive])}",
          status: "planned",
          project_type: "fundraise",
          description: "A test project",
          budget: Decimal.new("100000"),
          currency: "USD"
        })
      )

    project
  end

  # ── Depreciation ────────────────────────────────────────

  def fixed_asset_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, fa} =
      Holdco.Depreciation.create_fixed_asset(
        Enum.into(attrs, %{
          company_id: company.id,
          name: "Asset #{System.unique_integer([:positive])}",
          purchase_date: "2024-01-01",
          purchase_price: 10_000.0,
          useful_life_months: 60,
          salvage_value: 1_000.0,
          depreciation_method: "straight_line"
        })
      )

    fa
  end

  # ── Leases ──────────────────────────────────────────────

  def lease_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, lease} =
      Holdco.Finance.create_lease(
        Enum.into(attrs, %{
          company_id: company.id,
          lessor: "Lessor #{System.unique_integer([:positive])}",
          asset_description: "Office Space",
          start_date: "2024-01-01",
          end_date: "2028-12-31",
          monthly_payment: 5_000.0,
          discount_rate: 0.05,
          lease_type: "operating"
        })
      )

    lease
  end

  # ── Analytics ───────────────────────────────────────────

  def kpi_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, kpi} =
      Holdco.Analytics.create_kpi(
        Enum.into(attrs, %{
          company_id: company.id,
          name: "KPI #{System.unique_integer([:positive])}",
          metric_type: "currency",
          target_value: 100_000.0,
          unit: "USD"
        })
      )

    kpi
  end

  def kpi_snapshot_fixture(attrs \\ %{}) do
    kpi = Map.get_lazy(attrs, :kpi, fn -> kpi_fixture() end)

    {:ok, snap} =
      Holdco.Analytics.create_kpi_snapshot(
        Enum.into(attrs, %{
          kpi_id: kpi.id,
          current_value: 85_000.0,
          date: "2024-01-15",
          trend: "up"
        })
      )

    snap
  end

  def segment_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, seg} =
      Holdco.Finance.create_segment(
        Enum.into(attrs, %{
          company_id: company.id,
          name: "Segment #{System.unique_integer([:positive])}",
          segment_type: "business"
        })
      )

    seg
  end

  def report_template_fixture(attrs \\ %{}) do
    user = Map.get_lazy(attrs, :user, fn -> Holdco.AccountsFixtures.user_fixture() end)

    {:ok, rt} =
      Holdco.Analytics.create_report_template(
        Enum.into(attrs, %{
          user_id: user.id,
          name: "Report #{System.unique_integer([:positive])}",
          frequency: "monthly"
        })
      )

    rt
  end
end
