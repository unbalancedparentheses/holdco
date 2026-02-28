defmodule HoldcoWeb.BcpLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Compliance, Corporate}
  alias Holdco.Compliance.BcpPlan

  @impl true
  def mount(_params, _session, socket) do
    companies = Corporate.list_companies()
    plans = Compliance.list_bcp_plans()
    due_for_testing = Compliance.plans_due_for_testing()

    {:ok,
     assign(socket,
       page_title: "Business Continuity Planning",
       companies: companies,
       plans: plans,
       due_for_testing: due_for_testing,
       show_form: false,
       editing_item: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: :add, editing_item: nil)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false, editing_item: nil)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    plan = Compliance.get_bcp_plan!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: plan)}
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

  def handle_event("save", %{"bcp_plan" => params}, socket) do
    case Compliance.create_bcp_plan(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "BCP plan created")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create BCP plan")}
    end
  end

  def handle_event("update", %{"bcp_plan" => params}, socket) do
    plan = socket.assigns.editing_item

    case Compliance.update_bcp_plan(plan, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "BCP plan updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update BCP plan")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    plan = Compliance.get_bcp_plan!(String.to_integer(id))

    case Compliance.delete_bcp_plan(plan) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "BCP plan deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete BCP plan")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Business Continuity Planning</h1>
          <p class="deck">DR, BCP, pandemic, and incident response plans</p>
        </div>
        <%= if @can_write do %>
          <button class="btn btn-primary" phx-click="show_form">Add Plan</button>
        <% end %>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Plans</div>
        <div class="metric-value">{length(@plans)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Active</div>
        <div class="metric-value">{Enum.count(@plans, &(&1.status == "active"))}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Due for Testing</div>
        <div class="metric-value num-negative">{length(@due_for_testing)}</div>
      </div>
    </div>

    <%= if @due_for_testing != [] do %>
      <div class="section">
        <div class="section-head"><h2>Plans Due for Testing</h2></div>
        <div class="panel">
          <table>
            <thead>
              <tr><th>Company</th><th>Plan</th><th>Type</th><th>Next Test Date</th><th>Last Result</th></tr>
            </thead>
            <tbody>
              <%= for p <- @due_for_testing do %>
                <tr>
                  <td>{if p.company, do: p.company.name, else: "---"}</td>
                  <td class="td-name">{p.plan_name}</td>
                  <td><span class="tag tag-sky">{humanize(p.plan_type)}</span></td>
                  <td class="td-mono">{p.next_test_date}</td>
                  <td><span class={"tag #{test_result_tag(p.test_result)}"}>{humanize(p.test_result)}</span></td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    <% end %>

    <div class="section">
      <div class="section-head"><h2>All BCP Plans</h2></div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Company</th><th>Plan Name</th><th>Type</th><th>Version</th>
              <th>Status</th><th>Test Result</th><th>RTO (hrs)</th><th>RPO (hrs)</th><th></th>
            </tr>
          </thead>
          <tbody>
            <%= for p <- @plans do %>
              <tr>
                <td>{if p.company, do: p.company.name, else: "---"}</td>
                <td class="td-name">{p.plan_name}</td>
                <td><span class="tag tag-sky">{humanize(p.plan_type)}</span></td>
                <td>{p.version || "---"}</td>
                <td><span class={"tag #{bcp_status_tag(p.status)}"}>{humanize(p.status)}</span></td>
                <td><span class={"tag #{test_result_tag(p.test_result)}"}>{humanize(p.test_result)}</span></td>
                <td class="td-num">{p.rto_hours || "---"}</td>
                <td class="td-num">{p.rpo_hours || "---"}</td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit" phx-value-id={p.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete" phx-value-id={p.id} class="btn btn-danger btn-sm" data-confirm="Delete this plan?">Del</button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @plans == [] do %>
          <div class="empty-state">
            <p>No BCP plans found.</p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_form">Add Your First Plan</button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit BCP Plan", else: "Add BCP Plan"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="bcp_plan[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={@editing_item && @editing_item.company_id == c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Plan Name *</label>
                <input type="text" name="bcp_plan[plan_name]" class="form-input" value={if @editing_item, do: @editing_item.plan_name, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Plan Type *</label>
                <select name="bcp_plan[plan_type]" class="form-select" required>
                  <%= for t <- BcpPlan.plan_types() do %>
                    <option value={t} selected={@editing_item && @editing_item.plan_type == t}>{humanize(t)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Version</label>
                <input type="text" name="bcp_plan[version]" class="form-input" value={if @editing_item, do: @editing_item.version, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Status</label>
                <select name="bcp_plan[status]" class="form-select">
                  <%= for s <- BcpPlan.statuses() do %>
                    <option value={s} selected={@editing_item && @editing_item.status == s}>{humanize(s)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Approved By</label>
                <input type="text" name="bcp_plan[approved_by]" class="form-input" value={if @editing_item, do: @editing_item.approved_by, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Approved Date</label>
                <input type="date" name="bcp_plan[approved_date]" class="form-input" value={if @editing_item, do: @editing_item.approved_date, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Next Test Date</label>
                <input type="date" name="bcp_plan[next_test_date]" class="form-input" value={if @editing_item, do: @editing_item.next_test_date, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Test Result</label>
                <select name="bcp_plan[test_result]" class="form-select">
                  <%= for r <- BcpPlan.test_results() do %>
                    <option value={r} selected={@editing_item && @editing_item.test_result == r}>{humanize(r)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">RTO (hours)</label>
                <input type="number" name="bcp_plan[rto_hours]" class="form-input" value={if @editing_item, do: @editing_item.rto_hours, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">RPO (hours)</label>
                <input type="number" name="bcp_plan[rpo_hours]" class="form-input" value={if @editing_item, do: @editing_item.rpo_hours, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="bcp_plan[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">{if @show_form == :edit, do: "Update Plan", else: "Add Plan"}</button>
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
    plans = Compliance.list_bcp_plans()
    due_for_testing = Compliance.plans_due_for_testing()
    assign(socket, plans: plans, due_for_testing: due_for_testing)
  end

  defp humanize(str), do: str |> String.replace("_", " ") |> String.split(" ") |> Enum.map(&String.capitalize/1) |> Enum.join(" ")

  defp bcp_status_tag("draft"), do: "tag-lemon"
  defp bcp_status_tag("approved"), do: "tag-sky"
  defp bcp_status_tag("active"), do: "tag-jade"
  defp bcp_status_tag("under_review"), do: "tag-lemon"
  defp bcp_status_tag("retired"), do: ""
  defp bcp_status_tag(_), do: ""

  defp test_result_tag("passed"), do: "tag-jade"
  defp test_result_tag("partial"), do: "tag-lemon"
  defp test_result_tag("failed"), do: "tag-rose"
  defp test_result_tag("not_tested"), do: ""
  defp test_result_tag(_), do: ""
end
