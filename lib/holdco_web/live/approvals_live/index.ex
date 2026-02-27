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
       show_vote_form: nil,
       show_votes_for: nil,
       table_names: @table_names,
       actions: @actions
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("show_form", _, socket), do: {:noreply, assign(socket, show_form: true)}
  def handle_event("close_form", _, socket), do: {:noreply, assign(socket, show_form: false)}

  def handle_event("show_vote_form", %{"id" => id}, socket),
    do: {:noreply, assign(socket, show_vote_form: String.to_integer(id))}

  def handle_event("close_vote_form", _, socket),
    do: {:noreply, assign(socket, show_vote_form: nil)}

  def handle_event("show_votes", %{"id" => id}, socket) do
    req_id = String.to_integer(id)
    current = socket.assigns.show_votes_for

    if current == req_id do
      {:noreply, assign(socket, show_votes_for: nil)}
    else
      {:noreply, assign(socket, show_votes_for: req_id)}
    end
  end

  # --- Permission Guards ---
  def handle_event("create_request", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to create requests")}

  def handle_event("cast_vote", _params, %{assigns: %{can_admin: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "Admin access required to cast votes")}

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

  # --- Cast Vote ---
  def handle_event("cast_vote", %{"vote" => vote_params}, socket) do
    user_id = socket.assigns.current_scope.user.id
    request_id = String.to_integer(vote_params["request_id"])
    decision = vote_params["decision"]
    notes = vote_params["notes"]

    case Platform.cast_vote(request_id, user_id, decision, notes) do
      {:ok, _vote} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Vote recorded: #{decision}")
         |> assign(show_vote_form: nil)}

      {:error, :already_decided} ->
        {:noreply, put_flash(socket, :error, "This request has already been decided")}

      {:error, %Ecto.Changeset{} = changeset} ->
        error_msg =
          case changeset.errors do
            [{:approval_request_id_user_id, _} | _] -> "You have already voted on this request"
            [{field, {msg, _}} | _] -> "#{field}: #{msg}"
            _ -> "Failed to cast vote"
          end

        {:noreply, put_flash(socket, :error, error_msg)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to cast vote")}
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

  defp vote_counts(request) do
    votes = request.votes || []
    approve_count = Enum.count(votes, &(&1.decision == "approved"))
    reject_count = Enum.count(votes, &(&1.decision == "rejected"))
    required = request.required_approvals || 1
    {approve_count, reject_count, required}
  end

  defp current_user_voted?(request, user_id) do
    Enum.any?(request.votes || [], &(&1.user_id == user_id))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <h1>Approvals</h1>
      <p class="deck">
        Review and manage approval requests for data changes across all entities.
        Requests require N-of-M votes before they are approved or rejected.
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
              <th>Votes</th>
              <th>Status</th>
              <th>Submitted</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for req <- @pending do %>
              <% {approve_count, reject_count, required} = vote_counts(req) %>
              <tr>
                <td class="td-mono">{req.requested_by}</td>
                <td><span class={"tag #{action_tag(req.action)}"}>{req.action}</span></td>
                <td>{req.table_name}</td>
                <td class="td-mono">{if req.record_id, do: "##{req.record_id}", else: "-"}</td>
                <td>{req.notes}</td>
                <td>
                  <span class="tag tag-jade">{approve_count}/{required} approved</span>
                  <%= if reject_count > 0 do %>
                    <span class="tag tag-crimson">{reject_count}/{required} rejected</span>
                  <% end %>
                  <button
                    phx-click="show_votes"
                    phx-value-id={req.id}
                    class="btn btn-sm btn-secondary"
                    style="margin-left: 4px; padding: 2px 6px; font-size: 0.75rem;"
                  >
                    <%= if @show_votes_for == req.id, do: "Hide", else: "Details" %>
                  </button>
                </td>
                <td><span class="tag tag-lemon">{req.status}</span></td>
                <td class="td-mono">{format_datetime(req.inserted_at)}</td>
                <td>
                  <%= if @can_admin do %>
                    <%= unless current_user_voted?(req, @current_scope.user.id) do %>
                      <button
                        phx-click="show_vote_form"
                        phx-value-id={req.id}
                        class="btn btn-sm btn-primary"
                      >
                        Cast Vote
                      </button>
                    <% else %>
                      <span style="color: #888; font-size: 0.85rem;">Voted</span>
                    <% end %>
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
              <%= if @show_votes_for == req.id do %>
                <tr>
                  <td colspan="9" style="background: #f8f9fa; padding: 12px 24px;">
                    <strong>Votes ({length(req.votes || [])} total) -- requires {required}:</strong>
                    <%= if (req.votes || []) == [] do %>
                      <div style="color: #888; margin-top: 4px;">No votes yet.</div>
                    <% else %>
                      <table style="margin-top: 8px; width: 100%;">
                        <thead>
                          <tr>
                            <th>Voter</th>
                            <th>Decision</th>
                            <th>Notes</th>
                            <th>Voted At</th>
                          </tr>
                        </thead>
                        <tbody>
                          <%= for vote <- req.votes || [] do %>
                            <tr>
                              <td class="td-mono">{if vote.user, do: vote.user.email, else: "User ##{vote.user_id}"}</td>
                              <td>
                                <span class={"tag #{if vote.decision == "approved", do: "tag-jade", else: "tag-crimson"}"}>
                                  {vote.decision}
                                </span>
                              </td>
                              <td>{vote.notes || "-"}</td>
                              <td class="td-mono">{format_datetime(vote.inserted_at)}</td>
                            </tr>
                          <% end %>
                        </tbody>
                      </table>
                    <% end %>
                  </td>
                </tr>
              <% end %>
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
              <th>Votes</th>
              <th>Status</th>
              <th>Reviewed By</th>
              <th>Reviewed At</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for req <- @approved ++ @rejected do %>
              <% {approve_count, reject_count, required} = vote_counts(req) %>
              <tr>
                <td class="td-mono">{req.requested_by}</td>
                <td><span class={"tag #{action_tag(req.action)}"}>{req.action}</span></td>
                <td>{req.table_name}</td>
                <td class="td-mono">{if req.record_id, do: "##{req.record_id}", else: "-"}</td>
                <td>{req.notes}</td>
                <td>
                  <span class="tag tag-jade">{approve_count} approved</span>
                  <%= if reject_count > 0 do %>
                    <span class="tag tag-crimson">{reject_count} rejected</span>
                  <% end %>
                  <span style="color: #888; font-size: 0.8rem;">(needed {required})</span>
                  <button
                    phx-click="show_votes"
                    phx-value-id={req.id}
                    class="btn btn-sm btn-secondary"
                    style="margin-left: 4px; padding: 2px 6px; font-size: 0.75rem;"
                  >
                    <%= if @show_votes_for == req.id, do: "Hide", else: "Details" %>
                  </button>
                </td>
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
              <%= if @show_votes_for == req.id do %>
                <tr>
                  <td colspan="10" style="background: #f8f9fa; padding: 12px 24px;">
                    <strong>Votes ({length(req.votes || [])} total):</strong>
                    <%= if (req.votes || []) == [] do %>
                      <div style="color: #888; margin-top: 4px;">No votes recorded.</div>
                    <% else %>
                      <table style="margin-top: 8px; width: 100%;">
                        <thead>
                          <tr>
                            <th>Voter</th>
                            <th>Decision</th>
                            <th>Notes</th>
                            <th>Voted At</th>
                          </tr>
                        </thead>
                        <tbody>
                          <%= for vote <- req.votes || [] do %>
                            <tr>
                              <td class="td-mono">{if vote.user, do: vote.user.email, else: "User ##{vote.user_id}"}</td>
                              <td>
                                <span class={"tag #{if vote.decision == "approved", do: "tag-jade", else: "tag-crimson"}"}>
                                  {vote.decision}
                                </span>
                              </td>
                              <td>{vote.notes || "-"}</td>
                              <td class="td-mono">{format_datetime(vote.inserted_at)}</td>
                            </tr>
                          <% end %>
                        </tbody>
                      </table>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            <% end %>
          </tbody>
        </table>
        <%= if @approved == [] and @rejected == [] do %>
          <div class="empty-state">No reviewed requests yet.</div>
        <% end %>
      </div>
    </div>

    <%!-- New Request Form Modal --%>
    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>New Approval Request</h3>
          </div>
          <div class="dialog-body">
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
                <label class="form-label">Required Approvals *</label>
                <input
                  type="number"
                  name="approval_request[required_approvals]"
                  class="form-input"
                  value="1"
                  min="1"
                  required
                  placeholder="Number of votes needed to approve or reject"
                />
                <p style="color: #888; font-size: 0.8rem; margin-top: 2px;">
                  How many approval (or rejection) votes are needed before the request is finalized.
                </p>
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

    <%!-- Cast Vote Modal --%>
    <%= if @show_vote_form do %>
      <div class="dialog-overlay" phx-click="close_vote_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>Cast Your Vote</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit="cast_vote">
              <input type="hidden" name="vote[request_id]" value={@show_vote_form} />
              <div class="form-group">
                <label class="form-label">Decision *</label>
                <select name="vote[decision]" class="form-select" required>
                  <option value="">Select decision...</option>
                  <option value="approved">Approve</option>
                  <option value="rejected">Reject</option>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Notes (optional)</label>
                <textarea
                  name="vote[notes]"
                  class="form-input"
                  rows="2"
                  placeholder="Reason for your decision..."
                ></textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Submit Vote</button>
                <button type="button" phx-click="close_vote_form" class="btn btn-secondary">Cancel</button>
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
