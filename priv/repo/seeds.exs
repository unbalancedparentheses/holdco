# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs

alias Holdco.Repo
alias Holdco.Platform.{Setting, Category}
alias Holdco.Corporate.{Company, BeneficialOwner, KeyPersonnel, ServiceProvider}
alias Holdco.Assets.{AssetHolding, CustodianAccount, PortfolioSnapshot}
alias Holdco.Banking.{BankAccount, Transaction}
alias Holdco.Finance.{Financial, Liability, Dividend}
alias Holdco.Compliance.{TaxDeadline, InsurancePolicy}
alias Holdco.Governance.BoardMeeting
alias Holdco.Documents.Document
alias Holdco.Accounts.{User, UserRole}

# ---------- Admin User ----------

admin =
  case Repo.get_by(User, email: "admin@holdco.local") do
    nil ->
      %User{}
      |> User.email_changeset(%{email: "admin@holdco.local"})
      |> User.confirm_changeset()
      |> Repo.insert!()

    existing ->
      existing
  end

case Repo.get_by(UserRole, user_id: admin.id) do
  nil -> Repo.insert!(%UserRole{user_id: admin.id, role: "admin"})
  _existing -> :ok
end

# ---------- Settings ----------

for {key, value} <- [{"app_name", "Holdco"}, {"tagline", "Open source holding company management"}] do
  case Repo.get_by(Setting, key: key) do
    nil -> Repo.insert!(%Setting{key: key, value: value})
    _existing -> :ok
  end
end

# ---------- Categories ----------

categories = [
  %{name: "Technology", color: "#e8f5e9"},
  %{name: "Finance", color: "#fff3e0"},
  %{name: "Media", color: "#f3e5f5"},
  %{name: "Retail", color: "#fce4ec"},
  %{name: "Holding", color: "#e1f5fe"}
]

for cat <- categories do
  case Repo.get_by(Category, name: cat.name) do
    nil -> Repo.insert!(%Category{name: cat.name, color: cat.color})
    _existing -> :ok
  end
end

# ---------- Companies ----------

find_or_create_company = fn attrs ->
  case Repo.get_by(Company, name: attrs.name) do
    nil -> Repo.insert!(struct(Company, attrs))
    existing -> existing
  end
end

holdings = find_or_create_company.(%{
  name: "Acme Holdings",
  country: "United States",
  category: "Holding",
  is_holding: true,
  shareholders: ~s(["Jane Smith"]),
  directors: ~s(["Jane Smith", "John Doe"]),
  kyc_status: "approved",
  wind_down_status: "active"
})

tech = find_or_create_company.(%{
  name: "Acme Tech",
  country: "United States",
  category: "Technology",
  parent_id: holdings.id,
  ownership_pct: 100,
  wind_down_status: "active"
})

capital = find_or_create_company.(%{
  name: "Acme Capital",
  country: "United States",
  category: "Finance",
  parent_id: holdings.id,
  ownership_pct: 100,
  wind_down_status: "active"
})

media = find_or_create_company.(%{
  name: "Acme Media",
  country: "United Kingdom",
  category: "Media",
  parent_id: holdings.id,
  ownership_pct: 75,
  wind_down_status: "active"
})

retail = find_or_create_company.(%{
  name: "Acme Retail",
  country: "Germany",
  category: "Retail",
  parent_id: holdings.id,
  ownership_pct: 100,
  wind_down_status: "active"
})

# ---------- Asset Holdings ----------

find_or_create_holding = fn attrs ->
  case Repo.get_by(AssetHolding, company_id: attrs.company_id, asset: attrs.asset) do
    nil -> Repo.insert!(struct(AssetHolding, attrs))
    existing -> existing
  end
end

btc = find_or_create_holding.(%{company_id: tech.id, asset: "Bitcoin", ticker: "BTC", quantity: 2.5, unit: "BTC", currency: "USD", asset_type: "crypto"})
_aapl = find_or_create_holding.(%{company_id: tech.id, asset: "Apple Inc", ticker: "AAPL", quantity: 500.0, unit: "shares", currency: "USD", asset_type: "equity"})
_eth = find_or_create_holding.(%{company_id: tech.id, asset: "Ethereum", ticker: "ETH-USD", quantity: 15.0, unit: "ETH", currency: "USD", asset_type: "crypto"})

