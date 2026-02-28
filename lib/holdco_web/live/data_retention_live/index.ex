defmodule HoldcoWeb.DataRetentionLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.Platform

  @tabs ~w(policies requests)
  @data_categories ~w(personal_data financial_records audit_logs communications documents analytics)
  @legal_bases ~w(consent contract legal_obligation legitimate_interest public_interest)
  @actions_on_expiry ~w(delete anonymize archive)
  @request_types ~w(erasure portability access rectification)
  @request_statuses ~w(pending in_progress completed denied)

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Platform.subscribe("platform")

    {:ok,
     socket
     |> assign(
       page_title: "Data Retention & GDPR",
       tabs: @tabs,
       active_tab: "policies",
       data_categories: @data_categories,
       legal_bases: @legal_bases,
       actions_on_expiry: @actions_on_expiry,
       request_types: @request_types,
       request_statuses: @request_statuses,
       policies: Platform.list_data_retention_policies(),
       requests: Platform.list_data_deletion_requests(),
       show_form: false,
       editing_item: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("switch_tab", %{"tab" => tab}, socket) when tab in @tabs do
    {:noreply, assign(socket, active_tab: tab, show_form: false, editing_item: nil)}
  end

  def handle_event("show_form", _, socket),
    do: {:noreply, assign(socket, show_form: true, editing_item: nil)}

  def handle_event("close_form", _, socket),
    do: {:noreply, assign(socket, show_form: false, editing_item: nil)}

  def handle_event("edit_policy", %{"id" => id}, socket) do
    policy = Platform.get_data_retention_policy!(String.to_integer(id))
    {:noreply, assign(socket, show_form: true, editing_item: policy)}
  end

  # --- Permission Guards ---
  def handle_event("save_policy", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete_policy", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("save_request", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("process_request", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("save_policy", %{"policy" => params}, socket) do
    result =
      case socket.assigns.editing_item do
        nil -> Platform.create_data_retention_policy(params)
        policy -> Platform.update_data_retention_policy(policy, params)
      end

    case result do
      {:ok, _} ->
        action = if socket.assigns.editing_item, do: "updated", else: "created"
        {:noreply,
         socket
         |> put_flash(:info, "Policy #{action} successfully")
         |> assign(show_form: false, editing_item: nil)
         |> reload_data()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to save policy. Check required fields.")}
    end
  end

  def handle_event("delete_policy", %{"id" => id}, socket) do
    policy = Platform.get_data_retention_policy!(String.to_integer(id))
    {:ok, _} = Platform.delete_data_retention_policy(policy)

    {:noreply,
     socket
     |> put_flash(:info, "Policy deleted")
     |> reload_data()}
  end

  def handle_event("save_request", %{"request" => params}, socket) do
    case Platform.create_data_deletion_request(params) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Deletion request created")
         |> assign(show_form: false)
         |> reload_data()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create request.")}
    end
  end

  def handle_event("process_request", %{"id" => id, "status" => status}, socket) do
    request = Platform.get_data_deletion_request!(String.to_integer(id))
    user_id = socket.assigns.current_scope.user.id

    case Platform.process_deletion_request(request, %{status: status, processed_by_id: user_id}) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Request #{status}")
         |> reload_data()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to process request.")}
    end
  end

  @impl true
  def handle_info({event, _record}, socket) when event in [
    :data_retention_policies_created, :data_retention_policies_updated, :data_retention_policies_deleted,
    :data_deletion_requests_created, :data_deletion_requests_updated, :data_deletion_requests_deleted
  ] do
    {:noreply, reload_data(socket)}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  defp reload_data(socket) do
    assign(socket,
      policies: Platform.list_data_retention_policies(),
      requests: Platform.list_data_deletion_requests()
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-header">
      <h1>Data Retention & GDPR</h1>
      <button phx-click="show_form" class="btn btn-primary">
        <%= if @active_tab == "policies", do: "+ Add Policy", else: "+ New Request" %>
      </button>
    </div>

    <div class="tabs">
      <%= for tab <- @tabs do %>
        <button phx-click="switch_tab" phx-value-tab={tab}
          class={"tab #{if @active_tab == tab, do: "tab-active"}"}>
          <%= String.capitalize(tab) %>
        </button>
      <% end %>
    </div>

    <%= if @active_tab == "policies" do %>
      <div class="table-container">
        <table class="data-table">
          <thead>
            <tr>
              <th>Name</th>
              <th>Category</th>
              <th>Retention (days)</th>
              <th>Legal Basis</th>
              <th>Action</th>
              <th>Active</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            <%= for policy <- @policies do %>
              <tr>
                <td><%= policy.name %></td>
                <td><span class={"tag #{category_tag(policy.data_category)}"}><%= policy.data_category %></span></td>
                <td><%= policy.retention_period_days %></td>
                <td><%= policy.legal_basis %></td>
                <td><%= policy.action_on_expiry %></td>
                <td><span class={"tag #{if policy.is_active, do: "tag-jade", else: "tag-crimson"}"}><%= if policy.is_active, do: "Active", else: "Inactive" %></span></td>
                <td>
                  <button phx-click="edit_policy" phx-value-id={policy.id} class="btn btn-xs">Edit</button>
                  <button phx-click="delete_policy" phx-value-id={policy.id} data-confirm="Delete this policy?" class="btn btn-xs btn-danger">Delete</button>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    <% end %>

    <%= if @active_tab == "requests" do %>
      <div class="table-container">
        <table class="data-table">
          <thead>
            <tr>
              <th>Email</th>
              <th>Type</th>
              <th>Status</th>
              <th>Categories</th>
              <th>Submitted</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            <%= for req <- @requests do %>
              <tr>
                <td><%= req.requested_by_email %></td>
                <td><span class="tag tag-ink"><%= req.request_type %></span></td>
                <td><span class={"tag #{request_status_tag(req.status)}"}><%= req.status %></span></td>
                <td><%= Enum.join(req.data_categories || [], ", ") %></td>
                <td><%= format_datetime(req.inserted_at) %></td>
                <td>
                  <%= if req.status == "pending" do %>
                    <button phx-click="process_request" phx-value-id={req.id} phx-value-status="in_progress" class="btn btn-xs btn-primary">Process</button>
                    <button phx-click="process_request" phx-value-id={req.id} phx-value-status="denied" class="btn btn-xs btn-danger">Deny</button>
                  <% end %>
                  <%= if req.status == "in_progress" do %>
                    <button phx-click="process_request" phx-value-id={req.id} phx-value-status="completed" class="btn btn-xs btn-primary">Complete</button>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    <% end %>

    <%= if @show_form && @active_tab == "policies" do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click="noop">
          <div class="modal-header">
            <h2><%= if @editing_item, do: "Edit Policy", else: "New Policy" %></h2>
            <button phx-click="close_form" class="btn-close">&times;</button>
          </div>
          <form phx-submit="save_policy">
            <div class="form-group">
              <label class="form-label">Name *</label>
              <input type="text" name="policy[name]" class="form-input" required
                value={if @editing_item, do: @editing_item.name, else: ""} />
            </div>
            <div class="form-group">
              <label class="form-label">Description</label>
              <textarea name="policy[description]" class="form-input" rows="2"><%= if @editing_item, do: @editing_item.description, else: "" %></textarea>
            </div>
            <div class="form-group">
              <label class="form-label">Data Category *</label>
              <select name="policy[data_category]" class="form-select" required>
                <option value="">Select...</option>
                <%= for c <- @data_categories do %>
                  <option value={c} selected={@editing_item && @editing_item.data_category == c}><%= c %></option>
                <% end %>
              </select>
            </div>
            <div class="form-group">
              <label class="form-label">Retention Period (days) *</label>
              <input type="number" name="policy[retention_period_days]" class="form-input" required min="1"
                value={if @editing_item, do: @editing_item.retention_period_days, else: ""} />
            </div>
            <div class="form-group">
              <label class="form-label">Legal Basis *</label>
              <select name="policy[legal_basis]" class="form-select" required>
                <option value="">Select...</option>
                <%= for b <- @legal_bases do %>
                  <option value={b} selected={@editing_item && @editing_item.legal_basis == b}><%= b %></option>
                <% end %>
              </select>
            </div>
            <div class="form-group">
              <label class="form-label">Action on Expiry *</label>
              <select name="policy[action_on_expiry]" class="form-select" required>
                <option value="">Select...</option>
                <%= for a <- @actions_on_expiry do %>
                  <option value={a} selected={@editing_item && @editing_item.action_on_expiry == a}><%= a %></option>
                <% end %>
              </select>
            </div>
            <div class="form-group">
              <label class="form-label">Notes</label>
              <textarea name="policy[notes]" class="form-input" rows="2"><%= if @editing_item, do: @editing_item.notes, else: "" %></textarea>
            </div>
            <div class="form-actions">
              <button type="submit" class="btn btn-primary">
                <%= if @editing_item, do: "Update", else: "Create" %>
              </button>
              <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
            </div>
          </form>
        </div>
      </div>
    <% end %>

    <%= if @show_form && @active_tab == "requests" do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click="noop">
          <div class="modal-header">
            <h2>New Deletion Request</h2>
            <button phx-click="close_form" class="btn-close">&times;</button>
          </div>
          <form phx-submit="save_request">
            <div class="form-group">
              <label class="form-label">Requested By Email *</label>
              <input type="email" name="request[requested_by_email]" class="form-input" required />
            </div>
            <div class="form-group">
              <label class="form-label">Request Type *</label>
              <select name="request[request_type]" class="form-select" required>
                <option value="">Select...</option>
                <%= for t <- @request_types do %>
                  <option value={t}><%= t %></option>
                <% end %>
              </select>
            </div>
            <div class="form-group">
              <label class="form-label">Reason</label>
              <textarea name="request[reason]" class="form-input" rows="2"></textarea>
            </div>
            <div class="form-group">
              <label class="form-label">Notes</label>
              <textarea name="request[notes]" class="form-input" rows="2"></textarea>
            </div>
            <div class="form-actions">
              <button type="submit" class="btn btn-primary">Submit Request</button>
              <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
            </div>
          </form>
        </div>
      </div>
    <% end %>
    """
  end

  defp format_datetime(nil), do: "-"
  defp format_datetime(dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")

  defp category_tag("personal_data"), do: "tag-crimson"
  defp category_tag("financial_records"), do: "tag-jade"
  defp category_tag("audit_logs"), do: "tag-ink"
  defp category_tag("communications"), do: "tag-lemon"
  defp category_tag("documents"), do: "tag-ink"
  defp category_tag("analytics"), do: "tag-jade"
  defp category_tag(_), do: "tag-ink"

  defp request_status_tag("pending"), do: "tag-lemon"
  defp request_status_tag("in_progress"), do: "tag-ink"
  defp request_status_tag("completed"), do: "tag-jade"
  defp request_status_tag("denied"), do: "tag-crimson"
  defp request_status_tag(_), do: "tag-ink"
end
