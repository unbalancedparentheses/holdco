defmodule Holdco.AnalyticsTest do
  use Holdco.DataCase

  import Holdco.HoldcoFixtures

  alias Holdco.Analytics

  describe "KPIs" do
    test "list_kpis/0 returns all KPIs" do
      kpi = kpi_fixture(%{name: "Revenue"})
      kpis = Analytics.list_kpis()
      assert length(kpis) >= 1
      assert Enum.any?(kpis, &(&1.id == kpi.id))
    end

    test "list_kpis/1 filters by company_id" do
      c1 = company_fixture(%{name: "KpiCo1"})
      c2 = company_fixture(%{name: "KpiCo2"})
      kpi1 = kpi_fixture(%{company: c1, name: "KPI A"})
      _kpi2 = kpi_fixture(%{company: c2, name: "KPI B"})

      kpis = Analytics.list_kpis(c1.id)
      assert length(kpis) == 1
      assert hd(kpis).id == kpi1.id
    end

    test "get_kpi!/1 returns the KPI with given id" do
      kpi = kpi_fixture(%{name: "Get KPI"})
      found = Analytics.get_kpi!(kpi.id)
      assert found.id == kpi.id
      assert found.name == "Get KPI"
    end

    test "get_kpi!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Analytics.get_kpi!(0)
      end
    end

    test "create_kpi/1 with valid attrs" do
      company = company_fixture()

      assert {:ok, kpi} =
               Analytics.create_kpi(%{
                 company_id: company.id,
                 name: "Customer Retention",
                 metric_type: "percentage",
                 target_value: 95.0,
                 unit: "%"
               })

      assert kpi.name == "Customer Retention"
      assert kpi.metric_type == "percentage"
    end

    test "create_kpi/1 fails without name" do
      assert {:error, changeset} = Analytics.create_kpi(%{})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "create_kpi/1 validates metric_type" do
      assert {:error, changeset} =
               Analytics.create_kpi(%{name: "Bad Type", metric_type: "invalid"})

      assert %{metric_type: _} = errors_on(changeset)
    end

    test "update_kpi/2 updates successfully" do
      kpi = kpi_fixture(%{name: "Old KPI"})
      assert {:ok, updated} = Analytics.update_kpi(kpi, %{name: "New KPI"})
      assert updated.name == "New KPI"
    end

    test "delete_kpi/1 deletes the KPI" do
      kpi = kpi_fixture()
      assert {:ok, _} = Analytics.delete_kpi(kpi)

      assert_raise Ecto.NoResultsError, fn ->
        Analytics.get_kpi!(kpi.id)
      end
    end
  end

  describe "KPI Snapshots" do
    test "list_kpi_snapshots/1 returns snapshots for a KPI" do
      kpi = kpi_fixture()
      snap = kpi_snapshot_fixture(%{kpi: kpi, current_value: 80_000.0, date: "2024-01-15"})

      snapshots = Analytics.list_kpi_snapshots(kpi.id)
      assert length(snapshots) == 1
      assert hd(snapshots).id == snap.id
    end

    test "list_kpi_snapshots/1 returns empty for KPI with no snapshots" do
      kpi = kpi_fixture()
      assert Analytics.list_kpi_snapshots(kpi.id) == []
    end

    test "create_kpi_snapshot/1 with valid attrs" do
      kpi = kpi_fixture()

      assert {:ok, snap} =
               Analytics.create_kpi_snapshot(%{
                 kpi_id: kpi.id,
                 current_value: 95_000.0,
                 date: "2024-02-15",
                 trend: "up"
               })

      assert Decimal.equal?(snap.current_value, Decimal.new("95000.0"))
      assert snap.trend == "up"
    end

    test "create_kpi_snapshot/1 fails without kpi_id" do
      assert {:error, changeset} =
               Analytics.create_kpi_snapshot(%{current_value: 100.0})

      assert %{kpi_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "delete_kpi_snapshot/1 deletes the snapshot" do
      kpi = kpi_fixture()
      snap = kpi_snapshot_fixture(%{kpi: kpi})
      assert {:ok, _} = Analytics.delete_kpi_snapshot(snap)
      assert Analytics.list_kpi_snapshots(kpi.id) == []
    end
  end

  describe "Report Templates" do
    test "list_report_templates/0 returns all templates" do
      rt = report_template_fixture(%{name: "Monthly Report"})
      templates = Analytics.list_report_templates()
      assert length(templates) >= 1
      assert Enum.any?(templates, &(&1.id == rt.id))
    end

    test "list_report_templates/1 filters by user_id" do
      u1 = Holdco.AccountsFixtures.user_fixture()
      u2 = Holdco.AccountsFixtures.user_fixture()
      rt1 = report_template_fixture(%{user: u1, name: "User1 Report"})
      _rt2 = report_template_fixture(%{user: u2, name: "User2 Report"})

      templates = Analytics.list_report_templates(u1.id)
      assert length(templates) == 1
      assert hd(templates).id == rt1.id
    end

    test "get_report_template!/1 returns the template" do
      rt = report_template_fixture(%{name: "Get Template"})
      found = Analytics.get_report_template!(rt.id)
      assert found.id == rt.id
      assert found.name == "Get Template"
    end

    test "get_report_template!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Analytics.get_report_template!(0)
      end
    end

    test "create_report_template/1 with valid attrs" do
      user = Holdco.AccountsFixtures.user_fixture()

      assert {:ok, rt} =
               Analytics.create_report_template(%{
                 user_id: user.id,
                 name: "Quarterly Board Pack",
                 frequency: "quarterly"
               })

      assert rt.name == "Quarterly Board Pack"
      assert rt.frequency == "quarterly"
    end

    test "create_report_template/1 fails without name" do
      assert {:error, changeset} = Analytics.create_report_template(%{})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "create_report_template/1 validates frequency" do
      assert {:error, changeset} =
               Analytics.create_report_template(%{name: "Bad Freq", frequency: "invalid"})

      assert %{frequency: _} = errors_on(changeset)
    end

    test "update_report_template/2 updates successfully" do
      rt = report_template_fixture(%{name: "Old Report"})
      assert {:ok, updated} = Analytics.update_report_template(rt, %{name: "New Report"})
      assert updated.name == "New Report"
    end

    test "delete_report_template/1 deletes the template" do
      rt = report_template_fixture()
      assert {:ok, _} = Analytics.delete_report_template(rt)

      assert_raise Ecto.NoResultsError, fn ->
        Analytics.get_report_template!(rt.id)
      end
    end
  end
end
