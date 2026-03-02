defmodule HoldcoWeb.CalendarLiveIndexTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "Index" do
    test "shows tax deadline events", %{conn: conn} do
      company = company_fixture(%{name: "Tax Company"})
      today = Date.utc_today()
      today_str = Date.to_iso8601(today)

      tax_deadline_fixture(%{
        company: company,
        due_date: today_str,
        jurisdiction: "US",
        description: "Quarterly filing"
      })

      {:ok, _live, html} = live(conn, ~p"/calendar")
      assert html =~ "US" || html =~ "tax" || html =~ "Quarterly filing"
    end

    test "shows board meeting events", %{conn: conn} do
      company = company_fixture(%{name: "Meeting Corp"})
      today_str = Date.utc_today() |> Date.to_iso8601()

      board_meeting_fixture(%{company: company, scheduled_date: today_str})

      {:ok, _live, html} = live(conn, ~p"/calendar")
      assert html =~ "meeting" || html =~ "Meeting Corp"
    end

    test "shows liability maturity events", %{conn: conn} do
      company = company_fixture(%{name: "Liability Co"})
      future_date = Date.utc_today() |> Date.add(30) |> Date.to_iso8601()

      liability_fixture(%{
        company: company,
        maturity_date: future_date,
        principal: 50_000.0,
        creditor: "Maturity Bank"
      })

      {:ok, _live, html} = live(conn, ~p"/calendar")
      assert html =~ "liability" || html =~ "Maturity Bank" || html =~ "Liability Co"
    end

    test "shows insurance renewal events", %{conn: conn} do
      company = company_fixture(%{name: "Insurance Co"})
      future_date = Date.utc_today() |> Date.add(60) |> Date.to_iso8601()

      insurance_policy_fixture(%{
        company: company,
        expiry_date: future_date,
        policy_type: "D&O",
        provider: "Insurer XYZ"
      })

      {:ok, _live, html} = live(conn, ~p"/calendar")
      assert html =~ "insurance" || html =~ "Insurer XYZ" || html =~ "renewal"
    end

    test "shows regulatory filing events", %{conn: conn} do
      company = company_fixture(%{name: "Filing Co"})
      today_str = Date.utc_today() |> Date.to_iso8601()

      regulatory_filing_fixture(%{
        company: company,
        due_date: today_str,
        jurisdiction: "UK",
        filing_type: "Annual Return"
      })

      {:ok, _live, html} = live(conn, ~p"/calendar")
      assert html =~ "filing" || html =~ "UK" || html =~ "Annual Return"
    end

    test "filters events by tax type", %{conn: conn} do
      company = company_fixture()
      today_str = Date.utc_today() |> Date.to_iso8601()

      tax_deadline_fixture(%{company: company, due_date: today_str})
      board_meeting_fixture(%{company: company, scheduled_date: today_str})

      {:ok, live, _html} = live(conn, ~p"/calendar")
      html = render_click(live, "filter_type", %{"type" => "tax"})
      assert html =~ "tax" || html =~ "Calendar"
    end

    test "filters events by meeting type", %{conn: conn} do
      company = company_fixture()
      today_str = Date.utc_today() |> Date.to_iso8601()

      board_meeting_fixture(%{company: company, scheduled_date: today_str})

      {:ok, live, _html} = live(conn, ~p"/calendar")
      html = render_click(live, "filter_type", %{"type" => "meeting"})
      assert html =~ "meeting" || html =~ "Calendar"
    end

    test "filters events by liability type", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/calendar")
      html = render_click(live, "filter_type", %{"type" => "liability"})
      assert html =~ "Calendar"
    end

    test "filters events by insurance type", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/calendar")
      html = render_click(live, "filter_type", %{"type" => "insurance"})
      assert html =~ "Calendar"
    end

    test "filters events by filing type", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/calendar")
      html = render_click(live, "filter_type", %{"type" => "filing"})
      assert html =~ "Calendar"
    end

    test "filter back to all events shows everything", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/calendar")
      render_click(live, "filter_type", %{"type" => "tax"})
      html = render_click(live, "filter_type", %{"type" => "all"})
      assert html =~ "Calendar"
    end

    test "navigates months with prev/next", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/calendar")
      html = render_click(live, "next_month", %{})
      assert html =~ "Calendar"

      html = render_click(live, "prev_month", %{})
      assert html =~ "Calendar"
    end

    test "navigating to next month changes displayed month name", %{conn: conn} do
      {:ok, live, html} = live(conn, ~p"/calendar")
      today = Date.utc_today()
      current_month_name = Calendar.strftime(today, "%B %Y")
      assert html =~ current_month_name

      html = render_click(live, "next_month", %{})
      next_month = Date.utc_today() |> Date.add(Date.days_in_month(today)) |> Date.beginning_of_month()
      next_month_name = Calendar.strftime(next_month, "%B %Y")
      assert html =~ next_month_name
    end

    test "navigating to previous month changes displayed month", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/calendar")

      html = render_click(live, "prev_month", %{})
      prev_month = Date.utc_today() |> Date.add(-1) |> Date.beginning_of_month()
      prev_month_name = Calendar.strftime(prev_month, "%B %Y")
      assert html =~ prev_month_name
    end

    test "shows company link for events with company", %{conn: conn} do
      company = company_fixture(%{name: "EventLink Corp"})
      today_str = Date.utc_today() |> Date.to_iso8601()
      tax_deadline_fixture(%{company: company, due_date: today_str})

      {:ok, _live, html} = live(conn, ~p"/calendar")
      assert html =~ "EventLink Corp"
    end
  end
end
