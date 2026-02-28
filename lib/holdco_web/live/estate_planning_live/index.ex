defmodule HoldcoWeb.EstatePlanningLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.Governance
  alias Holdco.Corporate
  alias Holdco.Governance.{EstatePlan, SuccessionPlan}

  @impl true
  def mount(_params, _session, socket) do
    companies = Corporate.list_companies()
    charters = Governance.list_family_charters()
    estate_plans = Governance.list_estate_plans()
    succession_plans = Governance.list_succession_plans()
    plans_due = Governance.plans_due_for_review()

    {:ok,
     assign(socket,
       page_title: "Estate & Succession Planning",
       companies: companies,
       charters: charters,
       estate_plans: estate_plans,
       succession_plans: succession_plans,
       plans_due: plans_due,
       show_form: false,
       show_sp_form: false,
       editing_item: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: :add, editing_item: nil)}
  end

  def handle_event("show_sp_form", _, socket) do
    {:noreply, assign(socket, show_sp_form: :add, editing_item: nil)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false, show_sp_form: false, editing_item: nil)}
  end

  def handle_event("edit_estate", %{"id" => id}, socket) do
    plan = Governance.get_estate_plan!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: plan)}
  end

  def handle_event("edit_succession", %{"id" => id}, socket) do
    plan = Governance.get_succession_plan!(String.to_integer(id))
    {:noreply, assign(socket, show_sp_form: :edit, editing_item: plan)}
  end

  def handle_event("save", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("update", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("delete_estate", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("delete_succession", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("save_sp", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("update_sp", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("save", %{"estate_plan" => params}, socket) do
    case Governance.create_estate_plan(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Estate plan created")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create estate plan")}
    end
  end

  def handle_event("update", %{"estate_plan" => params}, socket) do
    plan = socket.assigns.editing_item

    case Governance.update_estate_plan(plan, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Estate plan updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update estate plan")}
    end
  end

  def handle_event("delete_estate", %{"id" => id}, socket) do
    plan = Governance.get_estate_plan!(String.to_integer(id))

    case Governance.delete_estate_plan(plan) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Estate plan deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete estate plan")}
    end
  end

  def handle_event("save_sp", %{"succession_plan" => params}, socket) do
    case Governance.create_succession_plan(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Succession plan created")
         |> assign(show_sp_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create succession plan")}
    end
  end

  def handle_event("update_sp", %{"succession_plan" => params}, socket) do
    plan = socket.assigns.editing_item

    case Governance.update_succession_plan(plan, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Succession plan updated")
         |> assign(show_sp_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update succession plan")}
    end
  end

  def handle_event("delete_succession", %{"id" => id}, socket) do
    plan = Governance.get_succession_plan!(String.to_integer(id))

    case Governance.delete_succession_plan(plan) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Succession plan deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete succession plan")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Estate & Succession Planning</h1>
          <p class="deck">Manage estate plans, wills, and succession planning</p>
        </div>
        <%= if @can_write do %>
          <div style="display: flex; gap: 0.5rem;">
            <button class="btn btn-primary" phx-click="show_form">Add Estate Plan</button>
            <button class="btn btn-primary" phx-click="show_sp_form">Add Succession Plan</button>
          </div>
        <% end %>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Estate Plans</div>
        <div class="metric-value">{length(@estate_plans)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Succession Plans</div>
        <div class="metric-value">{length(@succession_plans)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Due for Review</div>
        <div class="metric-value num-negative">{length(@plans_due)}</div>
      </div>
    </div>

    <%= if @plans_due != [] do %>
      <div class="section">
        <div class="section-head"><h2>Plans Due for Review</h2></div>
        <div class="panel">
          <table>
            <thead><tr><th>Plan Name</th><th>Type</th><th>Review Date</th><th>Status</th></tr></thead>
            <tbody>
              <%= for p <- @plans_due do %>
                <tr>
                  <td class="td-name">{p.plan_name}</td>
                  <td><span class="tag tag-sky">{humanize(p.plan_type)}</span></td>
                  <td class="td-mono">{p.next_review_date}</td>
                  <td><span class={"tag #{estate_status_tag(p.status)}"}>{humanize(p.status)}</span></td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    <% end %>

    <div class="section">
      <div class="section-head"><h2>Estate Plans</h2></div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Plan Name</th><th>Type</th><th>Principal</th><th>Attorney</th>
              <th>Status</th><th>Effective Date</th><th>Next Review</th><th></th>
            </tr>
          </thead>
          <tbody>
            <%= for p <- @estate_plans do %>
              <tr>
                <td class="td-name">{p.plan_name}</td>
                <td><span class="tag tag-sky">{humanize(p.plan_type)}</span></td>
                <td>{p.principal_name}</td>
                <td>{p.attorney_name || "---"}</td>
                <td><span class={"tag #{estate_status_tag(p.status)}"}>{humanize(p.status)}</span></td>
                <td class="td-mono">{p.effective_date || "---"}</td>
                <td class="td-mono">{p.next_review_date || "---"}</td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit_estate" phx-value-id={p.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete_estate" phx-value-id={p.id} class="btn btn-danger btn-sm" data-confirm="Delete this estate plan?">Del</button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @estate_plans == [] do %>
          <div class="empty-state">
            <p>No estate plans found.</p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_form">Add Your First Estate Plan</button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <div class="section">
      <div class="section-head"><h2>Succession Plans</h2></div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Position</th><th>Current Holder</th><th>Timeline</th>
              <th>Candidates</th><th>Status</th><th>Next Review</th><th></th>
            </tr>
          </thead>
          <tbody>
            <%= for sp <- @succession_plans do %>
              <tr>
                <td class="td-name">{sp.position_title}</td>
                <td>{sp.current_holder}</td>
                <td><span class={"tag #{timeline_tag(sp.timeline)}"}>{humanize(sp.timeline)}</span></td>
                <td>{length(sp.successor_candidates || [])}</td>
                <td><span class={"tag #{sp_status_tag(sp.status)}"}>{humanize(sp.status)}</span></td>
                <td class="td-mono">{sp.next_review_date || "---"}</td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit_succession" phx-value-id={sp.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete_succession" phx-value-id={sp.id} class="btn btn-danger btn-sm" data-confirm="Delete this succession plan?">Del</button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @succession_plans == [] do %>
          <div class="empty-state">
            <p>No succession plans found.</p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_sp_form">Add Your First Succession Plan</button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit Estate Plan", else: "Add Estate Plan"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Family Charter (optional)</label>
                <select name="estate_plan[family_charter_id]" class="form-select">
                  <option value="">None</option>
                  <%= for c <- @charters do %>
                    <option value={c.id} selected={@editing_item && @editing_item.family_charter_id == c.id}>{c.family_name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Plan Name *</label>
                <input type="text" name="estate_plan[plan_name]" class="form-input" value={if @editing_item, do: @editing_item.plan_name, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Plan Type *</label>
                <select name="estate_plan[plan_type]" class="form-select" required>
                  <option value="">Select type</option>
                  <%= for t <- EstatePlan.plan_types() do %>
                    <option value={t} selected={@editing_item && @editing_item.plan_type == t}>{humanize(t)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Principal Name *</label>
                <input type="text" name="estate_plan[principal_name]" class="form-input" value={if @editing_item, do: @editing_item.principal_name, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Attorney Name</label>
                <input type="text" name="estate_plan[attorney_name]" class="form-input" value={if @editing_item, do: @editing_item.attorney_name, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Executor Name</label>
                <input type="text" name="estate_plan[executor_name]" class="form-input" value={if @editing_item, do: @editing_item.executor_name, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Status</label>
                <select name="estate_plan[status]" class="form-select">
                  <%= for s <- EstatePlan.statuses() do %>
                    <option value={s} selected={@editing_item && @editing_item.status == s}>{humanize(s)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Effective Date</label>
                <input type="date" name="estate_plan[effective_date]" class="form-input" value={if @editing_item, do: @editing_item.effective_date, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Next Review Date</label>
                <input type="date" name="estate_plan[next_review_date]" class="form-input" value={if @editing_item, do: @editing_item.next_review_date, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Estimated Estate Value</label>
                <input type="number" name="estate_plan[estimated_estate_value]" class="form-input" step="0.01" value={if @editing_item && @editing_item.estimated_estate_value, do: Decimal.to_string(@editing_item.estimated_estate_value), else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Key Provisions</label>
                <textarea name="estate_plan[key_provisions]" class="form-input" rows="3">{if @editing_item, do: @editing_item.key_provisions, else: ""}</textarea>
              </div>
              <div class="form-group">
                <label class="form-label">Tax Implications</label>
                <textarea name="estate_plan[tax_implications]" class="form-input">{if @editing_item, do: @editing_item.tax_implications, else: ""}</textarea>
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="estate_plan[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">{if @show_form == :edit, do: "Update", else: "Add Estate Plan"}</button>
                <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>

    <%= if @show_sp_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_sp_form == :edit, do: "Edit Succession Plan", else: "Add Succession Plan"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_sp_form == :edit, do: "update_sp", else: "save_sp"}>
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="succession_plan[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={@editing_item && @editing_item.company_id == c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Position Title *</label>
                <input type="text" name="succession_plan[position_title]" class="form-input" value={if @editing_item, do: @editing_item.position_title, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Current Holder *</label>
                <input type="text" name="succession_plan[current_holder]" class="form-input" value={if @editing_item, do: @editing_item.current_holder, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Timeline</label>
                <select name="succession_plan[timeline]" class="form-select">
                  <%= for t <- SuccessionPlan.timelines() do %>
                    <option value={t} selected={@editing_item && @editing_item.timeline == t}>{humanize(t)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Status</label>
                <select name="succession_plan[status]" class="form-select">
                  <%= for s <- SuccessionPlan.statuses() do %>
                    <option value={s} selected={@editing_item && @editing_item.status == s}>{humanize(s)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Next Review Date</label>
                <input type="date" name="succession_plan[next_review_date]" class="form-input" value={if @editing_item, do: @editing_item.next_review_date, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="succession_plan[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">{if @show_sp_form == :edit, do: "Update", else: "Add Succession Plan"}</button>
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
    estate_plans = Governance.list_estate_plans()
    succession_plans = Governance.list_succession_plans()
    plans_due = Governance.plans_due_for_review()
    assign(socket, estate_plans: estate_plans, succession_plans: succession_plans, plans_due: plans_due)
  end

  defp humanize(str), do: str |> String.replace("_", " ") |> String.split(" ") |> Enum.map(&String.capitalize/1) |> Enum.join(" ")

  defp estate_status_tag("draft"), do: "tag-lemon"
  defp estate_status_tag("executed"), do: "tag-jade"
  defp estate_status_tag("filed"), do: "tag-jade"
  defp estate_status_tag("superseded"), do: ""
  defp estate_status_tag("revoked"), do: ""
  defp estate_status_tag(_), do: ""

  defp sp_status_tag("active"), do: "tag-jade"
  defp sp_status_tag("triggered"), do: "tag-lemon"
  defp sp_status_tag("completed"), do: "tag-sky"
  defp sp_status_tag("archived"), do: ""
  defp sp_status_tag(_), do: ""

  defp timeline_tag("immediate"), do: "tag-lemon"
  defp timeline_tag("short_term"), do: "tag-sky"
  defp timeline_tag("long_term"), do: "tag-jade"
  defp timeline_tag(_), do: ""
end
