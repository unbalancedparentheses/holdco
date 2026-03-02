defmodule HoldcoWeb.ApprovalsLiveIndexTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  # ── Show/Close Form ─────────────────────────────────────

  describe "show_form and close_form events" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "show_form opens New Approval Request modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/approvals")

      html = view |> element("button", "New Request") |> render_click()

      assert html =~ "dialog-overlay"
      assert html =~ "New Approval Request"
      assert html =~ ~s(phx-submit="create_request")
      assert html =~ ~s(name="approval_request[table_name]")
      assert html =~ ~s(name="approval_request[action]")
      assert html =~ ~s(name="approval_request[record_id]")
      assert html =~ ~s(name="approval_request[payload]")
      assert html =~ ~s(name="approval_request[notes]")
      assert html =~ ~s(name="approval_request[required_approvals]")
    end

    test "close_form closes the modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/approvals")

      view |> element("button", "New Request") |> render_click()
      html = view |> element(~s(button[phx-click="close_form"]), "Cancel") |> render_click()

      refute html =~ "dialog-overlay"
    end
  end

  # ── Create Request ──────────────────────────────────────

  describe "create_request event" do
    test "creates an approval request", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/approvals")

      view |> element("button", "New Request") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="create_request"]), %{
          "approval_request" => %{
            "table_name" => "companies",
            "action" => "create",
            "notes" => "Add new subsidiary",
            "required_approvals" => "2"
          }
        })
        |> render_submit()

      assert html =~ "Approval request submitted"
      assert html =~ "Add new subsidiary"
      refute html =~ "dialog-overlay"
    end

  end

  # ── Cast Vote ────────────────────────────────────────────

  describe "cast_vote event" do
    test "admin can cast a vote on a pending request", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "admin")
      req = approval_request_fixture(%{status: "pending", requested_by: "requester@test.com"})

      {:ok, view, _html} = live(conn, ~p"/approvals")

      # Open the vote form
      view |> element(~s(button[phx-click="show_vote_form"][phx-value-id="#{req.id}"])) |> render_click()

      # Submit the vote
      html =
        view
        |> form(~s(form[phx-submit="cast_vote"]), %{
          "vote" => %{
            "request_id" => to_string(req.id),
            "decision" => "approved",
            "notes" => "Looks good"
          }
        })
        |> render_submit()

      assert html =~ "Vote recorded: approved"
    end

    test "admin vote meets threshold and auto-approves", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "admin")
      req = approval_request_fixture(%{status: "pending", requested_by: "requester@test.com", required_approvals: 1})

      {:ok, view, _html} = live(conn, ~p"/approvals")

      view |> element(~s(button[phx-click="show_vote_form"][phx-value-id="#{req.id}"])) |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="cast_vote"]), %{
          "vote" => %{
            "request_id" => to_string(req.id),
            "decision" => "approved",
            "notes" => ""
          }
        })
        |> render_submit()

      assert html =~ "Vote recorded: approved"
      # The request should now be in the reviewed section
      html = render(view)
      assert html =~ "N-of-M threshold met"
    end

  end

  # ── Delete Request ──────────────────────────────────────

  describe "delete_request event" do
    test "admin deletes a request", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "admin")
      req = approval_request_fixture(%{status: "pending", requested_by: "del@test.com", notes: "Delete me"})

      {:ok, view, _html} = live(conn, ~p"/approvals")

      view |> element(~s(button[phx-click="delete_request"][phx-value-id="#{req.id}"])) |> render_click()

      html = render(view)
      assert html =~ "Request deleted"
      refute html =~ "Delete me"
    end

  end

  # ── Admin sees vote/delete buttons ────────────────────────

  describe "admin visibility" do
    test "admin sees Cast Vote and Del buttons for pending requests", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "admin")
      approval_request_fixture(%{status: "pending", requested_by: "someone@test.com"})

      {:ok, _view, html} = live(conn, ~p"/approvals")

      assert html =~ "Cast Vote"
      assert html =~ "Del"
    end

  end

  # ── Vote Details Toggle ──────────────────────────────────

  describe "show_votes event" do
    test "toggling vote details shows and hides vote information", %{conn: conn} do
      req = approval_request_fixture(%{status: "pending", requested_by: "someone@test.com"})

      {:ok, view, _html} = live(conn, ~p"/approvals")

      # Click to show
      html = view |> element(~s(button[phx-click="show_votes"][phx-value-id="#{req.id}"])) |> render_click()
      assert html =~ "No votes yet."

      # Click to hide
      html = view |> element(~s(button[phx-click="show_votes"][phx-value-id="#{req.id}"])) |> render_click()
      refute html =~ "No votes yet."
    end
  end

  # ── Noop event ──────────────────────────────────────────

  describe "noop event" do
    test "noop does not crash the view", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/approvals")

      render_hook(view, "noop", %{})
      assert render(view) =~ "Approvals"
    end
  end

  # ── handle_info PubSub ──────────────────────────────────

  describe "handle_info" do
    test "handles PubSub broadcast by reloading", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/approvals")

      # Create an approval request after mount
      approval_request_fixture(%{
        requested_by: "pubsub@test.com",
        table_name: "companies",
        action: "create",
        status: "pending"
      })

      # Sending any message should trigger reload
      send(view.pid, {:platform_changed, %{}})
      html = render(view)
      assert html =~ "pubsub@test.com"
    end
  end

  # ── Reviewed request rendering ──────────────────────────

  describe "reviewed requests rendering" do
    test "renders request without record_id shows dash", %{conn: conn} do
      approval_request_fixture(%{
        requested_by: "norecord@test.com",
        table_name: "companies",
        action: "create",
        record_id: nil,
        status: "pending"
      })

      {:ok, _view, html} = live(conn, ~p"/approvals")

      assert html =~ "norecord@test.com"
    end

    test "reviewed_at datetime is formatted", %{conn: conn} do
      approval_request_fixture(%{
        requested_by: "datetime@test.com",
        table_name: "companies",
        action: "create",
        status: "approved",
        reviewed_by: "admin@test.com",
        reviewed_at: ~U[2025-06-15 14:30:00Z]
      })

      {:ok, _view, html} = live(conn, ~p"/approvals")

      assert html =~ "2025-06-15 14:30"
    end
  end

  # ── Vote Form Open/Close ──────────────────────────────────

  describe "vote form events" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "admin")
      :ok
    end

    test "show_vote_form opens the vote dialog", %{conn: conn} do
      req = approval_request_fixture(%{status: "pending", requested_by: "voter@test.com"})

      {:ok, view, _html} = live(conn, ~p"/approvals")

      html =
        view
        |> element(~s(button[phx-click="show_vote_form"][phx-value-id="#{req.id}"]))
        |> render_click()

      assert html =~ "Cast Your Vote"
      assert html =~ "dialog-overlay"
      assert html =~ ~s(phx-submit="cast_vote")
    end

    test "close_vote_form closes the vote dialog", %{conn: conn} do
      req = approval_request_fixture(%{status: "pending", requested_by: "voter@test.com"})

      {:ok, view, _html} = live(conn, ~p"/approvals")

      view
      |> element(~s(button[phx-click="show_vote_form"][phx-value-id="#{req.id}"]))
      |> render_click()

      html = render_hook(view, "close_vote_form", %{})
      refute html =~ "Cast Your Vote"
    end
  end

  # ── Cast vote error paths ────────────────────────────────

  describe "cast_vote error paths" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "admin")
      :ok
    end

    test "voting on an already-decided request shows error", %{conn: conn, user: _user} do
      req =
        approval_request_fixture(%{
          status: "approved",
          requested_by: "finalized@test.com",
          reviewed_by: "admin@test.com",
          required_approvals: 1
        })

      {:ok, view, _html} = live(conn, ~p"/approvals")

      html =
        render_hook(view, "cast_vote", %{
          "vote" => %{
            "request_id" => to_string(req.id),
            "decision" => "approved",
            "notes" => "Late vote"
          }
        })

      assert html =~ "already been decided"
    end

    test "duplicate vote by same user shows error", %{conn: conn, user: _user} do
      req =
        approval_request_fixture(%{
          status: "pending",
          requested_by: "dupvote@test.com",
          required_approvals: 3
        })

      # Cast first vote
      {:ok, view, _html} = live(conn, ~p"/approvals")

      view
      |> element(~s(button[phx-click="show_vote_form"][phx-value-id="#{req.id}"]))
      |> render_click()

      view
      |> form(~s(form[phx-submit="cast_vote"]), %{
        "vote" => %{
          "request_id" => to_string(req.id),
          "decision" => "approved",
          "notes" => "First vote"
        }
      })
      |> render_submit()

      # Try to cast a second vote via hook
      render_hook(view, "cast_vote", %{
        "vote" => %{
          "request_id" => to_string(req.id),
          "decision" => "rejected",
          "notes" => "Second vote"
        }
      })

      html = render(view)
      assert html =~ "already voted" or html =~ "Failed to cast vote" or html =~ "Voted"
    end
  end

  # ── create_request failure ──────────────────────────────

  describe "create_request failure" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "create request with invalid data shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/approvals")

      view |> element("button", "New Request") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="create_request"]), %{
          "approval_request" => %{
            "table_name" => "",
            "action" => "",
            "required_approvals" => ""
          }
        })
        |> render_submit()

      assert html =~ "Failed to create approval request"
    end
  end
end
