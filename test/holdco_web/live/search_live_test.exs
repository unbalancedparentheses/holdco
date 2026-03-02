defmodule HoldcoWeb.SearchLiveTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "search with matching data" do
    test "finds matching companies", %{conn: conn} do
      company_fixture(%{name: "Acme Corporation"})

      {:ok, _view, html} = live(conn, ~p"/search?q=Acme")

      assert html =~ "Companies"
      assert html =~ "Acme Corporation"
    end

    test "finds matching holdings", %{conn: conn} do
      company = company_fixture()
      holding_fixture(%{company: company, asset: "Apple Inc", ticker: "AAPL"})

      {:ok, _view, html} = live(conn, ~p"/search?q=Apple")

      assert html =~ "Positions"
      assert html =~ "Apple Inc"
    end

    test "finds matching transactions", %{conn: conn} do
      company = company_fixture()
      transaction_fixture(%{company: company, description: "Office rent payment"})

      {:ok, _view, html} = live(conn, ~p"/search?q=Office rent")

      assert html =~ "Transactions"
      assert html =~ "Office rent payment"
    end

    test "finds matching documents", %{conn: conn} do
      company = company_fixture()
      document_fixture(%{company: company, name: "Board Resolution 2024"})

      {:ok, _view, html} = live(conn, ~p"/search?q=Board Resolution")

      assert html =~ "Documents"
      assert html =~ "Board Resolution 2024"
    end

  end

  describe "search event" do
    test "submitting search form navigates with query param", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/search")

      view
      |> form("form[phx-submit=\"search\"]", %{"q" => "myquery"})
      |> render_submit()

      # Should patch to /search?q=myquery
      assert render(view) =~ "results for"
    end
  end

  describe "result sections display" do
    test "company results link to company show page", %{conn: conn} do
      company = company_fixture(%{name: "Linkable Corp"})

      {:ok, _view, html} = live(conn, ~p"/search?q=Linkable")

      assert html =~ ~s(/companies/#{company.id})
    end

    test "holding results link to holdings page", %{conn: conn} do
      company = company_fixture()
      holding_fixture(%{company: company, asset: "LinkableHolding"})

      {:ok, _view, html} = live(conn, ~p"/search?q=LinkableHolding")

      assert html =~ "/holdings"
    end

    test "transaction results link to transactions page", %{conn: conn} do
      company = company_fixture()
      transaction_fixture(%{company: company, description: "LinkableTxn"})

      {:ok, _view, html} = live(conn, ~p"/search?q=LinkableTxn")

      assert html =~ "/transactions"
    end

    test "document results link to documents page", %{conn: conn} do
      company = company_fixture()
      document_fixture(%{company: company, name: "LinkableDoc"})

      {:ok, _view, html} = live(conn, ~p"/search?q=LinkableDoc")

      assert html =~ "/documents"
    end
  end

end
