defmodule Holdco.Analytics.CustomDashboardTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures
  import Holdco.AccountsFixtures

  alias Holdco.Analytics

  describe "custom_dashboards CRUD" do
    test "list_custom_dashboards/1 returns dashboards for a user" do
      user = user_fixture()
      dashboard = custom_dashboard_fixture(%{user: user})

      results = Analytics.list_custom_dashboards(user.id)
      assert Enum.any?(results, &(&1.id == dashboard.id))
    end

    test "list_custom_dashboards/1 does not return other users' dashboards" do
      user1 = user_fixture()
      user2 = user_fixture()
      _dash1 = custom_dashboard_fixture(%{user: user1})
      dash2 = custom_dashboard_fixture(%{user: user2})

      results = Analytics.list_custom_dashboards(user1.id)
      refute Enum.any?(results, &(&1.id == dash2.id))
    end

    test "get_custom_dashboard!/1 returns the dashboard" do
      dashboard = custom_dashboard_fixture()
      fetched = Analytics.get_custom_dashboard!(dashboard.id)
      assert fetched.id == dashboard.id
    end

    test "get_custom_dashboard!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Analytics.get_custom_dashboard!(0)
      end
    end

    test "create_custom_dashboard/1 with valid data" do
      user = user_fixture()

      assert {:ok, dashboard} =
               Analytics.create_custom_dashboard(%{
                 user_id: user.id,
                 name: "My Dashboard",
                 description: "Main overview dashboard",
                 theme: "dark",
                 refresh_interval_seconds: 60,
                 widgets: [%{"type" => "chart", "config" => %{}, "position" => %{"x" => 0, "y" => 0}}],
                 layout: %{"columns" => 3}
               })

      assert dashboard.name == "My Dashboard"
      assert dashboard.theme == "dark"
      assert dashboard.refresh_interval_seconds == 60
      assert length(dashboard.widgets) == 1
      assert dashboard.layout == %{"columns" => 3}
      assert dashboard.is_default == false
      assert dashboard.is_shared == false
    end

    test "create_custom_dashboard/1 with all themes" do
      user = user_fixture()

      for theme <- ~w(light dark auto) do
        assert {:ok, dashboard} =
                 Analytics.create_custom_dashboard(%{
                   user_id: user.id,
                   name: "Dashboard #{theme}",
                   theme: theme
                 })

        assert dashboard.theme == theme
      end
    end

    test "create_custom_dashboard/1 fails without required fields" do
      assert {:error, changeset} = Analytics.create_custom_dashboard(%{})
      errors = errors_on(changeset)
      assert errors[:user_id]
      assert errors[:name]
    end

    test "create_custom_dashboard/1 fails with invalid theme" do
      user = user_fixture()

      assert {:error, changeset} =
               Analytics.create_custom_dashboard(%{
                 user_id: user.id,
                 name: "Bad Theme",
                 theme: "invalid"
               })

      assert errors_on(changeset)[:theme]
    end

    test "create_custom_dashboard/1 fails with zero refresh interval" do
      user = user_fixture()

      assert {:error, changeset} =
               Analytics.create_custom_dashboard(%{
                 user_id: user.id,
                 name: "Bad Refresh",
                 refresh_interval_seconds: 0
               })

      assert errors_on(changeset)[:refresh_interval_seconds]
    end

    test "update_custom_dashboard/2 with valid data" do
      dashboard = custom_dashboard_fixture()

      assert {:ok, updated} =
               Analytics.update_custom_dashboard(dashboard, %{
                 name: "Updated Dashboard",
                 theme: "dark",
                 is_shared: true,
                 description: "Updated description"
               })

      assert updated.name == "Updated Dashboard"
      assert updated.theme == "dark"
      assert updated.is_shared == true
    end

    test "update_custom_dashboard/2 with widgets" do
      dashboard = custom_dashboard_fixture()

      widgets = [
        %{"type" => "metric", "config" => %{"metric" => "nav"}, "position" => %{"x" => 0, "y" => 0}},
        %{"type" => "chart", "config" => %{"chart_type" => "line"}, "position" => %{"x" => 1, "y" => 0}}
      ]

      assert {:ok, updated} =
               Analytics.update_custom_dashboard(dashboard, %{widgets: widgets})

      assert length(updated.widgets) == 2
    end

    test "delete_custom_dashboard/1 removes the dashboard" do
      dashboard = custom_dashboard_fixture()
      assert {:ok, _} = Analytics.delete_custom_dashboard(dashboard)

      assert_raise Ecto.NoResultsError, fn ->
        Analytics.get_custom_dashboard!(dashboard.id)
      end
    end

    test "default_dashboard_for_user/1 returns the default dashboard" do
      user = user_fixture()
      _regular = custom_dashboard_fixture(%{user: user, is_default: false, name: "Regular"})
      default = custom_dashboard_fixture(%{user: user, is_default: true, name: "Default"})

      result = Analytics.default_dashboard_for_user(user.id)
      assert result.id == default.id
    end

    test "default_dashboard_for_user/1 returns nil when no default" do
      user = user_fixture()
      _regular = custom_dashboard_fixture(%{user: user, is_default: false})

      assert Analytics.default_dashboard_for_user(user.id) == nil
    end

    test "shared_dashboards/0 returns only shared dashboards" do
      user = user_fixture()
      shared = custom_dashboard_fixture(%{user: user, is_shared: true, name: "Shared"})
      _private = custom_dashboard_fixture(%{user: user, is_shared: false, name: "Private"})

      results = Analytics.shared_dashboards()
      assert Enum.any?(results, &(&1.id == shared.id))
      refute Enum.any?(results, &(&1.is_shared == false))
    end

    test "create_custom_dashboard/1 with notes" do
      user = user_fixture()

      assert {:ok, dashboard} =
               Analytics.create_custom_dashboard(%{
                 user_id: user.id,
                 name: "With Notes",
                 notes: "Special dashboard for quarterly reviews"
               })

      assert dashboard.notes == "Special dashboard for quarterly reviews"
    end

    test "create_custom_dashboard/1 defaults" do
      user = user_fixture()

      assert {:ok, dashboard} =
               Analytics.create_custom_dashboard(%{
                 user_id: user.id,
                 name: "Defaults Test"
               })

      assert dashboard.theme == "light"
      assert dashboard.refresh_interval_seconds == 300
      assert dashboard.is_default == false
      assert dashboard.is_shared == false
      assert dashboard.widgets == []
      assert dashboard.layout == %{}
    end
  end
end
