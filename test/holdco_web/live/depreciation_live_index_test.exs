defmodule HoldcoWeb.DepreciationLiveIndexTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "Index" do
    test "renders Depreciation Schedule page", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/depreciation")
      assert html =~ "Depreciation Schedule"
    end

    test "shows page subtitle", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/depreciation")
      assert html =~ "Fixed asset depreciation tracking and schedules"
    end

    test "shows metrics strip with asset metrics", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/depreciation")
      assert html =~ "Total Asset Value"
      assert html =~ "Accumulated Depreciation"
      assert html =~ "Net Book Value"
      assert html =~ "Fixed Assets"
    end

    test "shows empty state when no assets", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/depreciation")
      assert html =~ "No fixed assets found"
    end

    test "shows asset table headers when assets exist", %{conn: conn} do
      company = company_fixture()
      fixed_asset_fixture(%{company: company, name: "Table Header Asset"})

      {:ok, _live, html} = live(conn, ~p"/depreciation")
      assert html =~ "Name"
      assert html =~ "Company"
      assert html =~ "Purchase Date"
      assert html =~ "Purchase Price"
      assert html =~ "Useful Life"
      assert html =~ "Salvage Value"
      assert html =~ "Method"
      assert html =~ "Current Book Value"
    end

    test "renders with fixed asset data", %{conn: conn} do
      company = company_fixture(%{name: "AssetCo"})
      fixed_asset_fixture(%{company: company, name: "Server Equipment"})

      {:ok, _live, html} = live(conn, ~p"/depreciation")
      assert html =~ "Server Equipment"
    end

    test "shows straight line depreciation method tag", %{conn: conn} do
      company = company_fixture()
      fixed_asset_fixture(%{company: company, name: "SL Asset", depreciation_method: "straight_line"})

      {:ok, _live, html} = live(conn, ~p"/depreciation")
      assert html =~ "Straight Line"
    end

    test "shows declining balance depreciation method tag", %{conn: conn} do
      company = company_fixture()
      fixed_asset_fixture(%{company: company, name: "DB Asset", depreciation_method: "declining_balance"})

      {:ok, _live, html} = live(conn, ~p"/depreciation")
      assert html =~ "Declining Balance"
    end

    test "shows company link for assets", %{conn: conn} do
      company = company_fixture(%{name: "LinkedAssetCo"})
      fixed_asset_fixture(%{company: company, name: "Linked Asset"})

      {:ok, _live, html} = live(conn, ~p"/depreciation")
      assert html =~ "LinkedAssetCo"
    end

    test "renders multiple assets", %{conn: conn} do
      company = company_fixture()
      fixed_asset_fixture(%{company: company, name: "Asset Alpha"})
      fixed_asset_fixture(%{company: company, name: "Asset Beta"})

      {:ok, _live, html} = live(conn, ~p"/depreciation")
      assert html =~ "Asset Alpha"
      assert html =~ "Asset Beta"
    end

    test "shows useful life in months", %{conn: conn} do
      company = company_fixture()
      fixed_asset_fixture(%{company: company, name: "Life Asset", useful_life_months: 120})

      {:ok, _live, html} = live(conn, ~p"/depreciation")
      assert html =~ "120 months"
    end
  end

  describe "form interactions" do
    test "opens add asset form", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/depreciation")
      html = render_click(live, "show_form", %{})
      assert html =~ "Add Fixed Asset"
      assert html =~ "Name"
      assert html =~ "Company"
      assert html =~ "Purchase Date"
      assert html =~ "Purchase Price"
      assert html =~ "Useful Life (months)"
      assert html =~ "Salvage Value"
      assert html =~ "Depreciation Method"
      assert html =~ "Notes"
    end

    test "form shows depreciation method options", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/depreciation")
      html = render_click(live, "show_form", %{})
      assert html =~ "Straight Line"
      assert html =~ "Declining Balance"
    end

    test "form shows company dropdown", %{conn: conn} do
      company_fixture(%{name: "DropdownAssetCo"})

      {:ok, live, _html} = live(conn, ~p"/depreciation")
      html = render_click(live, "show_form", %{})
      assert html =~ "DropdownAssetCo"
      assert html =~ "Select company"
    end

    test "closes form with close_form event", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/depreciation")
      render_click(live, "show_form", %{})
      html = render_click(live, "close_form", %{})
      refute html =~ "Add Fixed Asset"
    end

    test "opens edit form for existing asset", %{conn: conn} do
      company = company_fixture()
      asset = fixed_asset_fixture(%{company: company, name: "Edit Me Asset", depreciation_method: "declining_balance"})

      {:ok, live, _html} = live(conn, ~p"/depreciation")
      html = render_click(live, "edit", %{"id" => to_string(asset.id)})
      assert html =~ "Edit Fixed Asset"
      assert html =~ "Edit Me Asset"
    end

    test "noop event does nothing", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/depreciation")
      html = render_click(live, "noop", %{})
      assert html =~ "Depreciation Schedule"
    end
  end

  describe "company filter" do
    test "filters assets by company", %{conn: conn} do
      company1 = company_fixture(%{name: "AssetCompA"})
      company2 = company_fixture(%{name: "AssetCompB"})
      fixed_asset_fixture(%{company: company1, name: "Asset in A"})
      fixed_asset_fixture(%{company: company2, name: "Asset in B"})

      {:ok, live, _html} = live(conn, ~p"/depreciation")
      html = render_change(live, "filter_company", %{"company_id" => to_string(company1.id)})
      assert html =~ "Asset in A"
    end

    test "resets filter to show all assets", %{conn: conn} do
      company = company_fixture()
      fixed_asset_fixture(%{company: company, name: "All Assets Item"})

      {:ok, live, _html} = live(conn, ~p"/depreciation")
      render_change(live, "filter_company", %{"company_id" => to_string(company.id)})
      html = render_change(live, "filter_company", %{"company_id" => ""})
      assert html =~ "All Assets Item"
    end

    test "filter resets selected asset and schedule", %{conn: conn} do
      company = company_fixture()
      asset = fixed_asset_fixture(%{company: company, name: "Selected Asset"})

      {:ok, live, _html} = live(conn, ~p"/depreciation")
      render_click(live, "select_asset", %{"id" => to_string(asset.id)})
      html = render_change(live, "filter_company", %{"company_id" => ""})
      refute html =~ "Depreciation Schedule:"
    end

    test "company filter dropdown shows All Companies option", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/depreciation")
      assert html =~ "All Companies"
    end
  end

  describe "depreciation schedule" do
    test "selects an asset to show depreciation schedule", %{conn: conn} do
      company = company_fixture()
      asset = fixed_asset_fixture(%{
        company: company,
        name: "Schedule Asset",
        purchase_date: "2024-01-01",
        purchase_price: 10_000.0,
        useful_life_months: 60,
        salvage_value: 1_000.0,
        depreciation_method: "straight_line"
      })

      {:ok, live, _html} = live(conn, ~p"/depreciation")
      html = render_click(live, "select_asset", %{"id" => to_string(asset.id)})
      assert html =~ "Depreciation Schedule: Schedule Asset"
      assert html =~ "Month"
      assert html =~ "Date"
      assert html =~ "Depreciation"
      assert html =~ "Accumulated"
      assert html =~ "Book Value"
    end

    test "closes depreciation schedule", %{conn: conn} do
      company = company_fixture()
      asset = fixed_asset_fixture(%{company: company, name: "Close Schedule Asset"})

      {:ok, live, _html} = live(conn, ~p"/depreciation")
      render_click(live, "select_asset", %{"id" => to_string(asset.id)})
      html = render_click(live, "close_schedule", %{})
      refute html =~ "Depreciation Schedule: Close Schedule Asset"
    end

    test "shows Close button on schedule section", %{conn: conn} do
      company = company_fixture()
      asset = fixed_asset_fixture(%{company: company, name: "Close Btn Asset"})

      {:ok, live, _html} = live(conn, ~p"/depreciation")
      html = render_click(live, "select_asset", %{"id" => to_string(asset.id)})
      assert html =~ "Close"
    end
  end

  describe "viewer permission gating" do
    test "viewer cannot save a fixed asset", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/depreciation")
      render_click(live, "show_form", %{})

      html = render_click(live, "save", %{"fixed_asset" => %{"name" => "Test"}})
      assert html =~ "permission"
    end

    test "viewer cannot update a fixed asset", %{conn: conn} do
      company = company_fixture()
      asset = fixed_asset_fixture(%{company: company, name: "No Update Asset"})

      {:ok, live, _html} = live(conn, ~p"/depreciation")
      render_click(live, "edit", %{"id" => to_string(asset.id)})

      html = render_click(live, "update", %{"fixed_asset" => %{"name" => "Updated"}})
      assert html =~ "permission"
    end

    test "viewer cannot delete a fixed asset", %{conn: conn} do
      company = company_fixture()
      asset = fixed_asset_fixture(%{company: company, name: "No Delete Asset"})

      {:ok, live, _html} = live(conn, ~p"/depreciation")
      html = render_click(live, "delete", %{"id" => to_string(asset.id)})
      assert html =~ "permission"
    end
  end

  describe "editor operations" do
    test "editor can save a new fixed asset", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "EditorAssetCo"})

      {:ok, live, _html} = live(conn, ~p"/depreciation")
      render_click(live, "show_form", %{})

      html = render_click(live, "save", %{
        "fixed_asset" => %{
          "name" => "New Editor Asset",
          "company_id" => to_string(company.id),
          "purchase_date" => "2025-01-01",
          "purchase_price" => "50000",
          "useful_life_months" => "120",
          "salvage_value" => "5000",
          "depreciation_method" => "straight_line"
        }
      })
      assert html =~ "Fixed asset added" || html =~ "New Editor Asset"
    end

    test "editor can update a fixed asset", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()
      asset = fixed_asset_fixture(%{company: company, name: "Original Asset"})

      {:ok, live, _html} = live(conn, ~p"/depreciation")
      render_click(live, "edit", %{"id" => to_string(asset.id)})

      html = render_click(live, "update", %{
        "fixed_asset" => %{"name" => "Updated Asset", "depreciation_method" => "declining_balance"}
      })
      assert html =~ "Fixed asset updated" || html =~ "Updated Asset"
    end

    test "editor can delete a fixed asset", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()
      asset = fixed_asset_fixture(%{company: company, name: "Delete This Asset"})

      {:ok, live, _html} = live(conn, ~p"/depreciation")
      html = render_click(live, "delete", %{"id" => to_string(asset.id)})
      assert html =~ "Fixed asset deleted"
    end

    test "editor sees Add Asset button", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, _live, html} = live(conn, ~p"/depreciation")
      assert html =~ "Add Asset"
    end

    test "editor sees Edit and Del buttons on assets", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()
      fixed_asset_fixture(%{company: company, name: "Action Asset"})

      {:ok, _live, html} = live(conn, ~p"/depreciation")
      assert html =~ "Edit"
      assert html =~ "Del"
    end

    test "deleting selected asset clears the selection", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()
      asset = fixed_asset_fixture(%{company: company, name: "Selected Then Del Asset"})

      {:ok, live, _html} = live(conn, ~p"/depreciation")
      render_click(live, "select_asset", %{"id" => to_string(asset.id)})
      html = render_click(live, "delete", %{"id" => to_string(asset.id)})
      assert html =~ "Fixed asset deleted"
      refute html =~ "Depreciation Schedule: Selected Then Del Asset"
    end

    test "deleting a non-selected asset keeps current selection", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()
      asset1 = fixed_asset_fixture(%{company: company, name: "Keep Selected Asset"})
      asset2 = fixed_asset_fixture(%{company: company, name: "Delete Other Asset"})

      {:ok, live, _html} = live(conn, ~p"/depreciation")
      render_click(live, "select_asset", %{"id" => to_string(asset1.id)})
      html = render_click(live, "delete", %{"id" => to_string(asset2.id)})
      assert html =~ "Fixed asset deleted"
      assert html =~ "Depreciation Schedule: Keep Selected Asset"
    end

    test "editor sees Add Your First Asset when empty", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, _live, html} = live(conn, ~p"/depreciation")
      assert html =~ "Add Your First Asset"
    end

    test "editor save with invalid data shows error flash", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, live, _html} = live(conn, ~p"/depreciation")
      render_click(live, "show_form", %{})

      # Submit with empty name (should fail validation)
      html = render_click(live, "save", %{
        "fixed_asset" => %{
          "name" => "",
          "company_id" => "",
          "purchase_price" => "0",
          "useful_life_months" => "0",
          "salvage_value" => "0",
          "depreciation_method" => "straight_line"
        }
      })
      assert html =~ "Failed to add fixed asset"
    end

    test "editor update with invalid data shows error flash", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()
      asset = fixed_asset_fixture(%{company: company, name: "Update Fail Asset"})

      {:ok, live, _html} = live(conn, ~p"/depreciation")
      render_click(live, "edit", %{"id" => to_string(asset.id)})

      html = render_click(live, "update", %{
        "fixed_asset" => %{"name" => ""}
      })
      assert html =~ "Failed to update fixed asset"
    end

    test "editor save with declining_balance method", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "DeclBalCo"})

      {:ok, live, _html} = live(conn, ~p"/depreciation")
      render_click(live, "show_form", %{})

      html = render_click(live, "save", %{
        "fixed_asset" => %{
          "name" => "DB Method Asset",
          "company_id" => to_string(company.id),
          "purchase_date" => "2025-01-01",
          "purchase_price" => "20000",
          "useful_life_months" => "60",
          "salvage_value" => "2000",
          "depreciation_method" => "declining_balance"
        }
      })
      assert html =~ "Fixed asset added" || html =~ "DB Method Asset"
    end

    test "schedule shows empty state for asset with nil purchase_date", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()
      asset = fixed_asset_fixture(%{company: company, name: "No Date Asset", purchase_date: nil})

      {:ok, live, _html} = live(conn, ~p"/depreciation")
      html = render_click(live, "select_asset", %{"id" => to_string(asset.id)})
      assert html =~ "Depreciation Schedule: No Date Asset"
    end

    test "metrics display properly with assets", %{conn: conn} do
      company = company_fixture()
      fixed_asset_fixture(%{
        company: company,
        name: "Metrics Asset",
        purchase_price: 10_000.0,
        useful_life_months: 60,
        salvage_value: 1_000.0,
        purchase_date: "2024-01-01"
      })

      {:ok, _live, html} = live(conn, ~p"/depreciation")
      assert html =~ "10,000.00"
    end

    test "reload after filter applies correct company_id", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "ReloadCo"})
      fixed_asset_fixture(%{company: company, name: "Reload Asset"})

      {:ok, live, _html} = live(conn, ~p"/depreciation")
      # Filter to a company then save
      render_change(live, "filter_company", %{"company_id" => to_string(company.id)})
      render_click(live, "show_form", %{})

      html = render_click(live, "save", %{
        "fixed_asset" => %{
          "name" => "New Reload Asset",
          "company_id" => to_string(company.id),
          "purchase_date" => "2025-01-01",
          "purchase_price" => "5000",
          "useful_life_months" => "60",
          "salvage_value" => "500",
          "depreciation_method" => "straight_line"
        }
      })
      assert html =~ "Fixed asset added" || html =~ "New Reload Asset"
    end
  end
end
