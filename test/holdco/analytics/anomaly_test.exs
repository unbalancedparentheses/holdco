defmodule Holdco.Analytics.AnomalyTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Analytics

  describe "create_anomaly/1" do
    test "creates an anomaly with valid attrs" do
      company = company_fixture()

      assert {:ok, anomaly} =
               Analytics.create_anomaly(%{
                 company_id: company.id,
                 entity_type: "transaction",
                 anomaly_type: "outlier",
                 severity: "high",
                 description: "Large transaction detected",
                 detected_value: 50_000.0
               })

      assert anomaly.entity_type == "transaction"
      assert anomaly.anomaly_type == "outlier"
      assert anomaly.severity == "high"
      assert anomaly.status == "open"
    end

    test "fails without required fields" do
      assert {:error, changeset} = Analytics.create_anomaly(%{})
      errors = errors_on(changeset)
      assert %{entity_type: ["can't be blank"]} = errors
      assert %{anomaly_type: ["can't be blank"]} = errors
    end

    test "validates entity_type inclusion" do
      assert {:error, changeset} =
               Analytics.create_anomaly(%{
                 entity_type: "invalid",
                 anomaly_type: "outlier"
               })

      assert %{entity_type: _} = errors_on(changeset)
    end

    test "validates anomaly_type inclusion" do
      assert {:error, changeset} =
               Analytics.create_anomaly(%{
                 entity_type: "transaction",
                 anomaly_type: "invalid"
               })

      assert %{anomaly_type: _} = errors_on(changeset)
    end

    test "validates severity inclusion" do
      assert {:error, changeset} =
               Analytics.create_anomaly(%{
                 entity_type: "transaction",
                 anomaly_type: "outlier",
                 severity: "invalid"
               })

      assert %{severity: _} = errors_on(changeset)
    end

    test "validates status inclusion" do
      assert {:error, changeset} =
               Analytics.create_anomaly(%{
                 entity_type: "transaction",
                 anomaly_type: "outlier",
                 status: "invalid"
               })

      assert %{status: _} = errors_on(changeset)
    end
  end

  describe "get_anomaly!/1" do
    test "returns the anomaly with given id" do
      anomaly = anomaly_fixture()
      found = Analytics.get_anomaly!(anomaly.id)
      assert found.id == anomaly.id
    end

    test "raises when id does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Analytics.get_anomaly!(0)
      end
    end
  end

  describe "update_anomaly/2" do
    test "updates an anomaly" do
      anomaly = anomaly_fixture()
      assert {:ok, updated} = Analytics.update_anomaly(anomaly, %{severity: "critical"})
      assert updated.severity == "critical"
    end
  end

  describe "list_anomalies/1" do
    test "returns all anomalies" do
      anomaly = anomaly_fixture()
      anomalies = Analytics.list_anomalies()
      assert Enum.any?(anomalies, &(&1.id == anomaly.id))
    end

    test "filters by status" do
      a1 = anomaly_fixture(%{status: "open"})
      _a2 = anomaly_fixture(%{status: "resolved"})

      open = Analytics.list_anomalies(status: "open")
      assert Enum.any?(open, &(&1.id == a1.id))
      assert Enum.all?(open, &(&1.status == "open"))
    end

    test "filters by severity" do
      _low = anomaly_fixture(%{severity: "low"})
      high = anomaly_fixture(%{severity: "high"})

      results = Analytics.list_anomalies(severity: "high")
      assert Enum.any?(results, &(&1.id == high.id))
      assert Enum.all?(results, &(&1.severity == "high"))
    end

    test "filters by anomaly_type" do
      _outlier = anomaly_fixture(%{anomaly_type: "outlier"})
      dup = anomaly_fixture(%{anomaly_type: "duplicate"})

      results = Analytics.list_anomalies(anomaly_type: "duplicate")
      assert Enum.any?(results, &(&1.id == dup.id))
      assert Enum.all?(results, &(&1.anomaly_type == "duplicate"))
    end

    test "filters by entity_type" do
      _txn = anomaly_fixture(%{entity_type: "transaction"})
      fin = anomaly_fixture(%{entity_type: "financial"})

      results = Analytics.list_anomalies(entity_type: "financial")
      assert Enum.any?(results, &(&1.id == fin.id))
      assert Enum.all?(results, &(&1.entity_type == "financial"))
    end
  end

  describe "resolve_anomaly/3" do
    test "sets status to resolved and records user and time" do
      anomaly = anomaly_fixture()
      user = Holdco.AccountsFixtures.user_fixture()

      assert {:ok, resolved} = Analytics.resolve_anomaly(anomaly, user.id, "Investigated and confirmed")
      assert resolved.status == "resolved"
      assert resolved.resolved_by_id == user.id
      assert resolved.notes == "Investigated and confirmed"
      assert resolved.resolved_at != nil
    end

    test "works without notes" do
      anomaly = anomaly_fixture()
      user = Holdco.AccountsFixtures.user_fixture()

      assert {:ok, resolved} = Analytics.resolve_anomaly(anomaly, user.id)
      assert resolved.status == "resolved"
    end
  end

  describe "mark_false_positive/3" do
    test "sets status to false_positive" do
      anomaly = anomaly_fixture()
      user = Holdco.AccountsFixtures.user_fixture()

      assert {:ok, fp} = Analytics.mark_false_positive(anomaly, user.id, "Not a real anomaly")
      assert fp.status == "false_positive"
      assert fp.resolved_by_id == user.id
      assert fp.notes == "Not a real anomaly"
      assert fp.resolved_at != nil
    end
  end

  describe "count_open_anomalies/0" do
    test "counts open anomalies" do
      _a1 = anomaly_fixture(%{status: "open"})
      _a2 = anomaly_fixture(%{status: "open"})
      _a3 = anomaly_fixture(%{status: "resolved"})

      count = Analytics.count_open_anomalies()
      assert count >= 2
    end
  end

  describe "detect_transaction_anomalies/1" do
    test "returns empty list when no transactions exist" do
      company = company_fixture()
      result = Analytics.detect_transaction_anomalies(company.id)
      assert result == []
    end

    test "detects outliers in transactions" do
      company = company_fixture()

      # Create several normal transactions
      for _i <- 1..10 do
        transaction_fixture(%{company: company, amount: 100.0, description: "Normal txn", date: "2024-01-15"})
      end

      # Create one extreme outlier
      transaction_fixture(%{company: company, amount: 100_000.0, description: "Outlier txn", date: "2024-01-16"})

      results = Analytics.detect_transaction_anomalies(company.id)

      # Should detect anomalies (outlier and/or unusual_amount)
      assert length(results) > 0

      assert Enum.any?(results, fn
        {:ok, a} -> a.anomaly_type in ["outlier", "unusual_amount"]
        _ -> false
      end)
    end

    test "detects duplicate transactions" do
      company = company_fixture()

      # Create duplicate transactions (same description and date)
      transaction_fixture(%{company: company, amount: 100.0, description: "Duplicate payment", date: "2024-03-01"})
      transaction_fixture(%{company: company, amount: 100.0, description: "Duplicate payment", date: "2024-03-01"})
      transaction_fixture(%{company: company, amount: 200.0, description: "Other txn", date: "2024-03-02"})

      results = Analytics.detect_transaction_anomalies(company.id)

      duplicates =
        Enum.filter(results, fn
          {:ok, a} -> a.anomaly_type == "duplicate"
          _ -> false
        end)

      assert length(duplicates) >= 1
    end
  end

  describe "detect_financial_anomalies/1" do
    test "returns empty list when fewer than 2 financials" do
      company = company_fixture()
      _f1 = financial_fixture(%{company: company, period: "2024-Q1", revenue: 100_000.0, expenses: 50_000.0})

      result = Analytics.detect_financial_anomalies(company.id)
      assert result == []
    end

    test "detects rapid revenue changes" do
      company = company_fixture()

      # Create financials with >50% change
      _f1 = financial_fixture(%{company: company, period: "2024-Q1", revenue: 100_000.0, expenses: 50_000.0})
      _f2 = financial_fixture(%{company: company, period: "2024-Q2", revenue: 200_000.0, expenses: 55_000.0})

      results = Analytics.detect_financial_anomalies(company.id)

      rapid_changes =
        Enum.filter(results, fn
          {:ok, a} -> a.anomaly_type == "rapid_change"
          _ -> false
        end)

      assert length(rapid_changes) >= 1
    end

    test "returns empty with stable financials" do
      company = company_fixture()

      _f1 = financial_fixture(%{company: company, period: "2024-Q1", revenue: 100_000.0, expenses: 50_000.0})
      _f2 = financial_fixture(%{company: company, period: "2024-Q2", revenue: 105_000.0, expenses: 52_000.0})

      results = Analytics.detect_financial_anomalies(company.id)

      # With only a ~5% change, no rapid_change anomalies should be detected
      rapid_changes =
        Enum.filter(results, fn
          {:ok, a} -> a.anomaly_type == "rapid_change"
          _ -> false
        end)

      assert rapid_changes == []
    end
  end
end
