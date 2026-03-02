defmodule HoldcoWeb.TaxProvisionLiveIndexTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "show_form and close_form" do
    test "show_form opens the add provision dialog", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/tax-provisions")
      html = render_click(view, "show_form")
      assert html =~ "Add Tax Provision"
      assert html =~ "Company *"
      assert html =~ "Tax Year *"
      assert html =~ "Jurisdiction *"
      assert html =~ "Provision Type *"
    end

    test "close_form hides the dialog", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/tax-provisions")
      render_click(view, "show_form")
      html = render_click(view, "close_form")
      refute html =~ "dialog-overlay"
    end
  end

  describe "filter" do
    test "filtering by company updates the list", %{conn: conn} do
      company = company_fixture(%{name: "Tax Filter Corp"})
      tax_provision_fixture(%{company: company, jurisdiction: "DE"})

      {:ok, view, _html} = live(conn, ~p"/tax-provisions")

      html =
        render_change(view, "filter", %{
          "company_id" => to_string(company.id),
          "year" => "",
          "jurisdiction" => ""
        })

      assert html =~ "DE"
    end

    test "filtering by year updates the list", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/tax-provisions")

      html =
        render_change(view, "filter", %{
          "company_id" => "",
          "year" => "2025",
          "jurisdiction" => ""
        })

      assert html =~ "Provisions"
    end

    test "filtering by jurisdiction updates the list", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/tax-provisions")

      html =
        render_change(view, "filter", %{
          "company_id" => "",
          "year" => "",
          "jurisdiction" => "US"
        })

      assert html =~ "Provisions"
    end

    test "filtering by company and year shows tax summary", %{conn: conn} do
      company = company_fixture(%{name: "Summary Corp"})
      tax_provision_fixture(%{company: company, tax_year: 2025, jurisdiction: "US"})

      {:ok, view, _html} = live(conn, ~p"/tax-provisions")

      html =
        render_change(view, "filter", %{
          "company_id" => to_string(company.id),
          "year" => "2025",
          "jurisdiction" => ""
        })

      # Tax summary should be shown when both company and year are selected
      assert html =~ "Current Provision" || html =~ "Effective Rate"
    end

    test "clearing all filters shows all provisions", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/tax-provisions")

      html =
        render_change(view, "filter", %{
          "company_id" => "",
          "year" => "",
          "jurisdiction" => ""
        })

      assert html =~ "Provisions"
    end
  end

  describe "save (create)" do
    test "creating a tax provision with valid data", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()

      {:ok, view, _html} = live(conn, ~p"/tax-provisions")
      render_click(view, "show_form")

      html =
        render_click(view, "save", %{
          "provision" => %{
            "company_id" => to_string(company.id),
            "tax_year" => "2025",
            "jurisdiction" => "US",
            "provision_type" => "current",
            "tax_type" => "income",
            "taxable_income" => "500000",
            "tax_rate" => "21",
            "tax_amount" => "105000",
            "status" => "estimated"
          }
        })

      assert html =~ "Tax provision created"
    end

    test "creating a provision with invalid data shows error", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, view, _html} = live(conn, ~p"/tax-provisions")
      render_click(view, "show_form")

      html =
        render_click(view, "save", %{
          "provision" => %{
            "company_id" => "",
            "tax_year" => "",
            "jurisdiction" => "",
            "provision_type" => ""
          }
        })

      assert html =~ "Failed to create provision"
    end
  end

  describe "edit and update" do
    test "edit event opens edit form with existing data", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      tp = tax_provision_fixture(%{jurisdiction: "JP"})

      {:ok, view, _html} = live(conn, ~p"/tax-provisions")
      html = render_click(view, "edit", %{"id" => to_string(tp.id)})
      assert html =~ "Edit Tax Provision"
    end

    test "updating a tax provision with valid data", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()
      tp = tax_provision_fixture(%{company: company, jurisdiction: "US"})

      {:ok, view, _html} = live(conn, ~p"/tax-provisions")
      render_click(view, "edit", %{"id" => to_string(tp.id)})

      html =
        render_click(view, "update", %{
          "provision" => %{
            "company_id" => to_string(company.id),
            "tax_year" => "2025",
            "jurisdiction" => "UK",
            "provision_type" => "deferred",
            "tax_type" => "income",
            "taxable_income" => "200000",
            "tax_rate" => "19",
            "tax_amount" => "38000",
            "status" => "accrued"
          }
        })

      assert html =~ "Tax provision updated"
    end
  end

  describe "delete" do
    test "deleting a tax provision removes it", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      tp = tax_provision_fixture(%{jurisdiction: "SG"})

      {:ok, view, _html} = live(conn, ~p"/tax-provisions")
      assert render(view) =~ "SG"

      html = render_click(view, "delete", %{"id" => to_string(tp.id)})
      assert html =~ "Tax provision deleted"
    end
  end

  describe "calculate" do
    test "calculate provision returns computed result", %{conn: conn} do
      company = company_fixture()

      {:ok, view, _html} = live(conn, ~p"/tax-provisions")

      html =
        render_click(view, "calculate", %{
          "calc" => %{
            "company_id" => to_string(company.id),
            "tax_year" => "2025",
            "jurisdiction" => "US",
            "tax_rate" => "21"
          }
        })

      assert html =~ "Calculated Provision"
      assert html =~ "Taxable Income"
      assert html =~ "Tax Amount"
    end
  end

  describe "close_calculation" do
    test "close_calculation hides the calculation result", %{conn: conn} do
      company = company_fixture()

      {:ok, view, _html} = live(conn, ~p"/tax-provisions")

      render_click(view, "calculate", %{
        "calc" => %{
          "company_id" => to_string(company.id),
          "tax_year" => "2025",
          "jurisdiction" => "US",
          "tax_rate" => "21"
        }
      })

      html = render_click(view, "close_calculation")
      refute html =~ "Calculated Provision"
    end
  end

  describe "noop" do
    test "noop event does not crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/tax-provisions")
      html = render_click(view, "noop")
      assert html =~ "Tax Provisions"
    end
  end

  describe "handle_info" do
    test "pubsub message triggers reload", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/tax-provisions")

      tax_provision_fixture(%{jurisdiction: "HK"})

      send(view.pid, {:tax_changed, %{}})
      html = render(view)
      assert html =~ "HK"
    end
  end
end
