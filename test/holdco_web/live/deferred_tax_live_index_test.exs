defmodule HoldcoWeb.DeferredTaxLiveIndexTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "Index" do
    test "opens add deferred tax form", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/deferred-taxes")
      html = render_click(live, "show_form")
      assert html =~ "Add Deferred Tax"
      assert html =~ "Deferred Type"
    end
  end

  describe "close_form" do
    test "closes the add deferred tax form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/deferred-taxes")
      render_click(view, "show_form")
      html = render_click(view, "close_form")
      refute html =~ "dialog-overlay"
    end
  end

  describe "save (create deferred tax)" do
    test "creates a deferred tax with valid data", %{conn: conn} do
      company = company_fixture(%{name: "Tax Corp"})

      {:ok, view, _html} = live(conn, ~p"/deferred-taxes")
      render_click(view, "show_form")

      html =
        render_click(view, "save", %{
          "deferred_tax" => %{
            "company_id" => to_string(company.id),
            "tax_year" => "2025",
            "description" => "Equipment depreciation",
            "deferred_type" => "liability",
            "source" => "depreciation",
            "book_basis" => "100000",
            "tax_basis" => "80000",
            "temporary_difference" => "20000",
            "tax_rate" => "21",
            "deferred_amount" => "4200"
          }
        })

      assert html =~ "Deferred tax created"
      assert html =~ "Equipment depreciation"
    end

    test "shows error when creating with missing fields", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/deferred-taxes")
      render_click(view, "show_form")

      html =
        render_click(view, "save", %{
          "deferred_tax" => %{
            "description" => "",
            "deferred_type" => ""
          }
        })

      assert html =~ "Failed to create deferred tax"
    end
  end

  describe "edit" do
    test "opens edit form for an existing deferred tax", %{conn: conn} do
      company = company_fixture()
      dt = deferred_tax_fixture(%{company: company, description: "Editable DT"})

      {:ok, view, _html} = live(conn, ~p"/deferred-taxes")
      html = render_click(view, "edit", %{"id" => to_string(dt.id)})

      assert html =~ "Edit Deferred Tax"
      assert html =~ "Update Deferred Tax"
    end
  end

  describe "update" do
    test "updates a deferred tax", %{conn: conn} do
      company = company_fixture()
      dt = deferred_tax_fixture(%{company: company, description: "Old Description"})

      {:ok, view, _html} = live(conn, ~p"/deferred-taxes")
      render_click(view, "edit", %{"id" => to_string(dt.id)})

      html =
        render_click(view, "update", %{
          "deferred_tax" => %{
            "company_id" => to_string(company.id),
            "tax_year" => "2025",
            "description" => "Updated DT Description",
            "deferred_type" => "asset",
            "deferred_amount" => "5000"
          }
        })

      assert html =~ "Deferred tax updated"
      assert html =~ "Updated DT Description"
    end
  end

  describe "delete" do
    test "deletes a deferred tax", %{conn: conn} do
      company = company_fixture()
      dt = deferred_tax_fixture(%{company: company, description: "Delete Me DT"})

      {:ok, view, _html} = live(conn, ~p"/deferred-taxes")
      assert render(view) =~ "Delete Me DT"

      html = render_click(view, "delete", %{"id" => to_string(dt.id)})
      assert html =~ "Deferred tax deleted"
      refute html =~ "Delete Me DT"
    end
  end

  describe "filter" do
    test "filters by company", %{conn: conn} do
      company1 = company_fixture(%{name: "Filter DT Corp"})
      company2 = company_fixture(%{name: "Other DT Corp"})
      deferred_tax_fixture(%{company: company1, description: "Filtered DT Item"})
      deferred_tax_fixture(%{company: company2, description: "Other DT Item"})

      {:ok, view, _html} = live(conn, ~p"/deferred-taxes")
      html = render_click(view, "filter", %{"company_id" => to_string(company1.id), "year" => "", "deferred_type" => ""})
      assert html =~ "Filtered DT Item"
      refute html =~ "Other DT Item"
    end

    test "filters by year", %{conn: conn} do
      company = company_fixture()
      deferred_tax_fixture(%{company: company, tax_year: 2024, description: "Year 2024 DT"})
      deferred_tax_fixture(%{company: company, tax_year: 2023, description: "Year 2023 DT"})

      {:ok, view, _html} = live(conn, ~p"/deferred-taxes")
      html = render_click(view, "filter", %{"company_id" => "", "year" => "2024", "deferred_type" => ""})
      assert html =~ "Year 2024 DT"
      refute html =~ "Year 2023 DT"
    end

    test "filters by deferred type", %{conn: conn} do
      company = company_fixture()
      deferred_tax_fixture(%{company: company, deferred_type: "asset", description: "Asset Type DT"})
      deferred_tax_fixture(%{company: company, deferred_type: "liability", description: "Liability Type DT"})

      {:ok, view, _html} = live(conn, ~p"/deferred-taxes")
      html = render_click(view, "filter", %{"company_id" => "", "year" => "", "deferred_type" => "asset"})
      assert html =~ "Asset Type DT"
      refute html =~ "Liability Type DT"
    end

    test "clears all filters with empty values", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/deferred-taxes")
      html = render_click(view, "filter", %{"company_id" => "", "year" => "", "deferred_type" => ""})
      assert html =~ "Deferred Taxes"
    end
  end

  describe "calculate" do
    test "calculates deferred tax from book and tax basis", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/deferred-taxes")

      html =
        render_click(view, "calculate", %{
          "calc" => %{
            "book_basis" => "100000",
            "tax_basis" => "80000",
            "tax_rate" => "21"
          }
        })

      assert html =~ "Temporary Difference"
      assert html =~ "Deferred Amount"
    end
  end

  describe "close_calculation" do
    test "clears the calculation result", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/deferred-taxes")

      render_click(view, "calculate", %{
        "calc" => %{
          "book_basis" => "100000",
          "tax_basis" => "80000",
          "tax_rate" => "21"
        }
      })

      html = render_click(view, "close_calculation")
      # calc_result is nil, so the result section is hidden
      refute html =~ "Deferred Amount"
    end
  end

  describe "displays existing data" do
    test "shows deferred tax in table", %{conn: conn} do
      company = company_fixture(%{name: "Visible DT Corp"})
      deferred_tax_fixture(%{company: company, description: "Visible DT Item", deferred_type: "liability"})

      {:ok, _view, html} = live(conn, ~p"/deferred-taxes")
      assert html =~ "Visible DT Item"
      assert html =~ "liability"
    end
  end
end
