defmodule HoldcoWeb.PeriodLockLiveIndexTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "Index" do
    test "renders Period Locks page", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/period-locks")
      assert html =~ "Period Locks"
      assert html =~ "Lock accounting periods to prevent modifications to closed periods"
    end

    test "shows metrics strip", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/period-locks")
      assert html =~ "Total Locks"
      assert html =~ "Active Locks"
      assert html =~ "Unlocked"
    end

    test "shows table with headers", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/period-locks")
      assert html =~ "All Period Locks"
      assert html =~ "Company"
      assert html =~ "Period Type"
      assert html =~ "Status"
    end

    test "shows empty state when no period locks exist", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/period-locks")
      assert html =~ "No period locks defined."
    end

    test "shows company filter", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/period-locks")
      assert html =~ "All Companies"
    end
  end

  describe "show_form and close_form events" do
    test "show_form opens the lock period form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/period-locks")
      html = render_click(view, "show_form", %{})
      assert html =~ "Lock Period"
      assert html =~ "Period Type"
      assert html =~ "Period Start"
      assert html =~ "Period End"
    end

    test "close_form closes the form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/period-locks")
      render_click(view, "show_form", %{})
      html = render_click(view, "close_form", %{})
      # The dialog should be gone; the main page title should still be there
      assert html =~ "Period Locks"
    end
  end

  describe "filter_company event" do
    test "filters period locks by company", %{conn: conn, user: user} do
      company = company_fixture(%{name: "Lock Filter Co"})
      {:ok, _lock} = Holdco.Finance.lock_period(to_string(company.id), "2025-01-01", "2025-01-31", "month", user.id)

      {:ok, view, _html} = live(conn, ~p"/period-locks")
      html = render_change(view, "filter_company", %{"company_id" => to_string(company.id)})
      assert html =~ "Lock Filter Co"
    end

    test "filters with empty company_id shows all", %{conn: conn, user: user} do
      company = company_fixture(%{name: "All Locks Co"})
      {:ok, _lock} = Holdco.Finance.lock_period(to_string(company.id), "2025-02-01", "2025-02-28", "month", user.id)

      {:ok, view, _html} = live(conn, ~p"/period-locks")
      html = render_change(view, "filter_company", %{"company_id" => ""})
      assert html =~ "All Locks Co"
    end
  end

  describe "lock_period event" do
    test "locks a period successfully", %{conn: conn} do
      company = company_fixture(%{name: "Lock Period Co"})

      {:ok, view, _html} = live(conn, ~p"/period-locks")
      render_click(view, "show_form", %{})

      html =
        render_click(view, "lock_period", %{
          "lock" => %{
            "company_id" => to_string(company.id),
            "period_start" => "2025-01-01",
            "period_end" => "2025-01-31",
            "period_type" => "month"
          }
        })

      assert html =~ "Period locked successfully"
    end

    test "lock_period with invalid data shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/period-locks")
      render_click(view, "show_form", %{})

      html =
        render_click(view, "lock_period", %{
          "lock" => %{
            "company_id" => "",
            "period_start" => "",
            "period_end" => "",
            "period_type" => ""
          }
        })

      assert html =~ "Failed to lock period"
    end
  end

  describe "show_unlock and close_unlock events" do
    test "show_unlock opens the unlock form", %{conn: conn, user: user} do
      company = company_fixture()
      {:ok, lock} = Holdco.Finance.lock_period(to_string(company.id), "2025-03-01", "2025-03-31", "month", user.id)

      {:ok, view, _html} = live(conn, ~p"/period-locks")
      html = render_click(view, "show_unlock", %{"id" => to_string(lock.id)})
      assert html =~ "Unlock Period"
      assert html =~ "Reason for unlocking"
    end

    test "close_unlock closes the unlock form", %{conn: conn, user: user} do
      company = company_fixture()
      {:ok, lock} = Holdco.Finance.lock_period(to_string(company.id), "2025-04-01", "2025-04-30", "month", user.id)

      {:ok, view, _html} = live(conn, ~p"/period-locks")
      render_click(view, "show_unlock", %{"id" => to_string(lock.id)})
      html = render_click(view, "close_unlock", %{})
      refute html =~ "Unlock Period"
    end
  end

  describe "unlock_period event" do
    test "unlocks a locked period", %{conn: conn, user: user} do
      company = company_fixture()
      {:ok, lock} = Holdco.Finance.lock_period(to_string(company.id), "2025-05-01", "2025-05-31", "month", user.id)

      {:ok, view, _html} = live(conn, ~p"/period-locks")
      render_click(view, "show_unlock", %{"id" => to_string(lock.id)})
      html = render_click(view, "unlock_period", %{"reason" => "Need to make corrections"})
      assert html =~ "Period unlocked"
    end
  end

  describe "delete event" do
    test "deletes a period lock", %{conn: conn, user: user} do
      company = company_fixture()
      {:ok, lock} = Holdco.Finance.lock_period(to_string(company.id), "2025-06-01", "2025-06-30", "month", user.id)

      {:ok, view, _html} = live(conn, ~p"/period-locks")
      html = render_click(view, "delete", %{"id" => to_string(lock.id)})
      assert html =~ "Period lock deleted"
    end
  end

  describe "noop event" do
    test "noop does not change the page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/period-locks")
      html = render_click(view, "noop", %{})
      assert html =~ "Period Locks"
    end
  end
end
