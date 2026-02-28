defmodule Holdco.HealthScoreTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Analytics

  describe "health_scores" do
    test "create_health_score/1 with valid attrs" do
      company = company_fixture()

      {:ok, score} = Analytics.create_health_score(%{
        company_id: company.id,
        score_date: ~D[2026-01-15],
        overall_score: 82.5,
        liquidity_score: 90.0,
        profitability_score: 75.0,
        compliance_score: 88.0,
        governance_score: 80.0,
        risk_score: 70.0,
        operational_score: 85.0,
        trend: "improving"
      })

      assert Decimal.equal?(score.overall_score, Decimal.new("82.5"))
      assert score.trend == "improving"
      assert score.score_date == ~D[2026-01-15]
    end

    test "create_health_score/1 fails without required fields" do
      assert {:error, changeset} = Analytics.create_health_score(%{})
      errors = errors_on(changeset)
      assert %{company_id: ["can't be blank"]} = errors
      assert %{score_date: ["can't be blank"]} = errors
      assert %{overall_score: ["can't be blank"]} = errors
    end

    test "create_health_score/1 validates overall_score range (> 100)" do
      company = company_fixture()
      assert {:error, changeset} = Analytics.create_health_score(%{
        company_id: company.id,
        score_date: ~D[2026-01-15],
        overall_score: 150.0
      })
      assert %{overall_score: _} = errors_on(changeset)
    end

    test "create_health_score/1 validates overall_score range (< 0)" do
      company = company_fixture()
      assert {:error, changeset} = Analytics.create_health_score(%{
        company_id: company.id,
        score_date: ~D[2026-01-15],
        overall_score: -10.0
      })
      assert %{overall_score: _} = errors_on(changeset)
    end

    test "create_health_score/1 validates trend" do
      company = company_fixture()
      assert {:error, changeset} = Analytics.create_health_score(%{
        company_id: company.id,
        score_date: ~D[2026-01-15],
        overall_score: 75.0,
        trend: "invalid_trend"
      })
      assert %{trend: _} = errors_on(changeset)
    end

    test "list_health_scores/0 returns all scores" do
      score = health_score_fixture()
      scores = Analytics.list_health_scores()
      assert Enum.any?(scores, &(&1.id == score.id))
    end

    test "list_health_scores/1 filters by company_id" do
      c1 = company_fixture()
      c2 = company_fixture()
      s1 = health_score_fixture(%{company: c1})
      _s2 = health_score_fixture(%{company: c2})

      scores = Analytics.list_health_scores(c1.id)
      assert Enum.all?(scores, &(&1.company_id == c1.id))
      assert Enum.any?(scores, &(&1.id == s1.id))
    end

    test "get_health_score!/1 returns the score with preloaded company" do
      score = health_score_fixture()
      found = Analytics.get_health_score!(score.id)
      assert found.id == score.id
      assert found.company != nil
    end

    test "get_health_score!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Analytics.get_health_score!(0)
      end
    end

    test "update_health_score/2 updates successfully" do
      score = health_score_fixture()
      {:ok, updated} = Analytics.update_health_score(score, %{trend: "improving", notes: "Getting better"})
      assert updated.trend == "improving"
      assert updated.notes == "Getting better"
    end

    test "delete_health_score/1 deletes the score" do
      score = health_score_fixture()
      {:ok, _} = Analytics.delete_health_score(score)
      assert_raise Ecto.NoResultsError, fn ->
        Analytics.get_health_score!(score.id)
      end
    end

    test "latest_health_score/1 returns the most recent score" do
      company = company_fixture()
      health_score_fixture(%{company: company, score_date: ~D[2026-01-01]})
      s2 = health_score_fixture(%{company: company, score_date: ~D[2026-02-01]})

      latest = Analytics.latest_health_score(company.id)
      assert latest.id == s2.id
    end

    test "latest_health_score/1 returns nil when no scores" do
      company = company_fixture()
      assert Analytics.latest_health_score(company.id) == nil
    end

    test "health_score_trend/1 returns last 12 scores in chronological order" do
      company = company_fixture()
      for i <- 1..3 do
        health_score_fixture(%{company: company, score_date: Date.add(~D[2026-01-01], i * 30)})
      end

      trend = Analytics.health_score_trend(company.id)
      assert length(trend) == 3
      # Should be in ascending date order (oldest first)
      dates = Enum.map(trend, & &1.score_date)
      assert dates == Enum.sort(dates, Date)
    end

    test "calculate_health_score/1 creates a new score" do
      company = company_fixture()
      {:ok, score} = Analytics.calculate_health_score(company.id)

      assert score.company_id == company.id
      assert score.score_date == Date.utc_today()
      assert Decimal.compare(score.overall_score, 0) == :gt
      assert score.trend == "stable"
      assert is_map(score.components)
    end

    test "health scores preload company" do
      score = health_score_fixture()
      scores = Analytics.list_health_scores()
      found = Enum.find(scores, &(&1.id == score.id))
      assert found.company != nil
    end
  end
end
