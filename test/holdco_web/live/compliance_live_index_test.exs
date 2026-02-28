defmodule HoldcoWeb.ComplianceLiveIndexTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  # ── Mount & Render ──────────────────────────────────────

  describe "mount and render" do
    test "renders page title and deck", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/compliance")

      assert html =~ "<h1>Compliance</h1>"
      assert html =~ "Regulatory filings, licenses, insurance, sanctions, ESG, FATCA, and withholding taxes"
      assert html =~ "page-title-rule"
    end

    test "renders all tab buttons with correct labels", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/compliance")

      assert html =~ "Filings"
      assert html =~ "Licenses"
      assert html =~ "Insurance"
      assert html =~ "Sanctions"
      assert html =~ "ESG"
      assert html =~ "FATCA"
      assert html =~ "Withholding"
    end

    test "defaults to regulatory_filings tab", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/compliance")

      assert html =~ "Regulatory Filings"
      assert html =~ "Jurisdiction"
      assert html =~ "Type"
    end

    test "renders regulatory filing data", %{conn: conn} do
      company = company_fixture(%{name: "TestCo"})
      regulatory_filing_fixture(%{company_id: company.id, jurisdiction: "Cayman", filing_type: "10-K"})

      {:ok, _view, html} = live(conn, ~p"/compliance")

      assert html =~ "Cayman"
      assert html =~ "10-K"
      assert html =~ "TestCo"
    end

    test "viewer cannot see Add button", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/compliance")

      refute html =~ "phx-click=\"show_form\""
    end

    test "editor sees Add button on regulatory filings tab", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, _view, html} = live(conn, ~p"/compliance")

      assert html =~ "phx-click=\"show_form\""
    end
  end

  # ── Tab Switching ───────────────────────────────────────

  describe "switch_tab event" do
    test "switches to licenses tab and renders correct content", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")

      html = view |> element(~s(button[phx-value-tab="licenses"])) |> render_click()

      assert html =~ "Regulatory Licenses"
      assert html =~ "Authority"
    end

    test "switches to insurance tab", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")

      html = view |> element(~s(button[phx-value-tab="insurance"])) |> render_click()

      assert html =~ "Insurance Policies"
      assert html =~ "Provider"
      assert html =~ "Coverage"
    end

    test "switches to sanctions tab", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")

      html = view |> element(~s(button[phx-value-tab="sanctions"])) |> render_click()

      assert html =~ "Sanctions Checks"
      assert html =~ "Name Checked"
    end

    test "switches to esg tab", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")

      html = view |> element(~s(button[phx-value-tab="esg"])) |> render_click()

      assert html =~ "ESG Scores"
      assert html =~ "Framework"
    end

    test "switches to fatca tab", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")

      html = view |> element(~s(button[phx-value-tab="fatca"])) |> render_click()

      assert html =~ "FATCA Reports"
      assert html =~ "Year"
    end

    test "switches to withholding tab", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")

      html = view |> element(~s(button[phx-value-tab="withholding"])) |> render_click()

      assert html =~ "Withholding Taxes"
      assert html =~ "Payment Type"
    end

    test "switching tabs closes the form", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/compliance")

      view |> element("button", "Add") |> render_click()
      assert render(view) =~ "dialog-overlay"

      html = view |> element(~s(button[phx-value-tab="licenses"])) |> render_click()
      refute html =~ "dialog-overlay"
    end
  end

  # ── Show/Close Form ─────────────────────────────────────

  describe "show_form and close_form events" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "show_form opens modal on regulatory filings tab", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")

      html = view |> element("button", "Add") |> render_click()

      assert html =~ "dialog-overlay"
      assert html =~ "Add Regulatory Filing"
      assert html =~ ~s(phx-submit="save_filing")
    end

    test "close_form via Cancel button closes modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")

      view |> element("button", "Add") |> render_click()
      html = view |> element(~s(button[phx-click="close_form"]), "Cancel") |> render_click()

      refute html =~ "dialog-overlay"
    end

    test "close_form via overlay click closes modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")

      view |> element("button", "Add") |> render_click()
      html = view |> element(".dialog-overlay") |> render_click()

      refute html =~ "dialog-overlay"
    end

    test "show_form on licenses tab shows license form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")

      view |> element(~s(button[phx-value-tab="licenses"])) |> render_click()
      html = view |> element("button", "Add") |> render_click()

      assert html =~ "Add Regulatory License"
      assert html =~ ~s(phx-submit="save_license")
    end

    test "show_form on insurance tab shows insurance form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")

      view |> element(~s(button[phx-value-tab="insurance"])) |> render_click()
      html = view |> element("button", "Add") |> render_click()

      assert html =~ "Add Insurance Policy"
      assert html =~ ~s(phx-submit="save_insurance")
    end

    test "show_form on sanctions tab shows sanctions form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")

      view |> element(~s(button[phx-value-tab="sanctions"])) |> render_click()
      html = view |> element("button", "Add") |> render_click()

      assert html =~ "Run Sanctions Check"
      assert html =~ ~s(phx-submit="save_sanctions")
    end

    test "show_form on esg tab shows esg form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")

      view |> element(~s(button[phx-value-tab="esg"])) |> render_click()
      html = view |> element("button", "Add") |> render_click()

      assert html =~ "Add ESG Score"
      assert html =~ ~s(phx-submit="save_esg")
    end

    test "show_form on fatca tab shows fatca form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")

      view |> element(~s(button[phx-value-tab="fatca"])) |> render_click()
      html = view |> element("button", "Add") |> render_click()

      assert html =~ "Add FATCA Report"
      assert html =~ ~s(phx-submit="save_fatca")
    end

    test "show_form on withholding tab shows withholding form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")

      view |> element(~s(button[phx-value-tab="withholding"])) |> render_click()
      html = view |> element("button", "Add") |> render_click()

      assert html =~ "Add Withholding Tax"
      assert html =~ ~s(phx-submit="save_withholding")
    end
  end

  # ── Save Filing ─────────────────────────────────────────

  describe "save_filing event" do
    test "creates a regulatory filing and shows flash", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "FilingCo"})
      {:ok, view, _html} = live(conn, ~p"/compliance")

      view |> element("button", "Add") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_filing"]), %{
          "regulatory_filing" => %{
            "company_id" => company.id,
            "jurisdiction" => "Delaware",
            "filing_type" => "10-Q",
            "due_date" => "2025-06-30"
          }
        })
        |> render_submit()

      assert html =~ "Filing added"
      assert html =~ "Delaware"
      assert html =~ "10-Q"
      refute html =~ "dialog-overlay"
    end

    test "viewer cannot save a filing", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")

      render_hook(view, "save_filing", %{
        "regulatory_filing" => %{"jurisdiction" => "US", "filing_type" => "10-K", "due_date" => "2025-01-01"}
      })

      assert render(view) =~ "permission"
    end
  end

  # ── Delete Filing ───────────────────────────────────────

  describe "delete_filing event" do
    test "deletes a regulatory filing", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "DelFilingCo"})
      rf = regulatory_filing_fixture(%{company_id: company.id, jurisdiction: "BVI"})

      {:ok, view, html} = live(conn, ~p"/compliance")
      assert html =~ "BVI"

      view |> element(~s(button[phx-click="delete_filing"][phx-value-id="#{rf.id}"])) |> render_click()

      html = render(view)
      assert html =~ "Filing deleted"
      refute html =~ "BVI"
    end
  end

  # ── Save/Delete License ─────────────────────────────────

  describe "save_license event" do
    test "creates a license and shows flash", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "LicenseCo"})
      {:ok, view, _html} = live(conn, ~p"/compliance")

      view |> element(~s(button[phx-value-tab="licenses"])) |> render_click()
      view |> element("button", "Add") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_license"]), %{
          "regulatory_license" => %{
            "company_id" => company.id,
            "license_type" => "MFD",
            "issuing_authority" => "FINRA"
          }
        })
        |> render_submit()

      assert html =~ "License added"
      assert html =~ "MFD"
      assert html =~ "FINRA"
    end
  end

  describe "delete_license event" do
    test "deletes a license", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()
      rl = regulatory_license_fixture(%{company_id: company.id, license_type: "TestLicense"})

      {:ok, view, _html} = live(conn, ~p"/compliance")
      view |> element(~s(button[phx-value-tab="licenses"])) |> render_click()

      view |> element(~s(button[phx-click="delete_license"][phx-value-id="#{rl.id}"])) |> render_click()

      html = render(view)
      assert html =~ "License deleted"
    end
  end

  # ── Save/Delete Insurance ───────────────────────────────

  describe "save_insurance event" do
    test "creates an insurance policy", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "InsureCo"})
      {:ok, view, _html} = live(conn, ~p"/compliance")

      view |> element(~s(button[phx-value-tab="insurance"])) |> render_click()
      view |> element("button", "Add") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_insurance"]), %{
          "insurance_policy" => %{
            "company_id" => company.id,
            "policy_type" => "D&O",
            "provider" => "Allianz"
          }
        })
        |> render_submit()

      assert html =~ "Policy added"
    end
  end

  describe "delete_insurance event" do
    test "deletes an insurance policy", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()
      ip = insurance_policy_fixture(%{company_id: company.id, policy_type: "Cyber"})

      {:ok, view, _html} = live(conn, ~p"/compliance")
      view |> element(~s(button[phx-value-tab="insurance"])) |> render_click()

      view |> element(~s(button[phx-click="delete_insurance"][phx-value-id="#{ip.id}"])) |> render_click()

      assert render(view) =~ "Policy deleted"
    end
  end

  # ── Save/Delete Sanctions ───────────────────────────────

  describe "save_sanctions event" do
    test "creates a sanctions check", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "SanctionsCo"})
      {:ok, view, _html} = live(conn, ~p"/compliance")

      view |> element(~s(button[phx-value-tab="sanctions"])) |> render_click()
      view |> element("button", "Add") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_sanctions"]), %{
          "sanctions_check" => %{
            "company_id" => company.id,
            "checked_name" => "John Doe"
          }
        })
        |> render_submit()

      assert html =~ "Check added"
      assert html =~ "John Doe"
    end
  end

  describe "delete_sanctions event" do
    test "deletes a sanctions check", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()
      sc = sanctions_check_fixture(%{company_id: company.id, checked_name: "Sanctioned Entity"})

      {:ok, view, _html} = live(conn, ~p"/compliance")
      view |> element(~s(button[phx-value-tab="sanctions"])) |> render_click()

      view |> element(~s(button[phx-click="delete_sanctions"][phx-value-id="#{sc.id}"])) |> render_click()

      assert render(view) =~ "Check deleted"
    end
  end

  # ── Save/Delete ESG ─────────────────────────────────────

  describe "save_esg event" do
    test "creates an ESG score", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "ESGCo"})
      {:ok, view, _html} = live(conn, ~p"/compliance")

      view |> element(~s(button[phx-value-tab="esg"])) |> render_click()
      view |> element("button", "Add") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_esg"]), %{
          "esg_score" => %{
            "company_id" => company.id,
            "period" => "2025-Q1"
          }
        })
        |> render_submit()

      assert html =~ "Score added"
      assert html =~ "2025-Q1"
    end
  end

  describe "delete_esg event" do
    test "deletes an ESG score", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()
      esg = esg_score_fixture(%{company_id: company.id, period: "2024-Q4"})

      {:ok, view, _html} = live(conn, ~p"/compliance")
      view |> element(~s(button[phx-value-tab="esg"])) |> render_click()

      view |> element(~s(button[phx-click="delete_esg"][phx-value-id="#{esg.id}"])) |> render_click()

      assert render(view) =~ "Score deleted"
    end
  end

  # ── Save/Delete FATCA ───────────────────────────────────

  describe "save_fatca event" do
    test "creates a FATCA report", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "FATCACo"})
      {:ok, view, _html} = live(conn, ~p"/compliance")

      view |> element(~s(button[phx-value-tab="fatca"])) |> render_click()
      view |> element("button", "Add") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_fatca"]), %{
          "fatca_report" => %{
            "company_id" => company.id,
            "reporting_year" => "2025",
            "jurisdiction" => "Switzerland"
          }
        })
        |> render_submit()

      assert html =~ "Report added"
      assert html =~ "Switzerland"
    end
  end

  describe "delete_fatca event" do
    test "deletes a FATCA report", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()
      fr = fatca_report_fixture(%{company_id: company.id, jurisdiction: "Bermuda"})

      {:ok, view, _html} = live(conn, ~p"/compliance")
      view |> element(~s(button[phx-value-tab="fatca"])) |> render_click()

      view |> element(~s(button[phx-click="delete_fatca"][phx-value-id="#{fr.id}"])) |> render_click()

      assert render(view) =~ "Report deleted"
    end
  end

  # ── Save/Delete Withholding ─────────────────────────────

  describe "save_withholding event" do
    test "creates a withholding tax entry", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "WithholdCo"})
      {:ok, view, _html} = live(conn, ~p"/compliance")

      view |> element(~s(button[phx-value-tab="withholding"])) |> render_click()
      view |> element("button", "Add") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_withholding"]), %{
          "withholding_tax" => %{
            "company_id" => company.id,
            "payment_type" => "interest",
            "country_from" => "US",
            "country_to" => "UK",
            "gross_amount" => "50000",
            "rate" => "0.15",
            "tax_amount" => "7500",
            "date" => "2025-03-15"
          }
        })
        |> render_submit()

      assert html =~ "Tax entry added"
      assert html =~ "interest"
    end
  end

  describe "delete_withholding event" do
    test "deletes a withholding tax entry", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()
      wt = withholding_tax_fixture(%{company_id: company.id, payment_type: "royalty"})

      {:ok, view, _html} = live(conn, ~p"/compliance")
      view |> element(~s(button[phx-value-tab="withholding"])) |> render_click()

      view |> element(~s(button[phx-click="delete_withholding"][phx-value-id="#{wt.id}"])) |> render_click()

      assert render(view) =~ "Tax entry deleted"
    end
  end

  # ── Permission Guards ───────────────────────────────────

  describe "permission guards for viewer role" do
    test "save_filing is blocked for viewers", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")

      render_hook(view, "save_filing", %{"regulatory_filing" => %{"jurisdiction" => "US"}})
      assert render(view) =~ "permission"
    end

    test "delete_filing is blocked for viewers", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")

      render_hook(view, "delete_filing", %{"id" => "1"})
      assert render(view) =~ "permission"
    end

    test "save_license is blocked for viewers", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")

      render_hook(view, "save_license", %{"regulatory_license" => %{"license_type" => "x"}})
      assert render(view) =~ "permission"
    end

    test "save_sanctions is blocked for viewers", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")

      render_hook(view, "save_sanctions", %{"sanctions_check" => %{"checked_name" => "x"}})
      assert render(view) =~ "permission"
    end

    test "save_esg is blocked for viewers", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")

      render_hook(view, "save_esg", %{"esg_score" => %{"period" => "2025"}})
      assert render(view) =~ "permission"
    end

    test "save_fatca is blocked for viewers", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")

      render_hook(view, "save_fatca", %{"fatca_report" => %{"reporting_year" => "2025"}})
      assert render(view) =~ "permission"
    end

    test "save_withholding is blocked for viewers", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")

      render_hook(view, "save_withholding", %{"withholding_tax" => %{"payment_type" => "x"}})
      assert render(view) =~ "permission"
    end
  end

  # ── Noop event ──────────────────────────────────────────

  describe "noop event" do
    test "noop does not change the page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")

      render_hook(view, "noop", %{})

      assert render(view) =~ "Compliance"
    end
  end

  # ── Additional permission guards ──────────────────────

  describe "additional viewer permission guards" do
    test "delete_license is blocked for viewers", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")
      render_hook(view, "delete_license", %{"id" => "1"})
      assert render(view) =~ "permission"
    end

    test "delete_insurance is blocked for viewers", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")
      render_hook(view, "delete_insurance", %{"id" => "1"})
      assert render(view) =~ "permission"
    end

    test "delete_sanctions is blocked for viewers", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")
      render_hook(view, "delete_sanctions", %{"id" => "1"})
      assert render(view) =~ "permission"
    end

    test "delete_esg is blocked for viewers", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")
      render_hook(view, "delete_esg", %{"id" => "1"})
      assert render(view) =~ "permission"
    end

    test "delete_fatca is blocked for viewers", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")
      render_hook(view, "delete_fatca", %{"id" => "1"})
      assert render(view) =~ "permission"
    end

    test "delete_withholding is blocked for viewers", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")
      render_hook(view, "delete_withholding", %{"id" => "1"})
      assert render(view) =~ "permission"
    end

    test "save_insurance is blocked for viewers", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")
      render_hook(view, "save_insurance", %{"insurance_policy" => %{"policy_type" => "x"}})
      assert render(view) =~ "permission"
    end
  end

  # ── Data display on other tabs ────────────────────────

  describe "data display on licenses tab" do
    test "shows license data", %{conn: conn} do
      company = company_fixture(%{name: "LicDisplayCo"})
      regulatory_license_fixture(%{company_id: company.id, license_type: "Banking", issuing_authority: "OCC"})

      {:ok, view, _html} = live(conn, ~p"/compliance")
      html = view |> element(~s(button[phx-value-tab="licenses"])) |> render_click()

      assert html =~ "Banking"
      assert html =~ "OCC"
      assert html =~ "LicDisplayCo"
    end
  end

  describe "data display on insurance tab" do
    test "shows insurance policy data", %{conn: conn} do
      company = company_fixture(%{name: "InsDisplayCo"})
      insurance_policy_fixture(%{company_id: company.id, policy_type: "Directors", provider: "AIG"})

      {:ok, view, _html} = live(conn, ~p"/compliance")
      html = view |> element(~s(button[phx-value-tab="insurance"])) |> render_click()

      assert html =~ "Directors"
      assert html =~ "AIG"
      assert html =~ "InsDisplayCo"
    end
  end

  describe "data display on sanctions tab" do
    test "shows sanctions check data", %{conn: conn} do
      company = company_fixture(%{name: "SancDisplayCo"})
      sanctions_check_fixture(%{company_id: company.id, checked_name: "Some Person", status: "clear"})

      {:ok, view, _html} = live(conn, ~p"/compliance")
      html = view |> element(~s(button[phx-value-tab="sanctions"])) |> render_click()

      assert html =~ "Some Person"
      assert html =~ "clear"
      assert html =~ "tag-jade"
    end
  end

  describe "data display on esg tab" do
    test "shows ESG score data", %{conn: conn} do
      company = company_fixture(%{name: "ESGDisplayCo"})
      esg_score_fixture(%{company_id: company.id, period: "2025-Q2", environmental_score: 80.0, social_score: 75.0, governance_score: 90.0})

      {:ok, view, _html} = live(conn, ~p"/compliance")
      html = view |> element(~s(button[phx-value-tab="esg"])) |> render_click()

      assert html =~ "2025-Q2"
      assert html =~ "80"
      assert html =~ "75"
      assert html =~ "90"
    end
  end

  describe "data display on fatca tab" do
    test "shows FATCA report data", %{conn: conn} do
      company = company_fixture(%{name: "FATCADisplayCo"})
      fatca_report_fixture(%{company_id: company.id, reporting_year: 2025, jurisdiction: "Luxembourg"})

      {:ok, view, _html} = live(conn, ~p"/compliance")
      html = view |> element(~s(button[phx-value-tab="fatca"])) |> render_click()

      assert html =~ "2025"
      assert html =~ "Luxembourg"
      assert html =~ "FATCADisplayCo"
    end
  end

  describe "data display on withholding tab" do
    test "shows withholding tax data", %{conn: conn} do
      company = company_fixture(%{name: "WHDisplayCo"})
      withholding_tax_fixture(%{company_id: company.id, payment_type: "dividend", country_from: "DE", country_to: "US"})

      {:ok, view, _html} = live(conn, ~p"/compliance")
      html = view |> element(~s(button[phx-value-tab="withholding"])) |> render_click()

      assert html =~ "dividend"
      assert html =~ "DE"
      assert html =~ "US"
      assert html =~ "WHDisplayCo"
    end
  end
end
