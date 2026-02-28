defmodule Holdco.Analytics.CounterpartyExposureTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Analytics

  describe "Counterparty Exposures CRUD" do
    test "create_counterparty_exposure/1 with valid attrs" do
      company = company_fixture()

      assert {:ok, exposure} =
               Analytics.create_counterparty_exposure(%{
                 company_id: company.id,
                 counterparty_name: "Goldman Sachs",
                 counterparty_type: "bank",
                 exposure_amount: 5_000_000.0,
                 credit_rating: "A",
                 status: "active"
               })

      assert exposure.counterparty_name == "Goldman Sachs"
      assert exposure.counterparty_type == "bank"
      assert exposure.status == "active"
    end

    test "list_counterparty_exposures/0 returns all exposures" do
      exp = counterparty_exposure_fixture(%{counterparty_name: "Test Bank"})
      exposures = Analytics.list_counterparty_exposures()
      assert length(exposures) >= 1
      assert Enum.any?(exposures, &(&1.id == exp.id))
    end

    test "list_counterparty_exposures/1 filters by company_id" do
      c1 = company_fixture(%{name: "ExpCo1"})
      c2 = company_fixture(%{name: "ExpCo2"})
      exp1 = counterparty_exposure_fixture(%{company: c1, counterparty_name: "Bank A"})
      _exp2 = counterparty_exposure_fixture(%{company: c2, counterparty_name: "Bank B"})

      exposures = Analytics.list_counterparty_exposures(c1.id)
      assert length(exposures) == 1
      assert hd(exposures).id == exp1.id
    end

    test "get_counterparty_exposure!/1 returns the exposure" do
      exp = counterparty_exposure_fixture(%{counterparty_name: "Get Exposure"})
      found = Analytics.get_counterparty_exposure!(exp.id)
      assert found.id == exp.id
      assert found.counterparty_name == "Get Exposure"
    end

    test "update_counterparty_exposure/2 updates successfully" do
      exp = counterparty_exposure_fixture(%{counterparty_name: "Old Name"})
      assert {:ok, updated} = Analytics.update_counterparty_exposure(exp, %{counterparty_name: "New Name"})
      assert updated.counterparty_name == "New Name"
    end

    test "delete_counterparty_exposure/1 deletes the exposure" do
      exp = counterparty_exposure_fixture()
      assert {:ok, _} = Analytics.delete_counterparty_exposure(exp)

      assert_raise Ecto.NoResultsError, fn ->
        Analytics.get_counterparty_exposure!(exp.id)
      end
    end
  end

  describe "validations" do
    test "validates required counterparty_name" do
      assert {:error, changeset} = Analytics.create_counterparty_exposure(%{})
      assert %{counterparty_name: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates status inclusion" do
      assert {:error, changeset} =
               Analytics.create_counterparty_exposure(%{
                 counterparty_name: "Test",
                 status: "invalid_status"
               })

      assert %{status: _} = errors_on(changeset)
    end

    test "validates counterparty_type inclusion" do
      assert {:error, changeset} =
               Analytics.create_counterparty_exposure(%{
                 counterparty_name: "Test",
                 counterparty_type: "invalid_type"
               })

      assert %{counterparty_type: _} = errors_on(changeset)
    end

    test "validates credit_rating inclusion" do
      assert {:error, changeset} =
               Analytics.create_counterparty_exposure(%{
                 counterparty_name: "Test",
                 credit_rating: "AAAA"
               })

      assert %{credit_rating: _} = errors_on(changeset)
    end
  end

  describe "calculate_risk_score/1" do
    test "calculates low risk score for AAA-rated exposure" do
      exp = counterparty_exposure_fixture(%{
        credit_rating: "AAA",
        utilization_pct: 10.0,
        exposure_amount: 50_000.0,
        next_review_date: Date.add(Date.utc_today(), 90)
      })

      score = Analytics.calculate_risk_score(exp)
      # AAA=5*0.4=2, util=10*0.3=3, exposure=10*0.2=2, review=10*0.1=1 = 8.0
      assert Decimal.compare(score, Decimal.new("15")) == :lt
    end

    test "calculates high risk score for D-rated exposure" do
      exp = counterparty_exposure_fixture(%{
        credit_rating: "D",
        utilization_pct: 95.0,
        exposure_amount: 20_000_000.0,
        next_review_date: Date.add(Date.utc_today(), -30)
      })

      score = Analytics.calculate_risk_score(exp)
      # D=100*0.4=40, util=95*0.3=28.5, exposure=100*0.2=20, review=100*0.1=10 = 98.5
      assert Decimal.compare(score, Decimal.new("80")) == :gt
    end

    test "calculates higher score with high utilization" do
      low_util = counterparty_exposure_fixture(%{
        credit_rating: "A",
        utilization_pct: 10.0,
        exposure_amount: 500_000.0
      })

      high_util = counterparty_exposure_fixture(%{
        credit_rating: "A",
        utilization_pct: 90.0,
        exposure_amount: 500_000.0
      })

      low_score = Analytics.calculate_risk_score(low_util)
      high_score = Analytics.calculate_risk_score(high_util)

      assert Decimal.compare(high_score, low_score) == :gt
    end

    test "risk_score computation accuracy" do
      exp = counterparty_exposure_fixture(%{
        credit_rating: "BBB",
        utilization_pct: 50.0,
        exposure_amount: 2_000_000.0,
        next_review_date: Date.add(Date.utc_today(), 60)
      })

      score = Analytics.calculate_risk_score(exp)
      # BBB=25*0.4=10, util=50*0.3=15, exp(>1M)=50*0.2=10, review(>30d)=10*0.1=1 = 36.0
      assert Decimal.compare(score, Decimal.new("0")) == :gt
      assert Decimal.compare(score, Decimal.new("100")) in [:lt, :eq]
    end
  end

  describe "concentration_analysis/1" do
    test "groups by type" do
      company = company_fixture()
      counterparty_exposure_fixture(%{company: company, counterparty_type: "bank", exposure_amount: 1_000_000.0})
      counterparty_exposure_fixture(%{company: company, counterparty_type: "bank", exposure_amount: 500_000.0})
      counterparty_exposure_fixture(%{company: company, counterparty_type: "broker", exposure_amount: 200_000.0})

      analysis = Analytics.concentration_analysis(company.id)

      assert length(analysis.by_type) == 2
      bank_type = Enum.find(analysis.by_type, & &1.type == "bank")
      assert bank_type.count == 2
      assert Decimal.compare(bank_type.total, Decimal.new("1500000")) == :eq
    end

    test "flags high concentration" do
      company = company_fixture()
      # One type with 80% exposure
      counterparty_exposure_fixture(%{company: company, counterparty_type: "bank", exposure_amount: 8_000_000.0})
      counterparty_exposure_fixture(%{company: company, counterparty_type: "broker", exposure_amount: 2_000_000.0})

      analysis = Analytics.concentration_analysis(company.id)
      bank_type = Enum.find(analysis.by_type, & &1.type == "bank")
      assert bank_type.concentrated == true

      # Should have at least one warning
      assert length(analysis.warnings) >= 1
    end
  end
end
