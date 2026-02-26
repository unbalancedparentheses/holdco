defmodule Holdco.Corporate.Company do
  use Ecto.Schema
  import Ecto.Changeset

  schema "companies" do
    field :name, :string
    field :legal_name, :string
    field :country, :string
    field :category, :string
    field :is_holding, :boolean, default: false
    field :ownership_pct, :integer
    field :tax_id, :string
    field :shareholders, :string, default: "[]"
    field :directors, :string, default: "[]"
    field :lawyer_studio, :string
    field :notes, :string
    field :website, :string
    field :kyc_status, :string, default: "not_started"
    field :wind_down_status, :string, default: "active"
    field :formation_date, :string
    field :dissolution_date, :string

    belongs_to :parent, __MODULE__
    has_many :subsidiaries, __MODULE__, foreign_key: :parent_id
    has_many :asset_holdings, Holdco.Assets.AssetHolding
    has_many :bank_accounts, Holdco.Banking.BankAccount
    has_many :transactions, Holdco.Banking.Transaction
    has_many :documents, Holdco.Documents.Document
    has_many :tax_deadlines, Holdco.Compliance.TaxDeadline
    has_many :financials, Holdco.Finance.Financial
    has_many :board_meetings, Holdco.Governance.BoardMeeting
    has_many :beneficial_owners, Holdco.Corporate.BeneficialOwner
    has_many :key_personnel, Holdco.Corporate.KeyPersonnel
    has_many :ownership_changes, Holdco.Corporate.OwnershipChange
    has_many :service_providers, Holdco.Corporate.ServiceProvider
    has_many :insurance_policies, Holdco.Compliance.InsurancePolicy
    has_many :liabilities, Holdco.Finance.Liability
    has_many :dividends, Holdco.Finance.Dividend
    has_many :deals, Holdco.Governance.Deal
    has_many :joint_ventures, Holdco.Governance.JointVenture
    has_many :cap_table, Holdco.Governance.CapTableEntry
    has_many :resolutions, Holdco.Governance.ShareholderResolution
    has_many :equity_plans, Holdco.Governance.EquityIncentivePlan
    has_many :real_estate_properties, Holdco.Assets.RealEstateProperty
    has_many :fund_investments, Holdco.Assets.FundInvestment
    has_many :budgets, Holdco.Finance.Budget
    has_many :regulatory_filings, Holdco.Compliance.RegulatoryFiling
    has_many :regulatory_licenses, Holdco.Compliance.RegulatoryLicense
    has_many :compliance_checklists, Holdco.Compliance.ComplianceChecklist
    has_many :annual_filings, Holdco.Compliance.AnnualFiling
    has_many :powers_of_attorney, Holdco.Governance.PowerOfAttorney
    has_many :esg_scores, Holdco.Compliance.EsgScore
    has_many :sanctions_checks, Holdco.Compliance.SanctionsCheck

    timestamps(type: :utc_datetime)
  end

  def changeset(company, attrs) do
    company
    |> cast(attrs, [:name, :legal_name, :country, :category, :is_holding, :parent_id,
                     :ownership_pct, :tax_id, :shareholders, :directors, :lawyer_studio,
                     :notes, :website, :kyc_status, :wind_down_status, :formation_date,
                     :dissolution_date])
    |> validate_required([:name, :country])
    |> validate_inclusion(:kyc_status, ~w(not_started in_progress approved rejected))
    |> validate_inclusion(:wind_down_status, ~w(active winding_down dissolved))
  end
end
