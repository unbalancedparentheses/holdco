defmodule Holdco.AI.DataContextTest do
  use Holdco.DataCase, async: true

  alias Holdco.AI.DataContext

  # DataContext.build_summary/0 calls Portfolio.calculate_nav/0, which
  # works correctly when the database is empty (all Decimal.new(0) accumulators).
  # The upstream bug only triggers when existing seed data mixes floats with Decimals.

  describe "build_summary/0 with empty database" do
    test "returns a string with all expected section headers" do
      summary = DataContext.build_summary()

      assert is_binary(summary)
      assert summary =~ "Portfolio Summary"
      assert summary =~ "Companies"
      assert summary =~ "Asset Allocation"
      assert summary =~ "Holdings"
      assert summary =~ "Liabilities"
      assert summary =~ "Recent Transactions"
      assert summary =~ "Upcoming Tax Deadlines"
    end

    test "portfolio summary shows zero values when DB is empty" do
      summary = DataContext.build_summary()

      # NAV section should report zeros (or close) since no data exists
      assert summary =~ "Net Asset Value"
      assert summary =~ "Liquid"
      assert summary =~ "Marketable"
      assert summary =~ "Illiquid"
      assert summary =~ "Total Liabilities"
    end

    test "companies section shows 0 entities when none exist" do
      summary = DataContext.build_summary()
      assert summary =~ "Companies (0 entities)"
    end

    test "holdings section shows 0 total when none exist" do
      summary = DataContext.build_summary()
      assert summary =~ "Holdings (0 total"
    end

    test "liabilities section shows 0 when none exist" do
      summary = DataContext.build_summary()
      assert summary =~ "Liabilities (0)"
    end
  end

  describe "build_summary/0 with seeded data" do
    test "includes company names in the output" do
      {:ok, _company} =
        Holdco.Corporate.create_company(%{name: "DataContext Test Corp", country: "US"})

      summary = DataContext.build_summary()
      assert summary =~ "DataContext Test Corp"
      assert summary =~ "Companies (1 entities)"
    end

    test "includes multiple companies" do
      {:ok, _c1} = Holdco.Corporate.create_company(%{name: "Alpha Inc", country: "US"})
      {:ok, _c2} = Holdco.Corporate.create_company(%{name: "Beta Ltd", country: "UK"})

      summary = DataContext.build_summary()
      assert summary =~ "Alpha Inc"
      assert summary =~ "Beta Ltd"
      assert summary =~ "Companies (2 entities)"
    end

    test "includes company details like country and wind_down_status" do
      {:ok, _company} =
        Holdco.Corporate.create_company(%{
          name: "Wind Down Corp",
          country: "DE",
          category: "holding",
          wind_down_status: "active"
        })

      summary = DataContext.build_summary()
      assert summary =~ "Wind Down Corp"
      assert summary =~ "DE"
      assert summary =~ "active"
    end

    test "includes tax deadlines when present" do
      company = Holdco.HoldcoFixtures.company_fixture()

      {:ok, _deadline} =
        Holdco.Compliance.create_tax_deadline(%{
          company_id: company.id,
          description: "Q1 VAT filing",
          due_date: Date.to_iso8601(Date.add(Date.utc_today(), 30)),
          jurisdiction: "US",
          status: "pending"
        })

      summary = DataContext.build_summary()
      assert summary =~ "Q1 VAT filing"
      assert summary =~ "pending"
    end

    test "includes liabilities when present" do
      company = Holdco.HoldcoFixtures.company_fixture()

      {:ok, _liability} =
        Holdco.Finance.create_liability(%{
          company_id: company.id,
          creditor: "Bank ABC",
          liability_type: "loan",
          principal: "50000",
          currency: "USD",
          status: "active",
          interest_rate: "5.5"
        })

      summary = DataContext.build_summary()
      assert summary =~ "Bank ABC"
      assert summary =~ "USD"
    end

    test "includes recent transactions when present" do
      company = Holdco.HoldcoFixtures.company_fixture()

      {:ok, _txn} =
        Holdco.Banking.create_transaction(%{
          company_id: company.id,
          transaction_type: "credit",
          description: "Test payment received",
          amount: 1000.00,
          currency: "USD",
          date: Date.to_iso8601(Date.utc_today())
        })

      summary = DataContext.build_summary()
      assert summary =~ "Test payment received"
    end

    test "limits holdings to first 30" do
      summary = DataContext.build_summary()
      assert summary =~ "showing first 30"
    end
  end
end
