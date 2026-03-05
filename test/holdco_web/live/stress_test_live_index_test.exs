defmodule HoldcoWeb.StressTestLiveIndexTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "show_form and close_form" do
    test "show_form opens the new stress test dialog", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/stress-test")
      html = render_click(view, "show_form")
      assert html =~ "New Stress Test"
      assert html =~ "Name *"
      assert html =~ "Quick Scenarios"
    end

    test "close_form hides the dialog", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/stress-test")
      render_click(view, "show_form")
      html = render_click(view, "close_form")
      refute html =~ "dialog-overlay"
    end
  end

  describe "apply_scenario" do
    test "applying a predefined scenario populates the form", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/stress-test")
      render_click(view, "show_form")

      # Apply the first predefined scenario (Crypto Crash)
      html = render_click(view, "apply_scenario", %{"index" => "0"})
      assert html =~ "Crypto Crash"
    end
  end

  describe "add_shock and remove_shock" do
    test "add_shock adds a new shock row", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/stress-test")
      render_click(view, "show_form")

      html = render_click(view, "add_shock")
      # After adding a shock, the form should have a remove button
      assert html =~ "X"
    end

    test "remove_shock removes a shock row", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/stress-test")
      render_click(view, "show_form")

      # Add and then remove
      render_click(view, "add_shock")
      html = render_click(view, "remove_shock", %{"index" => "0"})
      # The form should still render
      assert html =~ "New Stress Test"
    end
  end

  describe "update_shock" do
    test "update_shock updates a shock value", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/stress-test")
      render_click(view, "show_form")
      render_click(view, "add_shock")

      html =
        render_click(view, "update_shock", %{
          "index" => "0",
          "field" => "key",
          "value" => "equity"
        })

      assert html =~ "New Stress Test"
    end
  end

  describe "save (create)" do
    test "creating a stress test with valid data", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/stress-test")
      render_click(view, "show_form")

      html =
        render_click(view, "save", %{
          "stress_test" => %{
            "name" => "My Custom Stress Test",
            "description" => "Testing equity crash"
          }
        })

      assert html =~ "Stress test created"
      assert html =~ "My Custom Stress Test"
    end

    test "creating a stress test with missing name shows error", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/stress-test")
      render_click(view, "show_form")

      html =
        render_click(view, "save", %{
          "stress_test" => %{
            "name" => "",
            "description" => ""
          }
        })

      assert html =~ "Failed to create stress test"
    end
  end

  describe "run" do
    test "running a stress test completes it", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      st = stress_test_fixture(%{name: "Runnable Test"})

      {:ok, view, _html} = live(conn, ~p"/stress-test")
      html = render_click(view, "run", %{"id" => to_string(st.id)})
      assert html =~ "Stress test completed"
    end
  end

  describe "show_results and close_results" do
    test "show_results opens results modal for completed test", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      st = stress_test_fixture(%{name: "Completed Test"})

      # Run the test first so it has results
      {:ok, completed_st} = Holdco.Analytics.run_stress_test(st)

      {:ok, view, _html} = live(conn, ~p"/stress-test")
      html = render_click(view, "show_results", %{"id" => to_string(completed_st.id)})
      assert html =~ "Results: Completed Test"
    end

    test "close_results hides the results modal", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      st = stress_test_fixture(%{name: "Close Results Test"})
      {:ok, _completed_st} = Holdco.Analytics.run_stress_test(st)

      {:ok, view, _html} = live(conn, ~p"/stress-test")
      render_click(view, "show_results", %{"id" => to_string(st.id)})
      html = render_click(view, "close_results")
      refute html =~ "Results: Close Results Test"
    end
  end

  describe "delete" do
    test "deleting a stress test removes it", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      st = stress_test_fixture(%{name: "Doomed Stress Test"})

      {:ok, view, _html} = live(conn, ~p"/stress-test")
      assert render(view) =~ "Doomed Stress Test"

      html = render_click(view, "delete", %{"id" => to_string(st.id)})
      assert html =~ "Stress test deleted"
      refute html =~ "Doomed Stress Test"
    end
  end

  describe "handle_info" do
    test "pubsub message triggers reload", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/stress-test")

      stress_test_fixture(%{name: "PubSub Stress Test"})

      send(view.pid, {:analytics_changed, %{}})
      html = render(view)
      assert html =~ "PubSub Stress Test"
    end
  end
end