gold = find_or_create_holding.(%{company_id: capital.id, asset: "Gold", ticker: "XAUUSD", quantity: 50.0, unit: "oz", currency: "USD", asset_type: "commodity"})
_spy = find_or_create_holding.(%{company_id: capital.id, asset: "S&P 500 ETF", ticker: "SPY", quantity: 200.0, unit: "shares", currency: "USD", asset_type: "equity"})
_office = find_or_create_holding.(%{company_id: capital.id, asset: "Office Building - NYC", quantity: 1.0, unit: "property", currency: "USD", asset_type: "real_estate"})

# ---------- Custodian for Gold ----------

case Repo.get_by(CustodianAccount, asset_holding_id: gold.id) do
  nil -> Repo.insert!(%CustodianAccount{asset_holding_id: gold.id, bank: "First National Bank", account_type: "Custody"})
  _existing -> :ok
end

# ---------- Bank Accounts ----------

find_or_create_bank_account = fn attrs ->
  import Ecto.Query
  query = from(b in BankAccount, where: b.company_id == ^attrs.company_id and b.bank_name == ^attrs.bank_name)
  case Repo.one(query) do
    nil -> Repo.insert!(struct(BankAccount, attrs))
    existing -> existing
  end
end

find_or_create_bank_account.(%{company_id: holdings.id, bank_name: "JPMorgan Chase", account_number: "****4521", currency: "USD", account_type: "operating", balance: 1_250_000.0, authorized_signers: ~s(["Jane Smith", "John Doe"])})
find_or_create_bank_account.(%{company_id: capital.id, bank_name: "First National Bank", iban: "US12345678901234", swift: "FNBKUS33", currency: "USD", account_type: "custody", balance: 500_000.0})
find_or_create_bank_account.(%{company_id: tech.id, bank_name: "Silicon Valley Bank", currency: "USD", account_type: "operating", balance: 320_000.0})
find_or_create_bank_account.(%{company_id: retail.id, bank_name: "Deutsche Bank", iban: "DE89370400440532013000", swift: "DEUTDEDB", currency: "EUR", account_type: "operating", balance: 180_000.0})
find_or_create_bank_account.(%{company_id: media.id, bank_name: "Barclays", iban: "GB29NWBK60161331926819", swift: "BARCGB22", currency: "GBP", account_type: "operating", balance: 95_000.0})

# ---------- Transactions ----------

import Ecto.Query

txns = [
  %{company_id: holdings.id, transaction_type: "dividend", description: "Q4 2024 dividend from Acme Tech", amount: 50_000.0, currency: "USD", counterparty: "Acme Tech", date: "2025-01-15"},
  %{company_id: capital.id, transaction_type: "buy", description: "Gold purchase - 10 oz", amount: -23_500.0, currency: "USD", counterparty: "Gold Dealer Inc", date: "2025-01-20"},
  %{company_id: tech.id, transaction_type: "fee", description: "Cloud infrastructure - January", amount: -8_500.0, currency: "USD", counterparty: "AWS", date: "2025-01-31"},
  %{company_id: holdings.id, transaction_type: "transfer", description: "Capital injection to Acme Media", amount: -100_000.0, currency: "USD", counterparty: "Acme Media", date: "2025-02-01"},
  %{company_id: media.id, transaction_type: "deposit", description: "Capital injection from parent", amount: 100_000.0, currency: "GBP", counterparty: "Acme Holdings", date: "2025-02-01"},
  %{company_id: capital.id, transaction_type: "sell", description: "Sold 5 oz Gold", amount: 12_500.0, currency: "USD", counterparty: "Gold Dealer Inc", date: "2025-02-10"},
  %{company_id: tech.id, transaction_type: "fee", description: "Cloud infrastructure - February", amount: -9_200.0, currency: "USD", counterparty: "AWS", date: "2025-02-28"},
  %{company_id: retail.id, transaction_type: "deposit", description: "Q1 retail revenue", amount: 45_000.0, currency: "EUR", counterparty: "Customers", date: "2025-03-15"},
  %{company_id: holdings.id, transaction_type: "dividend", description: "Q1 2025 dividend from Acme Capital", amount: 30_000.0, currency: "USD", counterparty: "Acme Capital", date: "2025-04-15"}
]

