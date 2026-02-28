defmodule Holdco.Platform.PluginTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Platform

  describe "plugins CRUD" do
    test "list_plugins/0 returns all plugins" do
      plugin = plugin_fixture()
      assert Enum.any?(Platform.list_plugins(), &(&1.id == plugin.id))
    end

    test "get_plugin!/1 returns plugin with hooks preloaded" do
      plugin = plugin_fixture()
      fetched = Platform.get_plugin!(plugin.id)
      assert fetched.id == plugin.id
      assert is_list(fetched.hooks)
    end

    test "get_plugin!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Platform.get_plugin!(0)
      end
    end

    test "install_plugin/1 with valid data" do
      assert {:ok, plugin} =
               Platform.install_plugin(%{
                 name: "Test Plugin",
                 slug: "test-plugin",
                 plugin_type: "integration",
                 version: "2.0.0",
                 author: "Dev",
                 description: "A test plugin"
               })

      assert plugin.name == "Test Plugin"
      assert plugin.slug == "test-plugin"
      assert plugin.plugin_type == "integration"
      assert plugin.status == "installed"
      assert plugin.installed_at != nil
    end

    test "install_plugin/1 with all plugin types" do
      for type <- ~w(integration report widget automation data_source) do
        slug = "plugin-#{type}-#{System.unique_integer([:positive])}"

        assert {:ok, plugin} =
                 Platform.install_plugin(%{
                   name: "Plugin #{type}",
                   slug: slug,
                   plugin_type: type
                 })

        assert plugin.plugin_type == type
      end
    end

    test "install_plugin/1 fails without required fields" do
      assert {:error, changeset} = Platform.install_plugin(%{})
      errors = errors_on(changeset)
      assert errors[:name]
      assert errors[:slug]
      assert errors[:plugin_type]
    end

    test "install_plugin/1 fails with invalid plugin_type" do
      assert {:error, changeset} =
               Platform.install_plugin(%{
                 name: "Bad",
                 slug: "bad-plugin",
                 plugin_type: "invalid"
               })

      assert errors_on(changeset)[:plugin_type]
    end

    test "install_plugin/1 enforces unique slug" do
      plugin_fixture(%{slug: "unique-slug"})

      assert {:error, changeset} =
               Platform.install_plugin(%{
                 name: "Duplicate",
                 slug: "unique-slug",
                 plugin_type: "integration"
               })

      assert errors_on(changeset)[:slug]
    end

    test "update_plugin/2 with valid data" do
      plugin = plugin_fixture()

      assert {:ok, updated} =
               Platform.update_plugin(plugin, %{
                 description: "Updated description",
                 version: "2.0.0"
               })

      assert updated.description == "Updated description"
      assert updated.version == "2.0.0"
    end

    test "activate_plugin/1 sets status to active" do
      plugin = plugin_fixture()
      assert {:ok, activated} = Platform.activate_plugin(plugin)
      assert activated.status == "active"
      assert activated.last_activated_at != nil
    end

    test "deactivate_plugin/1 sets status to disabled" do
      plugin = plugin_fixture()
      {:ok, activated} = Platform.activate_plugin(plugin)
      assert {:ok, deactivated} = Platform.deactivate_plugin(activated)
      assert deactivated.status == "disabled"
    end

    test "uninstall_plugin/1 removes the plugin" do
      plugin = plugin_fixture()
      assert {:ok, _} = Platform.uninstall_plugin(plugin)

      assert_raise Ecto.NoResultsError, fn ->
        Platform.get_plugin!(plugin.id)
      end
    end
  end

  describe "plugin hooks" do
    test "list_plugin_hooks/1 returns hooks for plugin" do
      plugin = plugin_fixture()
      hook = plugin_hook_fixture(%{plugin: plugin})
      hooks = Platform.list_plugin_hooks(plugin.id)
      assert Enum.any?(hooks, &(&1.id == hook.id))
    end

    test "create_plugin_hook/1 with valid data" do
      plugin = plugin_fixture()

      assert {:ok, hook} =
               Platform.create_plugin_hook(%{
                 plugin_id: plugin.id,
                 hook_point: "before_save",
                 handler_function: "MyModule.before_save",
                 entity_type: "companies",
                 priority: 10
               })

      assert hook.hook_point == "before_save"
      assert hook.handler_function == "MyModule.before_save"
      assert hook.priority == 10
    end

    test "create_plugin_hook/1 fails with invalid hook_point" do
      plugin = plugin_fixture()

      assert {:error, changeset} =
               Platform.create_plugin_hook(%{
                 plugin_id: plugin.id,
                 hook_point: "invalid_point",
                 handler_function: "handler"
               })

      assert errors_on(changeset)[:hook_point]
    end

    test "delete_plugin_hook/1 removes the hook" do
      hook = plugin_hook_fixture()
      assert {:ok, _} = Platform.delete_plugin_hook(hook)
    end

    test "hooks_for_point/1 returns active hooks ordered by priority" do
      plugin = plugin_fixture()

      {:ok, h1} =
        Platform.create_plugin_hook(%{
          plugin_id: plugin.id,
          hook_point: "after_save",
          handler_function: "handler1",
          priority: 100
        })

      {:ok, h2} =
        Platform.create_plugin_hook(%{
          plugin_id: plugin.id,
          hook_point: "after_save",
          handler_function: "handler2",
          priority: 10
        })

      hooks = Platform.hooks_for_point("after_save")
      hook_ids = Enum.map(hooks, & &1.id)
      idx1 = Enum.find_index(hook_ids, &(&1 == h2.id))
      idx2 = Enum.find_index(hook_ids, &(&1 == h1.id))
      assert idx1 < idx2
    end
  end
end
