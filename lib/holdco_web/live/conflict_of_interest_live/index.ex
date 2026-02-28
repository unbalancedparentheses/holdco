defmodule HoldcoWeb.ConflictOfInterestLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.Governance
  alias Holdco.Corporate
  alias Holdco.Governance.ConflictOfInterest

  @impl true
  def mount(_params, _session, socket) do
    companies = Corporate.list_companies()
    conflicts = Governance.list_conflicts_of_interest()
    active = Governance.active_conflicts()
    summary = Governance.conflict_summary()

    {:ok,
     assign(socket,
       page_title: "Conflicts of Interest",
       companies: companies,
       conflicts: conflicts,
       active: active,
       summary: summary,
       selected_company_id: "",
       show_form: false,
       editing_item: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("filter_company", %{"company_id" => id}, socket) do
    company_id = if id == "", do: nil, else: String.to_integer(id)
    conflicts = Governance.list_conflicts_of_interest(company_id)
    active = Governance.active_conflicts(company_id)
    summary = Governance.conflict_summary(company_id)

    {:noreply,
     assign(socket,
       selected_company_id: id,
       conflicts: conflicts,
       active: active,
       summary: summary
     )}
  end

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: :add, editing_item: nil)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false, editing_item: nil)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    coi = Governance.get_conflict_of_interest!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: coi)}
  end

  def handle_event("save", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("update", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("delete", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("save", %{"conflict_of_interest" => params}, socket) do
    case Governance.create_conflict_of_interest(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Conflict of interest declared")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add conflict of interest")}
    end
  end

  def handle_event("update", %{"conflict_of_interest" => params}, socket) do
    coi = socket.assigns.editing_item

    case Governance.update_conflict_of_interest(coi, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Conflict of interest updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update conflict of interest")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    coi = Governance.get_conflict_of_interest!(String.to_integer(id))

    case Governance.delete_conflict_of_interest(coi) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Conflict of interest deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete conflict of interest")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Conflict of Interest Register</h1>
          <p class="deck">Declare, review, and manage conflicts of interest</p>
        </div>
        <div style="display: flex; gap: 0.5rem; align-items: center;">
          <form phx-change="filter_company" style="display: flex; align-items: center; gap: 0.5rem;">
            <label class="form-label" style="margin: 0; font-size: 0.85rem;">Company</label>
            <select name="company_id" class="form-select" style="width: auto; padding: 0.3rem 0.5rem;">
              <option value="">All Companies</option>
              <%= for c <- @companies do %>
                <option value={c.id} selected={to_string(c.id) == @selected_company_id}>{c.name}</option>
              <% end %>
            </select>
          </form>
          <%= if @can_write do %>
            <button class="btn btn-primary" phx-click="show_form">Declare Conflict</button>
          <% end %>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Declarations</div>
        <div class="metric-value">{length(@conflicts)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Active Conflicts</div>
        <div class="metric-value num-negative">{length(@active)}</div>
      </div>
    </div>

    <%= if @summary.by_status != [] do %>
      <div class="section">
        <div class="section-head"><h2>Summary by Status</h2></div>
        <div class="panel">
          <table>
            <thead>
              <tr><th>Status</th><th class="th-num">Count</th></tr>
            </thead>
            <tbody>
              <%= for row <- @summary.by_status do %>
                <tr>
                  <td><span class={"tag #{coi_status_tag(row.status)}"}>{humanize(row.status)}</span></td>
                  <td class="td-num">{row.count}</td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    <% end %>

    <div class="section">
      <div class="section-head"><h2>All Declarations</h2></div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Declarant</th><th>Role</th><th>Conflict Type</th><th>Status</th>
              <th>Declared</th><th>Review Date</th><th>Reviewer</th><th></th>
            </tr>
          </thead>
          <tbody>
            <%= for coi <- @conflicts do %>
              <tr>
                <td class="td-name">{coi.declarant_name}</td>
                <td><span class="tag tag-sky">{humanize(coi.declarant_role)}</span></td>
                <td>{humanize(coi.conflict_type)}</td>
                <td><span class={"tag #{coi_status_tag(coi.status)}"}>{humanize(coi.status)}</span></td>
                <td class="td-mono">{coi.declared_date}</td>
                <td class="td-mono">{coi.review_date || "---"}</td>
                <td>{coi.reviewer_name || "---"}</td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit" phx-value-id={coi.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete" phx-value-id={coi.id} class="btn btn-danger btn-sm" data-confirm="Delete this declaration?">Del</button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @conflicts == [] do %>
          <div class="empty-state">
            <p>No conflict of interest declarations found.</p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_form">Declare Your First Conflict</button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit Conflict of Interest", else: "Declare Conflict of Interest"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="conflict_of_interest[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={@editing_item && @editing_item.company_id == c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Declarant Name *</label>
                <input type="text" name="conflict_of_interest[declarant_name]" class="form-input" value={if @editing_item, do: @editing_item.declarant_name, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Declarant Role *</label>
                <select name="conflict_of_interest[declarant_role]" class="form-select" required>
                  <option value="">Select</option>
                  <%= for r <- ConflictOfInterest.declarant_roles() do %>
                    <option value={r} selected={@editing_item && @editing_item.declarant_role == r}>{humanize(r)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Conflict Type *</label>
                <select name="conflict_of_interest[conflict_type]" class="form-select" required>
                  <option value="">Select</option>
                  <%= for t <- ConflictOfInterest.conflict_types() do %>
                    <option value={t} selected={@editing_item && @editing_item.conflict_type == t}>{humanize(t)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Description *</label>
                <textarea name="conflict_of_interest[description]" class="form-input" required>{if @editing_item, do: @editing_item.description, else: ""}</textarea>
              </div>
              <div class="form-group">
                <label class="form-label">Parties Involved</label>
                <input type="text" name="conflict_of_interest[parties_involved]" class="form-input" value={if @editing_item, do: @editing_item.parties_involved, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Potential Impact</label>
                <input type="text" name="conflict_of_interest[potential_impact]" class="form-input" value={if @editing_item, do: @editing_item.potential_impact, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Declared Date *</label>
                <input type="date" name="conflict_of_interest[declared_date]" class="form-input" value={if @editing_item, do: @editing_item.declared_date, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Status</label>
                <select name="conflict_of_interest[status]" class="form-select">
                  <%= for s <- ConflictOfInterest.statuses() do %>
                    <option value={s} selected={@editing_item && @editing_item.status == s}>{humanize(s)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Mitigation Plan</label>
                <textarea name="conflict_of_interest[mitigation_plan]" class="form-input">{if @editing_item, do: @editing_item.mitigation_plan, else: ""}</textarea>
              </div>
              <div class="form-group">
                <label class="form-label">Reviewer Name</label>
                <input type="text" name="conflict_of_interest[reviewer_name]" class="form-input" value={if @editing_item, do: @editing_item.reviewer_name, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Review Date</label>
                <input type="date" name="conflict_of_interest[review_date]" class="form-input" value={if @editing_item, do: @editing_item.review_date, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Review Notes</label>
                <textarea name="conflict_of_interest[review_notes]" class="form-input">{if @editing_item, do: @editing_item.review_notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">{if @show_form == :edit, do: "Update", else: "Declare Conflict"}</button>
                <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp reload(socket) do
    company_id = case socket.assigns.selected_company_id do
      "" -> nil
      id -> String.to_integer(id)
    end

    conflicts = Governance.list_conflicts_of_interest(company_id)
    active = Governance.active_conflicts(company_id)
    summary = Governance.conflict_summary(company_id)
    assign(socket, conflicts: conflicts, active: active, summary: summary)
  end

  defp humanize(str), do: str |> String.replace("_", " ") |> String.split(" ") |> Enum.map(&String.capitalize/1) |> Enum.join(" ")

  defp coi_status_tag("declared"), do: "tag-lemon"
  defp coi_status_tag("under_review"), do: "tag-lemon"
  defp coi_status_tag("approved"), do: "tag-jade"
  defp coi_status_tag("mitigated"), do: "tag-jade"
  defp coi_status_tag("ongoing"), do: "tag-sky"
  defp coi_status_tag("resolved"), do: "tag-jade"
  defp coi_status_tag(_), do: ""
end
