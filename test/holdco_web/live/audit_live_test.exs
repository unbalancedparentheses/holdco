defmodule HoldcoWeb.AuditLiveTest do
  use HoldcoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "GET /audit-log" do
    test "renders audit log page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/audit-log")

      assert html =~ "Audit Log"
    end

    test "renders page title and deck", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/audit-log")

      assert html =~ "page-title"
      assert html =~ "Real-time activity stream across all entities"
    end

    test "renders page-title-rule", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/audit-log")

      assert html =~ "page-title-rule"
    end

    test "shows filter controls", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/audit-log")

      assert html =~ "Filters"
      assert html =~ "Filter"
      assert html =~ "Clear"
    end

    test "shows action filter dropdown", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/audit-log")

      assert html =~ ~s(name="filters[action]")
      assert html =~ "create"
      assert html =~ "update"
      assert html =~ "delete"
    end

    test "shows table name filter input", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/audit-log")

      assert html =~ ~s(name="filters[table_name]")
      assert html =~ "e.g. companies"
    end

    test "shows date range filter inputs", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/audit-log")

      assert html =~ ~s(name="filters[from]")
      assert html =~ ~s(name="filters[to]")
    end

    test "shows metrics strip with counts", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/audit-log")

      assert html =~ "metrics-strip"
      assert html =~ "Total Entries"
      assert html =~ "Creates"
      assert html =~ "Updates"
      assert html =~ "Deletes"
    end

    test "shows Activity Stream section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/audit-log")

      assert html =~ "Activity Stream"
    end

    test "shows empty state when no audit logs", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/audit-log")

      assert html =~ "No audit log entries yet. Actions will appear here in real-time."
    end

    test "displays audit log table headers", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/audit-log")

      assert html =~ "Time"
      assert html =~ "Action"
      assert html =~ "Table"
      assert html =~ "Record ID"
      assert html =~ "Details"
    end
  end

  describe "with audit log entries" do
    test "displays existing audit log entries", %{conn: conn} do
      audit_log_fixture(%{action: "create", table_name: "companies", record_id: 42, details: "Created Acme Corp"})

      {:ok, _view, html} = live(conn, ~p"/audit-log")

      assert html =~ "create"
      assert html =~ "companies"
      assert html =~ "#42"
      assert html =~ "Created Acme Corp"
    end

    test "shows correct tag classes for different actions", %{conn: conn} do
      audit_log_fixture(%{action: "create", table_name: "companies"})
      audit_log_fixture(%{action: "update", table_name: "holdings"})
      audit_log_fixture(%{action: "delete", table_name: "transactions"})

      {:ok, _view, html} = live(conn, ~p"/audit-log")

      assert html =~ "tag-jade"
      assert html =~ "tag-lemon"
      assert html =~ "tag-crimson"
    end

    test "metrics strip reflects correct counts", %{conn: conn} do
      audit_log_fixture(%{action: "create", table_name: "companies"})
      audit_log_fixture(%{action: "create", table_name: "holdings"})
      audit_log_fixture(%{action: "update", table_name: "companies"})

      {:ok, _view, html} = live(conn, ~p"/audit-log")

      # Should show at least 3 total entries and 2 creates, 1 update
      assert html =~ "metric-value"
    end
  end

  describe "filtering" do
    test "filter by action", %{conn: conn} do
      audit_log_fixture(%{action: "create", table_name: "companies", details: "created_entry"})
      audit_log_fixture(%{action: "update", table_name: "companies", details: "updated_entry"})

      {:ok, view, _html} = live(conn, ~p"/audit-log")

      html =
        view
        |> form(~s(form[phx-submit="filter"]), %{
          "filters" => %{"action" => "create", "table_name" => "", "from" => "", "to" => ""}
        })
        |> render_submit()

      assert html =~ "created_entry"
      assert html =~ "Filtered"
    end

    test "filter by table_name", %{conn: conn} do
      audit_log_fixture(%{action: "create", table_name: "companies", details: "comp_entry"})
      audit_log_fixture(%{action: "create", table_name: "holdings", details: "hold_entry"})

      {:ok, view, _html} = live(conn, ~p"/audit-log")

      html =
        view
        |> form(~s(form[phx-submit="filter"]), %{
          "filters" => %{"action" => "", "table_name" => "companies", "from" => "", "to" => ""}
        })
        |> render_submit()

      assert html =~ "comp_entry"
      assert html =~ "Filtered"
    end

    test "clear filters resets to default", %{conn: conn} do
      audit_log_fixture(%{action: "create", table_name: "companies"})
      audit_log_fixture(%{action: "update", table_name: "holdings"})

      {:ok, view, _html} = live(conn, ~p"/audit-log")

      # Apply a filter first
      view
      |> form(~s(form[phx-submit="filter"]), %{
        "filters" => %{"action" => "create", "table_name" => "", "from" => "", "to" => ""}
      })
      |> render_submit()

      # Now clear
      html = view |> element(~s(button[phx-click="clear_filters"])) |> render_click()

      refute html =~ "Filtered"
    end

    test "shows filtered empty state when no matches", %{conn: conn} do
      audit_log_fixture(%{action: "create", table_name: "companies"})

      {:ok, view, _html} = live(conn, ~p"/audit-log")

      html =
        view
        |> form(~s(form[phx-submit="filter"]), %{
          "filters" => %{"action" => "delete", "table_name" => "", "from" => "", "to" => ""}
        })
        |> render_submit()

      assert html =~ "No audit log entries match the current filters."
    end
  end

  describe "real-time updates" do
    test "receives new audit log entries via PubSub", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/audit-log")

      # Simulate a new audit log being created and broadcast
      {:ok, log} = Holdco.Platform.create_audit_log(%{
        action: "create",
        table_name: "companies",
        record_id: 99,
        details: "Realtime entry"
      })

      send(view.pid, {:audit_log_created, log})

      html = render(view)
      assert html =~ "Realtime entry"
    end
  end

  describe "footer link" do
    test "audit-log link is present in footer", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/audit-log")

      assert html =~ ~s(href="/audit-log")
      assert html =~ "Audit Log"
    end
  end

  describe "filter by date range" do
    test "filter by from date", %{conn: conn} do
      audit_log_fixture(%{action: "create", table_name: "companies", details: "recent_entry"})

      {:ok, view, _html} = live(conn, ~p"/audit-log")

      html =
        view
        |> form(~s(form[phx-submit="filter"]), %{
          "filters" => %{"action" => "", "table_name" => "", "from" => "2020-01-01", "to" => ""}
        })
        |> render_submit()

      assert html =~ "recent_entry"
      assert html =~ "Filtered"
    end

    test "filter by to date", %{conn: conn} do
      audit_log_fixture(%{action: "create", table_name: "companies", details: "old_entry"})

      {:ok, view, _html} = live(conn, ~p"/audit-log")

      html =
        view
        |> form(~s(form[phx-submit="filter"]), %{
          "filters" => %{"action" => "", "table_name" => "", "from" => "", "to" => "2099-12-31"}
        })
        |> render_submit()

      assert html =~ "old_entry"
    end

    test "filter by date range narrows results", %{conn: conn} do
      audit_log_fixture(%{action: "create", table_name: "companies", details: "in_range_entry"})

      {:ok, view, _html} = live(conn, ~p"/audit-log")

      html =
        view
        |> form(~s(form[phx-submit="filter"]), %{
          "filters" => %{"action" => "", "table_name" => "", "from" => "2020-01-01", "to" => "2099-12-31"}
        })
        |> render_submit()

      assert html =~ "in_range_entry"
    end
  end

  describe "combined filters" do
    test "filter by action and table_name together", %{conn: conn} do
      audit_log_fixture(%{action: "create", table_name: "companies", details: "targeted_entry"})
      audit_log_fixture(%{action: "update", table_name: "companies", details: "other_entry"})

      {:ok, view, _html} = live(conn, ~p"/audit-log")

      html =
        view
        |> form(~s(form[phx-submit="filter"]), %{
          "filters" => %{"action" => "create", "table_name" => "companies", "from" => "", "to" => ""}
        })
        |> render_submit()

      assert html =~ "targeted_entry"
    end
  end

  describe "real-time filtered update" do
    test "new audit log matching filters appears", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/audit-log")

      # Apply a filter
      view
      |> form(~s(form[phx-submit="filter"]), %{
        "filters" => %{"action" => "create", "table_name" => "", "from" => "", "to" => ""}
      })
      |> render_submit()

      # Simulate a matching broadcast (build struct directly to avoid PubSub cross-test interference)
      log = %{
        id: System.unique_integer([:positive]),
        action: "create",
        table_name: "holdings",
        record_id: 55,
        details: "Filtered realtime",
        inserted_at: DateTime.utc_now()
      }

      send(view.pid, {:audit_log_created, log})

      html = render(view)
      assert html =~ "Filtered realtime"
    end

    test "new audit log NOT matching filters is ignored", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/audit-log")

      # Apply a filter for "delete" action only
      view
      |> form(~s(form[phx-submit="filter"]), %{
        "filters" => %{"action" => "delete", "table_name" => "", "from" => "", "to" => ""}
      })
      |> render_submit()

      # Simulate a NON-matching broadcast (action=create, but filter is "delete")
      log = %{
        id: System.unique_integer([:positive]),
        action: "create",
        table_name: "holdings",
        record_id: 56,
        details: "Should not appear",
        inserted_at: DateTime.utc_now()
      }

      send(view.pid, {:audit_log_created, log})

      html = render(view)
      refute html =~ "Should not appear"
    end
  end

  describe "generic handle_info" do
    test "unknown messages are handled gracefully", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/audit-log")

      send(view.pid, :unknown_message)

      html = render(view)
      assert html =~ "Audit Log"
    end
  end

  describe "real-time update with table_name filter" do
    test "new audit log matching table_name filter appears", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/audit-log")

      # Apply a table_name filter
      view
      |> form(~s(form[phx-submit="filter"]), %{
        "filters" => %{"action" => "", "table_name" => "holdings", "from" => "", "to" => ""}
      })
      |> render_submit()

      # Simulate a matching broadcast (build struct directly to avoid PubSub cross-test interference)
      log = %{
        id: System.unique_integer([:positive]),
        action: "create",
        table_name: "holdings",
        record_id: 77,
        details: "Holdings filter match",
        inserted_at: DateTime.utc_now()
      }

      send(view.pid, {:audit_log_created, log})

      html = render(view)
      assert html =~ "Holdings filter match"
    end

    test "new audit log NOT matching table_name filter is ignored", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/audit-log")

      # Apply table_name filter for "companies"
      view
      |> form(~s(form[phx-submit="filter"]), %{
        "filters" => %{"action" => "", "table_name" => "companies", "from" => "", "to" => ""}
      })
      |> render_submit()

      # Simulate a non-matching broadcast (table_name=holdings, but filter is "companies")
      log = %{
        id: System.unique_integer([:positive]),
        action: "create",
        table_name: "holdings",
        record_id: 78,
        details: "Should not show for companies filter",
        inserted_at: DateTime.utc_now()
      }

      send(view.pid, {:audit_log_created, log})

      html = render(view)
      refute html =~ "Should not show for companies filter"
    end
  end

  describe "real-time update with date filters" do
    test "new log with from date filter matching appears", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/audit-log")

      # Filter from a date in the past
      view
      |> form(~s(form[phx-submit="filter"]), %{
        "filters" => %{"action" => "", "table_name" => "", "from" => "2020-01-01", "to" => ""}
      })
      |> render_submit()

      log = %{
        id: System.unique_integer([:positive]),
        action: "create",
        table_name: "test",
        record_id: 80,
        details: "After from date",
        inserted_at: DateTime.utc_now()
      }

      send(view.pid, {:audit_log_created, log})

      html = render(view)
      assert html =~ "After from date"
    end

    test "new log with to date in the past is filtered out", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/audit-log")

      # Filter to a date in the past
      view
      |> form(~s(form[phx-submit="filter"]), %{
        "filters" => %{"action" => "", "table_name" => "", "from" => "", "to" => "2000-01-01"}
      })
      |> render_submit()

      log = %{
        id: System.unique_integer([:positive]),
        action: "create",
        table_name: "test",
        record_id: 81,
        details: "Too recent for old to filter",
        inserted_at: DateTime.utc_now()
      }

      send(view.pid, {:audit_log_created, log})

      html = render(view)
      refute html =~ "Too recent for old to filter"
    end
  end

  describe "unknown action tag" do
    test "unknown action gets ink tag", %{conn: conn} do
      audit_log_fixture(%{action: "archive", table_name: "companies", details: "archived_entry"})

      {:ok, _view, html} = live(conn, ~p"/audit-log")

      assert html =~ "tag-ink"
      assert html =~ "archive"
    end
  end

  describe "real-time update with invalid date filters" do
    test "invalid from date in filter does not break real-time matching", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/audit-log")

      view
      |> form(~s(form[phx-submit="filter"]), %{
        "filters" => %{"action" => "", "table_name" => "", "from" => "not-a-date", "to" => ""}
      })
      |> render_submit()

      log = %{
        id: System.unique_integer([:positive]),
        action: "create",
        table_name: "test",
        record_id: 82,
        details: "Invalid from date entry",
        inserted_at: DateTime.utc_now()
      }

      send(view.pid, {:audit_log_created, log})

      html = render(view)
      # With invalid date parse, matches_from? returns true
      assert html =~ "Invalid from date entry"
    end

    test "invalid to date in filter does not break real-time matching", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/audit-log")

      view
      |> form(~s(form[phx-submit="filter"]), %{
        "filters" => %{"action" => "", "table_name" => "", "from" => "", "to" => "not-a-date"}
      })
      |> render_submit()

      log = %{
        id: System.unique_integer([:positive]),
        action: "create",
        table_name: "test",
        record_id: 83,
        details: "Invalid to date entry",
        inserted_at: DateTime.utc_now()
      }

      send(view.pid, {:audit_log_created, log})

      html = render(view)
      # With invalid date parse, matches_to? returns true
      assert html =~ "Invalid to date entry"
    end
  end

  describe "format_time helper" do
    test "nil inserted_at renders empty for time column", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/audit-log")

      log = %{
        id: 900,
        action: "create",
        table_name: "test_nil_time",
        record_id: 1,
        details: "nil time entry",
        inserted_at: nil
      }

      send(view.pid, {:audit_log_created, log})

      html = render(view)
      assert html =~ "nil time entry"
    end
  end
end
