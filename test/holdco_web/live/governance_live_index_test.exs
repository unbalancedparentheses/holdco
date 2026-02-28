defmodule HoldcoWeb.GovernanceLiveIndexTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "mount and render" do
    test "renders the page title and deck", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/governance")

      assert html =~ "<h1>Governance</h1>"
      assert html =~ "Board meetings, cap table, resolutions, deals, equity plans, JVs, and powers of attorney"
      assert html =~ "page-title"
      assert html =~ "page-title-rule"
    end

    test "renders all seven tab buttons", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/governance")

      assert html =~ "Board Meetings"
      assert html =~ "Cap Table"
      assert html =~ "Resolutions"
      assert html =~ "Deals"
      assert html =~ "Equity Plans"
      assert html =~ "Joint Ventures"
      assert html =~ "Powers of Attorney"
    end

    test "renders tabs container and tab-body wrapper", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/governance")

      assert html =~ ~s(class="tabs")
      assert html =~ "tab-body"
    end

    test "meetings tab is active by default", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/governance")

      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="meetings"/s
    end

    test "default tab renders board meetings table headers", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/governance")

      assert html =~ "<th>Date</th>"
      assert html =~ "<th>Company</th>"
      assert html =~ "<th>Type</th>"
      assert html =~ "<th>Status</th>"
    end
  end

  describe "tab switching" do
    test "switching to cap_table tab shows cap table content", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/governance")

      html = view |> element(~s(button[phx-value-tab="cap_table"])) |> render_click()

      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="cap_table"/s
      assert html =~ "<h2>Cap Table</h2>"
      assert html =~ "<th>Investor</th>"
      assert html =~ "<th>Round</th>"
      assert html =~ "<th>Shares</th>"
      assert html =~ "<th>Amount</th>"
    end

    test "switching to resolutions tab shows resolutions content", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/governance")

      html = view |> element(~s(button[phx-value-tab="resolutions"])) |> render_click()

      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="resolutions"/s
      assert html =~ "<h2>Shareholder Resolutions</h2>"
      assert html =~ "<th>Title</th>"
      assert html =~ "<th>Passed</th>"
    end

    test "switching to deals tab shows deals content", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/governance")

      html = view |> element(~s(button[phx-value-tab="deals"])) |> render_click()

      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="deals"/s
      assert html =~ "<h2>Deals</h2>"
      assert html =~ "<th>Counterparty</th>"
      assert html =~ "<th>Value</th>"
      assert html =~ "<th>Status</th>"
    end

    test "switching to equity_plans tab shows equity plans content", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/governance")

      html = view |> element(~s(button[phx-value-tab="equity_plans"])) |> render_click()

      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="equity_plans"/s
      assert html =~ "<h2>Equity Incentive Plans</h2>"
      assert html =~ "<th>Plan Name</th>"
      assert html =~ "<th>Total Pool</th>"
      assert html =~ "<th>Vesting</th>"
    end

    test "switching to joint_ventures tab shows joint ventures content", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/governance")

      html = view |> element(~s(button[phx-value-tab="joint_ventures"])) |> render_click()

      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="joint_ventures"/s
      assert html =~ "<h2>Joint Ventures</h2>"
      assert html =~ "<th>Partner</th>"
      assert html =~ "<th>Ownership</th>"
    end

    test "switching to powers_of_attorney tab shows powers of attorney content", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/governance")

      html = view |> element(~s(button[phx-value-tab="powers_of_attorney"])) |> render_click()

      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="powers_of_attorney"/s
      assert html =~ "<h2>Powers of Attorney</h2>"
      assert html =~ "<th>Grantor</th>"
      assert html =~ "<th>Grantee</th>"
      assert html =~ "<th>Scope</th>"
    end

    test "switching tabs deactivates the previous tab", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/governance")

      html = view |> element(~s(button[phx-value-tab="deals"])) |> render_click()

      # meetings should no longer be active
      assert html =~ ~r/class="tab "[^>]*phx-value-tab="meetings"/s
    end

    test "switching tabs closes an open form", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/governance")

      view |> element("button", "Add") |> render_click()
      html = view |> element(~s(button[phx-value-tab="cap_table"])) |> render_click()

      refute html =~ "dialog-overlay"
    end
  end

  describe "data display" do
    test "shows board meeting data on meetings tab", %{conn: conn} do
      company = company_fixture(%{name: "MeetingCo"})
      board_meeting_fixture(%{company: company, scheduled_date: "2024-03-15", meeting_type: "regular", status: "scheduled"})

      {:ok, _view, html} = live(conn, ~p"/governance")

      assert html =~ "MeetingCo"
      assert html =~ "2024-03-15"
      assert html =~ "regular"
      assert html =~ "scheduled"
      assert html =~ "tag tag-ink"
    end

    test "shows cap table entries on cap_table tab", %{conn: conn} do
      company = company_fixture(%{name: "CapCo"})
      cap_table_entry_fixture(%{company: company, investor: "BigFund", round_name: "Series B", shares: 100.0, amount_invested: 500.0, currency: "USD", date: "2024-01-10"})

      {:ok, view, _html} = live(conn, ~p"/governance")
      html = view |> element(~s(button[phx-value-tab="cap_table"])) |> render_click()

      assert html =~ "BigFund"
      assert html =~ "Series B"
      assert html =~ "100.0"
      assert html =~ "500.0"
      assert html =~ "CapCo"
      assert html =~ "2024-01-10"
    end

    test "shows resolutions on resolutions tab", %{conn: conn} do
      company = company_fixture(%{name: "ResCo"})
      shareholder_resolution_fixture(%{company: company, title: "Approve Dividend", resolution_type: "ordinary", date: "2024-06-01", passed: true})

      {:ok, view, _html} = live(conn, ~p"/governance")
      html = view |> element(~s(button[phx-value-tab="resolutions"])) |> render_click()

      assert html =~ "Approve Dividend"
      assert html =~ "ordinary"
      assert html =~ "ResCo"
      assert html =~ "2024-06-01"
      assert html =~ "Yes"
    end

    test "shows deals on deals tab", %{conn: conn} do
      company = company_fixture(%{name: "DealCo"})
      deal_fixture(%{company: company, counterparty: "Target Corp", deal_type: "acquisition", value: 1_000_000.0, currency: "USD", status: "active"})

      {:ok, view, _html} = live(conn, ~p"/governance")
      html = view |> element(~s(button[phx-value-tab="deals"])) |> render_click()

      assert html =~ "Target Corp"
      assert html =~ "acquisition"
      assert html =~ "DealCo"
      assert html =~ "active"
      assert html =~ "tag tag-ink"
    end

    test "shows equity plans on equity_plans tab", %{conn: conn} do
      company = company_fixture(%{name: "EquityCo"})
      equity_incentive_plan_fixture(%{company: company, plan_name: "2024 ESOP", total_pool: 50000, vesting_schedule: "4-year cliff", board_approval_date: "2024-01-01"})

      {:ok, view, _html} = live(conn, ~p"/governance")
      html = view |> element(~s(button[phx-value-tab="equity_plans"])) |> render_click()

      assert html =~ "2024 ESOP"
      assert html =~ "EquityCo"
      assert html =~ "50000"
      assert html =~ "4-year cliff"
      assert html =~ "2024-01-01"
    end

    test "shows joint ventures on joint_ventures tab", %{conn: conn} do
      company = company_fixture(%{name: "JVCo"})
      joint_venture_fixture(%{company: company, name: "JV Alpha", partner: "Partner Inc", ownership_pct: 60.0, status: "active"})

      {:ok, view, _html} = live(conn, ~p"/governance")
      html = view |> element(~s(button[phx-value-tab="joint_ventures"])) |> render_click()

      assert html =~ "JV Alpha"
      assert html =~ "Partner Inc"
      assert html =~ "JVCo"
      assert html =~ "60"
      assert html =~ "active"
      assert html =~ "tag tag-ink"
    end

    test "shows powers of attorney on powers_of_attorney tab", %{conn: conn} do
      company = company_fixture(%{name: "POACo"})
      power_of_attorney_fixture(%{company: company, grantor: "CEO", grantee: "CFO", scope: "banking", start_date: "2024-01-01", end_date: "2025-01-01", status: "active"})

      {:ok, view, _html} = live(conn, ~p"/governance")
      html = view |> element(~s(button[phx-value-tab="powers_of_attorney"])) |> render_click()

      assert html =~ "CEO"
      assert html =~ "CFO"
      assert html =~ "POACo"
      assert html =~ "banking"
      assert html =~ "2024-01-01"
      assert html =~ "2025-01-01"
      assert html =~ "active"
      assert html =~ "tag tag-ink"
    end
  end

  describe "editor role - meetings tab" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "shows Add button on meetings tab", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/governance")

      assert html =~ ~s(phx-click="show_form")
    end

    test "clicking Add opens the board meeting form", %{conn: conn} do
      company_fixture(%{name: "MeetFormCo"})
      {:ok, view, _html} = live(conn, ~p"/governance")

      html = view |> element("button", "Add") |> render_click()

      assert html =~ "dialog-overlay"
      assert html =~ "Add Board Meeting"
      assert html =~ ~s(phx-submit="save_meeting")
      assert html =~ ~s(name="board_meeting[company_id]")
      assert html =~ ~s(name="board_meeting[scheduled_date]")
      assert html =~ ~s(name="board_meeting[meeting_type]")
      assert html =~ ~s(name="board_meeting[notes]")
      assert html =~ "MeetFormCo"
    end

    test "board meeting form shows meeting type options", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/governance")

      html = view |> element("button", "Add") |> render_click()

      assert html =~ "Regular"
      assert html =~ "Special"
      assert html =~ "Annual"
    end

    test "clicking Cancel closes the meeting form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/governance")

      view |> element("button", "Add") |> render_click()
      html = view |> element("button", "Cancel") |> render_click()

      refute html =~ "dialog-overlay"
    end

    test "submitting meeting form creates a meeting", %{conn: conn} do
      company = company_fixture(%{name: "SaveMeetCo"})
      {:ok, view, _html} = live(conn, ~p"/governance")

      view |> element("button", "Add") |> render_click()

      html =
        view
        |> form("form[phx-submit=\"save_meeting\"]", %{
          "board_meeting" => %{
            "company_id" => to_string(company.id),
            "scheduled_date" => "2024-06-15",
            "meeting_type" => "regular",
            "notes" => "Quarterly review"
          }
        })
        |> render_submit()

      assert html =~ "Meeting added"
      refute html =~ "dialog-overlay"
    end

    test "deleting a board meeting removes it", %{conn: conn} do
      bm = board_meeting_fixture(%{scheduled_date: "2024-09-01"})
      {:ok, view, html} = live(conn, ~p"/governance")

      assert html =~ "2024-09-01"

      html =
        view
        |> element(~s(button[phx-click="delete_meeting"][phx-value-id="#{bm.id}"]))
        |> render_click()

      assert html =~ "Meeting deleted"
      refute html =~ "2024-09-01"
    end
  end

  describe "editor role - cap_table tab" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "shows Add button on cap_table tab", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/governance")

      html = view |> element(~s(button[phx-value-tab="cap_table"])) |> render_click()

      assert html =~ ~s(phx-click="show_form")
    end

    test "clicking Add on cap_table tab opens the cap table entry form", %{conn: conn} do
      company_fixture(%{name: "CapFormCo"})
      {:ok, view, _html} = live(conn, ~p"/governance")

      view |> element(~s(button[phx-value-tab="cap_table"])) |> render_click()
      html = view |> element("button", "Add") |> render_click()

      assert html =~ "dialog-overlay"
      assert html =~ "Add Cap Table Entry"
      assert html =~ ~s(phx-submit="save_cap_table")
      assert html =~ ~s(name="cap_table_entry[company_id]")
      assert html =~ ~s(name="cap_table_entry[investor]")
      assert html =~ ~s(name="cap_table_entry[round_name]")
      assert html =~ ~s(name="cap_table_entry[shares]")
      assert html =~ ~s(name="cap_table_entry[amount_invested]")
      assert html =~ ~s(name="cap_table_entry[date]")
      assert html =~ "CapFormCo"
    end

    test "submitting cap table form creates an entry", %{conn: conn} do
      company = company_fixture(%{name: "SaveCapCo"})
      {:ok, view, _html} = live(conn, ~p"/governance")

      view |> element(~s(button[phx-value-tab="cap_table"])) |> render_click()
      view |> element("button", "Add") |> render_click()

      html =
        view
        |> form("form[phx-submit=\"save_cap_table\"]", %{
          "cap_table_entry" => %{
            "company_id" => to_string(company.id),
            "investor" => "Venture Fund",
            "round_name" => "Seed",
            "shares" => "5000",
            "amount_invested" => "250000",
            "date" => "2024-03-01"
          }
        })
        |> render_submit()

      assert html =~ "Entry added"
      refute html =~ "dialog-overlay"
    end

    test "deleting a cap table entry removes it", %{conn: conn} do
      ct = cap_table_entry_fixture(%{investor: "DeleteInvestor"})
      {:ok, view, _html} = live(conn, ~p"/governance")

      view |> element(~s(button[phx-value-tab="cap_table"])) |> render_click()

      html =
        view
        |> element(~s(button[phx-click="delete_cap_table"][phx-value-id="#{ct.id}"]))
        |> render_click()

      assert html =~ "Entry deleted"
      refute html =~ "DeleteInvestor"
    end
  end

  describe "editor role - resolutions tab" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "clicking Add on resolutions tab opens the resolution form", %{conn: conn} do
      company_fixture(%{name: "ResFormCo"})
      {:ok, view, _html} = live(conn, ~p"/governance")

      view |> element(~s(button[phx-value-tab="resolutions"])) |> render_click()
      html = view |> element("button", "Add") |> render_click()

      assert html =~ "Add Resolution"
      assert html =~ ~s(phx-submit="save_resolution")
      assert html =~ ~s(name="resolution[company_id]")
      assert html =~ ~s(name="resolution[title]")
      assert html =~ ~s(name="resolution[date]")
      assert html =~ ~s(name="resolution[resolution_type]")
      assert html =~ "Ordinary"
      assert html =~ "Special"
    end

    test "submitting resolution form creates a resolution", %{conn: conn} do
      company = company_fixture()
      {:ok, view, _html} = live(conn, ~p"/governance")

      view |> element(~s(button[phx-value-tab="resolutions"])) |> render_click()
      view |> element("button", "Add") |> render_click()

      html =
        view
        |> form("form[phx-submit=\"save_resolution\"]", %{
          "resolution" => %{
            "company_id" => to_string(company.id),
            "title" => "Approve Budget",
            "date" => "2024-06-01",
            "resolution_type" => "ordinary"
          }
        })
        |> render_submit()

      assert html =~ "Resolution added"
    end

    test "deleting a resolution removes it", %{conn: conn} do
      sr = shareholder_resolution_fixture(%{title: "DeleteResolution"})
      {:ok, view, _html} = live(conn, ~p"/governance")

      view |> element(~s(button[phx-value-tab="resolutions"])) |> render_click()

      html =
        view
        |> element(~s(button[phx-click="delete_resolution"][phx-value-id="#{sr.id}"]))
        |> render_click()

      assert html =~ "Resolution deleted"
      refute html =~ "DeleteResolution"
    end
  end

  describe "editor role - deals tab" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "clicking Add on deals tab opens the deal form", %{conn: conn} do
      company_fixture(%{name: "DealFormCo"})
      {:ok, view, _html} = live(conn, ~p"/governance")

      view |> element(~s(button[phx-value-tab="deals"])) |> render_click()
      html = view |> element("button", "Add") |> render_click()

      assert html =~ "Add Deal"
      assert html =~ ~s(phx-submit="save_deal")
      assert html =~ ~s(name="deal[company_id]")
      assert html =~ ~s(name="deal[counterparty]")
      assert html =~ ~s(name="deal[deal_type]")
      assert html =~ ~s(name="deal[value]")
      assert html =~ "Acquisition"
      assert html =~ "Divestiture"
      assert html =~ "Merger"
      assert html =~ "Investment"
    end

    test "submitting deal form creates a deal", %{conn: conn} do
      company = company_fixture()
      {:ok, view, _html} = live(conn, ~p"/governance")

      view |> element(~s(button[phx-value-tab="deals"])) |> render_click()
      view |> element("button", "Add") |> render_click()

      html =
        view
        |> form("form[phx-submit=\"save_deal\"]", %{
          "deal" => %{
            "company_id" => to_string(company.id),
            "counterparty" => "AcquireCo",
            "deal_type" => "acquisition",
            "value" => "5000000"
          }
        })
        |> render_submit()

      assert html =~ "Deal added"
    end

    test "deleting a deal removes it", %{conn: conn} do
      d = deal_fixture(%{counterparty: "DeleteDealTarget"})
      {:ok, view, _html} = live(conn, ~p"/governance")

      view |> element(~s(button[phx-value-tab="deals"])) |> render_click()

      html =
        view
        |> element(~s(button[phx-click="delete_deal"][phx-value-id="#{d.id}"]))
        |> render_click()

      assert html =~ "Deal deleted"
      refute html =~ "DeleteDealTarget"
    end
  end

  describe "editor role - equity_plans tab" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "clicking Add on equity_plans tab opens the equity plan form", %{conn: conn} do
      company_fixture(%{name: "EPFormCo"})
      {:ok, view, _html} = live(conn, ~p"/governance")

      view |> element(~s(button[phx-value-tab="equity_plans"])) |> render_click()
      html = view |> element("button", "Add") |> render_click()

      assert html =~ "Add Equity Plan"
      assert html =~ ~s(phx-submit="save_equity_plan")
      assert html =~ ~s(name="equity_plan[company_id]")
      assert html =~ ~s(name="equity_plan[plan_name]")
      assert html =~ ~s(name="equity_plan[total_pool]")
      assert html =~ ~s(name="equity_plan[vesting_schedule]")
    end

    test "submitting equity plan form creates a plan", %{conn: conn} do
      company = company_fixture()
      {:ok, view, _html} = live(conn, ~p"/governance")

      view |> element(~s(button[phx-value-tab="equity_plans"])) |> render_click()
      view |> element("button", "Add") |> render_click()

      html =
        view
        |> form("form[phx-submit=\"save_equity_plan\"]", %{
          "equity_plan" => %{
            "company_id" => to_string(company.id),
            "plan_name" => "2025 Stock Option Plan",
            "total_pool" => "100000",
            "vesting_schedule" => "4-year monthly"
          }
        })
        |> render_submit()

      assert html =~ "Equity plan added"
    end

    test "deleting an equity plan removes it", %{conn: conn} do
      ep = equity_incentive_plan_fixture(%{plan_name: "DeletePlan"})
      {:ok, view, _html} = live(conn, ~p"/governance")

      view |> element(~s(button[phx-value-tab="equity_plans"])) |> render_click()

      html =
        view
        |> element(~s(button[phx-click="delete_equity_plan"][phx-value-id="#{ep.id}"]))
        |> render_click()

      assert html =~ "Equity plan deleted"
      refute html =~ "DeletePlan"
    end
  end

  describe "editor role - joint_ventures tab" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "clicking Add on joint_ventures tab opens the joint venture form", %{conn: conn} do
      company_fixture(%{name: "JVFormCo"})
      {:ok, view, _html} = live(conn, ~p"/governance")

      view |> element(~s(button[phx-value-tab="joint_ventures"])) |> render_click()
      html = view |> element("button", "Add") |> render_click()

      assert html =~ "Add Joint Venture"
      assert html =~ ~s(phx-submit="save_jv")
      assert html =~ ~s(name="joint_venture[company_id]")
      assert html =~ ~s(name="joint_venture[name]")
      assert html =~ ~s(name="joint_venture[partner]")
      assert html =~ ~s(name="joint_venture[ownership_pct]")
    end

    test "submitting joint venture form creates a JV", %{conn: conn} do
      company = company_fixture()
      {:ok, view, _html} = live(conn, ~p"/governance")

      view |> element(~s(button[phx-value-tab="joint_ventures"])) |> render_click()
      view |> element("button", "Add") |> render_click()

      html =
        view
        |> form("form[phx-submit=\"save_jv\"]", %{
          "joint_venture" => %{
            "company_id" => to_string(company.id),
            "name" => "New JV",
            "partner" => "Partner LLC",
            "ownership_pct" => "55"
          }
        })
        |> render_submit()

      assert html =~ "Joint venture added"
    end

    test "deleting a joint venture removes it", %{conn: conn} do
      jv = joint_venture_fixture(%{name: "DeleteJV"})
      {:ok, view, _html} = live(conn, ~p"/governance")

      view |> element(~s(button[phx-value-tab="joint_ventures"])) |> render_click()

      html =
        view
        |> element(~s(button[phx-click="delete_jv"][phx-value-id="#{jv.id}"]))
        |> render_click()

      assert html =~ "Joint venture deleted"
      refute html =~ "DeleteJV"
    end
  end

  describe "editor role - powers_of_attorney tab" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "clicking Add on powers_of_attorney tab opens the POA form", %{conn: conn} do
      company_fixture(%{name: "POAFormCo"})
      {:ok, view, _html} = live(conn, ~p"/governance")

      view |> element(~s(button[phx-value-tab="powers_of_attorney"])) |> render_click()
      html = view |> element("button", "Add") |> render_click()

      assert html =~ "Add Power of Attorney"
      assert html =~ ~s(phx-submit="save_poa")
      assert html =~ ~s(name="power_of_attorney[company_id]")
      assert html =~ ~s(name="power_of_attorney[grantor]")
      assert html =~ ~s(name="power_of_attorney[grantee]")
      assert html =~ ~s(name="power_of_attorney[scope]")
      assert html =~ ~s(name="power_of_attorney[start_date]")
      assert html =~ ~s(name="power_of_attorney[end_date]")
    end

    test "submitting POA form creates a power of attorney", %{conn: conn} do
      company = company_fixture()
      {:ok, view, _html} = live(conn, ~p"/governance")

      view |> element(~s(button[phx-value-tab="powers_of_attorney"])) |> render_click()
      view |> element("button", "Add") |> render_click()

      html =
        view
        |> form("form[phx-submit=\"save_poa\"]", %{
          "power_of_attorney" => %{
            "company_id" => to_string(company.id),
            "grantor" => "Board Chair",
            "grantee" => "General Counsel",
            "scope" => "legal",
            "start_date" => "2024-01-01",
            "end_date" => "2025-12-31"
          }
        })
        |> render_submit()

      assert html =~ "Power of attorney added"
    end

    test "deleting a power of attorney removes it", %{conn: conn} do
      poa = power_of_attorney_fixture(%{grantor: "DeletePOAGrantor"})
      {:ok, view, _html} = live(conn, ~p"/governance")

      view |> element(~s(button[phx-value-tab="powers_of_attorney"])) |> render_click()

      html =
        view
        |> element(~s(button[phx-click="delete_poa"][phx-value-id="#{poa.id}"]))
        |> render_click()

      assert html =~ "Power of attorney deleted"
      refute html =~ "DeletePOAGrantor"
    end
  end

  describe "noop event" do
    test "noop does not crash the view", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/governance")

      render_hook(view, "noop", %{})
      assert render(view) =~ "Governance"
    end
  end

  describe "handle_info broadcast" do
    test "handles generic broadcast without crashing", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/governance")

      send(view.pid, :some_broadcast)

      html = render(view)
      assert html =~ "Governance"
    end
  end
end
