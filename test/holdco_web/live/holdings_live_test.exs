defmodule HoldcoWeb.HoldingsLiveTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "GET /holdings" do
    test "shows add button for editors", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, _view, html} = live(conn, ~p"/holdings")

      assert html =~ "Add Position"
    end

    test "displays holdings in table", %{conn: conn} do
      holding = holding_fixture(%{asset: "Test Asset XYZ", ticker: "TXYZ", quantity: 100.0})
      {:ok, _view, html} = live(conn, ~p"/holdings")

      assert html =~ "Test Asset XYZ"
      assert html =~ "TXYZ"
      assert html =~ "100"
    end
  end

  describe "event handlers" do
    test "show_form opens the add holding modal", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/holdings")

      html = view |> element("button", "Add Position") |> render_click()

      assert html =~ "dialog"
      assert html =~ "Asset Name"
      assert html =~ "Ticker"
      assert html =~ "Quantity"
    end

    test "close_form closes the modal", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/holdings")

      view |> element("button", "Add Position") |> render_click()
      html = view |> element("button", "Cancel") |> render_click()

      refute html =~ "dialog-overlay"
    end

    test "save creates a holding", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "Save Holding Corp"})
      {:ok, view, _html} = live(conn, ~p"/holdings")

      view |> element("button", "Add Position") |> render_click()

      html =
        view
        |> form("form[phx-submit='save']", %{
          "holding" => %{
            "company_id" => company.id,
            "asset" => "New Test Asset",
            "ticker" => "NTA",
            "quantity" => "50",
            "currency" => "USD",
            "asset_type" => "equity"
          }
        })
        |> render_submit()

      assert html =~ "Position added"
    end

    test "delete removes a holding", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      holding = holding_fixture(%{asset: "DeleteMe"})
      {:ok, view, html} = live(conn, ~p"/holdings")

      assert html =~ "DeleteMe"

      html = view |> element("button[phx-click='delete'][phx-value-id='#{holding.id}']") |> render_click()

      refute html =~ "DeleteMe"
    end

  end

  describe "editor form details" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "form shows company dropdown", %{conn: conn} do
      company_fixture(%{name: "FormCompanyCo"})
      {:ok, view, _html} = live(conn, ~p"/holdings")

      html = view |> element("button", "Add Position") |> render_click()

      assert html =~ "FormCompanyCo"
      assert html =~ ~s(name="holding[company_id]")
    end

    test "form shows asset type dropdown", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/holdings")

      html = view |> element("button", "Add Position") |> render_click()

      assert html =~ ~s(name="holding[asset_type]")
      assert html =~ "Equity"
    end

    test "form shows unit and currency inputs", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/holdings")

      html = view |> element("button", "Add Position") |> render_click()

      assert html =~ ~s(name="holding[unit]")
      assert html =~ ~s(name="holding[currency]")
      assert html =~ "USD"
    end

    test "clicking overlay closes the form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/holdings")

      view |> element("button", "Add Position") |> render_click()
      html = view |> element(".dialog-overlay") |> render_click()

      refute html =~ "dialog-overlay"
    end

    test "editor sees Import CSV link", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/holdings")

      assert html =~ "Import CSV"
      assert html =~ "/import?type=holdings"
    end
  end

  describe "holdings with company" do
    test "shows company name in table", %{conn: conn} do
      company = company_fixture(%{name: "HoldingCompanyCo"})
      holding_fixture(%{company: company, asset: "CompanyAsset"})

      {:ok, _view, html} = live(conn, ~p"/holdings")

      assert html =~ "HoldingCompanyCo"
      assert html =~ "CompanyAsset"
    end
  end

  describe "sort event" do
    test "sort by asset field is ascending on initial load", %{conn: conn} do
      holding_fixture(%{asset: "Zebra Corp", ticker: "ZC"})
      holding_fixture(%{asset: "Alpha Inc", ticker: "AI"})
      {:ok, _view, html} = live(conn, ~p"/holdings")

      # Default sort is asset asc, so Alpha should come before Zebra on initial load
      alpha_pos = :binary.match(html, "Alpha Inc") |> elem(0)
      zebra_pos = :binary.match(html, "Zebra Corp") |> elem(0)
      assert alpha_pos < zebra_pos
    end

    test "sort by asset field toggles to desc when clicked", %{conn: conn} do
      holding_fixture(%{asset: "Zebra Corp", ticker: "ZC"})
      holding_fixture(%{asset: "Alpha Inc", ticker: "AI"})
      {:ok, view, _html} = live(conn, ~p"/holdings")

      # Default is asset asc, so clicking asset toggles to desc
      html = render_hook(view, "sort", %{"field" => "asset"})

      # In desc order, Zebra should come before Alpha
      alpha_pos = :binary.match(html, "Alpha Inc") |> elem(0)
      zebra_pos = :binary.match(html, "Zebra Corp") |> elem(0)
      assert zebra_pos < alpha_pos
    end

    test "sort by quantity field", %{conn: conn} do
      holding_fixture(%{asset: "Small Qty", quantity: 10.0})
      holding_fixture(%{asset: "Large Qty", quantity: 1000.0})
      {:ok, view, _html} = live(conn, ~p"/holdings")

      html = render_hook(view, "sort", %{"field" => "quantity"})

      small_pos = :binary.match(html, "Small Qty") |> elem(0)
      large_pos = :binary.match(html, "Large Qty") |> elem(0)
      assert small_pos < large_pos
    end

    test "sort by type field", %{conn: conn} do
      holding_fixture(%{asset: "Bond Asset", asset_type: "bond"})
      holding_fixture(%{asset: "Equity Asset", asset_type: "equity"})
      {:ok, view, _html} = live(conn, ~p"/holdings")

      html = render_hook(view, "sort", %{"field" => "type"})

      bond_pos = :binary.match(html, "Bond Asset") |> elem(0)
      equity_pos = :binary.match(html, "Equity Asset") |> elem(0)
      assert bond_pos < equity_pos
    end

    test "sort by ticker field", %{conn: conn} do
      holding_fixture(%{asset: "Z Asset", ticker: "ZZZ"})
      holding_fixture(%{asset: "A Asset", ticker: "AAA"})
      {:ok, view, _html} = live(conn, ~p"/holdings")

      html = render_hook(view, "sort", %{"field" => "ticker"})

      aaa_pos = :binary.match(html, "AAA") |> elem(0)
      zzz_pos = :binary.match(html, "ZZZ") |> elem(0)
      assert aaa_pos < zzz_pos
    end

    test "sort by currency field", %{conn: conn} do
      holding_fixture(%{asset: "Euro Asset", currency: "EUR"})
      holding_fixture(%{asset: "Dollar Asset", currency: "USD"})
      {:ok, view, _html} = live(conn, ~p"/holdings")

      html = render_hook(view, "sort", %{"field" => "currency"})

      eur_pos = :binary.match(html, "Euro Asset") |> elem(0)
      usd_pos = :binary.match(html, "Dollar Asset") |> elem(0)
      assert eur_pos < usd_pos
    end

    test "sort toggles direction when same field clicked twice", %{conn: conn} do
      holding_fixture(%{asset: "Alpha Inc"})
      holding_fixture(%{asset: "Zebra Corp"})
      {:ok, view, _html} = live(conn, ~p"/holdings")

      # Default is asset asc, so clicking asset toggles to desc
      html = render_hook(view, "sort", %{"field" => "asset"})
      assert html =~ "\u2193"

      # Click again toggles back to asc
      html = render_hook(view, "sort", %{"field" => "asset"})
      assert html =~ "\u2191"
    end

    test "sort resets to asc when switching to different field", %{conn: conn} do
      holding_fixture(%{asset: "Test", quantity: 100.0})
      {:ok, view, _html} = live(conn, ~p"/holdings")

      # Click asset to toggle to desc
      render_hook(view, "sort", %{"field" => "asset"})
      # Switch to quantity - should reset to asc
      html = render_hook(view, "sort", %{"field" => "quantity"})
      assert html =~ "\u2191"
    end
  end

  describe "filter_company event" do
    test "filter_company filters holdings by company", %{conn: conn} do
      company_a = company_fixture(%{name: "FilterCoA"})
      company_b = company_fixture(%{name: "FilterCoB"})
      holding_fixture(%{company: company_a, asset: "Asset In A"})
      holding_fixture(%{company: company_b, asset: "Asset In B"})

      {:ok, view, html} = live(conn, ~p"/holdings")
      assert html =~ "Asset In A"
      assert html =~ "Asset In B"

      html = render_hook(view, "filter_company", %{"company_id" => to_string(company_a.id)})
      assert html =~ "Asset In A"
      refute html =~ "Asset In B"
    end

    test "filter_company with empty string shows all holdings", %{conn: conn} do
      company_a = company_fixture(%{name: "AllCoA"})
      company_b = company_fixture(%{name: "AllCoB"})
      holding_fixture(%{company: company_a, asset: "All Asset A"})
      holding_fixture(%{company: company_b, asset: "All Asset B"})

      {:ok, view, _html} = live(conn, ~p"/holdings")

      # Filter to one company first
      render_hook(view, "filter_company", %{"company_id" => to_string(company_a.id)})
      # Reset filter
      html = render_hook(view, "filter_company", %{"company_id" => ""})
      assert html =~ "All Asset A"
      assert html =~ "All Asset B"
    end
  end

  describe "edit event" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "edit event opens edit form with holding data", %{conn: conn} do
      company = company_fixture(%{name: "EditCo"})
      holding = holding_fixture(%{company: company, asset: "Editable Asset", ticker: "EDT", quantity: 42.0, currency: "EUR", asset_type: "equity"})

      {:ok, view, _html} = live(conn, ~p"/holdings")

      html = view |> element("button[phx-click='edit'][phx-value-id='#{holding.id}']") |> render_click()

      assert html =~ "Edit Position"
      assert html =~ "Save Changes"
      assert html =~ "Editable Asset"
      assert html =~ "EDT"
      assert html =~ "42"
      assert html =~ ~s(phx-submit="update")
    end

    test "edit form shows Cancel button that closes the modal", %{conn: conn} do
      holding = holding_fixture(%{asset: "CancelEdit"})
      {:ok, view, _html} = live(conn, ~p"/holdings")

      view |> element("button[phx-click='edit'][phx-value-id='#{holding.id}']") |> render_click()
      html = view |> element("button", "Cancel") |> render_click()

      refute html =~ "dialog-overlay"
    end
  end

  describe "update event" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "update event updates the holding", %{conn: conn} do
      company = company_fixture(%{name: "UpdateCo"})
      holding = holding_fixture(%{company: company, asset: "Before Update", ticker: "BU", quantity: 10.0})

      {:ok, view, _html} = live(conn, ~p"/holdings")

      # Open edit form
      view |> element("button[phx-click='edit'][phx-value-id='#{holding.id}']") |> render_click()

      # Submit update
      html =
        view
        |> form("form[phx-submit='update']", %{
          "holding" => %{
            "company_id" => company.id,
            "asset" => "After Update",
            "ticker" => "AU",
            "quantity" => "99",
            "currency" => "USD",
            "asset_type" => "equity"
          }
        })
        |> render_submit()

      assert html =~ "Position updated"
    end

  end

  describe "sort by company" do
    test "sort by company field sorts alphabetically by company name", %{conn: conn} do
      company_a = company_fixture(%{name: "Alpha Company"})
      company_z = company_fixture(%{name: "Zulu Company"})
      holding_fixture(%{company: company_a, asset: "AlphaCo Asset"})
      holding_fixture(%{company: company_z, asset: "ZuluCo Asset"})

      {:ok, view, _html} = live(conn, ~p"/holdings")

      html = render_hook(view, "sort", %{"field" => "company"})
      alpha_pos = :binary.match(html, "AlphaCo Asset") |> elem(0)
      zulu_pos = :binary.match(html, "ZuluCo Asset") |> elem(0)
      assert alpha_pos < zulu_pos
    end

    test "sort by unknown field falls back to asset sort", %{conn: conn} do
      holding_fixture(%{asset: "Alpha Fallback"})
      holding_fixture(%{asset: "Zulu Fallback"})

      {:ok, view, _html} = live(conn, ~p"/holdings")

      html = render_hook(view, "sort", %{"field" => "nonexistent"})
      alpha_pos = :binary.match(html, "Alpha Fallback") |> elem(0)
      zulu_pos = :binary.match(html, "Zulu Fallback") |> elem(0)
      assert alpha_pos < zulu_pos
    end
  end

  describe "save and update error paths" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "save with invalid data shows error flash", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/holdings")
      view |> element("button", "Add Position") |> render_click()

      html =
        view
        |> form("form[phx-submit='save']", %{
          "holding" => %{
            "company_id" => "",
            "asset" => ""
          }
        })
        |> render_submit()

      assert html =~ "Failed to add holding"
    end

    test "update with invalid data shows error flash", %{conn: conn} do
      company = company_fixture(%{name: "UpdateErrCo"})
      holding = holding_fixture(%{company: company, asset: "WillFailUpdate", ticker: "WFU"})

      {:ok, view, _html} = live(conn, ~p"/holdings")
      view |> element("button[phx-click='edit'][phx-value-id='#{holding.id}']") |> render_click()

      html =
        view
        |> form("form[phx-submit='update']", %{
          "holding" => %{
            "company_id" => "",
            "asset" => ""
          }
        })
        |> render_submit()

      assert html =~ "Failed to update holding"
    end
  end
end
