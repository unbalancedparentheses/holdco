defmodule HoldcoWeb.HoldingsLiveTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "GET /holdings" do
    test "renders holdings page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/holdings")

      assert html =~ "Holdings"
    end

    test "renders page title and deck", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/holdings")

      assert html =~ "page-title"
      assert html =~ "positions across all entities"
    end

    test "renders metrics strip", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/holdings")

      assert html =~ "metrics-strip"
      assert html =~ "Total Positions"
    end

    test "holdings nav link is active", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/holdings")

      assert html =~ "more-active"
    end

    test "shows export button", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/holdings")

      assert html =~ "Export CSV"
    end

    test "shows add button for editors", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, _view, html} = live(conn, ~p"/holdings")

      assert html =~ "Add Holding"
    end

    test "does not show add button for viewers", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/holdings")

      refute html =~ "Add Holding"
    end

    test "displays holdings in table", %{conn: conn} do
      holding = holding_fixture(%{asset: "Test Asset XYZ", ticker: "TXYZ", quantity: 100.0})
      {:ok, _view, html} = live(conn, ~p"/holdings")

      assert html =~ "Test Asset XYZ"
      assert html =~ "TXYZ"
      assert html =~ "100"
    end

    test "shows empty state when no holdings", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/holdings")

      assert html =~ "No holdings yet"
    end

    test "renders allocation section", %{conn: conn} do
      holding_fixture(%{asset_type: "equity"})
      {:ok, _view, html} = live(conn, ~p"/holdings")

      assert html =~ "Allocation by Type"
      assert html =~ "By Type Summary"
    end

    test "shows Total Quantity Value metric", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/holdings")

      assert html =~ "Total Quantity Value"
      assert html =~ "Asset Types"
    end
  end

  describe "event handlers" do
    test "show_form opens the add holding modal", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/holdings")

      html = view |> element("button", "Add Holding") |> render_click()

      assert html =~ "modal"
      assert html =~ "Asset Name"
      assert html =~ "Ticker"
      assert html =~ "Quantity"
    end

    test "close_form closes the modal", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/holdings")

      view |> element("button", "Add Holding") |> render_click()
      html = view |> element("button", "Cancel") |> render_click()

      refute html =~ "modal-overlay"
    end

    test "save creates a holding", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "Save Holding Corp"})
      {:ok, view, _html} = live(conn, ~p"/holdings")

      view |> element("button", "Add Holding") |> render_click()

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

      assert html =~ "Holding added" or html =~ "New Test Asset"
    end

    test "delete removes a holding", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      holding = holding_fixture(%{asset: "DeleteMe"})
      {:ok, view, html} = live(conn, ~p"/holdings")

      assert html =~ "DeleteMe"

      html = view |> element("button[phx-click='delete'][phx-value-id='#{holding.id}']") |> render_click()

      refute html =~ "DeleteMe"
    end

    test "viewers cannot delete holdings", %{conn: conn} do
      holding_fixture(%{asset: "Protected"})
      {:ok, _view, html} = live(conn, ~p"/holdings")

      assert html =~ "Protected"
      refute html =~ "Del"
    end
  end

  describe "viewer permission guards" do
    test "viewer save event returns permission error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/holdings")

      render_hook(view, "save", %{"holding" => %{"asset" => "test"}})
      assert render(view) =~ "permission"
    end

    test "viewer delete event returns permission error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/holdings")

      render_hook(view, "delete", %{"id" => "999"})
      assert render(view) =~ "permission"
    end
  end

  describe "noop event" do
    test "noop does not crash the view", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/holdings")

      render_hook(view, "noop", %{})
      assert render(view) =~ "Holdings"
    end
  end

  describe "handle_info for PubSub" do
    test "handles broadcast by reloading data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/holdings")

      send(view.pid, :some_broadcast)

      html = render(view)
      assert html =~ "Holdings"
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

      html = view |> element("button", "Add Holding") |> render_click()

      assert html =~ "FormCompanyCo"
      assert html =~ ~s(name="holding[company_id]")
    end

    test "form shows asset type dropdown", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/holdings")

      html = view |> element("button", "Add Holding") |> render_click()

      assert html =~ ~s(name="holding[asset_type]")
      assert html =~ "Equity"
    end

    test "form shows unit and currency inputs", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/holdings")

      html = view |> element("button", "Add Holding") |> render_click()

      assert html =~ ~s(name="holding[unit]")
      assert html =~ ~s(name="holding[currency]")
      assert html =~ "USD"
    end

    test "clicking overlay closes the form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/holdings")

      view |> element("button", "Add Holding") |> render_click()
      html = view |> element(".modal-overlay") |> render_click()

      refute html =~ "modal-overlay"
    end

    test "editor sees Import CSV link", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/holdings")

      assert html =~ "Import CSV"
      assert html =~ "/import?type=holdings"
    end
  end

  describe "holdings table headers" do
    test "renders all table headers", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/holdings")

      assert html =~ "Asset"
      assert html =~ "Ticker"
      assert html =~ "Qty"
      assert html =~ "Unit"
      assert html =~ "Type"
      assert html =~ "Currency"
      assert html =~ "Company"
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

    test "shows company name in table for each holding", %{conn: conn} do
      company2 = company_fixture(%{name: "SecondHoldingCo"})
      holding_fixture(%{company: company2, asset: "SecondAsset"})

      {:ok, _view, html} = live(conn, ~p"/holdings")

      assert html =~ "SecondAsset"
      assert html =~ "SecondHoldingCo"
    end
  end
end
