defmodule HoldcoWeb.RegulatoryCapitalLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Compliance, Corporate}
  alias Holdco.Compliance.RegulatoryCapital

  @impl true
  def mount(_params, _session, socket) do
    companies = Corporate.list_companies()
    records = Compliance.list_regulatory_capital_records()

    {:ok,
     assign(socket,
       page_title: "Regulatory Capital Requirements",
       companies: companies,
       records: records,
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
    record = Compliance.get_regulatory_capital!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: record)}
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

  def handle_event("save", %{"regulatory_capital" => params}, socket) do
    case Compliance.create_regulatory_capital(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Regulatory capital record created")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create regulatory capital record")}
    end
  end

  def handle_event("update", %{"regulatory_capital" => params}, socket) do
    record = socket.assigns.editing_item

    case Compliance.update_regulatory_capital(record, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Regulatory capital record updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update regulatory capital record")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    record = Compliance.get_regulatory_capital!(String.to_integer(id))

    case Compliance.delete_regulatory_capital(record) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Regulatory capital record deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete regulatory capital record")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Regulatory Capital Requirements</h1>
          <p class="deck">Basel III, Solvency II, and other capital adequacy frameworks</p>
        </div>
        <%= if @can_write do %>
          <button class="btn btn-primary" phx-click="show_form">Add Record</button>
        <% end %>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Records</div>
        <div class="metric-value">{length(@records)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Compliant</div>
        <div class="metric-value">{Enum.count(@records, &(&1.status == "compliant"))}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Warning</div>
        <div class="metric-value num-negative">{Enum.count(@records, &(&1.status == "warning"))}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Breach</div>
        <div class="metric-value num-negative">{Enum.count(@records, &(&1.status == "breach"))}</div>
      </div>
    </div>

    <div class="section">
      <div class="section-head"><h2>All Capital Records</h2></div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Company</th><th>Date</th><th>Framework</th><th>Capital Ratio</th>
              <th>Min Required</th><th>Surplus/Deficit</th><th>Status</th><th></th>
            </tr>
          </thead>
          <tbody>
            <%= for r <- @records do %>
              <tr>
                <td>{if r.company, do: r.company.name, else: "---"}</td>
                <td class="td-mono">{r.reporting_date}</td>
                <td><span class="tag tag-sky">{humanize(r.framework)}</span></td>
                <td class="td-num">{if r.capital_ratio, do: Decimal.to_string(r.capital_ratio), else: "---"}</td>
                <td class="td-num">{if r.minimum_required_ratio, do: Decimal.to_string(r.minimum_required_ratio), else: "---"}</td>
                <td class="td-num">{if r.surplus_or_deficit, do: Decimal.to_string(r.surplus_or_deficit), else: "---"}</td>
                <td><span class={"tag #{capital_status_tag(r.status)}"}>{humanize(r.status)}</span></td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit" phx-value-id={r.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete" phx-value-id={r.id} class="btn btn-danger btn-sm" data-confirm="Delete this record?">Del</button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @records == [] do %>
          <div class="empty-state">
            <p>No regulatory capital records found.</p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_form">Add Your First Record</button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit Capital Record", else: "Add Capital Record"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="regulatory_capital[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={@editing_item && @editing_item.company_id == c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Reporting Date *</label>
                <input type="date" name="regulatory_capital[reporting_date]" class="form-input" value={if @editing_item, do: @editing_item.reporting_date, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Framework *</label>
                <select name="regulatory_capital[framework]" class="form-select" required>
                  <%= for f <- RegulatoryCapital.frameworks() do %>
                    <option value={f} selected={@editing_item && @editing_item.framework == f}>{humanize(f)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Tier 1 Capital</label>
                <input type="number" name="regulatory_capital[tier1_capital]" class="form-input" step="0.01" value={if @editing_item && @editing_item.tier1_capital, do: Decimal.to_string(@editing_item.tier1_capital), else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Tier 2 Capital</label>
                <input type="number" name="regulatory_capital[tier2_capital]" class="form-input" step="0.01" value={if @editing_item && @editing_item.tier2_capital, do: Decimal.to_string(@editing_item.tier2_capital), else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Total Capital</label>
                <input type="number" name="regulatory_capital[total_capital]" class="form-input" step="0.01" value={if @editing_item && @editing_item.total_capital, do: Decimal.to_string(@editing_item.total_capital), else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Risk Weighted Assets</label>
                <input type="number" name="regulatory_capital[risk_weighted_assets]" class="form-input" step="0.01" value={if @editing_item && @editing_item.risk_weighted_assets, do: Decimal.to_string(@editing_item.risk_weighted_assets), else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Capital Ratio</label>
                <input type="number" name="regulatory_capital[capital_ratio]" class="form-input" step="0.01" value={if @editing_item && @editing_item.capital_ratio, do: Decimal.to_string(@editing_item.capital_ratio), else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Minimum Required Ratio</label>
                <input type="number" name="regulatory_capital[minimum_required_ratio]" class="form-input" step="0.01" value={if @editing_item && @editing_item.minimum_required_ratio, do: Decimal.to_string(@editing_item.minimum_required_ratio), else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Currency</label>
                <input type="text" name="regulatory_capital[currency]" class="form-input" value={if @editing_item, do: @editing_item.currency, else: "USD"} />
              </div>
              <div class="form-group">
                <label class="form-label">Status</label>
                <select name="regulatory_capital[status]" class="form-select">
                  <%= for s <- RegulatoryCapital.statuses() do %>
                    <option value={s} selected={@editing_item && @editing_item.status == s}>{humanize(s)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="regulatory_capital[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">{if @show_form == :edit, do: "Update Record", else: "Add Record"}</button>
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
    assign(socket, records: Compliance.list_regulatory_capital_records())
  end

  defp humanize(str), do: str |> String.replace("_", " ") |> String.split(" ") |> Enum.map(&String.capitalize/1) |> Enum.join(" ")

  defp capital_status_tag("compliant"), do: "tag-jade"
  defp capital_status_tag("warning"), do: "tag-lemon"
  defp capital_status_tag("breach"), do: "tag-rose"
  defp capital_status_tag(_), do: ""
end