if Repo.aggregate(Transaction, :count) == 0 do
  for t <- txns, do: Repo.insert!(struct(Transaction, t))
end

# ---------- Liabilities ----------

if Repo.aggregate(Liability, :count) == 0 do
  Repo.insert!(%Liability{company_id: holdings.id, liability_type: "bank_loan", creditor: "JPMorgan Chase", principal: 500_000.0, currency: "USD", interest_rate: 5.5, maturity_date: "2027-06-30", status: "active"})
  Repo.insert!(%Liability{company_id: retail.id, liability_type: "lease", creditor: "Berlin Properties GmbH", principal: 120_000.0, currency: "EUR", interest_rate: 3.2, maturity_date: "2028-12-31", status: "active"})
  Repo.insert!(%Liability{company_id: tech.id, liability_type: "credit_line", creditor: "Silicon Valley Bank", principal: 200_000.0, currency: "USD", interest_rate: 4.75, maturity_date: "2026-12-31", status: "active"})
end

# ---------- Service Providers ----------

if Repo.aggregate(ServiceProvider, :count) == 0 do
  for sp <- [
    %{company_id: holdings.id, role: "lawyer", name: "Sarah Johnson", firm: "Johnson & Partners LLP", email: "sarah@jpartners.com", phone: "+1-555-0100"},
    %{company_id: holdings.id, role: "accountant", name: "Michael Chen", firm: "Chen Accounting", email: "mchen@chenacct.com"},
    %{company_id: capital.id, role: "auditor", name: "Emily Brown", firm: "Big Four Auditors", email: "ebrown@bigfour.com"},
    %{company_id: retail.id, role: "tax_advisor", name: "Hans Mueller", firm: "Mueller Steuerberatung", email: "hans@mueller-tax.de"}
  ], do: Repo.insert!(struct(ServiceProvider, sp))
end

# ---------- Insurance Policies ----------

if Repo.aggregate(InsurancePolicy, :count) == 0 do
  for ip <- [
    %{company_id: holdings.id, policy_type: "directors_officers", provider: "AIG", policy_number: "DO-2025-001", coverage_amount: 5_000_000.0, premium: 25_000.0, currency: "USD", start_date: "2025-01-01", expiry_date: "2026-01-01"},
    %{company_id: tech.id, policy_type: "cyber", provider: "Chubb", policy_number: "CY-2025-042", coverage_amount: 2_000_000.0, premium: 12_000.0, currency: "USD", start_date: "2025-01-01", expiry_date: "2026-01-01"},
    %{company_id: retail.id, policy_type: "property", provider: "Allianz", policy_number: "PR-2025-DE-789", coverage_amount: 1_000_000.0, premium: 8_000.0, currency: "EUR", start_date: "2025-03-01", expiry_date: "2026-03-01"}
  ], do: Repo.insert!(struct(InsurancePolicy, ip))
end

# ---------- Board Meetings ----------

if Repo.aggregate(BoardMeeting, :count) == 0 do
  for bm <- [
    %{company_id: holdings.id, meeting_type: "annual", scheduled_date: "2025-03-15", status: "scheduled", notes: "Annual general meeting - review 2024 results"},
    %{company_id: holdings.id, meeting_type: "regular", scheduled_date: "2025-06-15", status: "scheduled"},
    %{company_id: tech.id, meeting_type: "special", scheduled_date: "2025-04-01", status: "scheduled", notes: "Review new product launch strategy"}
  ], do: Repo.insert!(struct(BoardMeeting, bm))
end

# ---------- Tax Deadlines ----------

