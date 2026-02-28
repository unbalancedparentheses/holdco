defmodule HoldcoWeb.AmlLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Compliance, Corporate}
  alias Holdco.Compliance.AmlAlert

  @impl true
  def mount(_params, _session, socket) do
    companies = Corporate.list_companies()
    alerts = Compliance.list_aml_alerts()
    open_alerts = Compliance.open_aml_alerts()
    summary = Compliance.aml_alert_summary()

    {:ok,
     assign(socket,
       page_title: "AML Monitoring",
       companies: companies,
       alerts: alerts,
       open_alerts: open_alerts,
       summary: summary,
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
    alert = Compliance.get_aml_alert!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: alert)}
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

  def handle_event("save", %{"aml_alert" => params}, socket) do
    case Compliance.create_aml_alert(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "AML alert created")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create AML alert")}
    end
  end

  def handle_event("update", %{"aml_alert" => params}, socket) do
    alert = socket.assigns.editing_item

    case Compliance.update_aml_alert(alert, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "AML alert updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update AML alert")}
    end
  end

  def handle_event("dismiss", %{"id" => id}, socket) do
    alert = Compliance.get_aml_alert!(String.to_integer(id))

    case Compliance.update_aml_alert(alert, %{status: "dismissed", resolved_at: DateTime.utc_now()}) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Alert dismissed")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to dismiss alert")}
    end
  end

  def handle_event("escalate", %{"id" => id}, socket) do
    alert = Compliance.get_aml_alert!(String.to_integer(id))

    case Compliance.update_aml_alert(alert, %{status: "escalated"}) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Alert escalated")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to escalate alert")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    alert = Compliance.get_aml_alert!(String.to_integer(id))

    case Compliance.delete_aml_alert(alert) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "AML alert deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete AML alert")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>AML Transaction Monitoring</h1>
          <p class="deck">Anti-money laundering alert queue and investigation workflow</p>
        </div>
        <%= if @can_write do %>
          <button class="btn btn-primary" phx-click="show_form">Add Alert</button>
        <% end %>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Alerts</div>
        <div class="metric-value">{length(@alerts)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Open</div>
        <div class="metric-value num-negative">{length(@open_alerts)}</div>
      </div>
      <%= for s <- @summary.by_severity do %>
        <div class="metric-cell">
          <div class="metric-label">{humanize_severity(s.severity)}</div>
          <div class="metric-value">{s.count}</div>
        </div>
      <% end %>
    </div>

    <%= if @open_alerts != [] do %>
      <div class="section">
        <div class="section-head"><h2>Open Alert Queue</h2></div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Company</th>
                <th>Type</th>
                <th>Severity</th>
                <th>Amount</th>
                <th>Status</th>
                <th>Assigned To</th>
                <th>Description</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <%= for a <- @open_alerts do %>
                <tr>
                  <td>{if a.company, do: a.company.name, else: "---"}</td>
                  <td><span class="tag tag-sky">{humanize_alert_type(a.alert_type)}</span></td>
                  <td><span class={"tag #{severity_tag(a.severity)}"}>{humanize_severity(a.severity)}</span></td>
                  <td class="td-num">{if a.amount, do: "#{a.currency} #{a.amount}", else: "---"}</td>
                  <td><span class={"tag #{alert_status_tag(a.status)}"}>{humanize_alert_status(a.status)}</span></td>
                  <td>{a.assigned_to || "---"}</td>
                  <td>{truncate(a.description || "", 50)}</td>
                  <td>
                    <%= if @can_write do %>
                      <div style="display: flex; gap: 0.25rem;">
                        <button phx-click="escalate" phx-value-id={a.id} class="btn btn-primary btn-sm">Escalate</button>
                        <button phx-click="dismiss" phx-value-id={a.id} class="btn btn-secondary btn-sm" data-confirm="Dismiss this alert?">Dismiss</button>
                      </div>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    <% end %>

    <div class="section">
      <div class="section-head"><h2>All Alerts</h2></div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Company</th>
              <th>Type</th>
              <th>Severity</th>
              <th>Amount</th>
              <th>Rule Triggered</th>
              <th>Status</th>
              <th>Assigned To</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for a <- @alerts do %>
              <tr>
                <td>{if a.company, do: a.company.name, else: "---"}</td>
                <td><span class="tag tag-sky">{humanize_alert_type(a.alert_type)}</span></td>
                <td><span class={"tag #{severity_tag(a.severity)}"}>{humanize_severity(a.severity)}</span></td>
                <td class="td-num">{if a.amount, do: "#{a.currency} #{a.amount}", else: "---"}</td>
                <td>{a.rule_triggered || "---"}</td>
                <td><span class={"tag #{alert_status_tag(a.status)}"}>{humanize_alert_status(a.status)}</span></td>
                <td>{a.assigned_to || "---"}</td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit" phx-value-id={a.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete" phx-value-id={a.id} class="btn btn-danger btn-sm" data-confirm="Delete this alert?">Del</button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @alerts == [] do %>
          <div class="empty-state">
            <p>No AML alerts found.</p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_form">Add Your First Alert</button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit Alert", else: "Add Alert"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="aml_alert[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={@editing_item && @editing_item.company_id == c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Alert Type</label>
                <select name="aml_alert[alert_type]" class="form-select">
                  <%= for t <- AmlAlert.alert_types() do %>
                    <option value={t} selected={@editing_item && @editing_item.alert_type == t}>{humanize_alert_type(t)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Severity</label>
                <select name="aml_alert[severity]" class="form-select">
                  <%= for s <- AmlAlert.severities() do %>
                    <option value={s} selected={@editing_item && @editing_item.severity == s}>{humanize_severity(s)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Amount</label>
                <input type="number" name="aml_alert[amount]" class="form-input" step="any"
                  value={if @editing_item, do: @editing_item.amount, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Currency</label>
                <input type="text" name="aml_alert[currency]" class="form-input"
                  value={if @editing_item, do: @editing_item.currency, else: "USD"} />
              </div>
              <div class="form-group">
                <label class="form-label">Transaction ID</label>
                <input type="text" name="aml_alert[transaction_id]" class="form-input"
                  value={if @editing_item, do: @editing_item.transaction_id, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Rule Triggered</label>
                <input type="text" name="aml_alert[rule_triggered]" class="form-input"
                  value={if @editing_item, do: @editing_item.rule_triggered, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Status</label>
                <select name="aml_alert[status]" class="form-select">
                  <%= for s <- AmlAlert.statuses() do %>
                    <option value={s} selected={@editing_item && @editing_item.status == s}>{humanize_alert_status(s)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Assigned To</label>
                <input type="text" name="aml_alert[assigned_to]" class="form-input"
                  value={if @editing_item, do: @editing_item.assigned_to, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Description</label>
                <textarea name="aml_alert[description]" class="form-input">{if @editing_item, do: @editing_item.description, else: ""}</textarea>
              </div>
              <div class="form-group">
                <label class="form-label">Resolution Notes</label>
                <textarea name="aml_alert[resolution_notes]" class="form-input">{if @editing_item, do: @editing_item.resolution_notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">
                  {if @show_form == :edit, do: "Update Alert", else: "Add Alert"}
                </button>
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
    alerts = Compliance.list_aml_alerts()
    open_alerts = Compliance.open_aml_alerts()
    summary = Compliance.aml_alert_summary()
    assign(socket, alerts: alerts, open_alerts: open_alerts, summary: summary)
  end

  defp humanize_alert_type("large_transaction"), do: "Large Transaction"
  defp humanize_alert_type("structuring"), do: "Structuring"
  defp humanize_alert_type("velocity"), do: "Velocity"
  defp humanize_alert_type("geographic_risk"), do: "Geographic Risk"
  defp humanize_alert_type("pattern_match"), do: "Pattern Match"
  defp humanize_alert_type("pep_related"), do: "PEP Related"
  defp humanize_alert_type(other), do: other || "Large Transaction"

  defp humanize_severity("low"), do: "Low"
  defp humanize_severity("medium"), do: "Medium"
  defp humanize_severity("high"), do: "High"
  defp humanize_severity("critical"), do: "Critical"
  defp humanize_severity(other), do: other || "Medium"

  defp severity_tag("low"), do: "tag-jade"
  defp severity_tag("medium"), do: "tag-lemon"
  defp severity_tag("high"), do: "tag-rose"
  defp severity_tag("critical"), do: "tag-rose"
  defp severity_tag(_), do: "tag-lemon"

  defp humanize_alert_status("open"), do: "Open"
  defp humanize_alert_status("investigating"), do: "Investigating"
  defp humanize_alert_status("escalated"), do: "Escalated"
  defp humanize_alert_status("filed_sar"), do: "Filed SAR"
  defp humanize_alert_status("dismissed"), do: "Dismissed"
  defp humanize_alert_status(other), do: other || "Open"

  defp alert_status_tag("open"), do: "tag-lemon"
  defp alert_status_tag("investigating"), do: "tag-sky"
  defp alert_status_tag("escalated"), do: "tag-rose"
  defp alert_status_tag("filed_sar"), do: "tag-rose"
  defp alert_status_tag("dismissed"), do: "tag-jade"
  defp alert_status_tag(_), do: "tag-lemon"

  defp truncate(str, max) when byte_size(str) > max, do: String.slice(str, 0, max) <> "..."
  defp truncate(str, _max), do: str
end
