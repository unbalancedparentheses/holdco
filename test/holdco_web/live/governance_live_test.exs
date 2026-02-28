defmodule HoldcoWeb.GovernanceLiveTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "GET /governance" do
    test "renders governance page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/governance")

      assert html =~ "Governance"
      assert html =~ "Board meetings, cap table, resolutions"
    end

    test "renders page title and rule", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/governance")

      assert html =~ "page-title"
      assert html =~ "page-title-rule"
    end

    test "renders tabs container", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/governance")

      assert html =~ ~s(class="tabs")
    end

    test "renders all seven governance tabs", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/governance")

      assert html =~ ~s(phx-value-tab="meetings")
      assert html =~ ~s(phx-value-tab="cap_table")
      assert html =~ ~s(phx-value-tab="resolutions")
      assert html =~ ~s(phx-value-tab="deals")
      assert html =~ ~s(phx-value-tab="equity_plans")
      assert html =~ ~s(phx-value-tab="joint_ventures")
      assert html =~ ~s(phx-value-tab="powers_of_attorney")
    end

    test "meetings tab is active by default", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/governance")

      # The first tab (meetings) should have tab-active class
      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="meetings"/s
    end

    test "renders tab-body wrapper", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/governance")

      assert html =~ "tab-body"
    end

    test "other tabs are not active by default", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/governance")

      # cap_table tab should not have tab-active
      assert html =~ ~r/class="tab "[^>]*phx-value-tab="cap_table"/s
    end
  end

  describe "tab switching" do
    test "clicking cap_table tab activates it", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/governance")

      html = view |> element(~s(button[phx-value-tab="cap_table"])) |> render_click()

      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="cap_table"/s
      # meetings should no longer be active
      assert html =~ ~r/class="tab "[^>]*phx-value-tab="meetings"/s
    end

    test "clicking resolutions tab activates it", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/governance")

      html = view |> element(~s(button[phx-value-tab="resolutions"])) |> render_click()

      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="resolutions"/s
    end

    test "clicking deals tab activates it", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/governance")

      html = view |> element(~s(button[phx-value-tab="deals"])) |> render_click()

      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="deals"/s
    end

    test "clicking equity_plans tab activates it", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/governance")

      html = view |> element(~s(button[phx-value-tab="equity_plans"])) |> render_click()

      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="equity_plans"/s
    end

    test "clicking joint_ventures tab activates it", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/governance")

      html = view |> element(~s(button[phx-value-tab="joint_ventures"])) |> render_click()

      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="joint_ventures"/s
    end

    test "clicking powers_of_attorney tab activates it", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/governance")

      html = view |> element(~s(button[phx-value-tab="powers_of_attorney"])) |> render_click()

      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="powers_of_attorney"/s
    end

    test "switching tabs closes form", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/governance")

      # Open form (only visible to editors)
      view |> element("button", "Add") |> render_click()

      # Switch tab — form should close
      html = view |> element(~s(button[phx-value-tab="cap_table"])) |> render_click()

      refute html =~ "dialog-overlay"
    end
  end

  describe "nav active state on governance page" do
    test "governance page renders without nav highlight", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/governance")

      # Governance is no longer in the nav bar (removed from Consolidated dropdown)
      assert html =~ "Governance"
    end
  end

  # ── show_form / close_form / noop ──────────────────────────

  describe "show_form and close_form events" do
    test "show_form opens the modal overlay for an editor", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/governance")

      html = view |> element("button", "Add") |> render_click()

      assert html =~ "dialog-overlay"
      assert html =~ "Add Board Meeting"
    end

    test "close_form hides the modal overlay", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/governance")

      # Open the form first
      view |> element("button", "Add") |> render_click()

      # Close it
      html = view |> element("button", "Cancel") |> render_click()

      refute html =~ "dialog-overlay"
    end

  end

  describe "noop event" do
    test "noop keeps the modal open when clicking inside it", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/governance")

      # Open the form
      view |> element("button", "Add") |> render_click()

      # The modal div has phx-click="noop"; triggering it should keep modal open
      html = render_click(view, "noop", %{})

      assert html =~ "dialog-overlay"
    end
  end

  # ── Tab content rendering ──────────────────────────────────

  describe "tab content rendering" do
    test "meetings tab shows board meeting data", %{conn: conn} do
      company = company_fixture(%{name: "TabMeetingCo"})
      board_meeting_fixture(%{company: company, scheduled_date: "2024-06-01", meeting_type: "annual"})

      {:ok, _view, html} = live(conn, ~p"/governance")

      assert html =~ "TabMeetingCo"
      assert html =~ "2024-06-01"
      assert html =~ "annual"
    end

    test "cap_table tab shows cap table entries", %{conn: conn} do
      company = company_fixture(%{name: "TabCapCo"})

      cap_table_entry_fixture(%{
        company: company,
        investor: "Sequoia Capital",
        round_name: "Series B"
      })

      {:ok, view, _html} = live(conn, ~p"/governance")

      html = view |> element(~s(button[phx-value-tab="cap_table"])) |> render_click()

      assert html =~ "Sequoia Capital"
      assert html =~ "Series B"
      assert html =~ "TabCapCo"
    end

    test "resolutions tab shows resolution data", %{conn: conn} do
      company = company_fixture(%{name: "TabResCo"})

      shareholder_resolution_fixture(%{
        company: company,
        title: "Approve Q4 dividend",
        date: "2024-12-01",
        resolution_type: "special"
      })

      {:ok, view, _html} = live(conn, ~p"/governance")

      html = view |> element(~s(button[phx-value-tab="resolutions"])) |> render_click()

      assert html =~ "Approve Q4 dividend"
      assert html =~ "special"
      assert html =~ "2024-12-01"
    end

    test "deals tab shows deal data", %{conn: conn} do
      company = company_fixture(%{name: "TabDealCo"})
      deal_fixture(%{company: company, counterparty: "Acme Inc", deal_type: "acquisition"})

      {:ok, view, _html} = live(conn, ~p"/governance")

      html = view |> element(~s(button[phx-value-tab="deals"])) |> render_click()

      assert html =~ "Acme Inc"
      assert html =~ "acquisition"
    end

    test "meetings tab shows empty state when no meetings exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/governance")

      assert html =~ "No board meetings recorded yet."
    end
  end

  # ── CRUD: Board Meetings ───────────────────────────────────

  describe "board meetings CRUD" do
    test "editor can create a board meeting", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "MeetingCRUDCo"})

      {:ok, view, _html} = live(conn, ~p"/governance")

      # Open form
      view |> element("button", "Add") |> render_click()

      # Submit create form
      html =
        view
        |> form("form[phx-submit=\"save_meeting\"]", %{
          "board_meeting" => %{
            "company_id" => company.id,
            "scheduled_date" => "2025-01-15",
            "meeting_type" => "special",
            "notes" => "Quarterly review"
          }
        })
        |> render_submit()

      assert html =~ "Meeting added"
      assert html =~ "2025-01-15"
      assert html =~ "special"
      refute html =~ "dialog-overlay"
    end

    test "editor can delete a board meeting", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "MeetingDelCo"})
      bm = board_meeting_fixture(%{company: company, scheduled_date: "2024-09-01"})

      {:ok, view, _html} = live(conn, ~p"/governance")

      assert render(view) =~ "2024-09-01"

      html =
        view
        |> element(~s(button[phx-click="delete_meeting"][phx-value-id="#{bm.id}"]))
        |> render_click()

      assert html =~ "Meeting deleted"
      refute html =~ "2024-09-01"
    end

    test "editor can edit and update a board meeting", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "MeetingEditCo"})
      bm = board_meeting_fixture(%{company: company, scheduled_date: "2024-04-01", meeting_type: "regular"})

      {:ok, view, _html} = live(conn, ~p"/governance")

      # Click edit
      html =
        view
        |> element(~s(button[phx-click="edit_meeting"][phx-value-id="#{bm.id}"]))
        |> render_click()

      assert html =~ "Edit Board Meeting"
      assert html =~ "dialog-overlay"

      # Submit update form
      html =
        view
        |> form("form[phx-submit=\"update_meeting\"]", %{
          "board_meeting" => %{
            "company_id" => company.id,
            "scheduled_date" => "2024-04-15",
            "meeting_type" => "annual",
            "notes" => "Updated notes"
          }
        })
        |> render_submit()

      assert html =~ "Meeting updated"
      assert html =~ "2024-04-15"
      assert html =~ "annual"
      refute html =~ "dialog-overlay"
    end

  end

  # ── CRUD: Cap Table ────────────────────────────────────────

  describe "cap table CRUD" do
    test "editor can create a cap table entry", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "CapCreateCo"})

      {:ok, view, _html} = live(conn, ~p"/governance")

      # Switch to cap_table tab
      view |> element(~s(button[phx-value-tab="cap_table"])) |> render_click()

      # Open form
      view |> element("button", "Add") |> render_click()

      # Submit
      html =
        view
        |> form("form[phx-submit=\"save_cap_table\"]", %{
          "cap_table_entry" => %{
            "company_id" => company.id,
            "investor" => "Andreessen Horowitz",
            "round_name" => "Series C",
            "shares" => "25000",
            "amount_invested" => "1000000",
            "date" => "2025-03-01"
          }
        })
        |> render_submit()

      assert html =~ "Entry added"
      assert html =~ "Andreessen Horowitz"
      assert html =~ "Series C"
      refute html =~ "dialog-overlay"
    end

    test "editor can delete a cap table entry", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "CapDelCo"})

      ct =
        cap_table_entry_fixture(%{
          company: company,
          investor: "SoftBank",
          round_name: "Series D"
        })

      {:ok, view, _html} = live(conn, ~p"/governance")

      # Switch to cap_table tab
      view |> element(~s(button[phx-value-tab="cap_table"])) |> render_click()

      assert render(view) =~ "SoftBank"

      html =
        view
        |> element(~s(button[phx-click="delete_cap_table"][phx-value-id="#{ct.id}"]))
        |> render_click()

      assert html =~ "Entry deleted"
      refute html =~ "SoftBank"
    end

    test "editor can edit and update a cap table entry", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "CapEditCo"})

      ct =
        cap_table_entry_fixture(%{
          company: company,
          investor: "Original Investor",
          round_name: "Seed"
        })

      {:ok, view, _html} = live(conn, ~p"/governance")

      # Switch tab
      view |> element(~s(button[phx-value-tab="cap_table"])) |> render_click()

      # Click edit
      html =
        view
        |> element(~s(button[phx-click="edit_cap_table"][phx-value-id="#{ct.id}"]))
        |> render_click()

      assert html =~ "Edit Cap Table Entry"

      # Submit update
      html =
        view
        |> form("form[phx-submit=\"update_cap_table\"]", %{
          "cap_table_entry" => %{
            "company_id" => company.id,
            "investor" => "Updated Investor",
            "round_name" => "Series A",
            "shares" => "50000",
            "amount_invested" => "2000000",
            "date" => "2025-06-01"
          }
        })
        |> render_submit()

      assert html =~ "Entry updated"
      assert html =~ "Updated Investor"
      assert html =~ "Series A"
    end

  end

  # ── CRUD: Resolutions ──────────────────────────────────────

  describe "resolutions CRUD" do
    test "editor can create a resolution", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "ResCreateCo"})

      {:ok, view, _html} = live(conn, ~p"/governance")

      # Switch to resolutions tab
      view |> element(~s(button[phx-value-tab="resolutions"])) |> render_click()

      # Open form
      view |> element("button", "Add") |> render_click()

      # Submit
      html =
        view
        |> form("form[phx-submit=\"save_resolution\"]", %{
          "resolution" => %{
            "company_id" => company.id,
            "title" => "Approve stock split",
            "date" => "2025-07-01",
            "resolution_type" => "special"
          }
        })
        |> render_submit()

      assert html =~ "Resolution added"
      assert html =~ "Approve stock split"
      assert html =~ "special"
      refute html =~ "dialog-overlay"
    end

    test "editor can delete a resolution", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "ResDelCo"})

      sr =
        shareholder_resolution_fixture(%{
          company: company,
          title: "Dissolve subsidiary",
          date: "2024-11-01"
        })

      {:ok, view, _html} = live(conn, ~p"/governance")

      # Switch tab
      view |> element(~s(button[phx-value-tab="resolutions"])) |> render_click()

      assert render(view) =~ "Dissolve subsidiary"

      html =
        view
        |> element(~s(button[phx-click="delete_resolution"][phx-value-id="#{sr.id}"]))
        |> render_click()

      assert html =~ "Resolution deleted"
      refute html =~ "Dissolve subsidiary"
    end

    test "editor can edit and update a resolution", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "ResEditCo"})

      sr =
        shareholder_resolution_fixture(%{
          company: company,
          title: "Original title",
          date: "2024-05-01",
          resolution_type: "ordinary"
        })

      {:ok, view, _html} = live(conn, ~p"/governance")

      # Switch tab
      view |> element(~s(button[phx-value-tab="resolutions"])) |> render_click()

      # Click edit
      html =
        view
        |> element(~s(button[phx-click="edit_resolution"][phx-value-id="#{sr.id}"]))
        |> render_click()

      assert html =~ "Edit Resolution"

      # Submit update
      html =
        view
        |> form("form[phx-submit=\"update_resolution\"]", %{
          "resolution" => %{
            "company_id" => company.id,
            "title" => "Updated resolution title",
            "date" => "2024-05-15",
            "resolution_type" => "special"
          }
        })
        |> render_submit()

      assert html =~ "Resolution updated"
      assert html =~ "Updated resolution title"
    end

  end

  # ── CRUD: Deals ──────────────────────────────────────────

  describe "deals CRUD" do
    test "editor can create a deal", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "DealCreateCo"})

      {:ok, view, _html} = live(conn, ~p"/governance")

      view |> element(~s(button[phx-value-tab="deals"])) |> render_click()
      view |> element("button", "Add") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_deal"]), %{
          "deal" => %{
            "company_id" => company.id,
            "counterparty" => "MegaCorp",
            "deal_type" => "merger"
          }
        })
        |> render_submit()

      assert html =~ "Deal added"
      assert html =~ "MegaCorp"
      assert html =~ "merger"
      refute html =~ "dialog-overlay"
    end

    test "editor can delete a deal", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "DealDelCo"})
      deal = deal_fixture(%{company: company, counterparty: "DeleteTarget"})

      {:ok, view, _html} = live(conn, ~p"/governance")
      view |> element(~s(button[phx-value-tab="deals"])) |> render_click()

      html =
        view
        |> element(~s(button[phx-click="delete_deal"][phx-value-id="#{deal.id}"]))
        |> render_click()

      assert html =~ "Deal deleted"
      refute html =~ "DeleteTarget"
    end

    test "editor can edit and update a deal", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "DealEditCo"})
      deal = deal_fixture(%{company: company, counterparty: "Original Counterparty", deal_type: "acquisition"})

      {:ok, view, _html} = live(conn, ~p"/governance")
      view |> element(~s(button[phx-value-tab="deals"])) |> render_click()

      html =
        view
        |> element(~s(button[phx-click="edit_deal"][phx-value-id="#{deal.id}"]))
        |> render_click()

      assert html =~ "Edit Deal"

      html =
        view
        |> form(~s(form[phx-submit="update_deal"]), %{
          "deal" => %{
            "company_id" => company.id,
            "counterparty" => "Updated Counterparty",
            "deal_type" => "divestiture"
          }
        })
        |> render_submit()

      assert html =~ "Deal updated"
      assert html =~ "Updated Counterparty"
    end
  end

  # ── CRUD: Equity Plans ──────────────────────────────────

  describe "equity plans CRUD" do
    test "editor can create an equity plan", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "EquityPlanCo"})

      {:ok, view, _html} = live(conn, ~p"/governance")

      view |> element(~s(button[phx-value-tab="equity_plans"])) |> render_click()
      view |> element("button", "Add") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_equity_plan"]), %{
          "equity_plan" => %{
            "company_id" => company.id,
            "plan_name" => "2025 Stock Option Plan"
          }
        })
        |> render_submit()

      assert html =~ "Equity plan added"
      assert html =~ "2025 Stock Option Plan"
      refute html =~ "dialog-overlay"
    end

    test "editor can delete an equity plan", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "EquityPlanDelCo"})
      plan = equity_incentive_plan_fixture(%{company: company, plan_name: "Old Plan"})

      {:ok, view, _html} = live(conn, ~p"/governance")
      view |> element(~s(button[phx-value-tab="equity_plans"])) |> render_click()

      html =
        view
        |> element(~s(button[phx-click="delete_equity_plan"][phx-value-id="#{plan.id}"]))
        |> render_click()

      assert html =~ "Equity plan deleted"
      refute html =~ "Old Plan"
    end

    test "editor can edit and update an equity plan", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "EquityPlanEditCo"})
      plan = equity_incentive_plan_fixture(%{company: company, plan_name: "Original Plan"})

      {:ok, view, _html} = live(conn, ~p"/governance")
      view |> element(~s(button[phx-value-tab="equity_plans"])) |> render_click()

      html =
        view
        |> element(~s(button[phx-click="edit_equity_plan"][phx-value-id="#{plan.id}"]))
        |> render_click()

      assert html =~ "Edit Equity Plan"

      html =
        view
        |> form(~s(form[phx-submit="update_equity_plan"]), %{
          "equity_plan" => %{
            "company_id" => company.id,
            "plan_name" => "Updated Plan 2025"
          }
        })
        |> render_submit()

      assert html =~ "Equity plan updated"
      assert html =~ "Updated Plan 2025"
    end
  end

  # ── CRUD: Joint Ventures ────────────────────────────────

  describe "joint ventures CRUD" do
    test "editor can create a joint venture", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "JVCreateCo"})

      {:ok, view, _html} = live(conn, ~p"/governance")

      view |> element(~s(button[phx-value-tab="joint_ventures"])) |> render_click()
      view |> element("button", "Add") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_jv"]), %{
          "joint_venture" => %{
            "company_id" => company.id,
            "partner" => "Partner Corp",
            "name" => "Asia JV"
          }
        })
        |> render_submit()

      assert html =~ "Joint venture added"
      assert html =~ "Asia JV"
      assert html =~ "Partner Corp"
      refute html =~ "dialog-overlay"
    end

    test "editor can delete a joint venture", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "JVDelCo"})
      jv = joint_venture_fixture(%{company: company, partner: "OldPartner", name: "Old JV"})

      {:ok, view, _html} = live(conn, ~p"/governance")
      view |> element(~s(button[phx-value-tab="joint_ventures"])) |> render_click()

      html =
        view
        |> element(~s(button[phx-click="delete_jv"][phx-value-id="#{jv.id}"]))
        |> render_click()

      assert html =~ "Joint venture deleted"
      refute html =~ "Old JV"
    end

    test "editor can edit and update a joint venture", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "JVEditCo"})
      jv = joint_venture_fixture(%{company: company, partner: "OrigPartner", name: "Orig JV"})

      {:ok, view, _html} = live(conn, ~p"/governance")
      view |> element(~s(button[phx-value-tab="joint_ventures"])) |> render_click()

      html =
        view
        |> element(~s(button[phx-click="edit_jv"][phx-value-id="#{jv.id}"]))
        |> render_click()

      assert html =~ "Edit Joint Venture"

      html =
        view
        |> form(~s(form[phx-submit="update_jv"]), %{
          "joint_venture" => %{
            "company_id" => company.id,
            "partner" => "New Partner",
            "name" => "Updated JV"
          }
        })
        |> render_submit()

      assert html =~ "Joint venture updated"
      assert html =~ "Updated JV"
    end
  end

  # ── CRUD: Powers of Attorney ────────────────────────────

  describe "powers of attorney CRUD" do
    test "editor can create a power of attorney", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "PoACo"})

      {:ok, view, _html} = live(conn, ~p"/governance")

      view |> element(~s(button[phx-value-tab="powers_of_attorney"])) |> render_click()
      view |> element("button", "Add") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_poa"]), %{
          "power_of_attorney" => %{
            "company_id" => company.id,
            "grantor" => "CEO Smith",
            "grantee" => "CFO Jones"
          }
        })
        |> render_submit()

      assert html =~ "Power of attorney added"
      assert html =~ "CEO Smith"
      assert html =~ "CFO Jones"
      refute html =~ "dialog-overlay"
    end

    test "editor can delete a power of attorney", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "PoADelCo"})
      poa = power_of_attorney_fixture(%{company: company, grantor: "OldGrantor", grantee: "OldGrantee"})

      {:ok, view, _html} = live(conn, ~p"/governance")
      view |> element(~s(button[phx-value-tab="powers_of_attorney"])) |> render_click()

      html =
        view
        |> element(~s(button[phx-click="delete_poa"][phx-value-id="#{poa.id}"]))
        |> render_click()

      assert html =~ "Power of attorney deleted"
      refute html =~ "OldGrantor"
    end

    test "editor can edit and update a power of attorney", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "PoAEditCo"})
      poa = power_of_attorney_fixture(%{company: company, grantor: "OrigGrantor", grantee: "OrigGrantee"})

      {:ok, view, _html} = live(conn, ~p"/governance")
      view |> element(~s(button[phx-value-tab="powers_of_attorney"])) |> render_click()

      html =
        view
        |> element(~s(button[phx-click="edit_poa"][phx-value-id="#{poa.id}"]))
        |> render_click()

      assert html =~ "Edit Power of Attorney"

      html =
        view
        |> form(~s(form[phx-submit="update_poa"]), %{
          "power_of_attorney" => %{
            "company_id" => company.id,
            "grantor" => "Updated Grantor",
            "grantee" => "Updated Grantee"
          }
        })
        |> render_submit()

      assert html =~ "Power of attorney updated"
      assert html =~ "Updated Grantor"
    end
  end

  # ── Tab content rendering: additional tabs ──────────────

  describe "additional tab content rendering" do
    test "equity_plans tab shows plan data", %{conn: conn} do
      company = company_fixture(%{name: "TabEPCo"})
      equity_incentive_plan_fixture(%{company: company, plan_name: "2024 ESOP"})

      {:ok, view, _html} = live(conn, ~p"/governance")
      html = view |> element(~s(button[phx-value-tab="equity_plans"])) |> render_click()

      assert html =~ "2024 ESOP"
      assert html =~ "TabEPCo"
    end

    test "joint_ventures tab shows JV data", %{conn: conn} do
      company = company_fixture(%{name: "TabJVCo"})
      joint_venture_fixture(%{company: company, partner: "JV Partner", name: "Pacific Venture"})

      {:ok, view, _html} = live(conn, ~p"/governance")
      html = view |> element(~s(button[phx-value-tab="joint_ventures"])) |> render_click()

      assert html =~ "Pacific Venture"
      assert html =~ "JV Partner"
    end

    test "powers_of_attorney tab shows PoA data", %{conn: conn} do
      company = company_fixture(%{name: "TabPoACo"})
      power_of_attorney_fixture(%{company: company, grantor: "CEO", grantee: "VP Legal"})

      {:ok, view, _html} = live(conn, ~p"/governance")
      html = view |> element(~s(button[phx-value-tab="powers_of_attorney"])) |> render_click()

      assert html =~ "CEO"
      assert html =~ "VP Legal"
    end
  end

  # ── handle_info ──────────────────────────────────────────

  describe "handle_info" do
    test "unknown messages trigger reload", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/governance")

      send(view.pid, :unknown_event)
      html = render(view)
      assert html =~ "Governance"
    end
  end

  describe "create error paths" do
    test "save_meeting with invalid data shows error", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/governance")

      html = render_hook(view, "save_meeting", %{"board_meeting" => %{"company_id" => "", "scheduled_date" => ""}})
      assert html =~ "Failed to add meeting"
    end

    test "save_cap_table with invalid data shows error", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/governance")

      html = render_hook(view, "save_cap_table", %{"cap_table_entry" => %{"company_id" => "", "investor" => ""}})
      assert html =~ "Failed to add entry"
    end

    test "save_resolution with invalid data shows error", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/governance")

      html = render_hook(view, "save_resolution", %{"resolution" => %{"company_id" => "", "title" => ""}})
      assert html =~ "Failed to add resolution"
    end

    test "save_deal with invalid data shows error", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/governance")

      html = render_hook(view, "save_deal", %{"deal" => %{"company_id" => "", "counterparty" => ""}})
      assert html =~ "Failed to add deal"
    end

    test "save_equity_plan with invalid data shows error", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/governance")

      html = render_hook(view, "save_equity_plan", %{"equity_plan" => %{"company_id" => "", "plan_name" => ""}})
      assert html =~ "Failed to add equity plan"
    end

    test "save_jv with invalid data shows error", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/governance")

      html = render_hook(view, "save_jv", %{"joint_venture" => %{"company_id" => "", "name" => ""}})
      assert html =~ "Failed to add joint venture"
    end

    test "save_poa with invalid data shows error", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/governance")

      html = render_hook(view, "save_poa", %{"power_of_attorney" => %{"company_id" => "", "grantor" => ""}})
      assert html =~ "Failed to add power of attorney"
    end
  end

  describe "update error paths" do
    test "update_meeting with invalid data shows error", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "ErrUpdMtgCo"})
      meeting = board_meeting_fixture(%{company: company, title: "Board Q1"})

      {:ok, view, _html} = live(conn, ~p"/governance")
      view |> element(~s(button[phx-click="edit_meeting"][phx-value-id="#{meeting.id}"])) |> render_click()

      html = render_hook(view, "update_meeting", %{"board_meeting" => %{"company_id" => "", "scheduled_date" => ""}})
      assert html =~ "Failed to update meeting"
    end

    test "update_cap_table with invalid data shows error", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "ErrUpdCapCo"})
      entry = cap_table_entry_fixture(%{company: company, shareholder_name: "Alice"})

      {:ok, view, _html} = live(conn, ~p"/governance")
      view |> element(~s(button[phx-value-tab="cap_table"])) |> render_click()
      view |> element(~s(button[phx-click="edit_cap_table"][phx-value-id="#{entry.id}"])) |> render_click()

      html = render_hook(view, "update_cap_table", %{"cap_table_entry" => %{"company_id" => "", "investor" => ""}})
      assert html =~ "Failed to update entry"
    end

    test "update_resolution with invalid data shows error", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "ErrUpdResCo"})
      resolution = shareholder_resolution_fixture(%{company: company, title: "Resolution A"})

      {:ok, view, _html} = live(conn, ~p"/governance")
      view |> element(~s(button[phx-value-tab="resolutions"])) |> render_click()
      view |> element(~s(button[phx-click="edit_resolution"][phx-value-id="#{resolution.id}"])) |> render_click()

      html = render_hook(view, "update_resolution", %{"resolution" => %{"company_id" => "", "title" => ""}})
      assert html =~ "Failed to update resolution"
    end

    test "update_deal with invalid data shows error", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "ErrUpdDealCo"})
      deal = deal_fixture(%{company: company, name: "Deal X"})

      {:ok, view, _html} = live(conn, ~p"/governance")
      view |> element(~s(button[phx-value-tab="deals"])) |> render_click()
      view |> element(~s(button[phx-click="edit_deal"][phx-value-id="#{deal.id}"])) |> render_click()

      html = render_hook(view, "update_deal", %{"deal" => %{"company_id" => "", "counterparty" => ""}})
      assert html =~ "Failed to update deal"
    end

    test "update_equity_plan with invalid data shows error", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "ErrUpdEPCo"})
      plan = equity_incentive_plan_fixture(%{company: company, plan_name: "ESOP"})

      {:ok, view, _html} = live(conn, ~p"/governance")
      view |> element(~s(button[phx-value-tab="equity_plans"])) |> render_click()
      view |> element(~s(button[phx-click="edit_equity_plan"][phx-value-id="#{plan.id}"])) |> render_click()

      html = render_hook(view, "update_equity_plan", %{"equity_plan" => %{"company_id" => "", "plan_name" => ""}})
      assert html =~ "Failed to update equity plan"
    end

    test "update_jv with invalid data shows error", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "ErrUpdJVCo"})
      jv = joint_venture_fixture(%{company: company, name: "JV Alpha"})

      {:ok, view, _html} = live(conn, ~p"/governance")
      view |> element(~s(button[phx-value-tab="joint_ventures"])) |> render_click()
      view |> element(~s(button[phx-click="edit_jv"][phx-value-id="#{jv.id}"])) |> render_click()

      html = render_hook(view, "update_jv", %{"joint_venture" => %{"company_id" => "", "name" => ""}})
      assert html =~ "Failed to update joint venture"
    end

    test "update_poa with invalid data shows error", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "ErrUpdPOACo"})
      poa = power_of_attorney_fixture(%{company: company, grantor: "John"})

      {:ok, view, _html} = live(conn, ~p"/governance")
      view |> element(~s(button[phx-value-tab="powers_of_attorney"])) |> render_click()
      view |> element(~s(button[phx-click="edit_poa"][phx-value-id="#{poa.id}"])) |> render_click()

      html = render_hook(view, "update_poa", %{"power_of_attorney" => %{"company_id" => "", "grantor" => ""}})
      assert html =~ "Failed to update power of attorney"
    end
  end
end
