defmodule HoldcoWeb.PeriodCloseLiveIndexTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "mount and render" do
    test "renders period close page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/period-close")

      assert html =~ "Period Close"
      assert html =~ "Close Checklist"
      assert html =~ "Entities"
    end

    test "shows companies in checklist", %{conn: conn} do
      company_fixture(%{name: "CloseCo"})

      {:ok, _view, html} = live(conn, ~p"/period-close")

      assert html =~ "CloseCo"
    end

    test "shows reconciliation status", %{conn: conn} do
      company = company_fixture(%{name: "ReconCheckCo"})
      ba = bank_account_fixture(%{company: company})
      config = bank_feed_config_fixture(%{company: company, bank_account: ba, is_active: true})

      Holdco.Integrations.create_bank_feed_transaction(%{
        feed_config_id: config.id,
        external_id: "ext_close_#{System.unique_integer([:positive])}",
        date: "2025-01-15",
        description: "Close check txn",
        amount: 100.00,
        currency: "USD"
      })

      {:ok, _view, html} = live(conn, ~p"/period-close")

      assert html =~ "ReconCheckCo"
      assert html =~ "unmatched"
    end

    test "shows empty state when no companies", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/period-close")

      # With no companies, should show empty or just the checklist header
      assert html =~ "Close Checklist"
    end
  end

  describe "period change" do
    test "changing period dates reloads checklist", %{conn: conn} do
      company_fixture(%{name: "PeriodChangeCo"})

      {:ok, view, _html} = live(conn, ~p"/period-close")

      html =
        render_change(view, "change_period", %{
          "period_start" => "2025-01-01",
          "period_end" => "2025-01-31"
        })

      assert html =~ "PeriodChangeCo"
    end
  end

  describe "quick lock" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "locks period for a company", %{conn: conn} do
      company = company_fixture(%{name: "QuickLockCo"})

      # Create a journal entry so it shows as "ready"
      Holdco.Finance.create_journal_entry(%{
        company_id: company.id,
        date: Date.to_iso8601(Date.add(Date.beginning_of_month(Date.add(Date.beginning_of_month(Date.utc_today()), -1)), 5)),
        description: "Test entry",
        debit_account: "Cash",
        credit_account: "Revenue",
        amount: 1000
      })

      {:ok, view, _html} = live(conn, ~p"/period-close")

      html = render_click(view, "quick_lock", %{"company_id" => to_string(company.id)})

      assert html =~ "Period locked"
    end
  end
end
