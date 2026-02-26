defmodule HoldcoWeb.ApprovalsLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.Platform

  @table_names ~w(
    companies holdings transactions bank_accounts documents
    asset_holdings fund_investments real_estate_properties crypto_wallets
    dividends inter_company_transfers key_personnel
    regulatory_filings regulatory_licenses insurance_policies
    sanctions_checks esg_scores fatca_reports withholding_taxes
    settings categories webhooks backup_configs
  )

  @actions ~w(create update delete)

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Platform.subscribe("platform")

    requests = Platform.list_approval_requests()

    {:ok,
     assign(socket,
       page_title: "Approvals",
       requests: requests,
       pending: Enum.filter(requests, &(&1.status == "pending")),
       approved: Enum.filter(requests, &(&1.status == "approved")),
       rejected: Enum.filter(requests, &(&1.status == "rejected")),
       show_form: false,
       table_names: @table_names,
       actions: @actions
     )}
  end

  @impl true
  def handle_event("show_form", _, socket), do: {:noreply, assign(socket, show_form: true)}
  def handle_event("close_form", _, socket), do: {:noreply, assign(socket, show_form: false)}

  # --- Permission Guards ---
  def handle_event("create_request", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to create requests")}

  def handle_event("approve", _params, %{assigns: %{can_admin: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "Admin access required to approve requests")}

  def handle_event("reject", _params, %{assigns: %{can_admin: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "Admin access required to reject requests")}

  def handle_event("delete_request", _params, %{assigns: %{can_admin: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "Admin access required to delete requests")}

  # --- Create Request ---
  def handle_event("create_request", %{"approval_request" => params}, socket) do
    user_email = socket.assigns.current_scope.user.email

    attrs =
      params
      |> Map.put("requested_by", user_email)
      |> Map.put("status", "pending")

    case Platform.create_approval_request(attrs) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Approval request submitted")
         |> assign(show_form: false)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create approval request")}
    end
  end

  # --- Approve ---
  def handle_event("approve", %{"id" => id}, socket) do
    request = Platform.get_approval_request!(String.to_integer(id))
    reviewer = socket.assigns.current_scope.user.email

    case Platform.update_approval_request(request, %{
           status: "approved",
           reviewed_by: reviewer,
           reviewed_at: DateTime.utc_now()
         }) do
      {:ok, _} ->
        {:noreply, reload(socket) |> put_flash(:info, "Request approved")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to approve request")}
    end
  end

  # --- Reject ---
  def handle_event("reject", %{"id" => id}, socket) do
    request = Platform.get_approval_request!(String.to_integer(id))
    reviewer = socket.assigns.current_scope.user.email

    case Platform.update_approval_request(request, %{
           status: "rejected",
           reviewed_by: reviewer,
           reviewed_at: DateTime.utc_now()
         }) do
      {:ok, _} ->
        {:noreply, reload(socket) |> put_flash(:info, "Request rejected")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to reject request")}
    end
  end

  # --- Delete ---
  def handle_event("delete_request", %{"id" => id}, socket) do
    request = Platform.get_approval_request!(String.to_integer(id))
    Platform.delete_approval_request(request)
    {:noreply, reload(socket) |> put_flash(:info, "Request deleted")}
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, reload(socket)}

  defp reload(socket) do
    requests = Platform.list_approval_requests()

    assign(socket,
      requests: requests,
      pending: Enum.filter(requests, &(&1.status == "pending")),
      approved: Enum.filter(requests, &(&1.status == "approved")),
      rejected: Enum.filter(requests, &(&1.status == "rejected"))
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <h1>Approvals</h1>
      <p class="deck">
        Review and manage approval requests for data changes across all entities
      </p>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Pending</div>
        <div class="metric-value">{length(@pending)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Approved</div>
        <div class="metric-value">{length(@approved)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Rejected</div>
        <div class="metric-value">{length(@rejected)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Total</div>
        <div class="metric-value">{length(@requests)}</div>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Pending Requests</h2>
        <span class="count">{length(@pending)} pending</span>
        <%= if @can_write do %>
          <button class="btn btn-sm btn-primary" phx-click="show_form">New Request</button>
        <% end %>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Requested By</th>
              <th>Action</th>
              <th>Table</th>
              <th>Record</th>
              <th>Notes</th>
              <th>Status</th>
              <th>Submitted</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for req <- @pending do %>
              <tr>
                <td class="td-mono">{req.requested_by}</td>
                <td><span class={"tag #{action_tag(req.action)}"}>{req.action}</span></td>
                <td>{req.table_name}</td>
                <td class="td-mono">{if req.record_id, do: "##{req.record_id}", else: "-"}</td>
                <td>{req.notes}</td>
                <td><span class="tag tag-lemon">{req.status}</span></td>
                <td class="td-mono">{format_datetime(req.inserted_at)}</td>
                <td>
                  <%= if @can_admin do %>
                    <button
                      phx-click="approve"
                      phx-value-id={req.id}
                      class="btn btn-sm"
                      style="background: #00994d; color: #fff;"
                      data-confirm="Approve this request?"
                    >
                      Approve
                    </button>
                    <button
                      phx-click="reject"
                      phx-value-id={req.id}
                      class="btn btn-danger btn-sm"
                      data-confirm="Reject this request?"
                    >
                      Reject
                    </button>
                  <% end %>
                  <%= if @can_admin do %>
                    <button
                      phx-click="delete_request"
                      phx-value-id={req.id}
                      class="btn btn-danger btn-sm"
                      data-confirm="Delete this request permanently?"
                    >
                      Del
                    </button>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @pending == [] do %>
          <div class="empty-state">No pending approval requests.</div>
        <% end %>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Reviewed Requests</h2>
        <span class="count">{length(@approved) + length(@rejected)} reviewed</span>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Requested By</th>
              <th>Action</th>
              <th>Table</th>
              <th>Record</th>
              <th>Notes</th>
              <th>Status</th>
              <th>Reviewed By</th>
              <th>Reviewed At</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for req <- @approved ++ @rejected do %>
              <tr>
                <td class="td-mono">{req.requested_by}</td>
                <td><span class={"tag #{action_tag(req.action)}"}>{req.action}</span></td>
                <td>{req.table_name}</td>
                <td class="td-mono">{if req.record_id, do: "##{req.record_id}", else: "-"}</td>
                <td>{req.notes}</td>
                <td><span class={"tag #{status_tag(req.status)}"}>{req.status}</span></td>
                <td class="td-mono">{req.reviewed_by}</td>
                <td class="td-mono">{format_datetime(req.reviewed_at)}</td>
                <td>
                  <%= if @can_admin do %>
                    <button
                      phx-click="delete_request"
                      phx-value-id={req.id}
                      class="btn btn-danger btn-sm"
                      data-confirm="Delete this request permanently?"
                    >
                      Del
                    </button>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @approved == [] and @rejected == [] do %>
          <div class="empty-state">No reviewed requests yet.</div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="modal-overlay">
        <div class="modal" phx-click-away="close_form">
          <div class="modal-header">
            <h3>New Approval Request</h3>
          </div>
          <div class="modal-body">
            <form phx-submit="create_request">
              <div class="form-group">
                <label class="form-label">Table *</label>
                <select name="approval_request[table_name]" class="form-select" required>
                  <option value="">Select table...</option>
                  <%= for t <- @table_names do %>
                    <option value={t}>{t}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Action *</label>
                <select name="approval_request[action]" class="form-select" required>
                  <option value="">Select action...</option>
                  <%= for a <- @actions do %>
                    <option value={a}>{a}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Record ID</label>
                <input
                  type="number"
                  name="approval_request[record_id]"
                  class="form-input"
                  placeholder="ID of record (for update/delete)"
                />
              </div>
              <div class="form-group">
                <label class="form-label">Payload (JSON)</label>
                <textarea
                  name="approval_request[payload]"
                  class="form-input"
                  rows="3"
                  placeholder="{}"
                >{}</textarea>
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea
                  name="approval_request[notes]"
                  class="form-input"
                  rows="2"
                  placeholder="Describe the change you are requesting..."
                ></textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Submit Request</button>
                <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp format_datetime(nil), do: ""
  defp format_datetime(dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")

  defp status_tag("pending"), do: "tag-lemon"
  defp status_tag("approved"), do: "tag-jade"
  defp status_tag("rejected"), do: "tag-crimson"
  defp status_tag(_), do: "tag-ink"

  defp action_tag("create"), do: "tag-jade"
  defp action_tag("update"), do: "tag-lemon"
  defp action_tag("delete"), do: "tag-crimson"
  defp action_tag(_), do: "tag-ink"
end
