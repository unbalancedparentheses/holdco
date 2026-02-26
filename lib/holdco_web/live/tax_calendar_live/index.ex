defmodule HoldcoWeb.TaxCalendarLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Compliance, Corporate}

  @impl true
  def mount(_params, _session, socket) do
    deadlines = Compliance.list_tax_deadlines()
    annual_filings = Compliance.list_annual_filings()
    companies = Corporate.list_companies()

    pending = Enum.count(deadlines, &(&1.status == "pending"))
    overdue = Enum.count(deadlines, &(&1.status == "overdue"))

    {:ok, assign(socket,
      page_title: "Tax Calendar",
      deadlines: deadlines,
      annual_filings: annual_filings,
      companies: companies,
      pending: pending,
      overdue: overdue,
      show_form: false
    )}
  end

  @impl true
  def handle_event("show_form", _, socket), do: {:noreply, assign(socket, show_form: true)}
  def handle_event("close_form", _, socket), do: {:noreply, assign(socket, show_form: false)}

  def handle_event("save", %{"tax_deadline" => params}, socket) do
    case Compliance.create_tax_deadline(params) do
      {:ok, _} ->
        deadlines = Compliance.list_tax_deadlines()
        pending = Enum.count(deadlines, &(&1.status == "pending"))
        overdue = Enum.count(deadlines, &(&1.status == "overdue"))
        {:noreply, assign(socket, deadlines: deadlines, pending: pending, overdue: overdue, show_form: false) |> put_flash(:info, "Deadline added")}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add deadline")}
    end
  end

  def handle_event("mark_complete", %{"id" => id}, socket) do
    Compliance.update_tax_deadline(id, %{status: "completed"})
    deadlines = Compliance.list_tax_deadlines()
    pending = Enum.count(deadlines, &(&1.status == "pending"))
    overdue = Enum.count(deadlines, &(&1.status == "overdue"))
    {:noreply, assign(socket, deadlines: deadlines, pending: pending, overdue: overdue) |> put_flash(:info, "Marked as completed")}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    tax_deadline = Compliance.get_tax_deadline!(String.to_integer(id))
    Compliance.delete_tax_deadline(tax_deadline)
    deadlines = Compliance.list_tax_deadlines()
    pending = Enum.count(deadlines, &(&1.status == "pending"))
    overdue = Enum.count(deadlines, &(&1.status == "overdue"))
    {:noreply, assign(socket, deadlines: deadlines, pending: pending, overdue: overdue) |> put_flash(:info, "Deadline deleted")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Tax Calendar</h1>
          <p class="deck">Tax deadlines, annual filings, and compliance checklists</p>
        </div>
        <button class="btn btn-primary" phx-click="show_form">Add Deadline</button>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Deadlines</div>
        <div class="metric-value"><%= length(@deadlines) %></div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Pending</div>
        <div class="metric-value"><%= @pending %></div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Overdue</div>
        <div class="metric-value num-negative"><%= @overdue %></div>
      </div>
    </div>

    <div class="section">
      <div class="section-head"><h2>Tax Deadlines</h2></div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Due Date</th>
              <th>Jurisdiction</th>
              <th>Description</th>
              <th>Company</th>
              <th>Status</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for td <- @deadlines do %>
              <tr>
                <td class="td-mono"><%= td.due_date %></td>
                <td><%= td.jurisdiction %></td>
                <td class="td-name"><%= td.description %></td>
                <td><%= if td.company, do: td.company.name, else: "---" %></td>
                <td><span class={"tag #{status_tag(td.status)}"}><%= td.status %></span></td>
                <td>
                  <%= if td.status != "completed" do %>
                    <button phx-click="mark_complete" phx-value-id={td.id} class="btn btn-sm btn-secondary">Complete</button>
                  <% end %>
                  <button phx-click="delete" phx-value-id={td.id} class="btn btn-danger btn-sm" data-confirm="Delete?">Del</button>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @deadlines == [] do %>
          <div class="empty-state">No tax deadlines yet.</div>
        <% end %>
      </div>
    </div>

    <div class="section">
      <div class="section-head"><h2>Annual Filings</h2></div>
      <div class="panel">
        <table>
          <thead>
            <tr><th>Due Date</th><th>Company</th><th>Status</th></tr>
          </thead>
          <tbody>
            <%= for af <- @annual_filings do %>
              <tr>
                <td class="td-mono"><%= af.due_date %></td>
                <td><%= if af.company, do: af.company.name, else: "---" %></td>
                <td><span class={"tag #{status_tag(af.status)}"}><%= af.status %></span></td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @annual_filings == [] do %>
          <div class="empty-state">No annual filings yet.</div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click-away="close_form">
          <div class="modal-header"><h3>Add Tax Deadline</h3></div>
          <div class="modal-body">
            <form phx-submit="save">
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="tax_deadline[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %><option value={c.id}><%= c.name %></option><% end %>
                </select>
              </div>
              <div class="form-group"><label class="form-label">Jurisdiction *</label><input type="text" name="tax_deadline[jurisdiction]" class="form-input" required /></div>
              <div class="form-group"><label class="form-label">Description *</label><input type="text" name="tax_deadline[description]" class="form-input" required /></div>
              <div class="form-group"><label class="form-label">Due Date *</label><input type="text" name="tax_deadline[due_date]" class="form-input" placeholder="YYYY-MM-DD" required /></div>
              <div class="form-group"><label class="form-label">Notes</label><textarea name="tax_deadline[notes]" class="form-input"></textarea></div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Add Deadline</button>
                <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp status_tag("completed"), do: "tag-jade"
  defp status_tag("filed"), do: "tag-jade"
  defp status_tag("pending"), do: "tag-lemon"
  defp status_tag("overdue"), do: "tag-crimson"
  defp status_tag(_), do: "tag-ink"
end
