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

  def insurance_policy_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, ip} =
      Holdco.Compliance.create_insurance_policy(
        Enum.into(attrs, %{company_id: company.id, policy_type: "D&O", provider: "Insurer Inc"})
      )

    ip
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

  # ── Documents ──────────────────────────────────────────

  def document_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, d} =
      Holdco.Documents.create_document(
        Enum.into(attrs, %{company_id: company.id, name: "Doc #{System.unique_integer([:positive])}"})
      )

    d
  end

  def document_upload_fixture(attrs \\ %{}) do
    doc = Map.get_lazy(attrs, :document, fn -> document_fixture() end)

    {:ok, du} =
      Holdco.Documents.create_document_upload(
        Enum.into(attrs, %{document_id: doc.id, file_path: "/tmp/test.pdf", file_name: "test.pdf"})
      )

    du
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

  # ── Alert Rules & Alerts ─────────────────────────────────

  def alert_rule_fixture(attrs \\ %{}) do
    {:ok, rule} =
      Holdco.Platform.create_alert_rule(
        Enum.into(attrs, %{
          name: "Rule #{System.unique_integer([:positive])}",
          metric: "nav",
          condition: "below",
          threshold: 1_000_000.0,
          severity: "warning"
        })
      )

    rule
  end

  def alert_fixture_for_rule(attrs \\ %{}) do
    rule = Map.get_lazy(attrs, :alert_rule, fn -> alert_rule_fixture() end)

    {:ok, alert} =
      Holdco.Platform.create_alert(
        Enum.into(attrs, %{
          alert_rule_id: rule.id,
          message: "Test alert for rule #{rule.id}",
          severity: rule.severity || "warning",
          metric_value: Decimal.new("500000"),
          threshold_value: rule.threshold
        })
      )

    alert
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

  def notification_channel_fixture(attrs \\ %{}) do
    user = Map.get_lazy(attrs, :user, fn -> Holdco.AccountsFixtures.user_fixture() end)

    {:ok, channel} =
      Holdco.Notifications.create_channel(
        Enum.into(attrs, %{
          user_id: user.id,
          provider: "slack",
          is_active: true,
          config: %{"webhook_url" => "https://hooks.slack.com/services/T00/B00/XXX"},
          event_types: ["alert", "system"]
        })
      )

    channel
  end

  def notification_delivery_fixture(attrs \\ %{}) do
    user = Map.get_lazy(attrs, :user, fn -> Holdco.AccountsFixtures.user_fixture() end)

    notification =
      Map.get_lazy(attrs, :notification, fn ->
        notification_fixture(%{user: user})
      end)

    channel =
      Map.get_lazy(attrs, :channel, fn ->
        notification_channel_fixture(%{user: user})
      end)

    {:ok, delivery} =
      Holdco.Notifications.create_delivery(
        Enum.into(attrs, %{
          notification_id: notification.id,
          channel_id: channel.id,
          provider: channel.provider,
          status: "pending"
        })
      )

    delivery
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
        Enum.into(attrs, %{company_id: company.id, bank_account_id: ba.id, provider: "csv_import"})
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

  # ── Analytics ───────────────────────────────────────────

  def scheduled_report_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, sr} =
      Holdco.Analytics.create_scheduled_report(
        Enum.into(attrs, %{
          company_id: company.id,
          name: "Report #{System.unique_integer([:positive])}",
          report_type: "portfolio_summary",
          frequency: "weekly",
          recipients: "test@example.com",
          format: "html"
        })
      )

    sr
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

  # ── Tasks ────────────────────────────────────────────

  def task_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> nil end)
    user = Map.get_lazy(attrs, :assignee, fn -> nil end)

    base = %{
      title: "Task #{System.unique_integer([:positive])}",
      status: "open",
      priority: "medium"
    }

    base = if company, do: Map.put(base, :company_id, company.id), else: base
    base = if user, do: Map.put(base, :assignee_id, user.id), else: base

    {:ok, task} =
      Holdco.Collaboration.create_task(
        Enum.into(attrs, base)
      )

    task
  end

  # ── Anomalies ────────────────────────────────────────

  def anomaly_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, anomaly} =
      Holdco.Analytics.create_anomaly(
        Enum.into(attrs, %{
          company_id: company.id,
          entity_type: "transaction",
          anomaly_type: "outlier",
          severity: "medium",
          description: "Test anomaly #{System.unique_integer([:positive])}",
          detected_value: 1000.0,
          status: "open"
        })
      )

    anomaly
  end

  # ── Accounting Books ───────────────────────────────────

  def accounting_book_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, book} =
      Holdco.Finance.create_accounting_book(
        Enum.into(attrs, %{
          company_id: company.id,
          name: "Book #{System.unique_integer([:positive])}",
          book_type: "ifrs",
          base_currency: "USD"
        })
      )

    book
  end

  def book_adjustment_fixture(attrs \\ %{}) do
    book = Map.get_lazy(attrs, :book, fn -> accounting_book_fixture() end)

    {:ok, adjustment} =
      Holdco.Finance.create_book_adjustment(
        Enum.into(attrs, %{
          book_id: book.id,
          adjustment_type: "reclassification",
          amount: 1000.0,
          effective_date: "2026-01-15",
          description: "Test adjustment"
        })
      )

    adjustment
  end

  # ── Tax Provisions ──────────────────────────────────────

  def tax_provision_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, tp} =
      Holdco.Tax.create_tax_provision(
        Enum.into(attrs, %{
          company_id: company.id,
          tax_year: 2025,
          jurisdiction: "US",
          provision_type: "current",
          tax_type: "income",
          taxable_income: 100_000.0,
          tax_rate: 21.0,
          tax_amount: 21_000.0,
          status: "estimated"
        })
      )

    tp
  end

  # ── Deferred Taxes ──────────────────────────────────────

  def deferred_tax_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, dt} =
      Holdco.Tax.create_deferred_tax(
        Enum.into(attrs, %{
          company_id: company.id,
          tax_year: 2025,
          description: "Depreciation difference #{System.unique_integer([:positive])}",
          deferred_type: "liability",
          source: "depreciation",
          book_basis: 100_000.0,
          tax_basis: 80_000.0,
          temporary_difference: 20_000.0,
          tax_rate: 21.0,
          deferred_amount: 4_200.0
        })
      )

    dt
  end

  # ── Tax Jurisdictions/Reclaims/Repatriation ────────────

  def jurisdiction_fixture(attrs \\ %{}) do
    {:ok, jurisdiction} =
      Holdco.Tax.create_jurisdiction(
        Enum.into(attrs, %{
          name: "Jurisdiction #{System.unique_integer([:positive])}",
          country_code: "US",
          tax_rate: 0.25,
          tax_type: "income",
          is_active: true
        })
      )

    jurisdiction
  end

  def withholding_reclaim_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, reclaim} =
      Holdco.Tax.create_withholding_reclaim(
        Enum.into(attrs, %{
          company_id: company.id,
          jurisdiction: "DE",
          tax_year: 2025,
          income_type: "dividend",
          gross_amount: 10000.0,
          withholding_rate: 0.2625,
          amount_withheld: 2625.0,
          treaty_rate: 0.15,
          reclaimable_amount: 1125.0,
          reclaimed_amount: 0.0,
          status: "pending"
        })
      )

    reclaim
  end

  def repatriation_plan_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, plan} =
      Holdco.Tax.create_repatriation_plan(
        Enum.into(attrs, %{
          company_id: company.id,
          source_jurisdiction: "IE",
          target_jurisdiction: "US",
          amount: 100000.0,
          currency: "USD",
          mechanism: "dividend",
          withholding_tax_rate: 0.05,
          status: "draft"
        })
      )

    plan
  end

  # ── Contracts ─────────────────────────────────────────

  def contract_fixture(attrs \\ %{}) do
    company = Map.get_lazy(attrs, :company, fn -> company_fixture() end)

    {:ok, contract} =
      Holdco.Corporate.create_contract(
        Enum.into(attrs, %{
          company_id: company.id,
          title: "Contract #{System.unique_integer([:positive])}",
          counterparty: "Acme Corp",
          contract_type: "service"
        })
      )

    contract
  end

  # ── SSO Configs ──────────────────────────────────────────

  def sso_config_fixture(attrs \\ %{}) do
    {:ok, config} =
      Holdco.Platform.create_sso_config(
        Enum.into(attrs, %{
          name: "SSO #{System.unique_integer([:positive])}",
          provider_type: "saml"
        })
      )

    config
  end

  # ── Security Keys ──────────────────────────────────────────

  def security_key_fixture(attrs \\ %{}) do
    user = Map.get_lazy(attrs, :user, fn -> Holdco.AccountsFixtures.user_fixture() end)

    {:ok, key} =
      Holdco.Platform.register_security_key(
        Enum.into(attrs, %{
          user_id: user.id,
          name: "Key #{System.unique_integer([:positive])}",
          credential_id: "cred_#{System.unique_integer([:positive])}",
          public_key: "pk_#{System.unique_integer([:positive])}"
        })
      )

    key
  end

  # ── Data Retention Policies ──────────────────────────────────────────

  def data_retention_policy_fixture(attrs \\ %{}) do
    {:ok, policy} =
      Holdco.Platform.create_data_retention_policy(
        Enum.into(attrs, %{
          name: "Policy #{System.unique_integer([:positive])}",
          data_category: "personal_data",
          retention_period_days: 365,
          legal_basis: "consent",
          action_on_expiry: "delete"
        })
      )

    policy
  end

  # ── Data Deletion Requests ──────────────────────────────────────────

  def data_deletion_request_fixture(attrs \\ %{}) do
    {:ok, request} =
      Holdco.Platform.create_data_deletion_request(
        Enum.into(attrs, %{
          requested_by_email: "user#{System.unique_integer([:positive])}@example.com",
          request_type: "erasure"
        })
      )

    request
  end

  # ── Plugins ──────────────────────────────────────────

  def plugin_fixture(attrs \\ %{}) do
    n = System.unique_integer([:positive])

    {:ok, plugin} =
      Holdco.Platform.install_plugin(
        Enum.into(attrs, %{
          name: "Plugin #{n}",
          slug: "plugin-#{n}",
          description: "Test plugin #{n}",
          version: "1.0.0",
          author: "Test Author",
          plugin_type: "integration",
          status: "installed"
        })
      )

    plugin
  end

  def plugin_hook_fixture(attrs \\ %{}) do
    plugin = Map.get_lazy(attrs, :plugin, fn -> plugin_fixture() end)

    {:ok, hook} =
      Holdco.Platform.create_plugin_hook(
        Enum.into(attrs, %{
          plugin_id: plugin.id,
          hook_point: "after_save",
          handler_function: "MyModule.handle",
          priority: 50,
          is_active: true
        })
      )

    hook
  end

  # ── White Label Config ───────────────────────────────

  def white_label_config_fixture(attrs \\ %{}) do
    n = System.unique_integer([:positive])

    {:ok, config} =
      Holdco.Platform.create_white_label_config(
        Enum.into(attrs, %{
          tenant_name: "Tenant #{n}",
          primary_color: "#3B82F6",
          secondary_color: "#10B981",
          accent_color: "#F59E0B",
          is_active: false
        })
      )

    config
  end

  # ── Webhook Endpoints ────────────────────────────────

  def webhook_endpoint_fixture(attrs \\ %{}) do
    n = System.unique_integer([:positive])

    {:ok, endpoint} =
      Holdco.Platform.create_webhook_endpoint(
        Enum.into(attrs, %{
          name: "Endpoint #{n}",
          url: "https://example.com/webhook/#{n}",
          secret_key: "secret_#{n}",
          events: ["create", "update"],
          is_active: true,
          max_retries: 3
        })
      )

    endpoint
  end

  def webhook_delivery_fixture(attrs \\ %{}) do
    endpoint = Map.get_lazy(attrs, :endpoint, fn -> webhook_endpoint_fixture() end)

    {:ok, delivery} =
      Holdco.Platform.create_webhook_delivery(
        Enum.into(attrs, %{
          endpoint_id: endpoint.id,
          event_type: "create",
          payload: %{"test" => true},
          status: "pending",
          attempts: 0
        })
      )

    delivery
  end

  # ── Notification Logs ────────────────────────────────────────

  def notification_log_fixture(attrs \\ %{}) do
    channel = Map.get_lazy(attrs, :channel, fn -> notification_channel_fixture() end)

    {:ok, log} =
      Holdco.Notifications.create_notification_log(
        Enum.into(attrs, %{
          channel_id: channel.id,
          event_type: "test_event",
          message: "Test notification message",
          status: "pending"
        })
      )

    log
  end

  # ── Collaboration Sessions ─────────────────────────────────

  def collaboration_session_fixture(attrs \\ %{}) do
    user = Map.get_lazy(attrs, :user, fn -> Holdco.AccountsFixtures.user_fixture() end)

    {:ok, session} =
      Holdco.Platform.create_session(
        Enum.into(attrs, %{
          entity_type: "company",
          entity_id: 1,
          user_id: user.id
        })
      )

    session
  end

  # ── Activity Events ──────────────────────────────────

  def activity_event_fixture(attrs \\ %{}) do
    n = System.unique_integer([:positive])

    {:ok, event} =
      Holdco.Platform.create_activity_event(
        Enum.into(attrs, %{
          action: "created",
          entity_type: "company",
          entity_id: n,
          entity_name: "Entity #{n}",
          actor_email: "user#{n}@example.com",
          context_module: "Holdco.Corporate"
        })
      )

    event
  end

  # ── Quick Actions ──────────────────────────────────

  def quick_action_fixture(attrs \\ %{}) do
    n = System.unique_integer([:positive])

    {:ok, action} =
      Holdco.Platform.create_quick_action(
        Enum.into(attrs, %{
          name: "Action #{n}",
          description: "Test action #{n}",
          action_type: "navigate",
          target_path: "/test-#{n}",
          category: "portfolio",
          search_keywords: ["test", "action"],
          sort_order: n
        })
      )

    action
  end

  # ── Data Lineage ──────────────────────────────────

  def data_lineage_fixture(attrs \\ %{}) do
    n = System.unique_integer([:positive])

    {:ok, lineage} =
      Holdco.Platform.create_data_lineage(
        Enum.into(attrs, %{
          source_type: "manual_entry",
          source_identifier: "source-#{n}",
          target_entity_type: "transaction",
          target_entity_id: n,
          transformation: "Direct entry",
          confidence: "high"
        })
      )

    lineage
  end
end
