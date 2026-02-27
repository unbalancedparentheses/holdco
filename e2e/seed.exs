# E2E seed script - populates the test database with data for Playwright tests.
# Run with: E2E=true MIX_ENV=test mix run e2e/seed.exs
#
# This reuses the main seeds file which creates the admin user and sample data.
Code.eval_file("priv/repo/seeds.exs")

# ---------- Additional E2E-specific data ----------
# (The main seeds already create companies, holdings, transactions, etc.)

alias Holdco.Repo
alias Holdco.Collaboration.{Contact, Project}

# ---------- Contacts ----------
if Repo.aggregate(Contact, :count) == 0 do
  for c <- [
        %{
          name: "Sarah Johnson",
          title: "Partner",
          organization: "Johnson & Partners LLP",
          email: "sarah@jpartners.com",
          phone: "+1-555-0100",
          role_tag: "lawyer",
          notes: "Primary legal counsel"
        },
        %{
          name: "Michael Chen",
          title: "Senior Accountant",
          organization: "Chen Accounting",
          email: "mchen@chenacct.com",
          role_tag: "accountant"
        }
      ] do
    Repo.insert!(struct(Contact, c))
  end
end

# ---------- Projects ----------
if Repo.aggregate(Project, :count) == 0 do
  for p <- [
        %{
          name: "Annual Audit 2025",
          status: "active",
          project_type: "audit",
          description: "Year-end audit for all entities",
          start_date: ~D[2025-01-15],
          target_date: ~D[2025-04-30],
          budget: 50000.0,
          currency: "USD"
        },
        %{
          name: "Nordic Acquisition Due Diligence",
          status: "planned",
          project_type: "acquisition",
          description: "DD for Nordic SaaS AB acquisition",
          start_date: ~D[2025-06-01],
          target_date: ~D[2025-09-30],
          budget: 25000.0,
          currency: "USD"
        }
      ] do
    Repo.insert!(struct(Project, p))
  end
end

IO.puts("E2E seeds loaded successfully!")
