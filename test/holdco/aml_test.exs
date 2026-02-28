defmodule Holdco.AmlTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Compliance

  describe "aml_alerts CRUD" do
    test "create_aml_alert/1 with valid data" do
      company = company_fixture()

      assert {:ok, alert} =
               Compliance.create_aml_alert(%{
                 company_id: company.id,
                 alert_type: "large_transaction",
                 severity: "high",
                 amount: 500_000,
                 currency: "USD",
                 description: "Large wire transfer"
               })

      assert alert.alert_type == "large_transaction"
      assert alert.severity == "high"
      assert alert.status == "open"
    end

    test "create_aml_alert/1 with invalid data" do
      assert {:error, changeset} = Compliance.create_aml_alert(%{})
      assert errors_on(changeset)[:company_id]
    end

    test "create_aml_alert/1 validates alert_type enum" do
      company = company_fixture()

      assert {:error, changeset} =
               Compliance.create_aml_alert(%{
                 company_id: company.id,
                 alert_type: "invalid",
                 severity: "high"
               })

      assert errors_on(changeset)[:alert_type]
    end

    test "create_aml_alert/1 validates severity enum" do
      company = company_fixture()

      assert {:error, changeset} =
               Compliance.create_aml_alert(%{
                 company_id: company.id,
                 alert_type: "large_transaction",
                 severity: "invalid"
               })

      assert errors_on(changeset)[:severity]
    end

    test "create_aml_alert/1 validates status enum" do
      company = company_fixture()

      assert {:error, changeset} =
               Compliance.create_aml_alert(%{
                 company_id: company.id,
                 alert_type: "large_transaction",
                 severity: "high",
                 status: "invalid"
               })

      assert errors_on(changeset)[:status]
    end

    test "list_aml_alerts/0 returns all alerts" do
      alert = aml_alert_fixture()
      assert Enum.any?(Compliance.list_aml_alerts(), &(&1.id == alert.id))
    end

    test "list_aml_alerts/1 filters by company" do
      company = company_fixture()
      alert = aml_alert_fixture(%{company: company})
      _other = aml_alert_fixture()

      results = Compliance.list_aml_alerts(company.id)
      assert Enum.any?(results, &(&1.id == alert.id))
      assert length(results) == 1
    end

    test "get_aml_alert!/1 returns the alert with preloads" do
      alert = aml_alert_fixture()
      fetched = Compliance.get_aml_alert!(alert.id)
      assert fetched.id == alert.id
      assert fetched.company != nil
    end

    test "update_aml_alert/2 updates the alert" do
      alert = aml_alert_fixture()

      assert {:ok, updated} =
               Compliance.update_aml_alert(alert, %{
                 status: "investigating",
                 assigned_to: "John Smith"
               })

      assert updated.status == "investigating"
      assert updated.assigned_to == "John Smith"
    end

    test "update_aml_alert/2 can resolve alert" do
      alert = aml_alert_fixture()
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      assert {:ok, updated} =
               Compliance.update_aml_alert(alert, %{
                 status: "dismissed",
                 resolution_notes: "False positive",
                 resolved_at: now
               })

      assert updated.status == "dismissed"
      assert updated.resolution_notes == "False positive"
      assert updated.resolved_at == now
    end

    test "delete_aml_alert/1 deletes the alert" do
      alert = aml_alert_fixture()
      assert {:ok, _} = Compliance.delete_aml_alert(alert)
      assert_raise Ecto.NoResultsError, fn -> Compliance.get_aml_alert!(alert.id) end
    end

    test "create with all alert types" do
      company = company_fixture()

      for type <- ~w(large_transaction structuring velocity geographic_risk pattern_match pep_related) do
        assert {:ok, a} =
                 Compliance.create_aml_alert(%{
                   company_id: company.id,
                   alert_type: type,
                   severity: "medium"
                 })

        assert a.alert_type == type
      end
    end
  end

  describe "open_aml_alerts/0" do
    test "returns open, investigating, and escalated alerts" do
      company = company_fixture()

      {:ok, open} =
        Compliance.create_aml_alert(%{
          company_id: company.id,
          alert_type: "large_transaction",
          severity: "high",
          status: "open"
        })

      {:ok, investigating} =
        Compliance.create_aml_alert(%{
          company_id: company.id,
          alert_type: "structuring",
          severity: "medium",
          status: "investigating"
        })

      {:ok, escalated} =
        Compliance.create_aml_alert(%{
          company_id: company.id,
          alert_type: "velocity",
          severity: "critical",
          status: "escalated"
        })

      {:ok, dismissed} =
        Compliance.create_aml_alert(%{
          company_id: company.id,
          alert_type: "pattern_match",
          severity: "low",
          status: "dismissed"
        })

      results = Compliance.open_aml_alerts()
      ids = Enum.map(results, & &1.id)
      assert open.id in ids
      assert investigating.id in ids
      assert escalated.id in ids
      refute dismissed.id in ids
    end
  end

  describe "aml_alert_summary/0" do
    test "returns counts by status, severity, and type" do
      company = company_fixture()

      Compliance.create_aml_alert(%{
        company_id: company.id,
        alert_type: "large_transaction",
        severity: "critical",
        status: "open"
      })

      Compliance.create_aml_alert(%{
        company_id: company.id,
        alert_type: "structuring",
        severity: "low",
        status: "dismissed"
      })

      summary = Compliance.aml_alert_summary()
      assert is_list(summary.by_status)
      assert is_list(summary.by_severity)
      assert is_list(summary.by_type)
      assert Enum.any?(summary.by_status, &(&1.status == "open"))
      assert Enum.any?(summary.by_severity, &(&1.severity == "critical"))
      assert Enum.any?(summary.by_type, &(&1.alert_type == "large_transaction"))
    end
  end
end
