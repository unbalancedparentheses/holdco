defmodule Holdco.Analytics.BiConnectorTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Analytics

  describe "bi_connectors CRUD" do
    test "list_bi_connectors/0 returns all connectors" do
      connector = bi_connector_fixture()
      assert Enum.any?(Analytics.list_bi_connectors(), &(&1.id == connector.id))
    end

    test "get_bi_connector!/1 returns connector with export logs" do
      connector = bi_connector_fixture()
      fetched = Analytics.get_bi_connector!(connector.id)
      assert fetched.id == connector.id
      assert is_list(fetched.export_logs)
    end

    test "get_bi_connector!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Analytics.get_bi_connector!(0)
      end
    end

    test "create_bi_connector/1 with valid data" do
      assert {:ok, connector} =
               Analytics.create_bi_connector(%{
                 name: "My Power BI",
                 connector_type: "power_bi",
                 dataset_name: "holdco_data",
                 refresh_frequency: "hourly",
                 format: "csv",
                 row_limit: 10000
               })

      assert connector.name == "My Power BI"
      assert connector.connector_type == "power_bi"
      assert connector.refresh_frequency == "hourly"
      assert connector.format == "csv"
      assert connector.row_limit == 10000
      assert connector.is_active == true
    end

    test "create_bi_connector/1 with all connector types" do
      for type <- ~w(power_bi tableau looker metabase custom) do
        assert {:ok, connector} =
                 Analytics.create_bi_connector(%{
                   name: "Connector #{type}",
                   connector_type: type
                 })

        assert connector.connector_type == type
      end
    end

    test "create_bi_connector/1 fails without required fields" do
      assert {:error, changeset} = Analytics.create_bi_connector(%{})
      errors = errors_on(changeset)
      assert errors[:name]
      assert errors[:connector_type]
    end

    test "create_bi_connector/1 fails with invalid connector_type" do
      assert {:error, changeset} =
               Analytics.create_bi_connector(%{
                 name: "Bad Connector",
                 connector_type: "invalid_type"
               })

      assert errors_on(changeset)[:connector_type]
    end

    test "update_bi_connector/2 with valid data" do
      connector = bi_connector_fixture()

      assert {:ok, updated} =
               Analytics.update_bi_connector(connector, %{
                 name: "Updated Connector",
                 refresh_frequency: "weekly",
                 sync_status: "completed"
               })

      assert updated.name == "Updated Connector"
      assert updated.refresh_frequency == "weekly"
      assert updated.sync_status == "completed"
    end

    test "delete_bi_connector/1 removes the connector" do
      connector = bi_connector_fixture()
      assert {:ok, _} = Analytics.delete_bi_connector(connector)

      assert_raise Ecto.NoResultsError, fn ->
        Analytics.get_bi_connector!(connector.id)
      end
    end

    test "active_connectors/0 returns only active connectors" do
      active = bi_connector_fixture(%{is_active: true})
      _inactive = bi_connector_fixture(%{is_active: false})

      results = Analytics.active_connectors()
      assert Enum.any?(results, &(&1.id == active.id))
      refute Enum.any?(results, &(&1.is_active == false))
    end
  end

  describe "bi_export_logs" do
    test "list_bi_export_logs/1 returns logs for connector" do
      connector = bi_connector_fixture()
      log = bi_export_log_fixture(%{connector: connector})
      logs = Analytics.list_bi_export_logs(connector.id)
      assert Enum.any?(logs, &(&1.id == log.id))
    end

    test "create_bi_export_log/1 with valid data" do
      connector = bi_connector_fixture()
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      assert {:ok, log} =
               Analytics.create_bi_export_log(%{
                 connector_id: connector.id,
                 started_at: now,
                 completed_at: now,
                 rows_exported: 500,
                 tables_exported: ["companies"],
                 status: "success",
                 file_size_bytes: 2048
               })

      assert log.rows_exported == 500
      assert log.status == "success"
    end

    test "create_bi_export_log/1 fails with invalid status" do
      connector = bi_connector_fixture()

      assert {:error, changeset} =
               Analytics.create_bi_export_log(%{
                 connector_id: connector.id,
                 status: "invalid_status"
               })

      assert errors_on(changeset)[:status]
    end

    test "latest_export_for_connector/1 returns most recent log" do
      connector = bi_connector_fixture()
      _old = bi_export_log_fixture(%{connector: connector, rows_exported: 10})
      new = bi_export_log_fixture(%{connector: connector, rows_exported: 20})

      latest = Analytics.latest_export_for_connector(connector.id)
      assert latest.id == new.id
    end

    test "latest_export_for_connector/1 returns nil when no logs" do
      connector = bi_connector_fixture()
      assert Analytics.latest_export_for_connector(connector.id) == nil
    end
  end
end
