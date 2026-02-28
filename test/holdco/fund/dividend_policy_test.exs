defmodule Holdco.Fund.DividendPolicyTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Fund

  describe "list_dividend_policies/1" do
    test "returns all dividend policies" do
      dp = dividend_policy_fixture()
      policies = Fund.list_dividend_policies()
      assert length(policies) >= 1
      assert Enum.any?(policies, &(&1.id == dp.id))
    end

    test "filters by company_id" do
      c1 = company_fixture(%{name: "DivCo1"})
      c2 = company_fixture(%{name: "DivCo2"})
      dp1 = dividend_policy_fixture(%{company: c1, name: "Policy A"})
      _dp2 = dividend_policy_fixture(%{company: c2, name: "Policy B"})

      policies = Fund.list_dividend_policies(c1.id)
      assert length(policies) == 1
      assert hd(policies).id == dp1.id
    end

    test "returns empty list when no policies for company" do
      company = company_fixture()
      assert Fund.list_dividend_policies(company.id) == []
    end
  end

  describe "get_dividend_policy!/1" do
    test "returns the dividend policy with given id" do
      dp = dividend_policy_fixture(%{name: "Fetched Policy"})
      found = Fund.get_dividend_policy!(dp.id)
      assert found.id == dp.id
      assert found.name == "Fetched Policy"
    end

    test "raises when id does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Fund.get_dividend_policy!(0)
      end
    end
  end

  describe "create_dividend_policy/1" do
    test "creates a dividend policy with valid attrs" do
      company = company_fixture()

      assert {:ok, dp} =
               Fund.create_dividend_policy(%{
                 company_id: company.id,
                 name: "Quarterly Distribution",
                 policy_type: "payout_ratio",
                 target_payout_ratio: 60.0,
                 frequency: "quarterly"
               })

      assert dp.name == "Quarterly Distribution"
      assert dp.policy_type == "payout_ratio"
      assert Decimal.equal?(dp.target_payout_ratio, Decimal.from_float(60.0))
    end

    test "validates required fields" do
      assert {:error, changeset} = Fund.create_dividend_policy(%{})
      errors = errors_on(changeset)
      assert errors[:name]
      assert errors[:policy_type]
      assert errors[:company_id]
    end

    test "validates policy_type inclusion" do
      company = company_fixture()

      assert {:error, changeset} =
               Fund.create_dividend_policy(%{
                 company_id: company.id,
                 name: "Bad Policy",
                 policy_type: "invalid_type"
               })

      assert %{policy_type: _} = errors_on(changeset)
    end

    test "validates frequency inclusion" do
      company = company_fixture()

      assert {:error, changeset} =
               Fund.create_dividend_policy(%{
                 company_id: company.id,
                 name: "Bad Freq",
                 policy_type: "fixed_amount",
                 frequency: "biweekly"
               })

      assert %{frequency: _} = errors_on(changeset)
    end
  end

  describe "update_dividend_policy/2" do
    test "updates a dividend policy" do
      dp = dividend_policy_fixture(%{name: "Old Name"})
      assert {:ok, updated} = Fund.update_dividend_policy(dp, %{name: "New Name"})
      assert updated.name == "New Name"
    end
  end

  describe "delete_dividend_policy/1" do
    test "deletes the dividend policy" do
      dp = dividend_policy_fixture()
      assert {:ok, _} = Fund.delete_dividend_policy(dp)

      assert_raise Ecto.NoResultsError, fn ->
        Fund.get_dividend_policy!(dp.id)
      end
    end
  end

  describe "calculate_dividend/2" do
    test "calculates with payout_ratio type" do
      company = company_fixture()

      # Create a financial record with revenue=200000 and expenses=100000 => net_income=100000
      {:ok, _} =
        Holdco.Finance.create_financial(%{
          company_id: company.id,
          period: "2025-Q1",
          revenue: 200_000.0,
          expenses: 100_000.0
        })

      {:ok, policy} =
        Fund.create_dividend_policy(%{
          company_id: company.id,
          name: "50% Payout",
          policy_type: "payout_ratio",
          target_payout_ratio: 50.0
        })

      result = Fund.calculate_dividend(policy, company.id)

      # 50% of 100,000 = 50,000
      assert Decimal.equal?(result.recommended_amount, Decimal.new("50000.00"))
      assert Decimal.equal?(result.payout_ratio, Decimal.new("50.00"))
      assert Decimal.equal?(result.retained_earnings, Decimal.new("50000.00"))
    end

    test "calculates with fixed_amount type" do
      company = company_fixture()

      {:ok, _} =
        Holdco.Finance.create_financial(%{
          company_id: company.id,
          period: "2025-Q1",
          revenue: 500_000.0,
          expenses: 200_000.0
        })

      {:ok, policy} =
        Fund.create_dividend_policy(%{
          company_id: company.id,
          name: "Fixed $10K",
          policy_type: "fixed_amount",
          fixed_amount: 10_000.0
        })

      result = Fund.calculate_dividend(policy, company.id)

      assert Decimal.equal?(result.recommended_amount, Decimal.new("10000.00"))
    end

    test "calculates with stable_growth type" do
      company = company_fixture()

      # Create a prior dividend for the last_dividend_amount lookup
      {:ok, _} =
        Holdco.Finance.create_dividend(%{
          company_id: company.id,
          amount: 5000.0,
          date: "2025-01-01"
        })

      {:ok, _} =
        Holdco.Finance.create_financial(%{
          company_id: company.id,
          period: "2025-Q1",
          revenue: 100_000.0,
          expenses: 50_000.0
        })

      {:ok, policy} =
        Fund.create_dividend_policy(%{
          company_id: company.id,
          name: "5% Growth",
          policy_type: "stable_growth",
          growth_rate: 5.0
        })

      result = Fund.calculate_dividend(policy, company.id)

      # 5000 * (1 + 0.05) = 5250
      assert Decimal.equal?(result.recommended_amount, Decimal.new("5250.00"))
    end

    test "respects max_payout_ratio constraint" do
      company = company_fixture()

      {:ok, _} =
        Holdco.Finance.create_financial(%{
          company_id: company.id,
          period: "2025-Q1",
          revenue: 100_000.0,
          expenses: 0.0
        })

      {:ok, policy} =
        Fund.create_dividend_policy(%{
          company_id: company.id,
          name: "Capped Policy",
          policy_type: "payout_ratio",
          target_payout_ratio: 80.0,
          max_payout_ratio: 50.0
        })

      result = Fund.calculate_dividend(policy, company.id)

      # 80% of 100k = 80k, but capped at 50% = 50k
      assert Decimal.equal?(result.recommended_amount, Decimal.new("50000.00"))
    end

    test "respects min_retained_earnings constraint" do
      company = company_fixture()

      {:ok, _} =
        Holdco.Finance.create_financial(%{
          company_id: company.id,
          period: "2025-Q1",
          revenue: 100_000.0,
          expenses: 50_000.0
        })

      {:ok, policy} =
        Fund.create_dividend_policy(%{
          company_id: company.id,
          name: "Min Retained",
          policy_type: "payout_ratio",
          target_payout_ratio: 80.0,
          min_retained_earnings: 40_000.0
        })

      result = Fund.calculate_dividend(policy, company.id)

      # net income = 50k, min retained = 40k, max distributable = 10k
      # 80% of 50k = 40k, but capped at 10k
      assert Decimal.equal?(result.recommended_amount, Decimal.new("10000.00"))
    end

    test "returns zero when no financials exist" do
      company = company_fixture()

      {:ok, policy} =
        Fund.create_dividend_policy(%{
          company_id: company.id,
          name: "No Data",
          policy_type: "payout_ratio",
          target_payout_ratio: 50.0
        })

      result = Fund.calculate_dividend(policy, company.id)
      assert Decimal.equal?(result.recommended_amount, Decimal.new("0.00"))
    end
  end

  describe "advance_dividend_date/1" do
    test "advances dividend date for quarterly frequency" do
      dp = dividend_policy_fixture(%{frequency: "quarterly"})
      assert {:ok, updated} = Fund.advance_dividend_date(dp)

      assert updated.last_dividend_date == Date.utc_today()
      assert updated.next_dividend_date == Date.add(Date.utc_today(), 91)
    end

    test "advances dividend date for monthly frequency" do
      dp = dividend_policy_fixture(%{frequency: "monthly"})
      assert {:ok, updated} = Fund.advance_dividend_date(dp)

      assert updated.last_dividend_date == Date.utc_today()
      assert updated.next_dividend_date == Date.add(Date.utc_today(), 30)
    end

    test "advances dividend date for annual frequency" do
      dp = dividend_policy_fixture(%{frequency: "annual"})
      assert {:ok, updated} = Fund.advance_dividend_date(dp)

      assert updated.last_dividend_date == Date.utc_today()
      assert updated.next_dividend_date == Date.add(Date.utc_today(), 365)
    end
  end
end
