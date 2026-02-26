defmodule HoldcoWeb.ComplianceLiveTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "GET /compliance" do
    test "renders compliance page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/compliance")

      assert html =~ "Compliance"
    end

    test "renders page title with rule", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/compliance")

      assert html =~ "page-title"
      assert html =~ "page-title-rule"
    end

    test "renders tabs container", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/compliance")

      assert html =~ ~s(class="tabs")
    end

    test "renders all seven compliance tabs", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/compliance")

      assert html =~ ~s(phx-value-tab="regulatory_filings")
      assert html =~ ~s(phx-value-tab="licenses")
      assert html =~ ~s(phx-value-tab="insurance")
      assert html =~ ~s(phx-value-tab="sanctions")
      assert html =~ ~s(phx-value-tab="esg")
      assert html =~ ~s(phx-value-tab="fatca")
      assert html =~ ~s(phx-value-tab="withholding")
    end

    test "regulatory_filings tab is active by default", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/compliance")

      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="regulatory_filings"/s
    end

    test "renders tab-body wrapper", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/compliance")

      assert html =~ "tab-body"
    end
  end

  describe "tab switching" do
    test "clicking licenses tab activates it", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")

      html = view |> element(~s(button[phx-value-tab="licenses"])) |> render_click()

      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="licenses"/s
      assert html =~ ~r/class="tab "[^>]*phx-value-tab="regulatory_filings"/s
    end

    test "clicking insurance tab activates it", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")

      html = view |> element(~s(button[phx-value-tab="insurance"])) |> render_click()

      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="insurance"/s
    end

    test "clicking sanctions tab activates it", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")

      html = view |> element(~s(button[phx-value-tab="sanctions"])) |> render_click()

      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="sanctions"/s
    end

    test "clicking esg tab activates it", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")

      html = view |> element(~s(button[phx-value-tab="esg"])) |> render_click()

      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="esg"/s
    end

    test "clicking fatca tab activates it", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")

      html = view |> element(~s(button[phx-value-tab="fatca"])) |> render_click()

      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="fatca"/s
    end

    test "clicking withholding tab activates it", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")

      html = view |> element(~s(button[phx-value-tab="withholding"])) |> render_click()

      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="withholding"/s
    end

    test "switching tabs closes form", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/compliance")

      view |> element("button", "Add") |> render_click()

      html = view |> element(~s(button[phx-value-tab="licenses"])) |> render_click()

      refute html =~ "modal-overlay"
    end
  end

  describe "nav active state" do
    test "compliance page renders without nav highlight", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/compliance")

      # Compliance is no longer in the nav bar (removed from Consolidated dropdown)
      assert html =~ "Compliance"
    end
  end

  # ------------------------------------------------------------------
  # show_form / close_form events
  # ------------------------------------------------------------------

  describe "show_form and close_form events" do
    test "show_form opens the modal overlay", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/compliance")

      html = view |> element("button", "Add") |> render_click()

      assert html =~ "modal-overlay"
    end

    test "close_form dismisses the modal", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/compliance")

      view |> element("button", "Add") |> render_click()
      html = view |> element("button", "Cancel") |> render_click()

      refute html =~ "modal-overlay"
    end

    test "clicking modal overlay fires close_form", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/compliance")

      view |> element("button", "Add") |> render_click()
      html = view |> element(".modal-overlay") |> render_click()

      refute html =~ "modal-overlay"
    end
  end

  # ------------------------------------------------------------------
  # noop event
  # ------------------------------------------------------------------

  describe "noop event" do
    test "clicking inside the modal does not close it", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/compliance")

      view |> element("button", "Add") |> render_click()
      html = view |> element(".modal") |> render_click()

      assert html =~ "modal-overlay"
    end
  end

  # ------------------------------------------------------------------
  # Regulatory Filings CRUD
  # ------------------------------------------------------------------

  describe "regulatory filings CRUD" do
    test "create filing with valid data as editor", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "Filing Corp"})
      {:ok, view, _html} = live(conn, ~p"/compliance")

      view |> element("button", "Add") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_filing"]), %{
          regulatory_filing: %{
            company_id: company.id,
            jurisdiction: "DE",
            filing_type: "Annual Return",
            due_date: "2025-06-30"
          }
        })
        |> render_submit()

      assert html =~ "Filing added"
      assert html =~ "DE"
      assert html =~ "Annual Return"
      refute html =~ "modal-overlay"
    end

    test "delete filing as editor", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "Del Filing Corp"})
      filing = regulatory_filing_fixture(%{company: company, jurisdiction: "JP", filing_type: "Quarterly"})

      {:ok, view, _html} = live(conn, ~p"/compliance")

      html =
        view
        |> element(~s(button[phx-click="delete_filing"][phx-value-id="#{filing.id}"]))
        |> render_click()

      assert html =~ "Filing deleted"
      refute html =~ "JP"
    end

    test "edit filing opens edit form with pre-filled data", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "Edit Filing Corp"})
      filing = regulatory_filing_fixture(%{company: company, jurisdiction: "FR", filing_type: "Semi-Annual"})

      {:ok, view, _html} = live(conn, ~p"/compliance")

      html =
        view
        |> element(~s(button[phx-click="edit_filing"][phx-value-id="#{filing.id}"]))
        |> render_click()

      assert html =~ "Edit Regulatory Filing"
      assert html =~ "FR"
      assert html =~ "Semi-Annual"
    end

    test "update filing saves changes", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "Update Filing Corp"})
      filing = regulatory_filing_fixture(%{company: company, jurisdiction: "FR", filing_type: "Semi-Annual"})

      {:ok, view, _html} = live(conn, ~p"/compliance")

      view
      |> element(~s(button[phx-click="edit_filing"][phx-value-id="#{filing.id}"]))
      |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="update_filing"]), %{
          regulatory_filing: %{
            company_id: company.id,
            jurisdiction: "IT",
            filing_type: "Amended",
            due_date: "2025-12-31"
          }
        })
        |> render_submit()

      assert html =~ "Filing updated"
      assert html =~ "IT"
      assert html =~ "Amended"
    end

    test "save_filing is denied for non-editor", %{conn: conn} do
      company = company_fixture(%{name: "Blocked Filing Corp"})
      {:ok, view, _html} = live(conn, ~p"/compliance")

      # Non-editor cannot see the Add button, but we push the event directly
      html =
        render_hook(view, "save_filing", %{
          "regulatory_filing" => %{
            "company_id" => company.id,
            "jurisdiction" => "US",
            "filing_type" => "10-K",
            "due_date" => "2025-03-31"
          }
        })

      assert html =~ "You don&#39;t have permission to do that"
    end

    test "delete_filing is denied for non-editor", %{conn: conn} do
      filing = regulatory_filing_fixture()
      {:ok, view, _html} = live(conn, ~p"/compliance")

      html = render_hook(view, "delete_filing", %{"id" => filing.id})

      assert html =~ "You don&#39;t have permission to do that"
    end

    test "update_filing is denied for non-editor", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")

      html =
        render_hook(view, "update_filing", %{
          "regulatory_filing" => %{
            "jurisdiction" => "US",
            "filing_type" => "10-K",
            "due_date" => "2025-03-31"
          }
        })

      assert html =~ "You don&#39;t have permission to do that"
    end
  end

  # ------------------------------------------------------------------
  # Insurance CRUD
  # ------------------------------------------------------------------

  describe "insurance CRUD" do
    test "create insurance policy as editor", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "Insured Corp"})
      {:ok, view, _html} = live(conn, ~p"/compliance")

      # Switch to insurance tab
      view |> element(~s(button[phx-value-tab="insurance"])) |> render_click()
      view |> element("button", "Add") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_insurance"]), %{
          insurance_policy: %{
            company_id: company.id,
            policy_type: "Cyber Liability",
            provider: "AIG",
            coverage_amount: "5000000",
            premium: "25000",
            expiry_date: "2026-01-01"
          }
        })
        |> render_submit()

      assert html =~ "Policy added"
      assert html =~ "Cyber Liability"
      assert html =~ "AIG"
      refute html =~ "modal-overlay"
    end

    test "delete insurance policy as editor", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "Del Insured Corp"})
      policy = insurance_policy_fixture(%{company: company, policy_type: "E&O", provider: "Lloyd"})

      {:ok, view, _html} = live(conn, ~p"/compliance")

      view |> element(~s(button[phx-value-tab="insurance"])) |> render_click()

      html =
        view
        |> element(~s(button[phx-click="delete_insurance"][phx-value-id="#{policy.id}"]))
        |> render_click()

      assert html =~ "Policy deleted"
      refute html =~ "E&amp;O"
    end

    test "edit insurance opens edit form", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "Edit Insured Corp"})
      policy = insurance_policy_fixture(%{company: company, policy_type: "D&O", provider: "Chubb"})

      {:ok, view, _html} = live(conn, ~p"/compliance")

      view |> element(~s(button[phx-value-tab="insurance"])) |> render_click()

      html =
        view
        |> element(~s(button[phx-click="edit_insurance"][phx-value-id="#{policy.id}"]))
        |> render_click()

      assert html =~ "Edit Insurance Policy"
      assert html =~ "Chubb"
    end

    test "update insurance saves changes", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "Update Insured Corp"})
      policy = insurance_policy_fixture(%{company: company, policy_type: "D&O", provider: "Chubb"})

      {:ok, view, _html} = live(conn, ~p"/compliance")

      view |> element(~s(button[phx-value-tab="insurance"])) |> render_click()

      view
      |> element(~s(button[phx-click="edit_insurance"][phx-value-id="#{policy.id}"]))
      |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="update_insurance"]), %{
          insurance_policy: %{
            company_id: company.id,
            policy_type: "General Liability",
            provider: "Allianz",
            coverage_amount: "10000000",
            premium: "50000",
            expiry_date: "2027-06-30"
          }
        })
        |> render_submit()

      assert html =~ "Policy updated"
      assert html =~ "General Liability"
      assert html =~ "Allianz"
    end

    test "save_insurance is denied for non-editor", %{conn: conn} do
      company = company_fixture()
      {:ok, view, _html} = live(conn, ~p"/compliance")

      view |> element(~s(button[phx-value-tab="insurance"])) |> render_click()

      html =
        render_hook(view, "save_insurance", %{
          "insurance_policy" => %{
            "company_id" => company.id,
            "policy_type" => "D&O",
            "provider" => "Test"
          }
        })

      assert html =~ "You don&#39;t have permission to do that"
    end

    test "delete_insurance is denied for non-editor", %{conn: conn} do
      policy = insurance_policy_fixture()
      {:ok, view, _html} = live(conn, ~p"/compliance")

      html = render_hook(view, "delete_insurance", %{"id" => policy.id})

      assert html =~ "You don&#39;t have permission to do that"
    end
  end

  # ------------------------------------------------------------------
  # Withholding Tax CRUD
  # ------------------------------------------------------------------

  describe "withholding tax CRUD" do
    test "create withholding tax as editor", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "Withholding Corp"})
      {:ok, view, _html} = live(conn, ~p"/compliance")

      view |> element(~s(button[phx-value-tab="withholding"])) |> render_click()
      view |> element("button", "Add") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_withholding"]), %{
          withholding_tax: %{
            company_id: company.id,
            payment_type: "royalty",
            country_from: "IE",
            country_to: "US",
            gross_amount: "50000",
            rate: "0.10",
            tax_amount: "5000",
            date: "2025-07-15"
          }
        })
        |> render_submit()

      assert html =~ "Tax entry added"
      assert html =~ "royalty"
      assert html =~ "IE"
      refute html =~ "modal-overlay"
    end

    test "delete withholding tax as editor", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "Del WH Corp"})

      wt =
        withholding_tax_fixture(%{
          company: company,
          payment_type: "interest",
          country_from: "CH",
          country_to: "DE"
        })

      {:ok, view, _html} = live(conn, ~p"/compliance")

      view |> element(~s(button[phx-value-tab="withholding"])) |> render_click()

      html =
        view
        |> element(~s(button[phx-click="delete_withholding"][phx-value-id="#{wt.id}"]))
        |> render_click()

      assert html =~ "Tax entry deleted"
      refute html =~ "interest"
    end

    test "edit withholding tax opens edit form", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "Edit WH Corp"})

      wt =
        withholding_tax_fixture(%{
          company: company,
          payment_type: "dividend",
          country_from: "US",
          country_to: "UK"
        })

      {:ok, view, _html} = live(conn, ~p"/compliance")

      view |> element(~s(button[phx-value-tab="withholding"])) |> render_click()

      html =
        view
        |> element(~s(button[phx-click="edit_withholding"][phx-value-id="#{wt.id}"]))
        |> render_click()

      assert html =~ "Edit Withholding Tax"
      assert html =~ "dividend"
    end

    test "update withholding tax saves changes", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "Update WH Corp"})

      wt =
        withholding_tax_fixture(%{
          company: company,
          payment_type: "dividend",
          country_from: "US",
          country_to: "UK"
        })

      {:ok, view, _html} = live(conn, ~p"/compliance")

      view |> element(~s(button[phx-value-tab="withholding"])) |> render_click()

      view
      |> element(~s(button[phx-click="edit_withholding"][phx-value-id="#{wt.id}"]))
      |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="update_withholding"]), %{
          withholding_tax: %{
            company_id: company.id,
            payment_type: "royalty",
            country_from: "DE",
            country_to: "FR",
            gross_amount: "20000",
            rate: "0.25",
            tax_amount: "5000",
            date: "2025-09-01"
          }
        })
        |> render_submit()

      assert html =~ "Tax entry updated"
      assert html =~ "royalty"
      assert html =~ "DE"
    end

    test "save_withholding is denied for non-editor", %{conn: conn} do
      company = company_fixture()
      {:ok, view, _html} = live(conn, ~p"/compliance")

      html =
        render_hook(view, "save_withholding", %{
          "withholding_tax" => %{
            "company_id" => company.id,
            "payment_type" => "dividend",
            "country_from" => "US",
            "country_to" => "UK",
            "gross_amount" => "10000",
            "rate" => "0.15",
            "tax_amount" => "1500",
            "date" => "2025-01-01"
          }
        })

      assert html =~ "You don&#39;t have permission to do that"
    end

    test "delete_withholding is denied for non-editor", %{conn: conn} do
      wt = withholding_tax_fixture()
      {:ok, view, _html} = live(conn, ~p"/compliance")

      html = render_hook(view, "delete_withholding", %{"id" => wt.id})

      assert html =~ "You don&#39;t have permission to do that"
    end

    test "update_withholding is denied for non-editor", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")

      html =
        render_hook(view, "update_withholding", %{
          "withholding_tax" => %{
            "payment_type" => "dividend",
            "country_from" => "US",
            "country_to" => "UK",
            "gross_amount" => "10000",
            "rate" => "0.15",
            "tax_amount" => "1500",
            "date" => "2025-01-01"
          }
        })

      assert html =~ "You don&#39;t have permission to do that"
    end
  end

  # ------------------------------------------------------------------
  # FATCA CRUD
  # ------------------------------------------------------------------

  describe "FATCA CRUD" do
    test "create FATCA report as editor", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "FATCA Corp"})
      {:ok, view, _html} = live(conn, ~p"/compliance")

      view |> element(~s(button[phx-value-tab="fatca"])) |> render_click()
      view |> element("button", "Add") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_fatca"]), %{
          fatca_report: %{
            company_id: company.id,
            reporting_year: "2025",
            jurisdiction: "CA",
            report_type: "crs"
          }
        })
        |> render_submit()

      assert html =~ "Report added"
      assert html =~ "2025"
      assert html =~ "CA"
      refute html =~ "modal-overlay"
    end

    test "delete FATCA report as editor", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "Del FATCA Corp"})
      report = fatca_report_fixture(%{company: company, reporting_year: 2023, jurisdiction: "AU"})

      {:ok, view, _html} = live(conn, ~p"/compliance")

      view |> element(~s(button[phx-value-tab="fatca"])) |> render_click()

      html =
        view
        |> element(~s(button[phx-click="delete_fatca"][phx-value-id="#{report.id}"]))
        |> render_click()

      assert html =~ "Report deleted"
    end

    test "save_fatca is denied for non-editor", %{conn: conn} do
      company = company_fixture()
      {:ok, view, _html} = live(conn, ~p"/compliance")

      html =
        render_hook(view, "save_fatca", %{
          "fatca_report" => %{
            "company_id" => company.id,
            "reporting_year" => "2025",
            "jurisdiction" => "US"
          }
        })

      assert html =~ "You don&#39;t have permission to do that"
    end
  end

  # ------------------------------------------------------------------
  # Sanctions CRUD
  # ------------------------------------------------------------------

  describe "sanctions CRUD" do
    test "create sanctions check as editor", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "Sanctions Corp"})
      {:ok, view, _html} = live(conn, ~p"/compliance")

      view |> element(~s(button[phx-value-tab="sanctions"])) |> render_click()
      view |> element("button", "Add") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_sanctions"]), %{
          sanctions_check: %{
            company_id: company.id,
            checked_name: "Suspicious Entity LLC",
            notes: "Routine screening"
          }
        })
        |> render_submit()

      assert html =~ "Check added"
      assert html =~ "Suspicious Entity LLC"
      refute html =~ "modal-overlay"
    end

    test "delete sanctions check as editor", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "Del Sanctions Corp"})
      check = sanctions_check_fixture(%{company: company, checked_name: "Old Entity"})

      {:ok, view, _html} = live(conn, ~p"/compliance")

      view |> element(~s(button[phx-value-tab="sanctions"])) |> render_click()

      html =
        view
        |> element(~s(button[phx-click="delete_sanctions"][phx-value-id="#{check.id}"]))
        |> render_click()

      assert html =~ "Check deleted"
      refute html =~ "Old Entity"
    end

    test "edit sanctions check opens edit form", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "Edit Sanctions Corp"})
      check = sanctions_check_fixture(%{company: company, checked_name: "Review Entity"})

      {:ok, view, _html} = live(conn, ~p"/compliance")

      view |> element(~s(button[phx-value-tab="sanctions"])) |> render_click()

      html =
        view
        |> element(~s(button[phx-click="edit_sanctions"][phx-value-id="#{check.id}"]))
        |> render_click()

      assert html =~ "Edit Sanctions Check"
      assert html =~ "Review Entity"
    end

    test "update sanctions check saves changes", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "Update Sanctions Corp"})
      check = sanctions_check_fixture(%{company: company, checked_name: "Old Name"})

      {:ok, view, _html} = live(conn, ~p"/compliance")

      view |> element(~s(button[phx-value-tab="sanctions"])) |> render_click()

      view
      |> element(~s(button[phx-click="edit_sanctions"][phx-value-id="#{check.id}"]))
      |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="update_sanctions"]), %{
          sanctions_check: %{
            company_id: company.id,
            checked_name: "Updated Name",
            notes: "Updated notes"
          }
        })
        |> render_submit()

      assert html =~ "Check updated"
      assert html =~ "Updated Name"
    end

    test "save_sanctions is denied for non-editor", %{conn: conn} do
      company = company_fixture()
      {:ok, view, _html} = live(conn, ~p"/compliance")

      html =
        render_hook(view, "save_sanctions", %{
          "sanctions_check" => %{
            "company_id" => company.id,
            "checked_name" => "Test"
          }
        })

      assert html =~ "You don&#39;t have permission to do that"
    end

    test "delete_sanctions is denied for non-editor", %{conn: conn} do
      check = sanctions_check_fixture()
      {:ok, view, _html} = live(conn, ~p"/compliance")

      html = render_hook(view, "delete_sanctions", %{"id" => check.id})

      assert html =~ "You don&#39;t have permission to do that"
    end
  end

  # ------------------------------------------------------------------
  # ESG CRUD
  # ------------------------------------------------------------------

  describe "ESG CRUD" do
    test "create ESG score as editor", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "ESG Corp"})
      {:ok, view, _html} = live(conn, ~p"/compliance")

      view |> element(~s(button[phx-value-tab="esg"])) |> render_click()
      view |> element("button", "Add") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_esg"]), %{
          esg_score: %{
            company_id: company.id,
            period: "2025-Q2",
            environmental_score: "85",
            social_score: "72",
            governance_score: "90",
            overall_score: "82"
          }
        })
        |> render_submit()

      assert html =~ "Score added"
      assert html =~ "2025-Q2"
      refute html =~ "modal-overlay"
    end

    test "delete ESG score as editor", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "Del ESG Corp"})
      score = esg_score_fixture(%{company: company, period: "2024-Q4"})

      {:ok, view, _html} = live(conn, ~p"/compliance")

      view |> element(~s(button[phx-value-tab="esg"])) |> render_click()

      html =
        view
        |> element(~s(button[phx-click="delete_esg"][phx-value-id="#{score.id}"]))
        |> render_click()

      assert html =~ "Score deleted"
    end

    test "save_esg is denied for non-editor", %{conn: conn} do
      company = company_fixture()
      {:ok, view, _html} = live(conn, ~p"/compliance")

      html =
        render_hook(view, "save_esg", %{
          "esg_score" => %{
            "company_id" => company.id,
            "period" => "2025-Q1"
          }
        })

      assert html =~ "You don&#39;t have permission to do that"
    end
  end

  # ------------------------------------------------------------------
  # Licenses CRUD
  # ------------------------------------------------------------------

  describe "licenses CRUD" do
    test "create license as editor", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "License Corp"})
      {:ok, view, _html} = live(conn, ~p"/compliance")

      view |> element(~s(button[phx-value-tab="licenses"])) |> render_click()
      view |> element("button", "Add") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_license"]), %{
          regulatory_license: %{
            company_id: company.id,
            license_type: "money-transmitter",
            issuing_authority: "FinCEN",
            license_number: "MT-12345",
            expiry_date: "2027-03-31"
          }
        })
        |> render_submit()

      assert html =~ "License added"
      assert html =~ "money-transmitter"
      assert html =~ "FinCEN"
      refute html =~ "modal-overlay"
    end

    test "delete license as editor", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "Del License Corp"})
      license = regulatory_license_fixture(%{company: company, license_type: "banking", issuing_authority: "OCC"})

      {:ok, view, _html} = live(conn, ~p"/compliance")

      view |> element(~s(button[phx-value-tab="licenses"])) |> render_click()

      html =
        view
        |> element(~s(button[phx-click="delete_license"][phx-value-id="#{license.id}"]))
        |> render_click()

      assert html =~ "License deleted"
      refute html =~ "banking"
    end

    test "save_license is denied for non-editor", %{conn: conn} do
      company = company_fixture()
      {:ok, view, _html} = live(conn, ~p"/compliance")

      html =
        render_hook(view, "save_license", %{
          "regulatory_license" => %{
            "company_id" => company.id,
            "license_type" => "broker-dealer",
            "issuing_authority" => "SEC"
          }
        })

      assert html =~ "You don&#39;t have permission to do that"
    end

    test "delete_license is denied for non-editor", %{conn: conn} do
      license = regulatory_license_fixture()
      {:ok, view, _html} = live(conn, ~p"/compliance")

      html = render_hook(view, "delete_license", %{"id" => license.id})

      assert html =~ "You don&#39;t have permission to do that"
    end
  end

  # ------------------------------------------------------------------
  # Tab content rendering
  # ------------------------------------------------------------------

  describe "tab content rendering" do
    test "regulatory filings tab shows filing data in table", %{conn: conn} do
      company = company_fixture(%{name: "Table Filing Corp"})
      regulatory_filing_fixture(%{company: company, jurisdiction: "SG", filing_type: "Form C"})

      {:ok, _view, html} = live(conn, ~p"/compliance")

      assert html =~ "Regulatory Filings"
      assert html =~ "SG"
      assert html =~ "Form C"
      assert html =~ "Table Filing Corp"
    end

    test "insurance tab shows policy data in table", %{conn: conn} do
      company = company_fixture(%{name: "Table Ins Corp"})
      insurance_policy_fixture(%{company: company, policy_type: "Property", provider: "Zurich"})

      {:ok, view, _html} = live(conn, ~p"/compliance")

      html = view |> element(~s(button[phx-value-tab="insurance"])) |> render_click()

      assert html =~ "Insurance Policies"
      assert html =~ "Property"
      assert html =~ "Zurich"
      assert html =~ "Table Ins Corp"
    end

    test "sanctions tab shows check data in table", %{conn: conn} do
      company = company_fixture(%{name: "Table Sanc Corp"})
      sanctions_check_fixture(%{company: company, checked_name: "Acme Trading"})

      {:ok, view, _html} = live(conn, ~p"/compliance")

      html = view |> element(~s(button[phx-value-tab="sanctions"])) |> render_click()

      assert html =~ "Sanctions Checks"
      assert html =~ "Acme Trading"
      assert html =~ "Table Sanc Corp"
    end

    test "withholding tab shows tax data in table", %{conn: conn} do
      company = company_fixture(%{name: "Table WH Corp"})

      withholding_tax_fixture(%{
        company: company,
        payment_type: "service_fee",
        country_from: "SG",
        country_to: "IN"
      })

      {:ok, view, _html} = live(conn, ~p"/compliance")

      html = view |> element(~s(button[phx-value-tab="withholding"])) |> render_click()

      assert html =~ "Withholding Taxes"
      assert html =~ "service_fee"
      assert html =~ "SG"
      assert html =~ "IN"
      assert html =~ "Table WH Corp"
    end

    test "FATCA tab shows report data in table", %{conn: conn} do
      company = company_fixture(%{name: "Table FATCA Corp"})
      fatca_report_fixture(%{company: company, reporting_year: 2024, jurisdiction: "LU"})

      {:ok, view, _html} = live(conn, ~p"/compliance")

      html = view |> element(~s(button[phx-value-tab="fatca"])) |> render_click()

      assert html =~ "FATCA Reports"
      assert html =~ "2024"
      assert html =~ "LU"
      assert html =~ "Table FATCA Corp"
    end

    test "ESG tab shows score data in table", %{conn: conn} do
      company = company_fixture(%{name: "Table ESG Corp"})
      esg_score_fixture(%{company: company, period: "2024-Q3"})

      {:ok, view, _html} = live(conn, ~p"/compliance")

      html = view |> element(~s(button[phx-value-tab="esg"])) |> render_click()

      assert html =~ "ESG Scores"
      assert html =~ "2024-Q3"
      assert html =~ "Table ESG Corp"
    end

    test "licenses tab shows license data in table", %{conn: conn} do
      company = company_fixture(%{name: "Table Lic Corp"})
      regulatory_license_fixture(%{company: company, license_type: "fund-manager", issuing_authority: "MAS"})

      {:ok, view, _html} = live(conn, ~p"/compliance")

      html = view |> element(~s(button[phx-value-tab="licenses"])) |> render_click()

      assert html =~ "Regulatory Licenses"
      assert html =~ "fund-manager"
      assert html =~ "MAS"
      assert html =~ "Table Lic Corp"
    end
  end

  # ------------------------------------------------------------------
  # Edit/Update FATCA
  # ------------------------------------------------------------------

  describe "FATCA edit/update" do
    test "edit FATCA report opens edit form", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "Edit FATCA Corp"})
      report = fatca_report_fixture(%{company: company, reporting_year: 2024, jurisdiction: "SG"})

      {:ok, view, _html} = live(conn, ~p"/compliance")
      view |> element(~s(button[phx-value-tab="fatca"])) |> render_click()

      html =
        view
        |> element(~s(button[phx-click="edit_fatca"][phx-value-id="#{report.id}"]))
        |> render_click()

      assert html =~ "Edit FATCA Report"
      assert html =~ "2024"
    end

    test "update FATCA report saves changes", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "Update FATCA Corp"})
      report = fatca_report_fixture(%{company: company, reporting_year: 2024, jurisdiction: "SG"})

      {:ok, view, _html} = live(conn, ~p"/compliance")
      view |> element(~s(button[phx-value-tab="fatca"])) |> render_click()

      view
      |> element(~s(button[phx-click="edit_fatca"][phx-value-id="#{report.id}"]))
      |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="update_fatca"]), %{
          fatca_report: %{
            company_id: company.id,
            reporting_year: "2025",
            jurisdiction: "NZ"
          }
        })
        |> render_submit()

      assert html =~ "Report updated"
      assert html =~ "NZ"
    end

    test "delete_fatca is denied for non-editor", %{conn: conn} do
      report = fatca_report_fixture()
      {:ok, view, _html} = live(conn, ~p"/compliance")

      html = render_hook(view, "delete_fatca", %{"id" => report.id})
      assert html =~ "You don&#39;t have permission to do that"
    end

    test "update_fatca is denied for non-editor", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")

      html =
        render_hook(view, "update_fatca", %{
          "fatca_report" => %{
            "reporting_year" => "2025",
            "jurisdiction" => "US"
          }
        })

      assert html =~ "You don&#39;t have permission to do that"
    end
  end

  # ------------------------------------------------------------------
  # Edit/Update ESG
  # ------------------------------------------------------------------

  describe "ESG edit/update" do
    test "edit ESG score opens edit form", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "Edit ESG Corp"})
      score = esg_score_fixture(%{company: company, period: "2024-Q2"})

      {:ok, view, _html} = live(conn, ~p"/compliance")
      view |> element(~s(button[phx-value-tab="esg"])) |> render_click()

      html =
        view
        |> element(~s(button[phx-click="edit_esg"][phx-value-id="#{score.id}"]))
        |> render_click()

      assert html =~ "Edit ESG Score"
      assert html =~ "2024-Q2"
    end

    test "update ESG score saves changes", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "Update ESG Corp"})
      score = esg_score_fixture(%{company: company, period: "2024-Q2"})

      {:ok, view, _html} = live(conn, ~p"/compliance")
      view |> element(~s(button[phx-value-tab="esg"])) |> render_click()

      view
      |> element(~s(button[phx-click="edit_esg"][phx-value-id="#{score.id}"]))
      |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="update_esg"]), %{
          esg_score: %{
            company_id: company.id,
            period: "2025-Q1",
            environmental_score: "90",
            social_score: "80",
            governance_score: "85",
            overall_score: "85"
          }
        })
        |> render_submit()

      assert html =~ "Score updated"
      assert html =~ "2025-Q1"
    end

    test "delete_esg is denied for non-editor", %{conn: conn} do
      score = esg_score_fixture()
      {:ok, view, _html} = live(conn, ~p"/compliance")

      html = render_hook(view, "delete_esg", %{"id" => score.id})
      assert html =~ "You don&#39;t have permission to do that"
    end

    test "update_esg is denied for non-editor", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")

      html =
        render_hook(view, "update_esg", %{
          "esg_score" => %{
            "period" => "2025-Q1"
          }
        })

      assert html =~ "You don&#39;t have permission to do that"
    end
  end

  # ------------------------------------------------------------------
  # Edit/Update Licenses
  # ------------------------------------------------------------------

  describe "licenses edit/update" do
    test "edit license opens edit form", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "Edit License Corp"})
      license = regulatory_license_fixture(%{company: company, license_type: "broker", issuing_authority: "SEC"})

      {:ok, view, _html} = live(conn, ~p"/compliance")
      view |> element(~s(button[phx-value-tab="licenses"])) |> render_click()

      html =
        view
        |> element(~s(button[phx-click="edit_license"][phx-value-id="#{license.id}"]))
        |> render_click()

      assert html =~ "Edit Regulatory License"
      assert html =~ "broker"
    end

    test "update license saves changes", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "Update License Corp"})
      license = regulatory_license_fixture(%{company: company, license_type: "broker", issuing_authority: "SEC"})

      {:ok, view, _html} = live(conn, ~p"/compliance")
      view |> element(~s(button[phx-value-tab="licenses"])) |> render_click()

      view
      |> element(~s(button[phx-click="edit_license"][phx-value-id="#{license.id}"]))
      |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="update_license"]), %{
          regulatory_license: %{
            company_id: company.id,
            license_type: "investment-advisor",
            issuing_authority: "FINRA"
          }
        })
        |> render_submit()

      assert html =~ "License updated"
      assert html =~ "investment-advisor"
      assert html =~ "FINRA"
    end

    test "update_license is denied for non-editor", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")

      html =
        render_hook(view, "update_license", %{
          "regulatory_license" => %{
            "license_type" => "broker",
            "issuing_authority" => "SEC"
          }
        })

      assert html =~ "You don&#39;t have permission to do that"
    end
  end

  # ------------------------------------------------------------------
  # Additional viewer permission guards
  # ------------------------------------------------------------------

  describe "additional viewer permission guards" do
    test "update_insurance is denied for non-editor", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")

      html =
        render_hook(view, "update_insurance", %{
          "insurance_policy" => %{
            "policy_type" => "D&O",
            "provider" => "Test"
          }
        })

      assert html =~ "You don&#39;t have permission to do that"
    end

    test "update_sanctions is denied for non-editor", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")

      html =
        render_hook(view, "update_sanctions", %{
          "sanctions_check" => %{
            "checked_name" => "Test"
          }
        })

      assert html =~ "You don&#39;t have permission to do that"
    end

    test "delete_sanctions is denied for non-editor via hook", %{conn: conn} do
      check = sanctions_check_fixture()
      {:ok, view, _html} = live(conn, ~p"/compliance")

      html = render_hook(view, "delete_sanctions", %{"id" => check.id})
      assert html =~ "You don&#39;t have permission to do that"
    end
  end

  # ------------------------------------------------------------------
  # Error paths for create/update operations
  # ------------------------------------------------------------------

  describe "create error paths" do
    test "save_filing with invalid data shows error", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/compliance")
      view |> element("button", "Add") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_filing"]), %{
          regulatory_filing: %{jurisdiction: "", filing_type: ""}
        })
        |> render_submit()

      assert html =~ "Failed to add filing"
    end

    test "save_license with invalid data shows error", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/compliance")
      view |> element(~s(button[phx-value-tab="licenses"])) |> render_click()
      view |> element("button", "Add") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_license"]), %{
          regulatory_license: %{license_type: "", issuing_authority: ""}
        })
        |> render_submit()

      assert html =~ "Failed to add license"
    end

    test "save_insurance with invalid data shows error", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/compliance")
      view |> element(~s(button[phx-value-tab="insurance"])) |> render_click()
      view |> element("button", "Add") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_insurance"]), %{
          insurance_policy: %{policy_type: "", provider: ""}
        })
        |> render_submit()

      assert html =~ "Failed to add policy"
    end

    test "save_sanctions with invalid data shows error", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/compliance")
      view |> element(~s(button[phx-value-tab="sanctions"])) |> render_click()
      view |> element("button", "Add") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_sanctions"]), %{
          sanctions_check: %{checked_name: ""}
        })
        |> render_submit()

      assert html =~ "Failed to add check"
    end

    test "save_esg with invalid data shows error", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/compliance")
      view |> element(~s(button[phx-value-tab="esg"])) |> render_click()
      view |> element("button", "Add") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_esg"]), %{
          esg_score: %{period: ""}
        })
        |> render_submit()

      assert html =~ "Failed to add score"
    end

    test "save_fatca with invalid data shows error", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/compliance")
      view |> element(~s(button[phx-value-tab="fatca"])) |> render_click()
      view |> element("button", "Add") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_fatca"]), %{
          fatca_report: %{reporting_year: ""}
        })
        |> render_submit()

      assert html =~ "Failed to add report"
    end

    test "save_withholding with invalid data shows error", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/compliance")
      view |> element(~s(button[phx-value-tab="withholding"])) |> render_click()
      view |> element("button", "Add") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_withholding"]), %{
          withholding_tax: %{payment_type: ""}
        })
        |> render_submit()

      assert html =~ "Failed to add tax entry"
    end
  end

  describe "update error paths" do
    test "update_filing with invalid data shows error", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "ErrUpdateFilingCo"})
      filing = regulatory_filing_fixture(%{company: company, jurisdiction: "US", filing_type: "10-K"})

      {:ok, view, _html} = live(conn, ~p"/compliance")
      view |> element(~s(button[phx-click="edit_filing"][phx-value-id="#{filing.id}"])) |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="update_filing"]), %{
          regulatory_filing: %{jurisdiction: "", filing_type: ""}
        })
        |> render_submit()

      assert html =~ "Failed to update filing"
    end

    test "update_license with invalid data shows error", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "ErrUpdateLicCo"})
      license = regulatory_license_fixture(%{company: company, license_type: "broker", issuing_authority: "SEC"})

      {:ok, view, _html} = live(conn, ~p"/compliance")
      view |> element(~s(button[phx-value-tab="licenses"])) |> render_click()
      view |> element(~s(button[phx-click="edit_license"][phx-value-id="#{license.id}"])) |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="update_license"]), %{
          regulatory_license: %{license_type: "", issuing_authority: ""}
        })
        |> render_submit()

      assert html =~ "Failed to update license"
    end

    test "update_insurance with invalid data shows error", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "ErrUpdateInsCo"})
      policy = insurance_policy_fixture(%{company: company, policy_type: "D&O", provider: "Chubb"})

      {:ok, view, _html} = live(conn, ~p"/compliance")
      view |> element(~s(button[phx-value-tab="insurance"])) |> render_click()
      view |> element(~s(button[phx-click="edit_insurance"][phx-value-id="#{policy.id}"])) |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="update_insurance"]), %{
          insurance_policy: %{policy_type: "", provider: ""}
        })
        |> render_submit()

      assert html =~ "Failed to update policy"
    end

    test "update_sanctions with invalid data shows error", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "ErrUpdateSancCo"})
      check = sanctions_check_fixture(%{company: company, checked_name: "Entity"})

      {:ok, view, _html} = live(conn, ~p"/compliance")
      view |> element(~s(button[phx-value-tab="sanctions"])) |> render_click()
      view |> element(~s(button[phx-click="edit_sanctions"][phx-value-id="#{check.id}"])) |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="update_sanctions"]), %{
          sanctions_check: %{checked_name: ""}
        })
        |> render_submit()

      assert html =~ "Failed to update check"
    end

    test "update_esg with invalid data shows error", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "ErrUpdateESGCo"})
      score = esg_score_fixture(%{company: company, period: "2024-Q2"})

      {:ok, view, _html} = live(conn, ~p"/compliance")
      view |> element(~s(button[phx-value-tab="esg"])) |> render_click()
      view |> element(~s(button[phx-click="edit_esg"][phx-value-id="#{score.id}"])) |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="update_esg"]), %{
          esg_score: %{period: ""}
        })
        |> render_submit()

      assert html =~ "Failed to update score"
    end

    test "update_fatca with invalid data shows error", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "ErrUpdateFATCACo"})
      report = fatca_report_fixture(%{company: company, reporting_year: 2024, jurisdiction: "SG"})

      {:ok, view, _html} = live(conn, ~p"/compliance")
      view |> element(~s(button[phx-value-tab="fatca"])) |> render_click()
      view |> element(~s(button[phx-click="edit_fatca"][phx-value-id="#{report.id}"])) |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="update_fatca"]), %{
          fatca_report: %{reporting_year: ""}
        })
        |> render_submit()

      assert html =~ "Failed to update report"
    end

    test "update_withholding with invalid data shows error", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "ErrUpdateWHCo"})
      wt = withholding_tax_fixture(%{company: company, payment_type: "dividend", country_from: "US", country_to: "UK"})

      {:ok, view, _html} = live(conn, ~p"/compliance")
      view |> element(~s(button[phx-value-tab="withholding"])) |> render_click()
      view |> element(~s(button[phx-click="edit_withholding"][phx-value-id="#{wt.id}"])) |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="update_withholding"]), %{
          withholding_tax: %{payment_type: ""}
        })
        |> render_submit()

      assert html =~ "Failed to update tax entry"
    end
  end

  # ------------------------------------------------------------------
  # Empty state rendering
  # ------------------------------------------------------------------

  describe "empty state rendering" do
    test "regulatory filings shows empty state when no records exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/compliance")

      assert html =~ "No regulatory filings yet."
    end

    test "insurance shows empty state when no records exist", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")

      html = view |> element(~s(button[phx-value-tab="insurance"])) |> render_click()

      assert html =~ "No insurance policies yet."
    end

    test "withholding shows empty state when no records exist", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")

      html = view |> element(~s(button[phx-value-tab="withholding"])) |> render_click()

      assert html =~ "No withholding taxes yet."
    end

    test "editor sees create-first button in empty state", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, _view, html} = live(conn, ~p"/compliance")

      assert html =~ "Create first filing"
    end

    test "non-editor does not see create-first button", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/compliance")

      refute html =~ "Create first filing"
    end
  end
end
