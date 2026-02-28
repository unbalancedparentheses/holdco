defmodule HoldcoWeb.ScenarioLiveShowTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  defp create_scenario(_context) do
    company = company_fixture(%{name: "ShowCo"})
    scenario = scenario_fixture(%{name: "Test Scenario", description: "A test projection", company_id: company.id, projection_months: 12})
    %{scenario: scenario, company: company}
  end

  # ── Mount & Render ──────────────────────────────────────

  describe "mount and render" do
    setup [:create_scenario]

    test "renders scenario name as page title", %{conn: conn, scenario: scenario} do
      {:ok, _view, html} = live(conn, ~p"/scenarios/#{scenario.id}")

      assert html =~ "<h1>Test Scenario</h1>"
    end

    test "renders description and projection months in deck", %{conn: conn, scenario: scenario} do
      {:ok, _view, html} = live(conn, ~p"/scenarios/#{scenario.id}")

      assert html =~ "A test projection"
      assert html =~ "12 months"
    end

    test "renders back link to scenarios", %{conn: conn, scenario: scenario} do
      {:ok, _view, html} = live(conn, ~p"/scenarios/#{scenario.id}")

      assert html =~ "Back to Scenarios"
      assert html =~ ~s(href="/scenarios")
    end

    test "renders Scenario Items section", %{conn: conn, scenario: scenario} do
      {:ok, _view, html} = live(conn, ~p"/scenarios/#{scenario.id}")

      assert html =~ "Scenario Items"
    end

    test "renders empty state when no items", %{conn: conn, scenario: scenario} do
      {:ok, _view, html} = live(conn, ~p"/scenarios/#{scenario.id}")

      assert html =~ "No items yet. Add revenue and expense items to build the projection."
    end

    test "renders scenario items in table", %{conn: conn, scenario: scenario} do
      scenario_item_fixture(%{scenario_id: scenario.id, name: "SaaS Revenue", item_type: "revenue", amount: 5000.0})

      {:ok, _view, html} = live(conn, ~p"/scenarios/#{scenario.id}")

      assert html =~ "SaaS Revenue"
      assert html =~ "revenue"
      assert html =~ "5,000"
    end

    test "renders Monthly Projections section", %{conn: conn, scenario: scenario} do
      {:ok, _view, html} = live(conn, ~p"/scenarios/#{scenario.id}")

      assert html =~ "Monthly Projections"
      assert html =~ "Month"
      assert html =~ "Revenue"
      assert html =~ "Expenses"
      assert html =~ "Net"
      assert html =~ "Total"
    end

    test "renders projection chart section", %{conn: conn, scenario: scenario} do
      {:ok, _view, html} = live(conn, ~p"/scenarios/#{scenario.id}")

      assert html =~ "Projection Chart"
      assert html =~ "projection-chart"
    end

    test "viewer cannot see Add Item button", %{conn: conn, scenario: scenario} do
      {:ok, _view, html} = live(conn, ~p"/scenarios/#{scenario.id}")

      refute html =~ "Add Item"
    end

    test "editor sees Add Item button", %{conn: conn, user: user, scenario: scenario} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, _view, html} = live(conn, ~p"/scenarios/#{scenario.id}")

      assert html =~ "Add Item"
    end
  end

  # ── Show/Close Form ─────────────────────────────────────

  describe "show_form and close_form events" do
    setup [:create_scenario]

    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "show_form opens Add Scenario Item modal", %{conn: conn, scenario: scenario} do
      {:ok, view, _html} = live(conn, ~p"/scenarios/#{scenario.id}")

      html = view |> element("button", "Add Item") |> render_click()

      assert html =~ "dialog-overlay"
      assert html =~ "Add Scenario Item"
      assert html =~ ~s(phx-submit="save_item")
      assert html =~ ~s(name="item[name]")
      assert html =~ ~s(name="item[item_type]")
      assert html =~ ~s(name="item[amount]")
      assert html =~ ~s(name="item[currency]")
      assert html =~ ~s(name="item[growth_rate]")
      assert html =~ ~s(name="item[growth_type]")
      assert html =~ ~s(name="item[recurrence]")
      assert html =~ ~s(name="item[probability]")
    end

    test "close_form closes the modal", %{conn: conn, scenario: scenario} do
      {:ok, view, _html} = live(conn, ~p"/scenarios/#{scenario.id}")

      view |> element("button", "Add Item") |> render_click()
      html = view |> element(~s(button[phx-click="close_form"]), "Cancel") |> render_click()

      refute html =~ "dialog-overlay"
    end

    test "overlay click closes the modal", %{conn: conn, scenario: scenario} do
      {:ok, view, _html} = live(conn, ~p"/scenarios/#{scenario.id}")

      view |> element("button", "Add Item") |> render_click()
      html = view |> element(".dialog-overlay") |> render_click()

      refute html =~ "dialog-overlay"
    end
  end

  # ── Save Item ───────────────────────────────────────────

  describe "save_item event" do
    setup [:create_scenario]

    test "creates a scenario item and shows flash", %{conn: conn, user: user, scenario: scenario} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/scenarios/#{scenario.id}")

      view |> element("button", "Add Item") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_item"]), %{
          "item" => %{
            "name" => "Consulting Revenue",
            "item_type" => "revenue",
            "amount" => "8000",
            "currency" => "USD",
            "growth_rate" => "5",
            "growth_type" => "compound",
            "recurrence" => "monthly",
            "probability" => "0.9"
          }
        })
        |> render_submit()

      assert html =~ "Item added"
      assert html =~ "Consulting Revenue"
      assert html =~ "revenue"
      refute html =~ "dialog-overlay"
    end

    test "viewer cannot save an item", %{conn: conn, scenario: scenario} do
      {:ok, view, _html} = live(conn, ~p"/scenarios/#{scenario.id}")

      render_hook(view, "save_item", %{"item" => %{"name" => "Blocked"}})
      assert render(view) =~ "permission"
    end
  end

  # ── Delete Item ─────────────────────────────────────────

  describe "delete_item event" do
    setup [:create_scenario]

    test "deletes a scenario item", %{conn: conn, user: user, scenario: scenario} do
      Holdco.Accounts.set_user_role(user, "editor")
      item = scenario_item_fixture(%{scenario_id: scenario.id, name: "ToRemove"})

      {:ok, view, html} = live(conn, ~p"/scenarios/#{scenario.id}")
      assert html =~ "ToRemove"

      view |> element(~s(button[phx-click="delete_item"][phx-value-id="#{item.id}"])) |> render_click()

      html = render(view)
      assert html =~ "Item deleted"
      refute html =~ "ToRemove"
    end

    test "viewer cannot delete an item", %{conn: conn, scenario: scenario} do
      item = scenario_item_fixture(%{scenario_id: scenario.id, name: "CantDelete"})

      {:ok, view, _html} = live(conn, ~p"/scenarios/#{scenario.id}")

      render_hook(view, "delete_item", %{"id" => to_string(item.id)})
      assert render(view) =~ "permission"
    end
  end

  # ── Projection with items ───────────────────────────────

  describe "projection rendering with items" do
    setup [:create_scenario]

    test "monthly projections reflect added items", %{conn: conn, scenario: scenario} do
      scenario_item_fixture(%{scenario_id: scenario.id, name: "Rev", item_type: "revenue", amount: 1000.0})
      scenario_item_fixture(%{scenario_id: scenario.id, name: "Exp", item_type: "expense", amount: 500.0})

      {:ok, _view, html} = live(conn, ~p"/scenarios/#{scenario.id}")

      assert html =~ "Month 1"
      assert html =~ "Month 12"
      # revenue and expense items are tagged
      assert html =~ "tag-jade"
      assert html =~ "tag-crimson"
    end
  end

  # ── Noop event ──────────────────────────────────────────

  describe "noop event" do
    setup [:create_scenario]

    test "noop does not crash the view", %{conn: conn, scenario: scenario} do
      {:ok, view, _html} = live(conn, ~p"/scenarios/#{scenario.id}")

      render_hook(view, "noop", %{})
      assert render(view) =~ "Test Scenario"
    end
  end

  # ── Save Item Error ──────────────────────────────────────────

  describe "save_item error path" do
    setup [:create_scenario]

    test "save_item with invalid data shows error flash", %{conn: conn, user: user, scenario: scenario} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/scenarios/#{scenario.id}")

      view |> element("button", "Add Item") |> render_click()

      # Submit without required name field
      html =
        render_hook(view, "save_item", %{
          "item" => %{
            "name" => "",
            "item_type" => "revenue",
            "amount" => "0"
          }
        })

      assert html =~ "Failed to add item"
    end
  end

  # ── Handle Info ──────────────────────────────────────────

  describe "handle_info" do
    setup [:create_scenario]

    test "handle_info reloads data on any message", %{conn: conn, scenario: scenario} do
      {:ok, view, _html} = live(conn, ~p"/scenarios/#{scenario.id}")

      send(view.pid, :some_event)
      html = render(view)
      assert html =~ "Test Scenario"
    end
  end

  # ── Scenario without description ─────────────────────────

  describe "scenario without description" do
    test "renders Financial projection default text", %{conn: conn} do
      company = company_fixture(%{name: "NoDescCo"})
      scenario = scenario_fixture(%{name: "No Desc Scenario", description: nil, company_id: company.id, projection_months: 6})

      {:ok, _view, html} = live(conn, ~p"/scenarios/#{scenario.id}")

      assert html =~ "Financial projection"
      assert html =~ "6 months"
    end
  end
end