if Repo.aggregate(TaxDeadline, :count) == 0 do
  for td <- [
    %{company_id: holdings.id, jurisdiction: "United States", description: "Federal corporate tax return (Form 1120)", due_date: "2025-04-15", status: "pending"},
    %{company_id: holdings.id, jurisdiction: "United States", description: "Q1 estimated tax payment", due_date: "2025-04-15", status: "pending"},
    %{company_id: tech.id, jurisdiction: "United States", description: "State franchise tax - Delaware", due_date: "2025-06-01", status: "pending"},
    %{company_id: retail.id, jurisdiction: "Germany", description: "Korperschaftsteuer (corporate tax)", due_date: "2025-07-31", status: "pending"},
    %{company_id: media.id, jurisdiction: "United Kingdom", description: "Corporation tax return (CT600)", due_date: "2025-09-30", status: "pending"},
    %{company_id: holdings.id, jurisdiction: "United States", description: "Q2 estimated tax payment", due_date: "2025-06-15", status: "pending"}
  ], do: Repo.insert!(struct(TaxDeadline, td))
end

# ---------- Financials ----------

if Repo.aggregate(Financial, :count) == 0 do
  financials = [
    %{company_id: tech.id, period: "2024-Q1", revenue: 150_000.0, expenses: 95_000.0, currency: "USD"},
    %{company_id: tech.id, period: "2024-Q2", revenue: 175_000.0, expenses: 102_000.0, currency: "USD"},
    %{company_id: tech.id, period: "2024-Q3", revenue: 190_000.0, expenses: 110_000.0, currency: "USD"},
    %{company_id: tech.id, period: "2024-Q4", revenue: 220_000.0, expenses: 125_000.0, currency: "USD"},
    %{company_id: capital.id, period: "2024-Q1", revenue: 85_000.0, expenses: 30_000.0, currency: "USD"},
    %{company_id: capital.id, period: "2024-Q2", revenue: 92_000.0, expenses: 35_000.0, currency: "USD"},
    %{company_id: capital.id, period: "2024-Q3", revenue: 78_000.0, expenses: 28_000.0, currency: "USD"},
    %{company_id: capital.id, period: "2024-Q4", revenue: 105_000.0, expenses: 40_000.0, currency: "USD"},
    %{company_id: retail.id, period: "2024-Q1", revenue: 62_000.0, expenses: 48_000.0, currency: "EUR"},
    %{company_id: retail.id, period: "2024-Q2", revenue: 71_000.0, expenses: 52_000.0, currency: "EUR"},
    %{company_id: retail.id, period: "2024-Q3", revenue: 68_000.0, expenses: 50_000.0, currency: "EUR"},
    %{company_id: retail.id, period: "2024-Q4", revenue: 95_000.0, expenses: 65_000.0, currency: "EUR"}
  ]
  for f <- financials, do: Repo.insert!(struct(Financial, f))
end

# ---------- Documents ----------

if Repo.aggregate(Document, :count) == 0 do
  for doc <- [
    %{company_id: holdings.id, name: "Certificate of Incorporation", doc_type: "certificate"},
    %{company_id: holdings.id, name: "Shareholder Agreement 2024", doc_type: "contract"},
    %{company_id: tech.id, name: "Software License Agreement - AWS", doc_type: "contract"},
    %{company_id: tech.id, name: "Employment Agreement - CTO", doc_type: "contract"},
    %{company_id: capital.id, name: "Investment Policy Statement", doc_type: "filing"},
    %{company_id: retail.id, name: "Lease Agreement - Berlin Office", doc_type: "contract"},
    %{company_id: media.id, name: "Articles of Association", doc_type: "certificate"}
  ], do: Repo.insert!(struct(Document, doc))
end

# ---------- Key Personnel ----------

if Repo.aggregate(KeyPersonnel, :count) == 0 do
  for kp <- [
    %{company_id: holdings.id, name: "Jane Smith", title: "CEO", department: "Executive", email: "jane@acme.com"},
    %{company_id: holdings.id, name: "John Doe", title: "CFO", department: "Finance", email: "john@acme.com"},
    %{company_id: tech.id, name: "Alice Wang", title: "CTO", department: "Engineering", email: "alice@acmetech.com"},
    %{company_id: tech.id, name: "Bob Martinez", title: "VP Engineering", department: "Engineering", email: "bob@acmetech.com"},
    %{company_id: capital.id, name: "Carol Davis", title: "Portfolio Manager", department: "Investments", email: "carol@acmecap.com"},
    %{company_id: retail.id, name: "Dieter Schmidt", title: "Managing Director", department: "Operations", email: "dieter@acmeretail.de"}
  ], do: Repo.insert!(struct(KeyPersonnel, kp))
