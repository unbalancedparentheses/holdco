defmodule HoldcoWeb.ApprovalsLiveIndexTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  # ── Mount & Render ──────────────────────────────────────

  describe "mount and render" do
    test "renders page title and deck", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/approvals")

      assert html =~ "<h1>Approvals</h1>"
      assert html =~ "Review and manage approval requests for data changes across all entities"
      assert html =~ "page-title-rule"
    end

    test "renders metrics strip with counts", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/approvals")

      assert html =~ "metrics-strip"
      assert html =~ "Pending"
      assert html =~ "Approved"
      assert html =~ "Rejected"
      assert html =~ "Total"
    end

    test "renders Pending Requests section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/approvals")

      assert html =~ "Pending Requests"
    end

    test "renders Reviewed Requests section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/approvals")

      assert html =~ "Reviewed Requests"
    end

    test "renders empty state when no pending requests", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/approvals")

      assert html =~ "No pending approval requests."
    end

    test "renders empty state when no reviewed requests", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/approvals")

      assert html =~ "No reviewed requests yet."
    end

    test "renders a pending approval request", %{conn: conn} do
      approval_request_fixture(%{
        requested_by: "alice@test.com",
        table_name: "companies",
        action: "create",
        notes: "Create new entity",
        status: "pending"
      })

      {:ok, _view, html} = live(conn, ~p"/approvals")

      assert html =~ "alice@test.com"
      assert html =~ "companies"
      assert html =~ "create"
      assert html =~ "Create new entity"
      assert html =~ "tag-lemon"
    end

    test "renders reviewed (approved) requests", %{conn: conn} do
      approval_request_fixture(%{
        requested_by: "bob@test.com",
        table_name: "holdings",
        action: "update",
        status: "approved",
        reviewed_by: "admin@test.com"
      })

      {:ok, _view, html} = live(conn, ~p"/approvals")

      assert html =~ "bob@test.com"
      assert html =~ "approved"
      assert html =~ "admin@test.com"
    end

    test "viewer cannot see New Request button", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/approvals")

      refute html =~ "New Request"
    end

    test "editor sees New Request button", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, _view, html} = live(conn, ~p"/approvals")

      assert html =~ "New Request"
    end
  end

  # ── Show/Close Form ─────────────────────────────────────

  describe "show_form and close_form events" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "show_form opens New Approval Request modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/approvals")

      html = view |> element("button", "New Request") |> render_click()

      assert html =~ "modal-overlay"
      assert html =~ "New Approval Request"
      assert html =~ ~s(phx-submit="create_request")
      assert html =~ ~s(name="approval_request[table_name]")
      assert html =~ ~s(name="approval_request[action]")
      assert html =~ ~s(name="approval_request[record_id]")
      assert html =~ ~s(name="approval_request[payload]")
      assert html =~ ~s(name="approval_request[notes]")
    end

    test "form shows table name options", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/approvals")

      html = view |> element("button", "New Request") |> render_click()

      assert html =~ "companies"
      assert html =~ "holdings"
      assert html =~ "transactions"
    end

    test "form shows action options", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/approvals")

      html = view |> element("button", "New Request") |> render_click()

      assert html =~ "create"
      assert html =~ "update"
      assert html =~ "delete"
    end

    test "close_form closes the modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/approvals")

      view |> element("button", "New Request") |> render_click()
      html = view |> element(~s(button[phx-click="close_form"]), "Cancel") |> render_click()

      refute html =~ "modal-overlay"
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
            "notes" => "Add new subsidiary"
          }
        })
        |> render_submit()

      assert html =~ "Approval request submitted"
      assert html =~ "Add new subsidiary"
      refute html =~ "modal-overlay"
    end

    test "viewer cannot create a request", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/approvals")

      render_hook(view, "create_request", %{"approval_request" => %{"table_name" => "companies", "action" => "create"}})
      assert render(view) =~ "permission"
    end
  end

  # ── Approve Request ─────────────────────────────────────

  describe "approve event" do
    test "admin approves a pending request", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "admin")
      req = approval_request_fixture(%{status: "pending", requested_by: "requester@test.com"})

      {:ok, view, _html} = live(conn, ~p"/approvals")

      view |> element(~s(button[phx-click="approve"][phx-value-id="#{req.id}"])) |> render_click()

      html = render(view)
      assert html =~ "Request approved"
    end

    test "non-admin cannot approve", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      req = approval_request_fixture(%{status: "pending"})

      {:ok, view, _html} = live(conn, ~p"/approvals")

      render_hook(view, "approve", %{"id" => to_string(req.id)})
      assert render(view) =~ "Admin access required"
    end
  end

  # ── Reject Request ──────────────────────────────────────

  describe "reject event" do
    test "admin rejects a pending request", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "admin")
      req = approval_request_fixture(%{status: "pending", requested_by: "requester@test.com"})

      {:ok, view, _html} = live(conn, ~p"/approvals")

      view |> element(~s(button[phx-click="reject"][phx-value-id="#{req.id}"])) |> render_click()

      html = render(view)
      assert html =~ "Request rejected"
    end

    test "non-admin cannot reject", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      req = approval_request_fixture(%{status: "pending"})

      {:ok, view, _html} = live(conn, ~p"/approvals")

      render_hook(view, "reject", %{"id" => to_string(req.id)})
      assert render(view) =~ "Admin access required"
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

    test "non-admin cannot delete", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      req = approval_request_fixture(%{status: "pending"})

      {:ok, view, _html} = live(conn, ~p"/approvals")

      render_hook(view, "delete_request", %{"id" => to_string(req.id)})
      assert render(view) =~ "Admin access required"
    end
  end

  # ── Admin sees approve/reject/delete buttons ────────────

  describe "admin visibility" do
    test "admin sees Approve and Reject buttons for pending requests", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "admin")
      approval_request_fixture(%{status: "pending", requested_by: "someone@test.com"})

      {:ok, _view, html} = live(conn, ~p"/approvals")

      assert html =~ "Approve"
      assert html =~ "Reject"
      assert html =~ "Del"
    end

    test "non-admin does not see Approve/Reject buttons", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      approval_request_fixture(%{status: "pending", requested_by: "someone@test.com"})

      {:ok, _view, html} = live(conn, ~p"/approvals")

      refute html =~ ~s(phx-click="approve")
      refute html =~ ~s(phx-click="reject")
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
    test "renders rejected request in reviewed section", %{conn: conn} do
      approval_request_fixture(%{
        requested_by: "rejected@test.com",
        table_name: "holdings",
        action: "delete",
        status: "rejected",
        reviewed_by: "reviewer@test.com"
      })

      {:ok, _view, html} = live(conn, ~p"/approvals")

      assert html =~ "rejected@test.com"
      assert html =~ "rejected"
      assert html =~ "reviewer@test.com"
    end

    test "renders request with record_id", %{conn: conn} do
      approval_request_fixture(%{
        requested_by: "record@test.com",
        table_name: "companies",
        action: "update",
        record_id: 42,
        status: "pending"
      })

      {:ok, _view, html} = live(conn, ~p"/approvals")

      assert html =~ "#42"
    end

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

    test "action tags render correctly for delete action", %{conn: conn} do
      approval_request_fixture(%{
        requested_by: "delaction@test.com",
        table_name: "companies",
        action: "delete",
        status: "pending"
      })

      {:ok, _view, html} = live(conn, ~p"/approvals")

      assert html =~ "tag-crimson"
    end

    test "action tags render correctly for update action", %{conn: conn} do
      approval_request_fixture(%{
        requested_by: "updaction@test.com",
        table_name: "companies",
        action: "update",
        status: "pending"
      })

      {:ok, _view, html} = live(conn, ~p"/approvals")

      assert html =~ "tag-lemon"
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

    test "status tags render correctly for approved, rejected, and unknown", %{conn: conn} do
      approval_request_fixture(%{
        requested_by: "approved@test.com",
        table_name: "companies",
        action: "create",
        status: "approved"
      })

      approval_request_fixture(%{
        requested_by: "rejected2@test.com",
        table_name: "companies",
        action: "create",
        status: "rejected"
      })

      {:ok, _view, html} = live(conn, ~p"/approvals")

      assert html =~ "tag-jade"
      assert html =~ "tag-crimson"
    end
  end
end
