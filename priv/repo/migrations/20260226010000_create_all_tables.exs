defmodule Holdco.Repo.Migrations.CreateAllTables do
  use Ecto.Migration

  def change do
    # Accounts
    create table(:user_roles) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :role, :string, default: "viewer", null: false
      timestamps()
    end

    create unique_index(:user_roles, [:user_id])

    create table(:api_keys) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :key, :string, null: false
      add :name, :string, null: false
      add :is_active, :boolean, default: true
      add :last_used_at, :utc_datetime
      timestamps()
    end

    create unique_index(:api_keys, [:key])

    # Platform
    create table(:settings) do
      add :key, :string, null: false
      add :value, :text
      timestamps()
    end

    create unique_index(:settings, [:key])

    create table(:categories) do
      add :name, :string, null: false
      add :color, :string, default: "#e0e0e0"
      timestamps()
    end

    create unique_index(:categories, [:name])

    create table(:audit_logs) do
      add :action, :string, null: false
      add :table_name, :string, null: false
      add :record_id, :integer
      add :details, :text
      add :user_id, references(:users, on_delete: :nilify_all)
      timestamps()
    end

    create index(:audit_logs, [:table_name])
    create index(:audit_logs, [:inserted_at])

    create table(:webhooks) do
      add :url, :string, null: false
      add :events, :text, default: "[]"
      add :is_active, :boolean, default: true
      add :secret, :string
      add :notes, :text
      timestamps()
    end

    create table(:approval_requests) do
      add :requested_by, :string, null: false
      add :table_name, :string, null: false
      add :record_id, :integer
      add :action, :string, null: false
      add :payload, :text, default: "{}"
      add :status, :string, default: "pending"
      add :reviewed_by, :string
      add :notes, :text
      add :reviewed_at, :utc_datetime
      timestamps()
    end

    create table(:custom_fields) do
      add :name, :string, null: false
      add :field_type, :string, default: "text"
      add :entity_type, :string, default: "company"
      add :options, :text, default: "[]"
      add :required, :boolean, default: false
      timestamps()
    end

    create table(:custom_field_values) do
      add :custom_field_id, references(:custom_fields, on_delete: :delete_all), null: false
      add :entity_type, :string, null: false
      add :entity_id, :integer, null: false
      add :value, :text
      timestamps()
    end

    create index(:custom_field_values, [:entity_type, :entity_id])

    create table(:backup_configs) do
      add :name, :string, null: false
      add :destination_type, :string, default: "local"
      add :destination_path, :string, null: false
      add :schedule, :string, default: "daily"
      add :retention_days, :integer, default: 30
      add :is_active, :boolean, default: true
      add :last_backup_at, :utc_datetime
      add :notes, :text
      timestamps()
    end

    create table(:backup_logs) do
      add :config_id, references(:backup_configs, on_delete: :delete_all), null: false
      add :status, :string, default: "running"
      add :file_path, :string
      add :file_size_bytes, :bigint
      add :error_message, :text
      add :completed_at, :utc_datetime
      timestamps()
    end

    # Corporate
    create table(:companies) do
      add :name, :string, null: false
      add :legal_name, :string
      add :country, :string, null: false
      add :category, :string
      add :is_holding, :boolean, default: false
      add :parent_id, references(:companies, on_delete: :nilify_all)
      add :ownership_pct, :integer
      add :tax_id, :string
      add :shareholders, :text, default: "[]"
      add :directors, :text, default: "[]"
      add :lawyer_studio, :string
      add :notes, :text
      add :website, :string
      add :kyc_status, :string, default: "not_started"
      add :wind_down_status, :string, default: "active"
      add :formation_date, :string
      add :dissolution_date, :string
      timestamps()
    end

    create index(:companies, [:parent_id])

    create table(:beneficial_owners) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :nationality, :string
      add :ownership_pct, :decimal, default: 0.0
      add :control_type, :string, default: "direct"
      add :verified, :boolean, default: false
      add :verified_date, :string
      add :notes, :text
      timestamps()
    end

    create index(:beneficial_owners, [:company_id])

    create table(:key_personnel) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :title, :string, null: false
      add :department, :string
      add :email, :string
      add :phone, :string
      add :start_date, :string
      add :end_date, :string
      add :notes, :text
      timestamps()
    end

    create index(:key_personnel, [:company_id])

    create table(:ownership_changes) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :date, :string, null: false
      add :from_owner, :string, null: false
      add :to_owner, :string, null: false
      add :ownership_pct, :decimal, default: 0.0
      add :transaction_type, :string, default: "transfer"
      add :notes, :text
      timestamps()
    end

    create index(:ownership_changes, [:company_id])

    create table(:service_providers) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :role, :string, null: false
      add :name, :string, null: false
      add :firm, :string
      add :email, :string
      add :phone, :string
      add :notes, :text
      timestamps()
    end

    create index(:service_providers, [:company_id])

    create table(:tenant_groups) do
      add :name, :string, null: false
      add :slug, :string, null: false
      timestamps()
    end

    create unique_index(:tenant_groups, [:slug])

    create table(:tenant_memberships) do
      add :tenant_id, references(:tenant_groups, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :role, :string, default: "member"
      timestamps()
    end

    create unique_index(:tenant_memberships, [:tenant_id, :user_id])

    create table(:entity_permissions) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :permission_level, :string, default: "view"
      timestamps()
    end

    create unique_index(:entity_permissions, [:user_id, :company_id])

    # Governance
    create table(:board_meetings) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :meeting_type, :string, default: "regular"
      add :scheduled_date, :string, null: false
      add :status, :string, default: "scheduled"
      add :notes, :text
      timestamps()
    end

    create index(:board_meetings, [:company_id])

    create table(:cap_table_entries) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :round_name, :string, null: false
      add :investor, :string, null: false
      add :instrument_type, :string, default: "equity"
      add :shares, :decimal, default: 0.0
      add :price_per_share, :decimal
      add :amount_invested, :decimal, default: 0.0
      add :currency, :string, default: "USD"
      add :date, :string
      add :notes, :text
      timestamps()
    end

    create index(:cap_table_entries, [:company_id])

    create table(:shareholder_resolutions) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :title, :string, null: false
      add :resolution_type, :string, default: "ordinary"
      add :date, :string, null: false
      add :passed, :boolean, default: false
      add :votes_for, :integer, default: 0
      add :votes_against, :integer, default: 0
      add :abstentions, :integer, default: 0
      add :notes, :text
      timestamps()
    end

    create index(:shareholder_resolutions, [:company_id])

    create table(:powers_of_attorney) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :grantor, :string, null: false
      add :grantee, :string, null: false
      add :scope, :text
      add :start_date, :string
      add :end_date, :string
      add :status, :string, default: "active"
      add :notes, :text
      timestamps()
    end

    create index(:powers_of_attorney, [:company_id])

    create table(:equity_incentive_plans) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :plan_name, :string, null: false
      add :total_pool, :integer, default: 0
      add :vesting_schedule, :string
      add :board_approval_date, :string
      add :notes, :text
      timestamps()
    end

    create index(:equity_incentive_plans, [:company_id])

    create table(:equity_grants) do
      add :plan_id, references(:equity_incentive_plans, on_delete: :delete_all), null: false
      add :recipient, :string, null: false
      add :grant_type, :string, default: "options"
      add :quantity, :integer, default: 0
      add :strike_price, :decimal
      add :grant_date, :string
      add :vesting_start, :string
      add :cliff_months, :integer, default: 12
      add :vesting_months, :integer, default: 48
      add :exercised, :integer, default: 0
      add :notes, :text
      timestamps()
    end

    create index(:equity_grants, [:plan_id])

    create table(:deals) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :deal_type, :string, default: "acquisition"
      add :counterparty, :string, null: false
      add :status, :string, default: "pipeline"
      add :value, :decimal
      add :currency, :string, default: "USD"
      add :target_close_date, :string
      add :closed_date, :string
      add :notes, :text
      timestamps()
    end

    create index(:deals, [:company_id])

    create table(:joint_ventures) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :partner, :string, null: false
      add :name, :string, null: false
      add :ownership_pct, :decimal, default: 50.0
      add :formation_date, :string
      add :status, :string, default: "active"
      add :total_value, :decimal
      add :currency, :string, default: "USD"
      add :notes, :text
      timestamps()
    end

    create index(:joint_ventures, [:company_id])

    create table(:investor_access) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :can_view_financials, :boolean, default: true
      add :can_view_holdings, :boolean, default: true
      add :can_view_documents, :boolean, default: false
      add :can_view_cap_table, :boolean, default: true
      add :expires_at, :utc_datetime
      add :notes, :text
      timestamps()
    end

    create unique_index(:investor_access, [:user_id, :company_id])

    # Assets
    create table(:asset_holdings) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :asset, :string, null: false
      add :ticker, :string
      add :quantity, :decimal
      add :unit, :string
      add :currency, :string, default: "USD"
      add :asset_type, :string, default: "other"
      timestamps()
    end

    create index(:asset_holdings, [:company_id])

    create table(:custodian_accounts) do
      add :asset_holding_id, references(:asset_holdings, on_delete: :delete_all), null: false
      add :bank, :string, null: false
      add :account_number, :string
      add :account_type, :string
      add :authorized_persons, :text, default: "[]"
      timestamps()
    end

    create unique_index(:custodian_accounts, [:asset_holding_id])

    create table(:cost_basis_lots) do
      add :holding_id, references(:asset_holdings, on_delete: :delete_all), null: false
      add :purchase_date, :string, null: false
      add :quantity, :decimal, null: false
      add :price_per_unit, :decimal, null: false
      add :fees, :decimal, default: 0.0
      add :currency, :string, default: "USD"
      add :sold_quantity, :decimal, default: 0.0
      add :sold_date, :string
      add :sold_price, :decimal
      add :notes, :text
      timestamps()
    end

    create index(:cost_basis_lots, [:holding_id])

    create table(:crypto_wallets) do
      add :holding_id, references(:asset_holdings, on_delete: :delete_all), null: false
      add :wallet_address, :string, null: false
      add :blockchain, :string, default: "ethereum"
      add :wallet_type, :string, default: "hot"
      add :notes, :text
      timestamps()
    end

    create index(:crypto_wallets, [:holding_id])

    create table(:real_estate_properties) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :address, :text
      add :property_type, :string, default: "commercial"
      add :purchase_date, :string
      add :purchase_price, :decimal
      add :current_valuation, :decimal
      add :rental_income_annual, :decimal
      add :currency, :string, default: "USD"
      add :notes, :text
      timestamps()
    end

    create index(:real_estate_properties, [:company_id])

    create table(:fund_investments) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :fund_name, :string, null: false
      add :fund_type, :string, default: "private_equity"
      add :commitment, :decimal, default: 0.0
      add :called, :decimal, default: 0.0
      add :distributed, :decimal, default: 0.0
      add :nav, :decimal, default: 0.0
      add :currency, :string, default: "USD"
      add :vintage_year, :integer
      add :notes, :text
      timestamps()
    end

    create index(:fund_investments, [:company_id])

    create table(:portfolio_snapshots) do
      add :date, :string, null: false
      add :liquid, :decimal, default: 0.0
      add :marketable, :decimal, default: 0.0
      add :illiquid, :decimal, default: 0.0
      add :liabilities, :decimal, default: 0.0
      add :nav, :decimal, default: 0.0
      add :currency, :string, default: "USD"
      timestamps()
    end

    # Banking
    create table(:bank_accounts) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :bank_name, :string, null: false
      add :account_number, :string
      add :iban, :string
      add :swift, :string
      add :currency, :string, default: "USD"
      add :account_type, :string, default: "operating"
      add :balance, :decimal, default: 0.0
      add :authorized_signers, :text, default: "[]"
      add :notes, :text
      timestamps()
    end

    create index(:bank_accounts, [:company_id])

    create table(:transactions) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :transaction_type, :string, null: false
      add :description, :string, null: false
      add :amount, :decimal, null: false
      add :currency, :string, default: "USD"
      add :counterparty, :string
      add :date, :string, null: false
      add :asset_holding_id, references(:asset_holdings, on_delete: :nilify_all)
      add :notes, :text
      timestamps()
    end

    create index(:transactions, [:company_id])
    create index(:transactions, [:date])

    # Finance
    create table(:financials) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :period, :string, null: false
      add :revenue, :decimal, default: 0.0
      add :expenses, :decimal, default: 0.0
      add :currency, :string, default: "USD"
      add :notes, :text
      timestamps()
    end

    create index(:financials, [:company_id])

    create table(:accounts) do
      add :name, :string, null: false
      add :account_type, :string, null: false
      add :code, :string, null: false
      add :parent_id, references(:accounts, on_delete: :nilify_all)
      add :currency, :string, default: "USD"
      add :notes, :text
      timestamps()
    end

    create unique_index(:accounts, [:code])

    create table(:journal_entries) do
      add :date, :string, null: false
      add :description, :string, null: false
      add :reference, :string
      timestamps()
    end

    create table(:journal_lines) do
      add :entry_id, references(:journal_entries, on_delete: :delete_all), null: false
      add :account_id, references(:accounts, on_delete: :delete_all), null: false
      add :debit, :decimal, default: 0.0
      add :credit, :decimal, default: 0.0
      add :notes, :string
      timestamps()
    end

    create index(:journal_lines, [:entry_id])
    create index(:journal_lines, [:account_id])

    create table(:inter_company_transfers) do
      add :from_company_id, references(:companies, on_delete: :delete_all), null: false
      add :to_company_id, references(:companies, on_delete: :delete_all), null: false
      add :amount, :decimal, null: false
      add :currency, :string, default: "USD"
      add :date, :string, null: false
      add :description, :string
      add :status, :string, default: "completed"
      add :notes, :text
      timestamps()
    end

    create index(:inter_company_transfers, [:from_company_id])
    create index(:inter_company_transfers, [:to_company_id])

    create table(:dividends) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :amount, :decimal, null: false
      add :currency, :string, default: "USD"
      add :date, :string, null: false
      add :recipient, :string
      add :dividend_type, :string, default: "regular"
      add :notes, :text
      timestamps()
    end

    create index(:dividends, [:company_id])

    create table(:capital_contributions) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :contributor, :string, null: false
      add :amount, :decimal, null: false
      add :currency, :string, default: "USD"
      add :date, :string, null: false
      add :contribution_type, :string, default: "cash"
      add :notes, :text
      timestamps()
    end

    create index(:capital_contributions, [:company_id])

    create table(:tax_payments) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :jurisdiction, :string, null: false
      add :tax_type, :string, null: false
      add :amount, :decimal, null: false
      add :currency, :string, default: "USD"
      add :date, :string, null: false
      add :period, :string
      add :status, :string, default: "paid"
      add :notes, :text
      timestamps()
    end

    create index(:tax_payments, [:company_id])

    create table(:budgets) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :period, :string, null: false
      add :category, :string, null: false
      add :budgeted, :decimal, default: 0.0
      add :actual, :decimal, default: 0.0
      add :currency, :string, default: "USD"
      add :notes, :text
      timestamps()
    end

    create index(:budgets, [:company_id])

    # Compliance
    create table(:tax_deadlines) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :jurisdiction, :string, null: false
      add :description, :string, null: false
      add :due_date, :string, null: false
      add :status, :string, default: "pending"
      add :notes, :text
      timestamps()
    end

    create index(:tax_deadlines, [:company_id])

    create table(:annual_filings) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :jurisdiction, :string, null: false
      add :filing_type, :string, null: false
      add :due_date, :string, null: false
      add :filed_date, :string
      add :status, :string, default: "pending"
      add :notes, :text
      timestamps()
    end

    create index(:annual_filings, [:company_id])

    create table(:regulatory_filings) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :jurisdiction, :string, null: false
      add :filing_type, :string, null: false
      add :due_date, :string, null: false
      add :filed_date, :string
      add :status, :string, default: "pending"
      add :reference_number, :string
      add :notes, :text
      timestamps()
    end

    create index(:regulatory_filings, [:company_id])

    create table(:regulatory_licenses) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :license_type, :string, null: false
      add :issuing_authority, :string, null: false
      add :license_number, :string
      add :issue_date, :string
      add :expiry_date, :string
      add :status, :string, default: "active"
      add :notes, :text
      timestamps()
    end

    create index(:regulatory_licenses, [:company_id])

    create table(:compliance_checklists) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :jurisdiction, :string, null: false
      add :item, :string, null: false
      add :category, :string, default: "regulatory"
      add :completed, :boolean, default: false
      add :due_date, :string
      add :completed_date, :string
      add :notes, :text
      timestamps()
    end

    create index(:compliance_checklists, [:company_id])

    create table(:insurance_policies) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :policy_type, :string, null: false
      add :provider, :string, null: false
      add :policy_number, :string
      add :coverage_amount, :decimal
      add :premium, :decimal
      add :currency, :string, default: "USD"
      add :start_date, :string
      add :expiry_date, :string
      add :notes, :text
      timestamps()
    end

    create index(:insurance_policies, [:company_id])

    create table(:transfer_pricing_docs) do
      add :from_company_id, references(:companies, on_delete: :delete_all), null: false
      add :to_company_id, references(:companies, on_delete: :delete_all), null: false
      add :description, :string, null: false
      add :method, :string, default: "comparable_uncontrolled"
      add :amount, :decimal, default: 0.0
      add :currency, :string, default: "USD"
      add :period, :string
      add :notes, :text
      timestamps()
    end

    create table(:withholding_taxes) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :payment_type, :string, null: false
      add :country_from, :string, null: false
      add :country_to, :string, null: false
      add :gross_amount, :decimal, null: false
      add :rate, :decimal, null: false
      add :tax_amount, :decimal, null: false
      add :currency, :string, default: "USD"
      add :date, :string, null: false
      add :notes, :text
      timestamps()
    end

    create index(:withholding_taxes, [:company_id])

    create table(:fatca_reports) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :reporting_year, :integer, null: false
      add :jurisdiction, :string, null: false
      add :report_type, :string, default: "fatca"
      add :status, :string, default: "not_started"
      add :filed_date, :string
      add :notes, :text
      timestamps()
    end

    create index(:fatca_reports, [:company_id])

    create table(:esg_scores) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :period, :string, null: false
      add :environmental_score, :decimal
      add :social_score, :decimal
      add :governance_score, :decimal
      add :overall_score, :decimal
      add :framework, :string, default: "custom"
      add :notes, :text
      timestamps()
    end

    create index(:esg_scores, [:company_id])

    create table(:sanctions_lists) do
      add :name, :string, null: false
      add :list_type, :string, null: false
      add :source_url, :string, default: ""
      add :last_updated, :utc_datetime
      add :entry_count, :integer, default: 0
      timestamps()
    end

    create table(:sanctions_entries) do
      add :sanctions_list_id, references(:sanctions_lists, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :entity_type, :string, default: "individual"
      add :country, :string, default: ""
      add :identifiers, :text, default: ""
      add :notes, :text, default: ""
      timestamps()
    end

    create index(:sanctions_entries, [:sanctions_list_id])

    create table(:sanctions_checks) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :checked_name, :string, null: false
      add :status, :string, default: "clear"
      add :matched_entry_id, references(:sanctions_entries, on_delete: :nilify_all)
      add :notes, :text, default: ""
      timestamps()
    end

    create index(:sanctions_checks, [:company_id])

    # Documents
    create table(:documents) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :doc_type, :string
      add :url, :string
      add :notes, :text
      timestamps()
    end

    create index(:documents, [:company_id])

    create table(:document_versions) do
      add :document_id, references(:documents, on_delete: :delete_all), null: false
      add :version_number, :integer, default: 1
      add :url, :string
      add :uploaded_by, :string
      add :notes, :text
      timestamps()
    end

    create index(:document_versions, [:document_id])

    create table(:document_uploads) do
      add :document_id, references(:documents, on_delete: :delete_all), null: false
      add :storage_backend, :string, default: "local"
      add :file_path, :text, null: false
      add :file_name, :string, null: false
      add :file_size, :bigint, default: 0
      add :content_type, :string, default: ""
      add :checksum, :string, default: ""
      add :uploaded_by, :string, default: ""
      timestamps()
    end

    create index(:document_uploads, [:document_id])

    # Treasury
    create table(:cash_pools) do
      add :name, :string, null: false
      add :currency, :string, default: "USD"
      add :target_balance, :decimal, default: 0.0
      add :notes, :text, default: ""
      timestamps()
    end

    create table(:cash_pool_entries) do
      add :pool_id, references(:cash_pools, on_delete: :delete_all), null: false
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :bank_account_id, references(:bank_accounts, on_delete: :nilify_all)
      add :allocated_amount, :decimal, default: 0.0
      add :notes, :text, default: ""
      timestamps()
    end

    create index(:cash_pool_entries, [:pool_id])

    # Pricing
    create table(:price_history) do
      add :ticker, :string, null: false
      add :price, :decimal, null: false
      add :currency, :string, default: "USD"
      timestamps()
    end

    create index(:price_history, [:ticker])
    create index(:price_history, [:inserted_at])

    # Integrations
    create table(:accounting_sync_configs) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :provider, :string, null: false
      add :external_id, :string, default: ""
      add :access_token, :text, default: ""
      add :refresh_token, :text, default: ""
      add :token_expires_at, :utc_datetime
      add :is_active, :boolean, default: true
      add :last_sync_at, :utc_datetime
      add :sync_direction, :string, default: "both"
      add :notes, :text, default: ""
      timestamps()
    end

    create index(:accounting_sync_configs, [:company_id])

    create table(:accounting_sync_logs) do
      add :config_id, references(:accounting_sync_configs, on_delete: :delete_all), null: false
      add :status, :string, default: "running"
      add :records_synced, :integer, default: 0
      add :error_message, :text, default: ""
      add :completed_at, :utc_datetime
      timestamps()
    end

    create table(:bank_feed_configs) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :bank_account_id, references(:bank_accounts, on_delete: :delete_all), null: false
      add :provider, :string, null: false
      add :external_account_id, :string, default: ""
      add :access_token, :text, default: ""
      add :is_active, :boolean, default: true
      add :last_sync_at, :utc_datetime
      add :notes, :text, default: ""
      timestamps()
    end

    create table(:bank_feed_transactions) do
      add :feed_config_id, references(:bank_feed_configs, on_delete: :delete_all), null: false
      add :external_id, :string, null: false
      add :date, :string, null: false
      add :description, :text, default: ""
      add :amount, :decimal, default: 0.0
      add :currency, :string, default: "USD"
      add :category, :string, default: ""
      add :is_matched, :boolean, default: false
      add :matched_transaction_id, references(:transactions, on_delete: :nilify_all)
      timestamps()
    end

    create table(:signature_requests) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :document_id, references(:documents, on_delete: :delete_all), null: false
      add :provider, :string, null: false
      add :external_id, :string, default: ""
      add :status, :string, default: "draft"
      add :signers, :text, default: ""
      add :sent_at, :utc_datetime
      add :completed_at, :utc_datetime
      add :notes, :text, default: ""
      timestamps()
    end

    create table(:email_digest_configs) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :frequency, :string, default: "weekly"
      add :is_active, :boolean, default: true
      add :include_portfolio, :boolean, default: true
      add :include_deadlines, :boolean, default: true
      add :include_audit_log, :boolean, default: true
      add :include_transactions, :boolean, default: true
      add :last_sent_at, :utc_datetime
      timestamps()
    end

    # Scenarios (new feature)
    create table(:scenarios) do
      add :name, :string, null: false
      add :description, :text
      add :company_id, references(:companies, on_delete: :delete_all)
      add :base_period, :string
      add :projection_months, :integer, default: 12
      add :status, :string, default: "draft"
      timestamps()
    end

    create index(:scenarios, [:company_id])

    create table(:scenario_items) do
      add :scenario_id, references(:scenarios, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :item_type, :string, default: "revenue"
      add :amount, :decimal, default: 0.0
      add :currency, :string, default: "USD"
      add :growth_rate, :decimal, default: 0.0
      add :growth_type, :string, default: "linear"
      add :recurrence, :string, default: "monthly"
      add :probability, :decimal, default: 1.0
      add :start_date, :string
      add :end_date, :string
      add :notes, :text
      timestamps()
    end

    create index(:scenario_items, [:scenario_id])

    # Liabilities (from original Django model)
    create table(:liabilities) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :liability_type, :string, null: false
      add :creditor, :string, null: false
      add :principal, :decimal, null: false
      add :currency, :string, default: "USD"
      add :interest_rate, :decimal
      add :maturity_date, :string
      add :status, :string, default: "active"
      add :notes, :text
      timestamps()
    end

    create index(:liabilities, [:company_id])
  end
end
