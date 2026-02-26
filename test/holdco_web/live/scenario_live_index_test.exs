defmodule HoldcoWeb.ScenarioLiveIndexTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  # ── Mount & Render ──────────────────────────────────────

  describe "mount and render" do
    test "renders page title and deck", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/scenarios")

      assert html =~ "<h1>Scenarios</h1>"
      assert html =~ "Financial projections and what-if analysis"
      assert html =~ "page-title-rule"
    end

    test "renders table headers", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/scenarios")

      assert html =~ "Name"
      assert html =~ "Company"
      assert html =~ "Status"
      assert html =~ "Months"
    end

    test "renders empty state when no scenarios", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/scenarios")

      assert html =~ "No scenarios yet."
      assert html =~ "Create one"
    end

    test "renders existing scenarios", %{conn: conn} do
      company = company_fixture(%{name: "ScenCo"})
      scenario_fixture(%{name: "Bull Case", company_id: company.id, projection_months: 24})

      {:ok, _view, html} = live(conn, ~p"/scenarios")

      assert html =~ "Bull Case"
      assert html =~ "ScenCo"
      assert html =~ "24"
    end

    test "scenario name links to show page", %{conn: conn} do
      s = scenario_fixture(%{name: "LinkedScenario"})

      {:ok, _view, html} = live(conn, ~p"/scenarios")

      assert html =~ ~s(href="/scenarios/#{s.id}")
      assert html =~ "LinkedScenario"
    end

    test "renders scenario status tag", %{conn: conn} do
      scenario_fixture(%{name: "DraftScen", status: "draft"})

      {:ok, _view, html} = live(conn, ~p"/scenarios")

      assert html =~ "draft"
      assert html =~ "tag-lemon"
    end

    test "viewer cannot see New Scenario link", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/scenarios")

      refute html =~ "New Scenario"
    end

    test "editor sees New Scenario link", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, _view, html} = live(conn, ~p"/scenarios")

      assert html =~ "New Scenario"
      assert html =~ ~s(href="/scenarios/new")
    end
  end

  # ── Handle Params ───────────────────────────────────────

  describe "handle_params for :new action" do
    test "navigating to /scenarios/new opens form modal for editors", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, _view, html} = live(conn, ~p"/scenarios/new")

      assert html =~ "modal-overlay"
      assert html =~ "New Scenario"
      assert html =~ ~s(phx-submit="save")
    end

    test "/scenarios does not show form", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, _view, html} = live(conn, ~p"/scenarios")

      refute html =~ "modal-overlay"
    end
  end

  # ── Show/Close Form ─────────────────────────────────────

  describe "show_form and close_form events" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "show_form opens the modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/scenarios")

      render_hook(view, "show_form", %{})
      html = render(view)

      assert html =~ "modal-overlay"
      assert html =~ "New Scenario"
      assert html =~ ~s(name="scenario[name]")
      assert html =~ ~s(name="scenario[description]")
      assert html =~ ~s(name="scenario[company_id]")
      assert html =~ ~s(name="scenario[base_period]")
      assert html =~ ~s(name="scenario[projection_months]")
    end

    test "close_form navigates back to /scenarios", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/scenarios/new")

      view |> element(~s(button[phx-click="close_form"]), "Cancel") |> render_click()

      # close_form pushes navigate to /scenarios
      assert_redirect(view, ~p"/scenarios")
    end
  end

  # ── Save Scenario ───────────────────────────────────────

  describe "save event" do
    test "creates a scenario and shows flash", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "ScenSaveCo"})

      {:ok, view, _html} = live(conn, ~p"/scenarios/new")

      view
      |> form(~s(form[phx-submit="save"]), %{
        "scenario" => %{
          "name" => "Best Case",
          "description" => "Optimistic projection",
          "company_id" => company.id,
          "projection_months" => "12"
        }
      })
      |> render_submit()

      # After save, push_navigate to /scenarios
      flash = assert_redirect(view, ~p"/scenarios")
      assert flash["info"] == "Scenario created"
    end

    test "viewer cannot save a scenario", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/scenarios")

      render_hook(view, "save", %{"scenario" => %{"name" => "Blocked"}})

      assert render(view) =~ "permission"
    end
  end

  # ── Delete Scenario ─────────────────────────────────────

  describe "delete event" do
    test "deletes a scenario", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      s = scenario_fixture(%{name: "ToDelete"})

      {:ok, view, html} = live(conn, ~p"/scenarios")
      assert html =~ "ToDelete"

      view |> element(~s(button[phx-click="delete"][phx-value-id="#{s.id}"])) |> render_click()

      html = render(view)
      assert html =~ "Scenario deleted"
      refute html =~ "ToDelete"
    end

    test "viewer cannot delete a scenario", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/scenarios")

      render_hook(view, "delete", %{"id" => "1"})
      assert render(view) =~ "permission"
    end
  end

  # ── Noop event ──────────────────────────────────────────

  describe "noop event" do
    test "noop does not change the page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/scenarios")

      render_hook(view, "noop", %{})
      assert render(view) =~ "Scenarios"
    end
  end

  # ── Save error ────────────────────────────────────────────

  describe "save error case" do
    test "save with invalid data shows error flash", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, view, _html} = live(conn, ~p"/scenarios/new")

      # Submit without a name (required field)
      view
      |> form(~s(form[phx-submit="save"]), %{
        "scenario" => %{
          "name" => "",
          "projection_months" => "12"
        }
      })
      |> render_submit()

      assert render(view) =~ "Failed to create scenario"
    end
  end

  # ── Status tag variants ──────────────────────────────────

  describe "status tags" do
    test "renders active status with tag-jade", %{conn: conn} do
      scenario_fixture(%{name: "Active Scen", status: "active"})

      {:ok, _view, html} = live(conn, ~p"/scenarios")

      assert html =~ "tag-jade"
      assert html =~ "active"
    end

    test "renders archived status with tag-ink", %{conn: conn} do
      scenario_fixture(%{name: "Archived Scen", status: "archived"})

      {:ok, _view, html} = live(conn, ~p"/scenarios")

      assert html =~ "tag-ink"
      assert html =~ "archived"
    end

    test "renders scenario with nil company as ---", %{conn: conn} do
      scenario_fixture(%{name: "No Company Scen", company_id: nil})

      {:ok, _view, html} = live(conn, ~p"/scenarios")

      assert html =~ "---"
    end
  end

  # ── PubSub handle_info ────────────────────────────────────

  describe "handle_info PubSub" do
    test "refreshes scenarios on PubSub message", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/scenarios")

      # Simulate a PubSub message
      send(view.pid, {:scenarios_created, %{}})

      html = render(view)
      assert html =~ "Scenarios"
    end
  end

  # ── Company dropdown in form ──────────────────────────────

  describe "form company dropdown" do
    test "form shows company options", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company_fixture(%{name: "FormDropCo"})

      {:ok, view, _html} = live(conn, ~p"/scenarios/new")

      html = render(view)
      assert html =~ "FormDropCo"
      assert html =~ "All companies"
    end
  end
end