end

# ---------- Beneficial Owners ----------

if Repo.aggregate(BeneficialOwner, :count) == 0 do
  Repo.insert!(%BeneficialOwner{company_id: holdings.id, name: "Jane Smith", nationality: "United States", ownership_pct: 60.0, control_type: "direct", verified: true, verified_date: "2024-12-01"})
  Repo.insert!(%BeneficialOwner{company_id: holdings.id, name: "John Doe", nationality: "United States", ownership_pct: 40.0, control_type: "direct", verified: true, verified_date: "2024-12-01"})
end

# ---------- Portfolio Snapshots ----------

if Repo.aggregate(PortfolioSnapshot, :count) == 0 do
  snapshots = [
    %{date: "2024-03-31", liquid: 1_800_000.0, marketable: 450_000.0, illiquid: 200_000.0, liabilities: 620_000.0, nav: 1_830_000.0, currency: "USD"},
    %{date: "2024-04-30", liquid: 1_850_000.0, marketable: 470_000.0, illiquid: 200_000.0, liabilities: 620_000.0, nav: 1_900_000.0, currency: "USD"},
    %{date: "2024-05-31", liquid: 1_900_000.0, marketable: 510_000.0, illiquid: 200_000.0, liabilities: 620_000.0, nav: 1_990_000.0, currency: "USD"},
    %{date: "2024-06-30", liquid: 1_920_000.0, marketable: 530_000.0, illiquid: 200_000.0, liabilities: 620_000.0, nav: 2_030_000.0, currency: "USD"},
    %{date: "2024-07-31", liquid: 1_950_000.0, marketable: 490_000.0, illiquid: 200_000.0, liabilities: 620_000.0, nav: 2_020_000.0, currency: "USD"},
    %{date: "2024-08-31", liquid: 1_980_000.0, marketable: 560_000.0, illiquid: 200_000.0, liabilities: 620_000.0, nav: 2_120_000.0, currency: "USD"},
    %{date: "2024-09-30", liquid: 2_010_000.0, marketable: 580_000.0, illiquid: 200_000.0, liabilities: 620_000.0, nav: 2_170_000.0, currency: "USD"},
    %{date: "2024-10-31", liquid: 2_050_000.0, marketable: 620_000.0, illiquid: 200_000.0, liabilities: 620_000.0, nav: 2_250_000.0, currency: "USD"},
    %{date: "2024-11-30", liquid: 2_100_000.0, marketable: 650_000.0, illiquid: 200_000.0, liabilities: 620_000.0, nav: 2_330_000.0, currency: "USD"},
    %{date: "2024-12-31", liquid: 2_150_000.0, marketable: 700_000.0, illiquid: 200_000.0, liabilities: 620_000.0, nav: 2_430_000.0, currency: "USD"},
    %{date: "2025-01-31", liquid: 2_200_000.0, marketable: 720_000.0, illiquid: 200_000.0, liabilities: 620_000.0, nav: 2_500_000.0, currency: "USD"},
    %{date: "2025-02-28", liquid: 2_250_000.0, marketable: 750_000.0, illiquid: 200_000.0, liabilities: 820_000.0, nav: 2_380_000.0, currency: "USD"}
  ]
  for s <- snapshots, do: Repo.insert!(struct(PortfolioSnapshot, s))
end

# ---------- Dividends ----------

if Repo.aggregate(Dividend, :count) == 0 do
  Repo.insert!(%Dividend{company_id: tech.id, amount: 50_000.0, currency: "USD", date: "2025-01-15", recipient: "Acme Holdings", dividend_type: "regular"})
  Repo.insert!(%Dividend{company_id: capital.id, amount: 30_000.0, currency: "USD", date: "2025-04-15", recipient: "Acme Holdings", dividend_type: "regular"})
end

IO.puts("Seeds loaded successfully!")
