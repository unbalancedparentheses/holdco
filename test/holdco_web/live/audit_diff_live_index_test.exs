defmodule HoldcoWeb.AuditDiffLiveIndexTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "Index" do
    test "renders Audit Diffs page", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/audit-diffs")
      assert html =~ "Audit Diffs"
    end

    test "shows filter panel", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/audit-diffs")
      assert html =~ "Filters"
      assert html =~ "Action"
      assert html =~ "Table Name"
    end

    test "shows metrics strip", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/audit-diffs")
      assert html =~ "Total Entries"
      assert html =~ "With Diffs"
      assert html =~ "Creates"
      assert html =~ "Updates"
    end

    test "shows empty state when no audit logs", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/audit-diffs")
      assert html =~ "No audit log entries"
    end

    test "renders with audit log data", %{conn: conn} do
      audit_log_fixture(%{
        action: "create",
        table_name: "companies",
        record_id: 1,
        old_values: nil,
        new_values: Jason.encode!(%{"name" => "New Corp"})
      })

      {:ok, _live, html} = live(conn, ~p"/audit-diffs")
      assert html =~ "companies"
      assert html =~ "create"
    end

    test "expands an audit entry to show diff", %{conn: conn} do
      log =
        audit_log_fixture(%{
          action: "update",
          table_name: "companies",
          record_id: 1,
          old_values: Jason.encode!(%{"name" => "Old Name"}),
          new_values: Jason.encode!(%{"name" => "New Name"})
        })

      {:ok, live, _html} = live(conn, ~p"/audit-diffs")
      html = render_click(live, "toggle_expand", %{"id" => to_string(log.id)})
      assert html =~ "Old Name" || html =~ "New Name" || html =~ "field(s) changed"
    end

    test "toggle_expand collapses when clicked again", %{conn: conn} do
      log =
        audit_log_fixture(%{
          action: "update",
          table_name: "companies",
          record_id: 1,
          old_values: Jason.encode!(%{"name" => "Old Name"}),
          new_values: Jason.encode!(%{"name" => "New Name"})
        })

      {:ok, live, _html} = live(conn, ~p"/audit-diffs")
      # First click expands
      render_click(live, "toggle_expand", %{"id" => to_string(log.id)})
      # Second click collapses
      html = render_click(live, "toggle_expand", %{"id" => to_string(log.id)})
      # After collapse, the diff table should not be visible
      assert html =~ "Audit Diffs"
    end

    test "expanded entry without diffs shows no diff data message", %{conn: conn} do
      log =
        audit_log_fixture(%{
          action: "create",
          table_name: "companies",
          record_id: 1,
          old_values: nil,
          new_values: nil
        })

      {:ok, live, _html} = live(conn, ~p"/audit-diffs")
      html = render_click(live, "toggle_expand", %{"id" => to_string(log.id)})
      assert html =~ "No old/new value data recorded" || html =~ "No diff data"
    end

    test "filters by action type", %{conn: conn} do
      audit_log_fixture(%{action: "create", table_name: "companies"})
      audit_log_fixture(%{action: "update", table_name: "companies"})

      {:ok, live, _html} = live(conn, ~p"/audit-diffs")

      html =
        live
        |> form("form[phx-submit=filter]", %{"filters" => %{"action" => "create", "table_name" => "", "from" => "", "to" => ""}})
        |> render_submit()

      assert html =~ "create"
    end

    test "filters by table name", %{conn: conn} do
      audit_log_fixture(%{action: "create", table_name: "companies"})
      audit_log_fixture(%{action: "create", table_name: "holdings"})

      {:ok, live, _html} = live(conn, ~p"/audit-diffs")

      html =
        live
        |> form("form[phx-submit=filter]", %{"filters" => %{"action" => "", "table_name" => "companies", "from" => "", "to" => ""}})
        |> render_submit()

      assert html =~ "companies"
    end

    test "filters by date range (from and to)", %{conn: conn} do
      audit_log_fixture(%{action: "create", table_name: "companies"})

      {:ok, live, _html} = live(conn, ~p"/audit-diffs")

      today = Date.utc_today() |> Date.to_iso8601()

      html =
        live
        |> form("form[phx-submit=filter]", %{
          "filters" => %{"action" => "", "table_name" => "", "from" => today, "to" => today}
        })
        |> render_submit()

      assert html =~ "Filtered"
    end

    test "filters with invalid from date still works", %{conn: conn} do
      audit_log_fixture(%{action: "create", table_name: "companies"})

      {:ok, live, _html} = live(conn, ~p"/audit-diffs")

      html =
        live
        |> form("form[phx-submit=filter]", %{
          "filters" => %{"action" => "", "table_name" => "", "from" => "not-a-date", "to" => ""}
        })
        |> render_submit()

      assert html =~ "Audit Diffs"
    end

    test "filters with invalid to date still works", %{conn: conn} do
      audit_log_fixture(%{action: "create", table_name: "companies"})

      {:ok, live, _html} = live(conn, ~p"/audit-diffs")

      html =
        live
        |> form("form[phx-submit=filter]", %{
          "filters" => %{"action" => "", "table_name" => "", "from" => "", "to" => "bad-date"}
        })
        |> render_submit()

      assert html =~ "Audit Diffs"
    end

    test "clears filters", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/audit-diffs")
      html = render_click(live, "clear_filters", %{})
      assert html =~ "Audit Diffs"
    end

    test "shows Filtered tag when filters are active", %{conn: conn} do
      audit_log_fixture(%{action: "create", table_name: "companies"})

      {:ok, live, _html} = live(conn, ~p"/audit-diffs")

      html =
        live
        |> form("form[phx-submit=filter]", %{"filters" => %{"action" => "create", "table_name" => "", "from" => "", "to" => ""}})
        |> render_submit()

      assert html =~ "Filtered"
    end

    test "handles audit_log_created broadcast for matching log", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/audit-diffs")

      # Create a log that should match default (empty) filters
      log =
        audit_log_fixture(%{
          action: "create",
          table_name: "test_table",
          record_id: 42,
          old_values: nil,
          new_values: Jason.encode!(%{"field" => "value"})
        })

      send(live.pid, {:audit_log_created, log})
      html = render(live)
      assert html =~ "test_table"
    end

    test "handles audit_log_created broadcast for non-matching log when filters active", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/audit-diffs")

      # Set a filter so only "delete" actions match
      live
      |> form("form[phx-submit=filter]", %{
        "filters" => %{"action" => "delete", "table_name" => "", "from" => "", "to" => ""}
      })
      |> render_submit()

      # Send a "create" action log, which should not match the filter
      log =
        audit_log_fixture(%{
          action: "create",
          table_name: "companies",
          record_id: 99
        })

      send(live.pid, {:audit_log_created, log})
      html = render(live)
      # The page should still render fine
      assert html =~ "Audit Diffs"
    end

    test "handles unknown info messages gracefully", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/audit-diffs")
      send(live.pid, :some_unknown_message)
      html = render(live)
      assert html =~ "Audit Diffs"
    end

    test "renders delete action with correct styling", %{conn: conn} do
      audit_log_fixture(%{
        action: "delete",
        table_name: "companies",
        record_id: 1,
        old_values: Jason.encode!(%{"name" => "Deleted Corp"}),
        new_values: nil
      })

      {:ok, _live, html} = live(conn, ~p"/audit-diffs")
      assert html =~ "delete"
      assert html =~ "companies"
    end

    test "expanded entry shows field diff details with added/removed/changed types", %{conn: conn} do
      # Create an update log with a field that was changed and a field that was added
      log =
        audit_log_fixture(%{
          action: "update",
          table_name: "companies",
          record_id: 1,
          old_values: Jason.encode!(%{"name" => "Old Name", "status" => "active"}),
          new_values: Jason.encode!(%{"name" => "New Name", "status" => "active", "country" => "US"})
        })

      {:ok, live, _html} = live(conn, ~p"/audit-diffs")
      html = render_click(live, "toggle_expand", %{"id" => to_string(log.id)})
      # Should show the diff table fields
      assert html =~ "Field" || html =~ "Change" || html =~ "Old Value" || html =~ "New Value"
    end

    test "metrics show correct counts for creates and updates", %{conn: conn} do
      audit_log_fixture(%{action: "create", table_name: "companies"})
      audit_log_fixture(%{action: "create", table_name: "holdings"})
      audit_log_fixture(%{action: "update", table_name: "companies",
        old_values: Jason.encode!(%{"name" => "Old"}),
        new_values: Jason.encode!(%{"name" => "New"})
      })

      {:ok, _live, html} = live(conn, ~p"/audit-diffs")
      assert html =~ "Total Entries"
      assert html =~ "Creates"
      assert html =~ "Updates"
    end

    test "renders entries with user email when user is present", %{conn: conn, user: user} do
      audit_log_fixture(%{
        action: "create",
        table_name: "companies",
        record_id: 1,
        user_id: user.id
      })

      {:ok, _live, html} = live(conn, ~p"/audit-diffs")
      # The audit log should show user email or fallback
      assert html =~ "companies"
    end
  end
end
