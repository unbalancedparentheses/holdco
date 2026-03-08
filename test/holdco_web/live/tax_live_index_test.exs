defmodule HoldcoWeb.TaxLiveIndexTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "provisions tab — show_form and close_form" do
    test "show_form opens the add provision dialog", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/tax")
      html = render_click(view, "show_form")
      assert html =~ "Add Tax Provision"
      assert html =~ "Company *"
      assert html =~ "Tax Year *"
      assert html =~ "Jurisdiction *"
      assert html =~ "Provision Type *"
    end

    test "close_form hides the dialog", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/tax")
      render_click(view, "show_form")
      html = render_click(view, "close_form")
      refute html =~ "dialog-overlay"
    end
  end

  describe "provisions tab — filter" do
    test "filtering by company shows only that company's provisions", %{conn: conn} do
      company1 = company_fixture(%{name: "Tax Filter Corp"})
      company2 = company_fixture(%{name: "Other Tax Corp"})
      tax_provision_fixture(%{company: company1, jurisdiction: "DE", taxable_income: 111_111.0})
      tax_provision_fixture(%{company: company2, jurisdiction: "FR", taxable_income: 222_222.0})

      {:ok, view, html} = live(conn, ~p"/tax")
      assert html =~ "111111.00"
      assert html =~ "222222.00"

      html = render_change(view, "filter", %{"company_id" => to_string(company1.id), "year" => "", "jurisdiction" => ""})
      assert html =~ "111111.00"
      refute html =~ "222222.00"
    end

    test "filtering by year shows only that year's provisions", %{conn: conn} do
      company = company_fixture()
      tax_provision_fixture(%{company: company, tax_year: 2025, jurisdiction: "US", taxable_income: 333_333.0})
      tax_provision_fixture(%{company: company, tax_year: 2024, jurisdiction: "JP", taxable_income: 444_444.0})

      {:ok, view, html} = live(conn, ~p"/tax")
      assert html =~ "333333.00"
      assert html =~ "444444.00"

      html = render_change(view, "filter", %{"company_id" => "", "year" => "2025", "jurisdiction" => ""})
      assert html =~ "333333.00"
      refute html =~ "444444.00"
    end

    test "filtering by jurisdiction shows only that jurisdiction's provisions", %{conn: conn} do
      company = company_fixture()
      tax_provision_fixture(%{company: company, tax_year: 2025, jurisdiction: "US", taxable_income: 555_555.0})
      tax_provision_fixture(%{company: company, tax_year: 2025, jurisdiction: "JP", taxable_income: 666_666.0})

      {:ok, view, html} = live(conn, ~p"/tax")
      assert html =~ "555555.00"
      assert html =~ "666666.00"

      html = render_change(view, "filter", %{"company_id" => "", "year" => "", "jurisdiction" => "US"})
      assert html =~ "555555.00"
      refute html =~ "666666.00"
    end

    test "filtering by company and year shows tax summary", %{conn: conn} do
      company = company_fixture(%{name: "Summary Corp"})
      tax_provision_fixture(%{company: company, tax_year: 2025, jurisdiction: "US"})

      {:ok, view, _html} = live(conn, ~p"/tax")

      html =
        render_change(view, "filter", %{
          "company_id" => to_string(company.id),
          "year" => "2025",
          "jurisdiction" => ""
        })

      assert html =~ "Current Provision"
    end

    test "clearing all filters shows all provisions", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/tax")

      html =
        render_change(view, "filter", %{
          "company_id" => "",
          "year" => "",
          "jurisdiction" => ""
        })

      assert html =~ "Provisions"
    end
  end

  describe "provisions tab — save (create)" do
    test "creating a tax provision with valid data", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()

      {:ok, view, _html} = live(conn, ~p"/tax")
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

      {:ok, view, _html} = live(conn, ~p"/tax")
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

  describe "provisions tab — edit and update" do
    test "edit event opens edit form with existing data", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      tp = tax_provision_fixture(%{jurisdiction: "JP"})

      {:ok, view, _html} = live(conn, ~p"/tax")
      html = render_click(view, "edit", %{"id" => to_string(tp.id)})
      assert html =~ "Edit Tax Provision"
    end

    test "updating a tax provision with valid data", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()
      tp = tax_provision_fixture(%{company: company, jurisdiction: "US"})

      {:ok, view, _html} = live(conn, ~p"/tax")
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

  describe "provisions tab — delete" do
    test "deleting a tax provision removes it", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      tp = tax_provision_fixture(%{jurisdiction: "SG"})

      {:ok, view, _html} = live(conn, ~p"/tax")
      assert render(view) =~ "SG"

      html = render_click(view, "delete", %{"id" => to_string(tp.id)})
      assert html =~ "Tax provision deleted"
    end
  end

  describe "provisions tab — calculate" do
    test "calculate provision returns computed result", %{conn: conn} do
      company = company_fixture()

      {:ok, view, _html} = live(conn, ~p"/tax")

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

  describe "provisions tab — close_calculation" do
    test "close_calculation hides the calculation result", %{conn: conn} do
      company = company_fixture()

      {:ok, view, _html} = live(conn, ~p"/tax")

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

  describe "provisions tab — handle_info" do
    test "pubsub message triggers reload", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/tax")

      tax_provision_fixture(%{jurisdiction: "HK"})

      send(view.pid, {:tax_changed, %{}})
      html = render(view)
      assert html =~ "HK"
    end
  end

  describe "capital gains tab" do
    test "switches to capital gains tab and back", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/tax")
      html = render_click(view, "switch_tab", %{"tab" => "capital_gains"})
      assert html =~ "Capital Gains"
      assert html =~ "Holdings Detail"

      html = render_click(view, "switch_tab", %{"tab" => "provisions"})
      assert html =~ "Provisions"
    end

    test "switches to LIFO method", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/tax")
      render_click(view, "switch_tab", %{"tab" => "capital_gains"})
      html = render_click(view, "change_method", %{"method" => "lifo"})
      assert html =~ "Capital Gains"
    end

    test "defaults to FIFO method on mount", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/tax")
      html = render_click(view, "switch_tab", %{"tab" => "capital_gains"})
      assert html =~ "FIFO"
    end

    test "method change recomputes summary data", %{conn: conn} do
      company = company_fixture()
      holding = holding_fixture(%{company: company, asset: "TSLA", ticker: "TSLA", quantity: 200.0})
      cost_basis_lot_fixture(%{holding: holding, purchase_date: "2022-01-01", quantity: 100.0, price_per_unit: 200.0})
      cost_basis_lot_fixture(%{holding: holding, purchase_date: "2023-01-01", quantity: 100.0, price_per_unit: 250.0})

      {:ok, view, _html} = live(conn, ~p"/tax")
      render_click(view, "switch_tab", %{"tab" => "capital_gains"})
      html = render_click(view, "change_method", %{"method" => "lifo"})
      assert html =~ "Capital Gains"
      assert html =~ "Total Gains"
    end

    test "renders company name in results table", %{conn: conn} do
      company = company_fixture(%{name: "Capital Corp"})
      holding = holding_fixture(%{company: company, asset: "CapAsset", ticker: "CA", quantity: 50.0})
      cost_basis_lot_fixture(%{holding: holding, purchase_date: "2023-01-01", quantity: 50.0, price_per_unit: 100.0})

      {:ok, view, _html} = live(conn, ~p"/tax")
      html = render_click(view, "switch_tab", %{"tab" => "capital_gains"})
      assert html =~ "Capital Corp"
      assert html =~ "CapAsset"
    end

    test "shows ticker in parentheses next to asset name", %{conn: conn} do
      company = company_fixture()
      holding = holding_fixture(%{company: company, asset: "Apple Inc", ticker: "AAPL", quantity: 10.0})
      cost_basis_lot_fixture(%{holding: holding, purchase_date: "2023-01-01", quantity: 10.0, price_per_unit: 150.0})

      {:ok, view, _html} = live(conn, ~p"/tax")
      html = render_click(view, "switch_tab", %{"tab" => "capital_gains"})
      assert html =~ "Apple Inc"
      assert html =~ "(AAPL)"
    end
  end
end
