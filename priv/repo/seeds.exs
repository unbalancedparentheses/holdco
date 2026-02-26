# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs

alias Holdco.Repo
alias Holdco.Platform.{Setting, Category}
alias Holdco.Corporate.{Company, BeneficialOwner, KeyPersonnel, ServiceProvider}
alias Holdco.Assets.{AssetHolding, CustodianAccount, PortfolioSnapshot}
alias Holdco.Banking.{BankAccount, Transaction}
alias Holdco.Finance.{Financial, Liability, Dividend, Account, JournalEntry, JournalLine}
alias Holdco.Compliance.{TaxDeadline, InsurancePolicy}
alias Holdco.Governance.{BoardMeeting, CapTableEntry, ShareholderResolution, Deal, EquityIncentivePlan, JointVenture, PowerOfAttorney}
alias Holdco.Documents.Document
alias Holdco.Accounts.{User, UserRole}

# ---------- Admin User ----------

admin =
  case Repo.get_by(User, email: "admin@holdco.local") do
    nil ->
      %User{}
      |> User.email_changeset(%{email: "admin@holdco.local"})
      |> User.password_changeset(%{password: "admin1234567!"})
      |> User.confirm_changeset()
      |> Repo.insert!()

    existing ->
      # Ensure password is set if user exists but has no password
      if is_nil(existing.hashed_password) do
        existing
        |> User.password_changeset(%{password: "admin1234567!"})
        |> Repo.update!()
      else
        existing
      end
  end

case Repo.get_by(UserRole, user_id: admin.id) do
  nil -> Repo.insert!(%UserRole{user_id: admin.id, role: "admin"})
  _existing -> :ok
end

# ---------- Settings ----------

for {key, value} <- [
      {"app_name", "Holdco"},
      {"tagline", "Open source holding company management"},
      {"asset_types", "equity,etf,crypto,commodity,bond,real_estate,private_equity,fund,other"}
    ] do
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

holdings =
  find_or_create_company.(%{
    name: "Acme Holdings",
    country: "United States",
    category: "Holding",
    is_holding: true,
    shareholders: ~s(["Jane Smith"]),
    directors: ~s(["Jane Smith", "John Doe"]),
    kyc_status: "approved",
    wind_down_status: "active"
  })

tech =
  find_or_create_company.(%{
    name: "Acme Tech",
    country: "United States",
    category: "Technology",
    parent_id: holdings.id,
    ownership_pct: 100,
    wind_down_status: "active"
  })

capital =
  find_or_create_company.(%{
    name: "Acme Capital",
    country: "United States",
    category: "Finance",
    parent_id: holdings.id,
    ownership_pct: 100,
    wind_down_status: "active"
  })

media =
  find_or_create_company.(%{
    name: "Acme Media",
    country: "United Kingdom",
    category: "Media",
    parent_id: holdings.id,
    ownership_pct: 75,
    wind_down_status: "active"
  })

