defmodule HoldcoWeb.CompanyLiveShowTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  defp create_company(_context) do
    company = company_fixture(%{name: "Test Corp", country: "US", category: "Operating"})
    %{company: company}
  end

  describe "tab switching" do
    setup [:create_company]

    test "switching tab resets show_form (no modal visible)", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      # Open a form on holdings tab
      view |> element(~s(button[phx-value-tab="holdings"])) |> render_click()
      view |> element(~s(button[phx-value-form="holding"])) |> render_click()

      # Switch to another tab
      html = view |> element(~s(button[phx-value-tab="transactions"])) |> render_click()

      refute html =~ "dialog-overlay"
    end
  end

  describe "overview tab content" do
    setup [:create_company]

    test "displays key personnel data when present", %{conn: conn, company: company} do
      key_personnel_fixture(%{company: company, name: "Jane Director", title: "CEO"})

      {:ok, _view, html} = live(conn, ~p"/companies/#{company.id}")

      assert html =~ "Jane Director"
      assert html =~ "CEO"
    end

    test "displays beneficial owner data when present", %{conn: conn, company: company} do
      beneficial_owner_fixture(%{company: company, name: "John Owner", nationality: "US", ownership_pct: 51.0})

      {:ok, _view, html} = live(conn, ~p"/companies/#{company.id}")

      assert html =~ "John Owner"
      assert html =~ "51.0%"
    end

    test "displays service provider data when present", %{conn: conn, company: company} do
      service_provider_fixture(%{company: company, role: "Legal", name: "Big Law LLP"})

      {:ok, _view, html} = live(conn, ~p"/companies/#{company.id}")

      assert html =~ "Big Law LLP"
      assert html =~ "Legal"
    end

    test "shows Subsidiaries section when subsidiaries exist", %{conn: conn, company: company} do
      _child = company_fixture(%{name: "SubCo Inc", parent_id: company.id, country: "UK"})

      {:ok, _view, html} = live(conn, ~p"/companies/#{company.id}")

      assert html =~ "Subsidiaries"
      assert html =~ "SubCo Inc"
    end
  end

  describe "holdings tab content" do
    setup [:create_company]

    test "displays holding data in table", %{conn: conn, company: company} do
      holding_fixture(%{company: company, asset: "Apple Inc", ticker: "AAPL", quantity: 100.0, currency: "USD"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = view |> element(~s(button[phx-value-tab="holdings"])) |> render_click()

      assert html =~ "Apple Inc"
      assert html =~ "AAPL"
    end

  end

  describe "holdings tab - add holding form" do
    setup [:create_company]

    test "editor can open the Add Holding modal", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-tab="holdings"])) |> render_click()
      html = view |> element(~s(button[phx-value-form="holding"])) |> render_click()

      assert html =~ "Add Position"
      assert html =~ "dialog-overlay"
      assert html =~ ~s(name="holding[asset]")
      assert html =~ ~s(name="holding[ticker]")
      assert html =~ ~s(name="holding[quantity]")
    end

    test "editor can submit a new holding", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-tab="holdings"])) |> render_click()
      view |> element(~s(button[phx-value-form="holding"])) |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_holding"]), %{holding: %{asset: "Gold Bars", ticker: "GLD", quantity: "50"}})
        |> render_submit()

      assert html =~ "Holding added"
    end

    test "editor can delete a holding", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      holding = holding_fixture(%{company: company, asset: "Delete Me"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-tab="holdings"])) |> render_click()

      html =
        view
        |> element(~s(button[phx-click="delete_holding"][phx-value-id="#{holding.id}"]))
        |> render_click()

      assert html =~ "Holding deleted"
    end
  end

  describe "bank accounts tab content" do
    setup [:create_company]

    test "displays bank account data", %{conn: conn, company: company} do
      bank_account_fixture(%{company: company, bank_name: "Swiss National Bank", account_number: "123456", currency: "CHF"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = view |> element(~s(button[phx-value-tab="bank_accounts"])) |> render_click()

      assert html =~ "Swiss National Bank"
      assert html =~ "123456"
    end

    test "editor can submit a new bank account", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-tab="bank_accounts"])) |> render_click()
      view |> element(~s(button[phx-value-form="bank_account"])) |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_bank_account"]), %{bank_account: %{bank_name: "New Bank"}})
        |> render_submit()

      assert html =~ "Bank account added"
    end

    test "editor can delete a bank account", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      ba = bank_account_fixture(%{company: company, bank_name: "Old Bank"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-tab="bank_accounts"])) |> render_click()

      html =
        view
        |> element(~s(button[phx-click="delete_bank_account"][phx-value-id="#{ba.id}"]))
        |> render_click()

      assert html =~ "Bank account deleted"
    end
  end

  describe "transactions tab content" do
    setup [:create_company]

    test "displays transaction data", %{conn: conn, company: company} do
      transaction_fixture(%{company: company, description: "Wire transfer", transaction_type: "credit", amount: 5000.0})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = view |> element(~s(button[phx-value-tab="transactions"])) |> render_click()

      assert html =~ "Wire transfer"
      assert html =~ "credit"
    end

    test "editor can submit a new transaction", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-tab="transactions"])) |> render_click()
      view |> element(~s(button[phx-value-form="transaction"])) |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_transaction"]), %{
          transaction: %{description: "Payment received", transaction_type: "credit", amount: "1000", date: "2024-06-01"}
        })
        |> render_submit()

      assert html =~ "Transaction added"
    end

    test "editor can delete a transaction", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      tx = transaction_fixture(%{company: company, description: "To delete"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-tab="transactions"])) |> render_click()

      html =
        view
        |> element(~s(button[phx-click="delete_transaction"][phx-value-id="#{tx.id}"]))
        |> render_click()

      assert html =~ "Transaction deleted"
    end
  end

  describe "documents tab content" do
    setup [:create_company]

    test "displays document data", %{conn: conn, company: company} do
      document_fixture(%{company: company, name: "Articles of Incorporation"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = view |> element(~s(button[phx-value-tab="documents"])) |> render_click()

      assert html =~ "Articles of Incorporation"
    end

  end

  describe "governance tab content" do
    setup [:create_company]

    test "displays board meeting data when present", %{conn: conn, company: company} do
      board_meeting_fixture(%{company: company, scheduled_date: "2024-03-15"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = view |> element(~s(button[phx-value-tab="governance"])) |> render_click()

      assert html =~ "2024-03-15"
    end

    test "displays cap table entry when present", %{conn: conn, company: company} do
      cap_table_entry_fixture(%{company: company, investor: "Venture Fund Alpha", round_name: "Series A"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = view |> element(~s(button[phx-value-tab="governance"])) |> render_click()

      assert html =~ "Venture Fund Alpha"
      assert html =~ "Series A"
    end

    test "displays resolution when present", %{conn: conn, company: company} do
      shareholder_resolution_fixture(%{company: company, title: "Approve Dividend", date: "2024-01-15"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = view |> element(~s(button[phx-value-tab="governance"])) |> render_click()

      assert html =~ "Approve Dividend"
    end

  end

  describe "compliance tab content" do
    setup [:create_company]

    test "displays tax deadline when present", %{conn: conn, company: company} do
      tax_deadline_fixture(%{company: company, jurisdiction: "US", description: "Annual filing", due_date: "2024-04-15"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = view |> element(~s(button[phx-value-tab="compliance"])) |> render_click()

      assert html =~ "Annual filing"
      assert html =~ "2024-04-15"
    end

    test "displays insurance policy when present", %{conn: conn, company: company} do
      insurance_policy_fixture(%{company: company, policy_type: "D&amp;O", provider: "Insurer Inc"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = view |> element(~s(button[phx-value-tab="compliance"])) |> render_click()

      assert html =~ "Insurer Inc"
    end

  end

  describe "financials tab content" do
    setup [:create_company]

    test "displays financial data when present", %{conn: conn, company: company} do
      financial_fixture(%{company: company, period: "2024-Q1", revenue: 100_000.0, expenses: 80_000.0})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = view |> element(~s(button[phx-value-tab="financials"])) |> render_click()

      assert html =~ "2024-Q1"
    end

    test "editor can add a financial record", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-tab="financials"])) |> render_click()
      view |> element(~s(button[phx-value-form="financial"])) |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_financial"]), %{financial: %{period: "2024-Q2"}})
        |> render_submit()

      assert html =~ "Financial record added"
    end

    test "editor can delete a financial record", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      fin = financial_fixture(%{company: company, period: "2024-Q3"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-tab="financials"])) |> render_click()

      html =
        view
        |> element(~s(button[phx-click="delete_financial"][phx-value-id="#{fin.id}"]))
        |> render_click()

      assert html =~ "Financial record deleted"
    end
  end

  describe "comments tab content" do
    setup [:create_company]

    test "user can submit a comment", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-tab="comments"])) |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_comment"]), %{body: "This is a test comment"})
        |> render_submit()

      assert html =~ "This is a test comment"
      assert html =~ "Comments (1)"
    end
  end

  describe "close form modal" do
    setup [:create_company]

    test "close_form hides the modal", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-tab="holdings"])) |> render_click()
      view |> element(~s(button[phx-value-form="holding"])) |> render_click()

      html = view |> element(~s(button[phx-click="close_form"])) |> render_click()

      refute html =~ "dialog-overlay"
    end
  end

  describe "governance tab - CRUD operations" do
    setup [:create_company]

    test "editor can add a board meeting", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-tab="governance"])) |> render_click()
      view |> element(~s(button[phx-value-form="board_meeting"])) |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_board_meeting"]), %{board_meeting: %{scheduled_date: "2024-06-01"}})
        |> render_submit()

      assert html =~ "Board meeting added"
    end

    test "editor can delete a board meeting", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      bm = board_meeting_fixture(%{company: company, scheduled_date: "2024-07-01"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-tab="governance"])) |> render_click()

      html =
        view
        |> element(~s(button[phx-click="delete_board_meeting"][phx-value-id="#{bm.id}"]))
        |> render_click()

      assert html =~ "Board meeting deleted"
    end

    test "editor can add a cap table entry", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-tab="governance"])) |> render_click()
      view |> element(~s(button[phx-value-form="cap_table"])) |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_cap_table"]), %{cap_table: %{investor: "New Investor", round_name: "Seed"}})
        |> render_submit()

      assert html =~ "Cap table entry added"
    end

    test "editor can delete a cap table entry", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      ct = cap_table_entry_fixture(%{company: company, investor: "Delete Investor"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-tab="governance"])) |> render_click()

      html =
        view
        |> element(~s(button[phx-click="delete_cap_table"][phx-value-id="#{ct.id}"]))
        |> render_click()

      assert html =~ "Cap table entry deleted"
    end

    test "editor can add a resolution", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-tab="governance"])) |> render_click()
      view |> element(~s(button[phx-value-form="resolution"])) |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_resolution"]), %{resolution: %{title: "Approve Budget", date: "2024-02-01"}})
        |> render_submit()

      assert html =~ "Resolution added"
    end

    test "editor can delete a resolution", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      res = shareholder_resolution_fixture(%{company: company, title: "Old Res", date: "2024-01-01"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-tab="governance"])) |> render_click()

      html =
        view
        |> element(~s(button[phx-click="delete_resolution"][phx-value-id="#{res.id}"]))
        |> render_click()

      assert html =~ "Resolution deleted"
    end

    test "editor can add a deal", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-tab="governance"])) |> render_click()
      view |> element(~s(button[phx-value-form="deal"])) |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_deal"]), %{deal: %{counterparty: "AcquireCo"}})
        |> render_submit()

      assert html =~ "Deal added"
    end

    test "editor can delete a deal", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      deal = deal_fixture(%{company: company, counterparty: "Delete Deal"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-tab="governance"])) |> render_click()

      html =
        view
        |> element(~s(button[phx-click="delete_deal"][phx-value-id="#{deal.id}"]))
        |> render_click()

      assert html =~ "Deal deleted"
    end

    test "editor can add a joint venture", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-tab="governance"])) |> render_click()
      view |> element(~s(button[phx-value-form="jv"])) |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_jv"]), %{jv: %{name: "New JV", partner: "Partner Ltd"}})
        |> render_submit()

      assert html =~ "Joint venture added"
    end

    test "editor can delete a joint venture", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      jv = joint_venture_fixture(%{company: company, name: "Old JV", partner: "Old Partner"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-tab="governance"])) |> render_click()

      html =
        view
        |> element(~s(button[phx-click="delete_jv"][phx-value-id="#{jv.id}"]))
        |> render_click()

      assert html =~ "Joint venture deleted"
    end

    test "editor can add a power of attorney", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-tab="governance"])) |> render_click()
      view |> element(~s(button[phx-value-form="poa"])) |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_poa"]), %{poa: %{grantor: "CEO", grantee: "CFO"}})
        |> render_submit()

      assert html =~ "Power of attorney added"
    end

    test "editor can delete a power of attorney", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      poa = power_of_attorney_fixture(%{company: company, grantor: "Old CEO", grantee: "Old CFO"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-tab="governance"])) |> render_click()

      html =
        view
        |> element(~s(button[phx-click="delete_poa"][phx-value-id="#{poa.id}"]))
        |> render_click()

      assert html =~ "Power of attorney deleted"
    end

    test "editor can add an equity plan", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-tab="governance"])) |> render_click()
      view |> element(~s(button[phx-value-form="equity_plan"])) |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_equity_plan"]), %{equity_plan: %{plan_name: "2024 ESOP"}})
        |> render_submit()

      assert html =~ "Equity plan added"
    end

    test "editor can delete an equity plan", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      ep = equity_incentive_plan_fixture(%{company: company, plan_name: "Old ESOP"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-tab="governance"])) |> render_click()

      html =
        view
        |> element(~s(button[phx-click="delete_equity_plan"][phx-value-id="#{ep.id}"]))
        |> render_click()

      assert html =~ "Equity plan deleted"
    end

    test "displays deal data when present", %{conn: conn, company: company} do
      deal_fixture(%{company: company, counterparty: "Target Corp", deal_type: "acquisition"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = view |> element(~s(button[phx-value-tab="governance"])) |> render_click()

      assert html =~ "Target Corp"
      assert html =~ "acquisition"
    end

    test "displays joint venture data when present", %{conn: conn, company: company} do
      joint_venture_fixture(%{company: company, name: "Tech JV", partner: "Partner Corp"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = view |> element(~s(button[phx-value-tab="governance"])) |> render_click()

      assert html =~ "Tech JV"
      assert html =~ "Partner Corp"
    end

    test "displays power of attorney data when present", %{conn: conn, company: company} do
      power_of_attorney_fixture(%{company: company, grantor: "CEO Smith", grantee: "CFO Jones"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = view |> element(~s(button[phx-value-tab="governance"])) |> render_click()

      assert html =~ "CEO Smith"
      assert html =~ "CFO Jones"
    end

    test "displays equity plan data when present", %{conn: conn, company: company} do
      equity_incentive_plan_fixture(%{company: company, plan_name: "2024 Stock Option Plan"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = view |> element(~s(button[phx-value-tab="governance"])) |> render_click()

      assert html =~ "2024 Stock Option Plan"
    end
  end

  describe "compliance tab - CRUD operations" do
    setup [:create_company]

    test "editor can add a tax deadline", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-tab="compliance"])) |> render_click()
      view |> element(~s(button[phx-value-form="tax_deadline"])) |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_tax_deadline"]), %{
          tax_deadline: %{jurisdiction: "UK", description: "VAT return", due_date: "2024-07-31"}
        })
        |> render_submit()

      assert html =~ "Tax deadline added"
    end

    test "editor can delete a tax deadline", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      td = tax_deadline_fixture(%{company: company, jurisdiction: "DE", due_date: "2024-09-30"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-tab="compliance"])) |> render_click()

      html =
        view
        |> element(~s(button[phx-click="delete_tax_deadline"][phx-value-id="#{td.id}"]))
        |> render_click()

      assert html =~ "Tax deadline deleted"
    end

    test "editor can add an insurance policy", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-tab="compliance"])) |> render_click()
      view |> element(~s(button[phx-value-form="insurance_policy"])) |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_insurance_policy"]), %{
          insurance_policy: %{policy_type: "D&O", provider: "BigInsure"}
        })
        |> render_submit()

      assert html =~ "Insurance policy added"
    end

    test "editor can delete an insurance policy", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      ip = insurance_policy_fixture(%{company: company, policy_type: "General"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-tab="compliance"])) |> render_click()

      html =
        view
        |> element(~s(button[phx-click="delete_insurance_policy"][phx-value-id="#{ip.id}"]))
        |> render_click()

      assert html =~ "Insurance policy deleted"
    end

    test "editor can add a regulatory filing", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-tab="compliance"])) |> render_click()
      view |> element(~s(button[phx-value-form="filing"])) |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_filing"]), %{
          filing: %{jurisdiction: "US", filing_type: "10-K", due_date: "2024-03-31"}
        })
        |> render_submit()

      assert html =~ "Regulatory filing added"
    end

    test "editor can delete a regulatory filing", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      rf = regulatory_filing_fixture(%{company: company, jurisdiction: "US"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-tab="compliance"])) |> render_click()

      html =
        view
        |> element(~s(button[phx-click="delete_filing"][phx-value-id="#{rf.id}"]))
        |> render_click()

      assert html =~ "Regulatory filing deleted"
    end

    test "editor can add a regulatory license", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-tab="compliance"])) |> render_click()
      view |> element(~s(button[phx-value-form="license"])) |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_license"]), %{
          license: %{license_type: "broker-dealer", issuing_authority: "SEC"}
        })
        |> render_submit()

      assert html =~ "Regulatory license added"
    end

    test "editor can delete a regulatory license", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      rl = regulatory_license_fixture(%{company: company})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-tab="compliance"])) |> render_click()

      html =
        view
        |> element(~s(button[phx-click="delete_license"][phx-value-id="#{rl.id}"]))
        |> render_click()

      assert html =~ "Regulatory license deleted"
    end

    test "editor can add an ESG score", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-tab="compliance"])) |> render_click()
      view |> element(~s(button[phx-value-form="esg"])) |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_esg"]), %{esg: %{period: "2024"}})
        |> render_submit()

      assert html =~ "ESG score added"
    end

    test "editor can delete an ESG score", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      esg = esg_score_fixture(%{company: company, period: "2023"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-tab="compliance"])) |> render_click()

      html =
        view
        |> element(~s(button[phx-click="delete_esg"][phx-value-id="#{esg.id}"]))
        |> render_click()

      assert html =~ "ESG score deleted"
    end

    test "editor can add a sanctions check", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-tab="compliance"])) |> render_click()
      view |> element(~s(button[phx-value-form="sanctions"])) |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_sanctions"]), %{sanctions: %{checked_name: "Test Entity"}})
        |> render_submit()

      assert html =~ "Sanctions check added"
    end

    test "editor can delete a sanctions check", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      sc = sanctions_check_fixture(%{company: company, checked_name: "Old Check"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-tab="compliance"])) |> render_click()

      html =
        view
        |> element(~s(button[phx-click="delete_sanctions"][phx-value-id="#{sc.id}"]))
        |> render_click()

      assert html =~ "Sanctions check deleted"
    end

    test "editor can add a FATCA report", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-tab="compliance"])) |> render_click()
      view |> element(~s(button[phx-value-form="fatca"])) |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_fatca"]), %{fatca: %{reporting_year: "2024", jurisdiction: "US"}})
        |> render_submit()

      assert html =~ "FATCA report added"
    end

    test "editor can delete a FATCA report", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      fr = fatca_report_fixture(%{company: company, reporting_year: 2023})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-tab="compliance"])) |> render_click()

      html =
        view
        |> element(~s(button[phx-click="delete_fatca"][phx-value-id="#{fr.id}"]))
        |> render_click()

      assert html =~ "FATCA report deleted"
    end

    test "editor can add a withholding tax", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-tab="compliance"])) |> render_click()
      view |> element(~s(button[phx-value-form="withholding"])) |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_withholding"]), %{
          withholding: %{
            payment_type: "dividend",
            country_from: "US",
            country_to: "UK",
            gross_amount: "10000",
            rate: "0.15",
            tax_amount: "1500",
            date: "2024-06-01"
          }
        })
        |> render_submit()

      assert html =~ "Withholding tax added"
    end

    test "editor can delete a withholding tax", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      wt = withholding_tax_fixture(%{company: company})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-tab="compliance"])) |> render_click()

      html =
        view
        |> element(~s(button[phx-click="delete_withholding"][phx-value-id="#{wt.id}"]))
        |> render_click()

      assert html =~ "Withholding tax deleted"
    end

    test "displays regulatory filing data when present", %{conn: conn, company: company} do
      regulatory_filing_fixture(%{company: company, jurisdiction: "UK", filing_type: "20-F"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = view |> element(~s(button[phx-value-tab="compliance"])) |> render_click()

      assert html =~ "UK"
      assert html =~ "20-F"
    end

    test "displays regulatory license data when present", %{conn: conn, company: company} do
      regulatory_license_fixture(%{company: company, license_type: "banking", issuing_authority: "FCA"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = view |> element(~s(button[phx-value-tab="compliance"])) |> render_click()

      assert html =~ "banking"
      assert html =~ "FCA"
    end

    test "displays ESG score data when present", %{conn: conn, company: company} do
      esg_score_fixture(%{company: company, period: "2024"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = view |> element(~s(button[phx-value-tab="compliance"])) |> render_click()

      assert html =~ "2024"
    end

    test "displays sanctions check data when present", %{conn: conn, company: company} do
      sanctions_check_fixture(%{company: company, checked_name: "Acme Entity"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = view |> element(~s(button[phx-value-tab="compliance"])) |> render_click()

      assert html =~ "Acme Entity"
    end

    test "displays FATCA report data when present", %{conn: conn, company: company} do
      fatca_report_fixture(%{company: company, reporting_year: 2024, jurisdiction: "CH"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = view |> element(~s(button[phx-value-tab="compliance"])) |> render_click()

      assert html =~ "2024"
      assert html =~ "CH"
    end

    test "displays withholding tax data when present", %{conn: conn, company: company} do
      withholding_tax_fixture(%{company: company, payment_type: "interest", country_from: "DE", country_to: "FR"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = view |> element(~s(button[phx-value-tab="compliance"])) |> render_click()

      assert html =~ "interest"
      assert html =~ "DE"
      assert html =~ "FR"
    end
  end

  describe "financials tab - liabilities and dividends" do
    setup [:create_company]

    test "editor can add a liability", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-tab="financials"])) |> render_click()
      view |> element(~s(button[phx-value-form="liability"])) |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_liability"]), %{
          liability: %{liability_type: "loan", creditor: "Bank ABC", principal: "50000"}
        })
        |> render_submit()

      assert html =~ "Liability added"
    end

    test "editor can delete a liability", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      l = liability_fixture(%{company: company, creditor: "Old Bank"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-tab="financials"])) |> render_click()

      html =
        view
        |> element(~s(button[phx-click="delete_liability"][phx-value-id="#{l.id}"]))
        |> render_click()

      assert html =~ "Liability deleted"
    end

    test "editor can add a dividend", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-tab="financials"])) |> render_click()
      view |> element(~s(button[phx-value-form="dividend"])) |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_dividend"]), %{
          dividend: %{date: "2024-06-15", recipient: "Shareholder A", amount: "5000"}
        })
        |> render_submit()

      assert html =~ "Dividend added"
    end

    test "editor can delete a dividend", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      d = dividend_fixture(%{company: company, amount: 2000.0})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-tab="financials"])) |> render_click()

      html =
        view
        |> element(~s(button[phx-click="delete_dividend"][phx-value-id="#{d.id}"]))
        |> render_click()

      assert html =~ "Dividend deleted"
    end

    test "displays liability data when present", %{conn: conn, company: company} do
      liability_fixture(%{company: company, liability_type: "bond", creditor: "Bondholders Inc"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = view |> element(~s(button[phx-value-tab="financials"])) |> render_click()

      assert html =~ "bond"
      assert html =~ "Bondholders Inc"
    end

    test "displays dividend data when present", %{conn: conn, company: company} do
      dividend_fixture(%{company: company, amount: 3000.0, date: "2024-03-15"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = view |> element(~s(button[phx-value-tab="financials"])) |> render_click()

      assert html =~ "2024-03-15"
    end
  end

  describe "accounting tab" do
    setup [:create_company]

    test "displays account data when present", %{conn: conn, company: company} do
      account_fixture(%{company: company, name: "Cash", code: "1000", account_type: "asset"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = render_hook(view, :switch_tab, %{"tab" => "accounting"})

      assert html =~ "Cash"
      assert html =~ "1000"
      assert html =~ "asset"
    end

    test "editor can add an account", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      render_hook(view, :switch_tab, %{"tab" => "accounting"})
      view |> element(~s(button[phx-value-form="account"])) |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_account"]), %{
          account: %{code: "2000", name: "Accounts Payable", account_type: "liability"}
        })
        |> render_submit()

      assert html =~ "Account added"
    end

    test "editor can delete an account", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      acct = account_fixture(%{company: company, name: "Old Account", code: "9999"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      render_hook(view, :switch_tab, %{"tab" => "accounting"})

      html =
        view
        |> element(~s(button[phx-click="delete_account"][phx-value-id="#{acct.id}"]))
        |> render_click()

      assert html =~ "Account deleted"
    end

    test "editor can add a journal entry line", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      render_hook(view, :switch_tab, %{"tab" => "accounting"})
      view |> element(~s(button[phx-value-form="journal_entry"])) |> render_click()

      # Click add_je_line button to add another row
      html = view |> element(~s(button[phx-click="add_je_line"])) |> render_click()

      assert html =~ "dialog-overlay"
    end

    test "editor can create a balanced journal entry", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      acct1 = account_fixture(%{company: company, name: "Cash", code: "1001", account_type: "asset"})
      acct2 = account_fixture(%{company: company, name: "Revenue", code: "4001", account_type: "revenue"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      render_hook(view, :switch_tab, %{"tab" => "accounting"})
      view |> element(~s(button[phx-value-form="journal_entry"])) |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_journal_entry"]), %{
          entry: %{date: "2024-06-01", description: "Test JE"},
          lines: %{
            "0" => %{account_id: acct1.id, debit: "100", credit: "0"},
            "1" => %{account_id: acct2.id, debit: "0", credit: "100"}
          }
        })
        |> render_submit()

      assert html =~ "Journal entry created"
    end

    test "journal entry fails when debits do not equal credits", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      acct1 = account_fixture(%{company: company, name: "Cash", code: "1002", account_type: "asset"})
      acct2 = account_fixture(%{company: company, name: "Revenue", code: "4002", account_type: "revenue"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      render_hook(view, :switch_tab, %{"tab" => "accounting"})
      view |> element(~s(button[phx-value-form="journal_entry"])) |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_journal_entry"]), %{
          entry: %{date: "2024-06-01", description: "Unbalanced JE"},
          lines: %{
            "0" => %{account_id: acct1.id, debit: "100", credit: "0"},
            "1" => %{account_id: acct2.id, debit: "0", credit: "50"}
          }
        })
        |> render_submit()

      assert html =~ "Debits must equal credits"
    end

    test "journal entry fails with less than 2 lines", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      acct = account_fixture(%{company: company, name: "Cash", code: "1003", account_type: "asset"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      render_hook(view, :switch_tab, %{"tab" => "accounting"})
      view |> element(~s(button[phx-value-form="journal_entry"])) |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_journal_entry"]), %{
          entry: %{date: "2024-06-01", description: "Single line"},
          lines: %{
            "0" => %{account_id: acct.id, debit: "100", credit: "0"},
            "1" => %{account_id: "", debit: "0", credit: "0"}
          }
        })
        |> render_submit()

      assert html =~ "At least 2 lines required"
    end

    test "editor can delete a journal entry", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      je = journal_entry_fixture(%{company: company, date: "2024-01-01", description: "Test entry"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      render_hook(view, :switch_tab, %{"tab" => "accounting"})

      html =
        view
        |> element(~s(button[phx-click="delete_journal_entry"][phx-value-id="#{je.id}"]))
        |> render_click()

      assert html =~ "Journal entry deleted"
    end
  end

  describe "overview tab - editor CRUD on overview entities" do
    setup [:create_company]

    test "editor can add key personnel", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-form="key_personnel"])) |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_key_personnel"]), %{key_personnel: %{name: "Alice Director", title: "COO"}})
        |> render_submit()

      assert html =~ "Key personnel added"
    end

    test "editor can delete key personnel", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      kp = key_personnel_fixture(%{company: company, name: "To Delete KP"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html =
        view
        |> element(~s(button[phx-click="delete_key_personnel"][phx-value-id="#{kp.id}"]))
        |> render_click()

      assert html =~ "Key personnel deleted"
    end

    test "editor can add beneficial owner", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-form="beneficial_owner"])) |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_beneficial_owner"]), %{beneficial_owner: %{name: "New BO"}})
        |> render_submit()

      assert html =~ "Beneficial owner added"
    end

    test "editor can delete beneficial owner", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      bo = beneficial_owner_fixture(%{company: company, name: "To Delete BO"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html =
        view
        |> element(~s(button[phx-click="delete_beneficial_owner"][phx-value-id="#{bo.id}"]))
        |> render_click()

      assert html =~ "Beneficial owner deleted"
    end

    test "editor can add service provider", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-form="service_provider"])) |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_service_provider"]), %{service_provider: %{role: "Auditor", name: "Big Four"}})
        |> render_submit()

      assert html =~ "Service provider added"
    end

    test "editor can delete service provider", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      sp = service_provider_fixture(%{company: company, name: "To Delete SP"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html =
        view
        |> element(~s(button[phx-click="delete_service_provider"][phx-value-id="#{sp.id}"]))
        |> render_click()

      assert html =~ "Service provider deleted"
    end

    test "editor can update company", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = render_hook(view, :update_company, %{"company" => %{"name" => "Updated Corp"}})

      assert html =~ "Company updated"
    end
  end

  describe "documents tab - submit and delete" do
    setup [:create_company]

    test "editor can submit a new document", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-tab="documents"])) |> render_click()
      view |> element(~s(button[phx-value-form="document"])) |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_document"]), %{document: %{name: "Board Minutes"}})
        |> render_submit()

      assert html =~ "Document added"
    end

    test "editor can delete a document", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      doc = document_fixture(%{company: company, name: "To Delete Doc"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-tab="documents"])) |> render_click()

      html =
        view
        |> element(~s(button[phx-click="delete_document"][phx-value-id="#{doc.id}"]))
        |> render_click()

      assert html =~ "Document deleted"
    end
  end

  describe "comments tab - admin operations" do
    setup [:create_company]

    test "admin can see delete button for comments", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "admin")

      # Create a comment first
      Holdco.Collaboration.create_comment(%{
        user_id: user.id,
        entity_type: "companies",
        entity_id: company.id,
        body: "Test admin comment"
      })

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = view |> element(~s(button[phx-value-tab="comments"])) |> render_click()

      assert html =~ "Delete"
      assert html =~ "Test admin comment"
    end

    test "admin can delete a comment", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "admin")

      {:ok, comment} =
        Holdco.Collaboration.create_comment(%{
          user_id: user.id,
          entity_type: "companies",
          entity_id: company.id,
          body: "Comment to delete"
        })

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      view |> element(~s(button[phx-value-tab="comments"])) |> render_click()

      html =
        view
        |> element(~s(button[phx-click="delete_comment"][phx-value-id="#{comment.id}"]))
        |> render_click()

      assert html =~ "Comment deleted"
    end

  end

  describe "handle_info broadcasts" do
    setup [:create_company]

    test "company update broadcast reloads company", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      send(view.pid, {:company_updated, %{}})

      html = render(view)
      assert html =~ company.name
    end

    test "new_comment broadcast updates comments list", %{conn: conn, company: company, user: user} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      # Create a comment outside the view
      Holdco.Collaboration.create_comment(%{
        user_id: user.id,
        entity_type: "companies",
        entity_id: company.id,
        body: "Broadcast comment"
      })

      send(view.pid, {:new_comment, %{}})

      _html = render(view)
      view |> element(~s(button[phx-value-tab="comments"])) |> render_click()
      html = render(view)

      assert html =~ "Broadcast comment"
    end
  end

  describe "journal entry validation" do
    setup [:create_company]

    test "editor gets error when journal entry has fewer than 2 lines", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      account = Holdco.HoldcoFixtures.account_fixture(%{company: company})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html =
        render_hook(view, :save_journal_entry, %{
          "entry" => %{"date" => "2024-01-01", "description" => "Test"},
          "lines" => %{"0" => %{"account_id" => "#{account.id}", "debit" => "100", "credit" => "0"}}
        })

      assert html =~ "At least 2 lines required"
    end

    test "editor gets error when debits do not equal credits", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      account1 = Holdco.HoldcoFixtures.account_fixture(%{company: company})
      account2 = Holdco.HoldcoFixtures.account_fixture(%{company: company})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html =
        render_hook(view, :save_journal_entry, %{
          "entry" => %{"date" => "2024-01-01", "description" => "Unbalanced"},
          "lines" => %{
            "0" => %{"account_id" => "#{account1.id}", "debit" => "100", "credit" => "0"},
            "1" => %{"account_id" => "#{account2.id}", "debit" => "0", "credit" => "50"}
          }
        })

      assert html =~ "Debits must equal credits"
    end

    test "editor can add a journal entry line", %{conn: conn, company: company, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      # Add a line via event hook
      html = render_hook(view, :add_je_line, %{})
      # Should still render without crashing
      assert html =~ company.name
    end
  end


  # ── Consolidated view ──────────────────────────────────────

  describe "consolidated view with subsidiaries" do
    test "shows consolidated banner when company has children", %{conn: conn} do
      parent = company_fixture(%{name: "Parent HoldCo", country: "US"})
      company_fixture(%{name: "Sub Entity", parent_id: parent.id, country: "UK"})

      {:ok, _view, html} = live(conn, ~p"/companies/#{parent.id}")

      assert html =~ "Consolidated view"
      assert html =~ "1 subsidiaries"
    end

    test "consolidated holdings tab shows Company column header", %{conn: conn} do
      parent = company_fixture(%{name: "Consol Parent", country: "US"})
      child = company_fixture(%{name: "Consol Child", parent_id: parent.id, country: "UK"})
      holding_fixture(%{company: parent, asset: "Parent Stock", ticker: "PS"})
      holding_fixture(%{company: child, asset: "Child Stock", ticker: "CS"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{parent.id}")
      html = view |> element(~s(button[phx-value-tab="holdings"])) |> render_click()

      assert html =~ "Company"
      assert html =~ "Parent Stock"
      assert html =~ "Child Stock"
    end

    test "consolidated bank_accounts tab shows data from both companies", %{conn: conn} do
      parent = company_fixture(%{name: "BA Parent", country: "US"})
      child = company_fixture(%{name: "BA Child", parent_id: parent.id, country: "UK"})
      bank_account_fixture(%{company: parent, bank_name: "Parent Bank"})
      bank_account_fixture(%{company: child, bank_name: "Child Bank"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{parent.id}")
      html = view |> element(~s(button[phx-value-tab="bank_accounts"])) |> render_click()

      assert html =~ "Parent Bank"
      assert html =~ "Child Bank"
    end

    test "consolidated transactions tab shows data from both companies", %{conn: conn} do
      parent = company_fixture(%{name: "TX Parent", country: "US"})
      child = company_fixture(%{name: "TX Child", parent_id: parent.id, country: "UK"})
      transaction_fixture(%{company: parent, description: "Parent Tx"})
      transaction_fixture(%{company: child, description: "Child Tx"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{parent.id}")
      html = view |> element(~s(button[phx-value-tab="transactions"])) |> render_click()

      assert html =~ "Parent Tx"
      assert html =~ "Child Tx"
    end

    test "consolidated accounting tab shows accounts and entries from both", %{conn: conn} do
      parent = company_fixture(%{name: "Acct Parent", country: "US"})
      child = company_fixture(%{name: "Acct Child", parent_id: parent.id, country: "UK"})
      account_fixture(%{company: parent, name: "Parent Cash", code: "1000"})
      account_fixture(%{company: child, name: "Child Cash", code: "1001"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{parent.id}")
      html = render_hook(view, :switch_tab, %{"tab" => "accounting"})

      assert html =~ "Parent Cash"
      assert html =~ "Child Cash"
    end
  end

  # ── Save error paths ──────────────────────────────────────

  describe "save error paths" do
    setup [:create_company]

    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "save_holding with invalid data shows error", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = render_hook(view, :save_holding, %{"holding" => %{"asset" => ""}})
      assert html =~ "Failed to add holding"
    end

    test "save_bank_account with invalid data shows error", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = render_hook(view, :save_bank_account, %{"bank_account" => %{"bank_name" => ""}})
      assert html =~ "Failed to add bank account"
    end

    test "save_transaction with invalid data shows error", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = render_hook(view, :save_transaction, %{"transaction" => %{"description" => ""}})
      assert html =~ "Failed to add transaction"
    end

    test "save_document with invalid data shows error", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = render_hook(view, :save_document, %{"document" => %{"name" => ""}})
      assert html =~ "Failed to add document"
    end

    test "save_board_meeting with invalid data shows error", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = render_hook(view, :save_board_meeting, %{"board_meeting" => %{"scheduled_date" => ""}})
      assert html =~ "Failed to add board meeting"
    end

    test "save_service_provider with invalid data shows error", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = render_hook(view, :save_service_provider, %{"service_provider" => %{"name" => ""}})
      assert html =~ "Failed to add service provider"
    end

    test "save_key_personnel with invalid data shows error", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = render_hook(view, :save_key_personnel, %{"key_personnel" => %{"name" => ""}})
      assert html =~ "Failed to add key personnel"
    end

    test "save_beneficial_owner with invalid data shows error", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = render_hook(view, :save_beneficial_owner, %{"beneficial_owner" => %{"name" => ""}})
      assert html =~ "Failed to add beneficial owner"
    end

    test "save_tax_deadline with invalid data shows error", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = render_hook(view, :save_tax_deadline, %{"tax_deadline" => %{"description" => ""}})
      assert html =~ "Failed to add tax deadline"
    end

    test "save_financial with invalid data shows error", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = render_hook(view, :save_financial, %{"financial" => %{"period" => ""}})
      assert html =~ "Failed to add financial"
    end

    test "save_insurance_policy with invalid data shows error", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = render_hook(view, :save_insurance_policy, %{"insurance_policy" => %{"policy_type" => ""}})
      assert html =~ "Failed to add insurance policy"
    end

    test "save_cap_table with invalid data shows error", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = render_hook(view, :save_cap_table, %{"cap_table" => %{"investor" => ""}})
      assert html =~ "Failed to add cap table entry"
    end

    test "save_resolution with invalid data shows error", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = render_hook(view, :save_resolution, %{"resolution" => %{"title" => ""}})
      assert html =~ "Failed to add resolution"
    end

    test "save_deal with invalid data shows error", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = render_hook(view, :save_deal, %{"deal" => %{"counterparty" => ""}})
      assert html =~ "Failed to add deal"
    end

    test "save_jv with invalid data shows error", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = render_hook(view, :save_jv, %{"jv" => %{"name" => ""}})
      assert html =~ "Failed to add joint venture"
    end

    test "save_poa with invalid data shows error", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = render_hook(view, :save_poa, %{"poa" => %{"grantor" => ""}})
      assert html =~ "Failed to add power of attorney"
    end

    test "save_equity_plan with invalid data shows error", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = render_hook(view, :save_equity_plan, %{"equity_plan" => %{"plan_name" => ""}})
      assert html =~ "Failed to add equity plan"
    end

    test "save_filing with invalid data shows error", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = render_hook(view, :save_filing, %{"filing" => %{"filing_type" => ""}})
      assert html =~ "Failed to add regulatory filing"
    end

    test "save_license with invalid data shows error", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = render_hook(view, :save_license, %{"license" => %{"license_type" => ""}})
      assert html =~ "Failed to add regulatory license"
    end

    test "save_esg with invalid data shows error", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = render_hook(view, :save_esg, %{"esg" => %{"period" => ""}})
      assert html =~ "Failed to add ESG score"
    end

    test "save_fatca with invalid data shows error", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = render_hook(view, :save_fatca, %{"fatca" => %{"reporting_year" => ""}})
      assert html =~ "Failed to add FATCA report"
    end

    test "save_withholding with invalid data shows error", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = render_hook(view, :save_withholding, %{"withholding" => %{"payment_type" => ""}})
      assert html =~ "Failed to add withholding tax"
    end

    test "save_liability with invalid data shows error", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = render_hook(view, :save_liability, %{"liability" => %{"creditor" => ""}})
      assert html =~ "Failed to add liability"
    end

    test "save_dividend with invalid data shows error", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = render_hook(view, :save_dividend, %{"dividend" => %{"amount" => ""}})
      assert html =~ "Failed to add dividend"
    end

    test "save_account with invalid data shows error", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = render_hook(view, :save_account, %{"account" => %{"name" => ""}})
      assert html =~ "Failed to add account"
    end

    test "save_journal_entry with valid data creates entry", %{conn: conn, company: company} do
      account1 = account_fixture(%{company: company, code: "1010", name: "JE Cash"})
      account2 = account_fixture(%{company: company, code: "2010", name: "JE Payable"})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html =
        render_hook(view, :save_journal_entry, %{
          "entry" => %{"date" => "2024-01-01", "description" => "Test JE"},
          "lines" => %{
            "0" => %{"account_id" => "#{account1.id}", "debit" => "500", "credit" => "0"},
            "1" => %{"account_id" => "#{account2.id}", "debit" => "0", "credit" => "500"}
          }
        })

      assert html =~ "Journal entry created"
    end

    test "save_comment with empty body shows error", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = render_hook(view, :save_comment, %{"body" => ""})
      assert html =~ "Failed to post comment"
    end

    test "save_sanctions with valid data adds check", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = render_hook(view, :save_sanctions, %{"sanctions" => %{"checked_name" => "Test Entity"}})
      assert html =~ "Sanctions check added"
    end

    test "update_company with invalid name shows error", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = render_hook(view, :update_company, %{"company" => %{"name" => ""}})
      assert html =~ "Failed to update company"
    end

    test "delete_journal_entry removes entry and its lines", %{conn: conn, company: company} do
      entry = journal_entry_fixture(%{company: company, description: "To Delete JE"})
      account = account_fixture(%{company: company})
      journal_line_fixture(%{entry: entry, account: account, debit: 100.0, credit: 0.0})

      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = render_hook(view, :delete_journal_entry, %{"id" => "#{entry.id}"})
      assert html =~ "Journal entry deleted"
    end
  end
end
