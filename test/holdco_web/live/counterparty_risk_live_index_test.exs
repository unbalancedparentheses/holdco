defmodule HoldcoWeb.CounterpartyRiskLiveIndexTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "Index" do
    test "renders Counterparty Risk page", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/counterparty-risk")
      assert html =~ "Counterparty Risk"
      assert html =~ "Monitor counterparty exposures, credit risk, and concentration"
    end

    test "shows metrics strip", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/counterparty-risk")
      assert html =~ "Total Exposure"
      assert html =~ "Avg Risk Score"
      assert html =~ "Watchlist"
      assert html =~ "Concentration Warnings"
    end

    test "shows exposures table with headers", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/counterparty-risk")
      assert html =~ "Counterparty"
      assert html =~ "Credit Rating"
      assert html =~ "Risk Score"
    end

    test "shows empty state when no exposures", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/counterparty-risk")
      assert html =~ "No counterparty exposures tracked yet"
    end

    test "shows concentration by type section", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/counterparty-risk")
      assert html =~ "Concentration by Type"
    end

    test "opens add exposure form", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/counterparty-risk")
      html = render_click(live, "show_form")
      assert html =~ "Add Exposure"
      assert html =~ "Counterparty Name"
    end
  end

  describe "exposure data display" do
    test "displays counterparty exposure in the table", %{conn: conn} do
      _exposure = counterparty_exposure_fixture(%{counterparty_name: "Big Bank Corp", status: "active", credit_rating: "AA"})

      {:ok, _live, html} = live(conn, ~p"/counterparty-risk")
      assert html =~ "Big Bank Corp"
      assert html =~ "AA"
      assert html =~ "active"
    end
  end

  describe "show_form and close_form events" do
    test "show_form opens the add form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/counterparty-risk")
      html = render_click(view, "show_form", %{})
      assert html =~ "Add Exposure"
      assert html =~ "Counterparty Name"
      assert html =~ "Exposure Amount"
    end

    test "close_form closes the form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/counterparty-risk")
      render_click(view, "show_form", %{})
      html = render_click(view, "close_form", %{})
      # The dialog-overlay should be gone when form is closed
      refute html =~ "dialog-overlay"
    end
  end

  describe "filter_company event" do
    test "filters exposures by company", %{conn: conn} do
      company = company_fixture(%{name: "Filter Test Co"})
      counterparty_exposure_fixture(%{company: company, counterparty_name: "Filtered Counterparty"})

      {:ok, view, _html} = live(conn, ~p"/counterparty-risk")
      html = render_change(view, "filter_company", %{"company_id" => to_string(company.id)})
      assert html =~ "Filtered Counterparty"
    end

    test "filters with empty company_id shows all", %{conn: conn} do
      counterparty_exposure_fixture(%{counterparty_name: "All Counterparty"})

      {:ok, view, _html} = live(conn, ~p"/counterparty-risk")
      html = render_change(view, "filter_company", %{"company_id" => ""})
      assert html =~ "All Counterparty"
    end
  end

  describe "edit event" do
    test "opens edit form with existing data", %{conn: conn} do
      exposure = counterparty_exposure_fixture(%{counterparty_name: "Edit Me Corp"})

      {:ok, view, _html} = live(conn, ~p"/counterparty-risk")
      html = render_click(view, "edit", %{"id" => to_string(exposure.id)})
      assert html =~ "Edit Exposure"
      assert html =~ "Edit Me Corp"
    end
  end

  describe "save event" do
    test "creates a new counterparty exposure", %{conn: conn} do
      company = company_fixture()

      {:ok, view, _html} = live(conn, ~p"/counterparty-risk")
      render_click(view, "show_form", %{})

      html =
        render_click(view, "save", %{
          "exposure" => %{
            "counterparty_name" => "New Counterparty",
            "counterparty_type" => "bank",
            "exposure_amount" => "500000",
            "currency" => "USD",
            "credit_rating" => "A",
            "status" => "active",
            "company_id" => to_string(company.id)
          }
        })

      assert html =~ "Counterparty exposure created"
    end

    test "save with invalid data shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/counterparty-risk")
      render_click(view, "show_form", %{})

      html =
        render_click(view, "save", %{
          "exposure" => %{"counterparty_name" => ""}
        })

      assert html =~ "Failed to create counterparty exposure"
    end
  end

  describe "update event" do
    test "updates an existing counterparty exposure", %{conn: conn} do
      exposure = counterparty_exposure_fixture(%{counterparty_name: "Update Me"})

      {:ok, view, _html} = live(conn, ~p"/counterparty-risk")
      render_click(view, "edit", %{"id" => to_string(exposure.id)})

      html =
        render_click(view, "update", %{
          "exposure" => %{
            "counterparty_name" => "Updated Counterparty",
            "credit_rating" => "BBB"
          }
        })

      assert html =~ "Counterparty exposure updated"
    end
  end

  describe "delete event" do
    test "deletes a counterparty exposure", %{conn: conn} do
      exposure = counterparty_exposure_fixture(%{counterparty_name: "Delete Me Corp"})

      {:ok, view, _html} = live(conn, ~p"/counterparty-risk")
      html = render_click(view, "delete", %{"id" => to_string(exposure.id)})
      assert html =~ "Counterparty exposure deleted"
    end
  end

  describe "noop event" do
    test "noop does not change the page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/counterparty-risk")
      html = render_click(view, "noop", %{})
      assert html =~ "Counterparty Risk"
    end
  end
end