retail =
  find_or_create_company.(%{
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

btc =
  find_or_create_holding.(%{
    company_id: tech.id,
    asset: "Bitcoin",
    ticker: "BTC",
    quantity: 2.5,
    unit: "BTC",
    currency: "USD",
    asset_type: "crypto"
  })

_aapl =
  find_or_create_holding.(%{
    company_id: tech.id,
    asset: "Apple Inc",
    ticker: "AAPL",
    quantity: 500.0,
    unit: "shares",
    currency: "USD",
    asset_type: "equity"
  })

_eth =
  find_or_create_holding.(%{
    company_id: tech.id,
    asset: "Ethereum",
    ticker: "ETH-USD",
    quantity: 15.0,
    unit: "ETH",
    currency: "USD",
    asset_type: "crypto"
  })

gold =
  find_or_create_holding.(%{
    company_id: capital.id,
    asset: "Gold",
    ticker: "XAUUSD",
    quantity: 50.0,
    unit: "oz",
    currency: "USD",
    asset_type: "commodity"
  })

_spy =
  find_or_create_holding.(%{
    company_id: capital.id,
    asset: "S&P 500 ETF",
    ticker: "SPY",
    quantity: 200.0,
    unit: "shares",
    currency: "USD",
    asset_type: "etf"
  })

_office =
  find_or_create_holding.(%{
    company_id: capital.id,
    asset: "Office Building - NYC",
    quantity: 1.0,
    unit: "property",
    currency: "USD",
    asset_type: "real_estate"
  })

_us_treasury =
  find_or_create_holding.(%{
    company_id: capital.id,
    asset: "US Treasury 10Y Note",
    ticker: "ZN",
    quantity: 100.0,
    unit: "contracts",
    currency: "USD",
    asset_type: "bond"
  })

_pe_fund =
  find_or_create_holding.(%{
    company_id: holdings.id,
    asset: "Sequoia Capital Fund XV",
    quantity: 1.0,
    unit: "LP interest",
    currency: "USD",
    asset_type: "private_equity"
  })

_hedge_fund =
  find_or_create_holding.(%{
    company_id: capital.id,
    asset: "Bridgewater All Weather Fund",
    quantity: 5000.0,
    unit: "units",
    currency: "USD",
    asset_type: "fund"
  })

_em_etf =
  find_or_create_holding.(%{
    company_id: capital.id,
    asset: "Emerging Markets ETF",
    ticker: "VWO",
    quantity: 350.0,
    unit: "shares",
    currency: "USD",
    asset_type: "etf"
  })

# ---------- Custodian for Gold ----------

case Repo.get_by(CustodianAccount, asset_holding_id: gold.id) do
  nil ->
    Repo.insert!(%CustodianAccount{
      asset_holding_id: gold.id,
      bank: "First National Bank",
      account_type: "Custody"
    })

  _existing ->
    :ok
end

# ---------- Bank Accounts ----------

find_or_create_bank_account = fn attrs ->
  import Ecto.Query

  query =
    from(b in BankAccount,
      where: b.company_id == ^attrs.company_id and b.bank_name == ^attrs.bank_name
    )

  case Repo.one(query) do
    nil -> Repo.insert!(struct(BankAccount, attrs))
    existing -> existing
  end
end

find_or_create_bank_account.(%{
  company_id: holdings.id,
  bank_name: "JPMorgan Chase",
  account_number: "****4521",
  currency: "USD",
  account_type: "operating",
  balance: 1_250_000.0,
  authorized_signers: ~s(["Jane Smith", "John Doe"])
})

find_or_create_bank_account.(%{
  company_id: capital.id,
  bank_name: "First National Bank",
  iban: "US12345678901234",
  swift: "FNBKUS33",
  currency: "USD",
  account_type: "custody",
  balance: 500_000.0
})

find_or_create_bank_account.(%{
  company_id: tech.id,
  bank_name: "Silicon Valley Bank",
  currency: "USD",
  account_type: "operating",
  balance: 320_000.0
})

find_or_create_bank_account.(%{
  company_id: retail.id,
  bank_name: "Deutsche Bank",
  iban: "DE89370400440532013000",
  swift: "DEUTDEDB",
  currency: "EUR",
  account_type: "operating",
  balance: 180_000.0
})

find_or_create_bank_account.(%{
  company_id: media.id,
  bank_name: "Barclays",
  iban: "GB29NWBK60161331926819",
  swift: "BARCGB22",
  currency: "GBP",
  account_type: "operating",
  balance: 95_000.0
})

# ---------- Transactions ----------

import Ecto.Query

txns = [
  %{
    company_id: holdings.id,
    transaction_type: "dividend",
    description: "Q4 2024 dividend from Acme Tech",
    amount: 50_000.0,
    currency: "USD",
    counterparty: "Acme Tech",
    date: "2025-01-15"
  },
  %{
    company_id: capital.id,
    transaction_type: "buy",
    description: "Gold purchase - 10 oz",
    amount: -23_500.0,
    currency: "USD",
    counterparty: "Gold Dealer Inc",
    date: "2025-01-20"
  },
  %{
    company_id: tech.id,
    transaction_type: "fee",
    description: "Cloud infrastructure - January",
    amount: -8_500.0,
    currency: "USD",
    counterparty: "AWS",
    date: "2025-01-31"
  },
  %{
    company_id: holdings.id,
    transaction_type: "transfer",
    description: "Capital injection to Acme Media",
    amount: -100_000.0,
    currency: "USD",
    counterparty: "Acme Media",
    date: "2025-02-01"
  },
  %{
    company_id: media.id,
    transaction_type: "deposit",
    description: "Capital injection from parent",
    amount: 100_000.0,
    currency: "GBP",
    counterparty: "Acme Holdings",
    date: "2025-02-01"
  },
  %{
    company_id: capital.id,
    transaction_type: "sell",
    description: "Sold 5 oz Gold",
    amount: 12_500.0,
    currency: "USD",
    counterparty: "Gold Dealer Inc",
    date: "2025-02-10"
  },
  %{
    company_id: tech.id,
    transaction_type: "fee",
    description: "Cloud infrastructure - February",
    amount: -9_200.0,
    currency: "USD",
    counterparty: "AWS",
    date: "2025-02-28"
  },
  %{
    company_id: retail.id,
    transaction_type: "deposit",
    description: "Q1 retail revenue",
    amount: 45_000.0,
    currency: "EUR",
    counterparty: "Customers",
    date: "2025-03-15"
  },
  %{
    company_id: holdings.id,
    transaction_type: "dividend",
    description: "Q1 2025 dividend from Acme Capital",
    amount: 30_000.0,
    currency: "USD",
    counterparty: "Acme Capital",
    date: "2025-04-15"
  }
]

if Repo.aggregate(Transaction, :count) == 0 do
  for t <- txns, do: Repo.insert!(struct(Transaction, t))
end

# ---------- Liabilities ----------

if Repo.aggregate(Liability, :count) == 0 do
  Repo.insert!(%Liability{
    company_id: holdings.id,
    liability_type: "bank_loan",
    creditor: "JPMorgan Chase",
    principal: 500_000.0,
    currency: "USD",
    interest_rate: 5.5,
    maturity_date: "2027-06-30",
    status: "active"
  })

  Repo.insert!(%Liability{
    company_id: retail.id,
    liability_type: "lease",
    creditor: "Berlin Properties GmbH",
    principal: 120_000.0,
    currency: "EUR",
    interest_rate: 3.2,
    maturity_date: "2028-12-31",
    status: "active"
  })

  Repo.insert!(%Liability{
    company_id: tech.id,
    liability_type: "credit_line",
    creditor: "Silicon Valley Bank",
    principal: 200_000.0,
    currency: "USD",
    interest_rate: 4.75,
    maturity_date: "2026-12-31",
    status: "active"
  })
end

# ---------- Service Providers ----------

if Repo.aggregate(ServiceProvider, :count) == 0 do
  for sp <- [
        %{
          company_id: holdings.id,
          role: "lawyer",
          name: "Sarah Johnson",
          firm: "Johnson & Partners LLP",
          email: "sarah@jpartners.com",
          phone: "+1-555-0100"
        },
        %{
          company_id: holdings.id,
          role: "accountant",
          name: "Michael Chen",
          firm: "Chen Accounting",
          email: "mchen@chenacct.com"
        },
        %{
          company_id: capital.id,
          role: "auditor",
          name: "Emily Brown",
          firm: "Big Four Auditors",
          email: "ebrown@bigfour.com"
        },
        %{
          company_id: retail.id,
          role: "tax_advisor",
          name: "Hans Mueller",
          firm: "Mueller Steuerberatung",
          email: "hans@mueller-tax.de"
        }
      ],
      do: Repo.insert!(struct(ServiceProvider, sp))
end

# ---------- Insurance Policies ----------

if Repo.aggregate(InsurancePolicy, :count) == 0 do
  for ip <- [
        %{
          company_id: holdings.id,
          policy_type: "directors_officers",
          provider: "AIG",
          policy_number: "DO-2025-001",
          coverage_amount: 5_000_000.0,
          premium: 25_000.0,
          currency: "USD",
          start_date: "2025-01-01",
          expiry_date: "2026-01-01"
        },
        %{
          company_id: tech.id,
          policy_type: "cyber",
          provider: "Chubb",
          policy_number: "CY-2025-042",
          coverage_amount: 2_000_000.0,
          premium: 12_000.0,
          currency: "USD",
          start_date: "2025-01-01",
          expiry_date: "2026-01-01"
        },
        %{
          company_id: retail.id,
          policy_type: "property",
          provider: "Allianz",
          policy_number: "PR-2025-DE-789",
          coverage_amount: 1_000_000.0,
          premium: 8_000.0,
          currency: "EUR",
          start_date: "2025-03-01",
          expiry_date: "2026-03-01"
        }
      ],
      do: Repo.insert!(struct(InsurancePolicy, ip))
end

# ---------- Board Meetings ----------

if Repo.aggregate(BoardMeeting, :count) == 0 do
  for bm <- [
        %{
          company_id: holdings.id,
          meeting_type: "annual",
          scheduled_date: "2025-03-15",
          status: "scheduled",
          notes: "Annual general meeting - review 2024 results"
        },
        %{
          company_id: holdings.id,
          meeting_type: "regular",
          scheduled_date: "2025-06-15",
          status: "scheduled"
        },
        %{
          company_id: tech.id,
          meeting_type: "special",
          scheduled_date: "2025-04-01",
          status: "scheduled",
          notes: "Review new product launch strategy"
        }
      ],
      do: Repo.insert!(struct(BoardMeeting, bm))
end

# ---------- Cap Table ----------

if Repo.aggregate(CapTableEntry, :count) == 0 do
  for ct <- [
        %{
          company_id: holdings.id,
          investor: "Jane Smith",
          round_name: "Founder",
          instrument_type: "equity",
          shares: 600_000.0,
          price_per_share: 1.0,
          amount_invested: 600_000.0,
          currency: "USD",
          date: "2020-01-01"
        },
        %{
          company_id: holdings.id,
          investor: "John Doe",
          round_name: "Founder",
          instrument_type: "equity",
          shares: 400_000.0,
          price_per_share: 1.0,
          amount_invested: 400_000.0,
          currency: "USD",
          date: "2020-01-01"
        },
        %{
          company_id: tech.id,
          investor: "Acme Holdings",
          round_name: "Incorporation",
          instrument_type: "equity",
          shares: 1_000_000.0,
          price_per_share: 1.0,
          amount_invested: 1_000_000.0,
          currency: "USD",
          date: "2020-06-01"
        }
      ],
      do: Repo.insert!(struct(CapTableEntry, ct))
end

# ---------- Shareholder Resolutions ----------

if Repo.aggregate(ShareholderResolution, :count) == 0 do
  for sr <- [
        %{
          company_id: holdings.id,
          title: "Approve 2024 Annual Accounts",
          resolution_type: "ordinary",
          date: "2025-03-15",
          passed: true,
          votes_for: 1_000_000,
          votes_against: 0
        },
        %{
          company_id: holdings.id,
          title: "Authorize Share Buyback Programme",
          resolution_type: "special",
          date: "2025-03-15",
          passed: true,
          votes_for: 800_000,
          votes_against: 200_000
        },
        %{
          company_id: tech.id,
          title: "Appoint New Board Director",
          resolution_type: "ordinary",
          date: "2025-04-01",
          passed: false,
          votes_for: 400_000,
          votes_against: 600_000
        }
      ],
      do: Repo.insert!(struct(ShareholderResolution, sr))
end

# ---------- Deals ----------

if Repo.aggregate(Deal, :count) == 0 do
  for d <- [
        %{
          company_id: holdings.id,
          deal_type: "acquisition",
          counterparty: "Nordic SaaS AB",
          status: "pipeline",
          value: 2_500_000.0,
          currency: "USD",
          target_close_date: "2025-09-30",
          notes: "Early-stage SaaS company in Nordics"
        },
        %{
          company_id: capital.id,
          deal_type: "investment",
          counterparty: "GreenEnergy Fund III",
          status: "due_diligence",
          value: 500_000.0,
          currency: "USD",
          target_close_date: "2025-06-15"
        }
      ],
      do: Repo.insert!(struct(Deal, d))
end

# ---------- Equity Incentive Plans ----------

if Repo.aggregate(EquityIncentivePlan, :count) == 0 do
  for ep <- [
        %{
          company_id: tech.id,
          plan_name: "2024 Employee Stock Option Plan",
          total_pool: 100_000,
          vesting_schedule: "4-year with 1-year cliff",
          board_approval_date: "2024-01-15"
        },
        %{
          company_id: holdings.id,
          plan_name: "Executive Phantom Share Plan",
          total_pool: 50_000,
          vesting_schedule: "3-year quarterly vesting",
          board_approval_date: "2024-06-01"
        }
      ],
      do: Repo.insert!(struct(EquityIncentivePlan, ep))
end

# ---------- Joint Ventures ----------

if Repo.aggregate(JointVenture, :count) == 0 do
  for jv <- [
        %{
          company_id: media.id,
          name: "Digital Content Partners",
          partner: "StreamCo Ltd",
          ownership_pct: 50.0,
          formation_date: "2024-09-01",
          status: "active",
          total_value: 800_000.0,
          currency: "GBP"
        },
        %{
          company_id: retail.id,
          name: "EU Distribution Alliance",
          partner: "LogiCorp GmbH",
          ownership_pct: 60.0,
          formation_date: "2024-11-15",
          status: "active",
          total_value: 350_000.0,
          currency: "EUR"
        }
      ],
      do: Repo.insert!(struct(JointVenture, jv))
end

# ---------- Powers of Attorney ----------

if Repo.aggregate(PowerOfAttorney, :count) == 0 do
  for poa <- [
        %{
          company_id: holdings.id,
          grantor: "Acme Holdings",
          grantee: "Sarah Johnson (Johnson & Partners LLP)",
          scope: "Corporate filings and regulatory submissions",
          start_date: "2025-01-01",
          end_date: "2025-12-31",
          status: "active"
        },
        %{
          company_id: retail.id,
          grantor: "Acme Retail",
          grantee: "Hans Mueller (Mueller Steuerberatung)",
          scope: "German tax filings and audit representation",
          start_date: "2025-01-01",
          end_date: "2025-12-31",
          status: "active"
        }
      ],
      do: Repo.insert!(struct(PowerOfAttorney, poa))
end

# ---------- Tax Deadlines ----------

if Repo.aggregate(TaxDeadline, :count) == 0 do
  for td <- [
        %{
          company_id: holdings.id,
          jurisdiction: "United States",
          description: "Federal corporate tax return (Form 1120)",
          due_date: "2025-04-15",
          status: "pending"
        },
        %{
          company_id: holdings.id,
          jurisdiction: "United States",
          description: "Q1 estimated tax payment",
          due_date: "2025-04-15",
          status: "pending"
        },
        %{
          company_id: tech.id,
          jurisdiction: "United States",
          description: "State franchise tax - Delaware",
          due_date: "2025-06-01",
          status: "pending"
        },
        %{
          company_id: retail.id,
          jurisdiction: "Germany",
          description: "Korperschaftsteuer (corporate tax)",
          due_date: "2025-07-31",
          status: "pending"
        },
        %{
          company_id: media.id,
          jurisdiction: "United Kingdom",
          description: "Corporation tax return (CT600)",
          due_date: "2025-09-30",
          status: "pending"
        },
        %{
          company_id: holdings.id,
          jurisdiction: "United States",
          description: "Q2 estimated tax payment",
          due_date: "2025-06-15",
          status: "pending"
        }
      ],
      do: Repo.insert!(struct(TaxDeadline, td))
end

# ---------- Financials ----------

if Repo.aggregate(Financial, :count) == 0 do
  financials = [
    %{
      company_id: tech.id,
      period: "2024-Q1",
      revenue: 150_000.0,
      expenses: 95_000.0,
      currency: "USD"
    },
    %{
      company_id: tech.id,
      period: "2024-Q2",
      revenue: 175_000.0,
      expenses: 102_000.0,
      currency: "USD"
    },
    %{
      company_id: tech.id,
      period: "2024-Q3",
      revenue: 190_000.0,
      expenses: 110_000.0,
      currency: "USD"
    },
    %{
      company_id: tech.id,
      period: "2024-Q4",
      revenue: 220_000.0,
      expenses: 125_000.0,
      currency: "USD"
    },
    %{
      company_id: capital.id,
      period: "2024-Q1",
      revenue: 85_000.0,
      expenses: 30_000.0,
      currency: "USD"
    },
    %{
      company_id: capital.id,
      period: "2024-Q2",
      revenue: 92_000.0,
      expenses: 35_000.0,
      currency: "USD"
    },
    %{
      company_id: capital.id,
      period: "2024-Q3",
      revenue: 78_000.0,
      expenses: 28_000.0,
      currency: "USD"
    },
    %{
      company_id: capital.id,
      period: "2024-Q4",
      revenue: 105_000.0,
      expenses: 40_000.0,
      currency: "USD"
    },
    %{
      company_id: retail.id,
      period: "2024-Q1",
      revenue: 62_000.0,
      expenses: 48_000.0,
      currency: "EUR"
    },
    %{
      company_id: retail.id,
      period: "2024-Q2",
      revenue: 71_000.0,
      expenses: 52_000.0,
      currency: "EUR"
    },
    %{
      company_id: retail.id,
      period: "2024-Q3",
      revenue: 68_000.0,
      expenses: 50_000.0,
      currency: "EUR"
    },
    %{
      company_id: retail.id,
      period: "2024-Q4",
      revenue: 95_000.0,
      expenses: 65_000.0,
      currency: "EUR"
    }
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
      ],
      do: Repo.insert!(struct(Document, doc))
end

# ---------- Key Personnel ----------

if Repo.aggregate(KeyPersonnel, :count) == 0 do
  for kp <- [
        %{
          company_id: holdings.id,
          name: "Jane Smith",
          title: "CEO",
          department: "Executive",
          email: "jane@acme.com"
        },
        %{
          company_id: holdings.id,
          name: "John Doe",
          title: "CFO",
          department: "Finance",
          email: "john@acme.com"
        },
        %{
          company_id: tech.id,
          name: "Alice Wang",
          title: "CTO",
          department: "Engineering",
          email: "alice@acmetech.com"
        },
        %{
          company_id: tech.id,
          name: "Bob Martinez",
          title: "VP Engineering",
          department: "Engineering",
          email: "bob@acmetech.com"
        },
        %{
          company_id: capital.id,
          name: "Carol Davis",
          title: "Portfolio Manager",
          department: "Investments",
          email: "carol@acmecap.com"
        },
        %{
          company_id: retail.id,
          name: "Dieter Schmidt",
          title: "Managing Director",
          department: "Operations",
          email: "dieter@acmeretail.de"
        }
      ],
      do: Repo.insert!(struct(KeyPersonnel, kp))
end

# ---------- Beneficial Owners ----------

if Repo.aggregate(BeneficialOwner, :count) == 0 do
  Repo.insert!(%BeneficialOwner{
    company_id: holdings.id,
    name: "Jane Smith",
    nationality: "United States",
    ownership_pct: 60.0,
    control_type: "direct",
    verified: true,
    verified_date: "2024-12-01"
  })

  Repo.insert!(%BeneficialOwner{
    company_id: holdings.id,
    name: "John Doe",
    nationality: "United States",
    ownership_pct: 40.0,
    control_type: "direct",
    verified: true,
    verified_date: "2024-12-01"
  })
end

# ---------- Portfolio Snapshots ----------

if Repo.aggregate(PortfolioSnapshot, :count) == 0 do
  snapshots = [
    %{
      date: "2024-03-31",
      liquid: 1_800_000.0,
      marketable: 450_000.0,
      illiquid: 200_000.0,
      liabilities: 620_000.0,
      nav: 1_830_000.0,
      currency: "USD"
    },
    %{
      date: "2024-04-30",
      liquid: 1_850_000.0,
      marketable: 470_000.0,
      illiquid: 200_000.0,
      liabilities: 620_000.0,
      nav: 1_900_000.0,
      currency: "USD"
    },
    %{
      date: "2024-05-31",
      liquid: 1_900_000.0,
      marketable: 510_000.0,
      illiquid: 200_000.0,
      liabilities: 620_000.0,
      nav: 1_990_000.0,
      currency: "USD"
    },
    %{
      date: "2024-06-30",
      liquid: 1_920_000.0,
      marketable: 530_000.0,
      illiquid: 200_000.0,
      liabilities: 620_000.0,
      nav: 2_030_000.0,
      currency: "USD"
    },
    %{
      date: "2024-07-31",
      liquid: 1_950_000.0,
      marketable: 490_000.0,
      illiquid: 200_000.0,
      liabilities: 620_000.0,
      nav: 2_020_000.0,
      currency: "USD"
    },
    %{
      date: "2024-08-31",
      liquid: 1_980_000.0,
      marketable: 560_000.0,
      illiquid: 200_000.0,
      liabilities: 620_000.0,
      nav: 2_120_000.0,
      currency: "USD"
    },
    %{
      date: "2024-09-30",
      liquid: 2_010_000.0,
      marketable: 580_000.0,
      illiquid: 200_000.0,
      liabilities: 620_000.0,
      nav: 2_170_000.0,
      currency: "USD"
    },
    %{
      date: "2024-10-31",
      liquid: 2_050_000.0,
      marketable: 620_000.0,
      illiquid: 200_000.0,
      liabilities: 620_000.0,
      nav: 2_250_000.0,
      currency: "USD"
    },
    %{
      date: "2024-11-30",
      liquid: 2_100_000.0,
      marketable: 650_000.0,
      illiquid: 200_000.0,
      liabilities: 620_000.0,
      nav: 2_330_000.0,
      currency: "USD"
    },
    %{
      date: "2024-12-31",
      liquid: 2_150_000.0,
      marketable: 700_000.0,
      illiquid: 200_000.0,
      liabilities: 620_000.0,
      nav: 2_430_000.0,
      currency: "USD"
    },
    %{
      date: "2025-01-31",
      liquid: 2_200_000.0,
      marketable: 720_000.0,
      illiquid: 200_000.0,
      liabilities: 620_000.0,
      nav: 2_500_000.0,
      currency: "USD"
    },
    %{
      date: "2025-02-28",
      liquid: 2_250_000.0,
      marketable: 750_000.0,
      illiquid: 200_000.0,
      liabilities: 820_000.0,
      nav: 2_380_000.0,
      currency: "USD"
    }
  ]

  for s <- snapshots, do: Repo.insert!(struct(PortfolioSnapshot, s))
end

# ---------- Dividends ----------

if Repo.aggregate(Dividend, :count) == 0 do
  Repo.insert!(%Dividend{
    company_id: tech.id,
    amount: 50_000.0,
    currency: "USD",
    date: "2025-01-15",
    recipient: "Acme Holdings",
    dividend_type: "regular"
  })

  Repo.insert!(%Dividend{
    company_id: capital.id,
    amount: 30_000.0,
    currency: "USD",
    date: "2025-04-15",
    recipient: "Acme Holdings",
    dividend_type: "regular"
  })
end

# ---------- Chart of Accounts ----------

find_or_create_account = fn attrs ->
  case Repo.get_by(Account, code: attrs.code) do
    nil -> Repo.insert!(struct(Account, attrs))
    existing -> existing
  end
end

if Repo.aggregate(Account, :count) == 0 do
  # Assets (1xxx)
  cash = find_or_create_account.(%{code: "1000", name: "Cash", account_type: "asset", currency: "USD"})
  find_or_create_account.(%{code: "1010", name: "Petty Cash", account_type: "asset", currency: "USD", parent_id: cash.id})
  find_or_create_account.(%{code: "1020", name: "Checking Account", account_type: "asset", currency: "USD", parent_id: cash.id})
  ar = find_or_create_account.(%{code: "1100", name: "Accounts Receivable", account_type: "asset", currency: "USD"})
  find_or_create_account.(%{code: "1200", name: "Investments", account_type: "asset", currency: "USD"})
  find_or_create_account.(%{code: "1210", name: "Marketable Securities", account_type: "asset", currency: "USD"})
  find_or_create_account.(%{code: "1300", name: "Fixed Assets", account_type: "asset", currency: "USD"})
  find_or_create_account.(%{code: "1310", name: "Office Equipment", account_type: "asset", currency: "USD"})
  find_or_create_account.(%{code: "1320", name: "Accumulated Depreciation", account_type: "asset", currency: "USD"})

  # Liabilities (2xxx)
  ap = find_or_create_account.(%{code: "2000", name: "Accounts Payable", account_type: "liability", currency: "USD"})
  find_or_create_account.(%{code: "2100", name: "Loans Payable", account_type: "liability", currency: "USD"})
  find_or_create_account.(%{code: "2200", name: "Accrued Expenses", account_type: "liability", currency: "USD"})
  find_or_create_account.(%{code: "2300", name: "Taxes Payable", account_type: "liability", currency: "USD"})

  # Equity (3xxx)
  oe = find_or_create_account.(%{code: "3000", name: "Owner's Equity", account_type: "equity", currency: "USD"})
  find_or_create_account.(%{code: "3100", name: "Retained Earnings", account_type: "equity", currency: "USD"})
  find_or_create_account.(%{code: "3200", name: "Common Stock", account_type: "equity", currency: "USD"})

  # Revenue (4xxx)
  inv_income = find_or_create_account.(%{code: "4000", name: "Investment Income", account_type: "revenue", currency: "USD"})
  mgmt_fees = find_or_create_account.(%{code: "4100", name: "Management Fees", account_type: "revenue", currency: "USD"})
  div_received = find_or_create_account.(%{code: "4200", name: "Dividends Received", account_type: "revenue", currency: "USD"})
  find_or_create_account.(%{code: "4300", name: "Interest Income", account_type: "revenue", currency: "USD"})

  # Expenses (5xxx)
  op_exp = find_or_create_account.(%{code: "5000", name: "Operating Expenses", account_type: "expense", currency: "USD"})
  find_or_create_account.(%{code: "5100", name: "Legal Fees", account_type: "expense", currency: "USD"})
  acct_fees = find_or_create_account.(%{code: "5200", name: "Accounting Fees", account_type: "expense", currency: "USD"})
  find_or_create_account.(%{code: "5300", name: "Travel & Entertainment", account_type: "expense", currency: "USD"})
  find_or_create_account.(%{code: "5400", name: "Office Supplies", account_type: "expense", currency: "USD"})
  find_or_create_account.(%{code: "5500", name: "Insurance", account_type: "expense", currency: "USD"})
  find_or_create_account.(%{code: "5600", name: "Depreciation Expense", account_type: "expense", currency: "USD"})

  # ---------- Sample Journal Entries ----------

  if Repo.aggregate(JournalEntry, :count) == 0 do
    # JE1: Initial capital contribution
    {:ok, je1} = Holdco.Finance.create_journal_entry(%{
      "date" => "2024-01-01",
      "description" => "Initial capital contribution from owners",
      "reference" => "JE-001"
    })
    Repo.insert!(%JournalLine{entry_id: je1.id, account_id: cash.id, debit: 1_000_000.0, credit: 0.0})
    Repo.insert!(%JournalLine{entry_id: je1.id, account_id: oe.id, debit: 0.0, credit: 1_000_000.0})

    # JE2: Received dividend income
    {:ok, je2} = Holdco.Finance.create_journal_entry(%{
      "date" => "2025-01-15",
      "description" => "Q4 2024 dividend received from Acme Tech",
      "reference" => "JE-002"
    })
    Repo.insert!(%JournalLine{entry_id: je2.id, account_id: cash.id, debit: 50_000.0, credit: 0.0})
    Repo.insert!(%JournalLine{entry_id: je2.id, account_id: div_received.id, debit: 0.0, credit: 50_000.0})

    # JE3: Paid accounting fees
    {:ok, je3} = Holdco.Finance.create_journal_entry(%{
      "date" => "2025-02-01",
      "description" => "Monthly accounting fees - Chen Accounting",
      "reference" => "JE-003"
    })
    Repo.insert!(%JournalLine{entry_id: je3.id, account_id: acct_fees.id, debit: 5_000.0, credit: 0.0})
    Repo.insert!(%JournalLine{entry_id: je3.id, account_id: cash.id, debit: 0.0, credit: 5_000.0})

    # JE4: Management fees earned
    {:ok, je4} = Holdco.Finance.create_journal_entry(%{
      "date" => "2025-02-15",
      "description" => "Q1 management fees from subsidiaries",
      "reference" => "JE-004"
    })
    Repo.insert!(%JournalLine{entry_id: je4.id, account_id: ar.id, debit: 25_000.0, credit: 0.0})
    Repo.insert!(%JournalLine{entry_id: je4.id, account_id: mgmt_fees.id, debit: 0.0, credit: 25_000.0})

    # JE5: Operating expenses
    {:ok, je5} = Holdco.Finance.create_journal_entry(%{
      "date" => "2025-02-28",
      "description" => "February operating expenses",
      "reference" => "JE-005"
    })
    Repo.insert!(%JournalLine{entry_id: je5.id, account_id: op_exp.id, debit: 8_500.0, credit: 0.0})
    Repo.insert!(%JournalLine{entry_id: je5.id, account_id: cash.id, debit: 0.0, credit: 8_500.0})

    # JE6: Vendor payment
    {:ok, je6} = Holdco.Finance.create_journal_entry(%{
      "date" => "2025-03-01",
      "description" => "Payment to vendors - accounts payable",
      "reference" => "JE-006"
    })
    Repo.insert!(%JournalLine{entry_id: je6.id, account_id: ap.id, debit: 12_000.0, credit: 0.0})
    Repo.insert!(%JournalLine{entry_id: je6.id, account_id: cash.id, debit: 0.0, credit: 12_000.0})

    # JE7: Investment income
    {:ok, je7} = Holdco.Finance.create_journal_entry(%{
      "date" => "2025-04-15",
      "description" => "Q1 2025 investment returns",
      "reference" => "JE-007"
    })
    Repo.insert!(%JournalLine{entry_id: je7.id, account_id: cash.id, debit: 30_000.0, credit: 0.0})
    Repo.insert!(%JournalLine{entry_id: je7.id, account_id: inv_income.id, debit: 0.0, credit: 30_000.0})
  end
end

IO.puts("Seeds loaded successfully!")
