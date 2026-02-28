defmodule HoldcoWeb.WithholdingReclaimLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Tax, Corporate}

  @impl true
  def mount(_params, _session, socket) do
    companies = Corporate.list_companies()

    {:ok,
     assign(socket,
       page_title: "Withholding Tax Reclaims",
       companies: companies,
       selected_company_id: "",
       reclaims: [],
       summary: nil,
       show_form: false,
       editing_item: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("filter_company", %{"company_id" => id}, socket) do
    if id == "" do
      {:noreply, assign(socket, selected_company_id: "", reclaims: [], summary: nil)}
    else
      company_id = String.to_integer(id)
      reclaims = Tax.list_withholding_reclaims(company_id)
      summary = Tax.reclaim_summary(company_id)
      {:noreply, assign(socket, selected_company_id: id, reclaims: reclaims, summary: summary)}
    end
  end

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: :add, editing_item: nil)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false, editing_item: nil)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    reclaim = Tax.get_withholding_reclaim!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: reclaim)}
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

  def handle_event("save", %{"reclaim" => params}, socket) do
    case Tax.create_withholding_reclaim(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Withholding reclaim created")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create reclaim")}
    end
  end

  def handle_event("update", %{"reclaim" => params}, socket) do
    reclaim = socket.assigns.editing_item

    case Tax.update_withholding_reclaim(reclaim, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Withholding reclaim updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update reclaim")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    reclaim = Tax.get_withholding_reclaim!(String.to_integer(id))

    case Tax.delete_withholding_reclaim(reclaim) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Withholding reclaim deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete reclaim")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Withholding Tax Reclaims</h1>
          <p class="deck">Track and manage withholding tax reclaim filings</p>
        </div>
        <div style="display: flex; gap: 0.5rem; align-items: center;">
          <form phx-change="filter_company" style="display: flex; align-items: center; gap: 0.5rem;">
            <label class="form-label" style="margin: 0; font-size: 0.85rem;">Company</label>
            <select name="company_id" class="form-select" style="width: auto; padding: 0.3rem 0.5rem;">
              <option value="">Select Company</option>
              <%= for c <- @companies do %>
                <option value={c.id} selected={to_string(c.id) == @selected_company_id}>{c.name}</option>
              <% end %>
            </select>
          </form>
          <%= if @can_write && @selected_company_id != "" do %>
            <button class="btn btn-primary" phx-click="show_form">Add Reclaim</button>
          <% end %>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <%= if @summary do %>
      <div class="metrics-strip">
        <div class="metric-cell">
          <div class="metric-label">Total Withheld</div>
          <div class="metric-value">${format_number(@summary.total_withheld)}</div>
        </div>
        <div class="metric-cell">
          <div class="metric-label">Total Reclaimable</div>
          <div class="metric-value">${format_number(@summary.total_reclaimable)}</div>
        </div>
        <div class="metric-cell">
          <div class="metric-label">Total Reclaimed</div>
          <div class="metric-value num-positive">${format_number(@summary.total_reclaimed)}</div>
        </div>
        <div class="metric-cell">
          <div class="metric-label">Recovery Rate</div>
          <div class="metric-value">{format_pct(@summary.recovery_rate)}%</div>
        </div>
      </div>

      <%= if @summary.by_status != [] do %>
        <div class="section">
          <div class="section-head"><h2>Summary by Status</h2></div>
          <div class="panel">
            <table>
              <thead>
                <tr>
                  <th>Status</th>
                  <th class="th-num">Count</th>
                  <th class="th-num">Withheld</th>
                  <th class="th-num">Reclaimable</th>
                  <th class="th-num">Reclaimed</th>
                </tr>
              </thead>
              <tbody>
                <%= for s <- @summary.by_status do %>
                  <tr>
                    <td><span class={"tag #{status_tag(s.status)}"}>{s.status}</span></td>
                    <td class="td-num">{s.count}</td>
                    <td class="td-num">${format_number(s.total_withheld)}</td>
                    <td class="td-num">${format_number(s.total_reclaimable)}</td>
                    <td class="td-num">${format_number(s.total_reclaimed)}</td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
      <% end %>
    <% end %>

    <div class="section">
      <div class="section-head"><h2>Reclaim Records</h2></div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Jurisdiction</th>
              <th>Year</th>
              <th>Type</th>
              <th class="th-num">Gross</th>
              <th class="th-num">Withheld</th>
              <th class="th-num">Reclaimable</th>
              <th class="th-num">Reclaimed</th>
              <th>Status</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for r <- @reclaims do %>
              <tr>
                <td class="td-name">{r.jurisdiction}</td>
                <td class="td-mono">{r.tax_year}</td>
                <td>{r.income_type}</td>
                <td class="td-num">${format_number(r.gross_amount)}</td>
                <td class="td-num">${format_number(r.amount_withheld)}</td>
                <td class="td-num">${format_number(r.reclaimable_amount)}</td>
                <td class="td-num">${format_number(r.reclaimed_amount)}</td>
                <td><span class={"tag #{status_tag(r.status)}"}>{r.status}</span></td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit" phx-value-id={r.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete" phx-value-id={r.id} class="btn btn-danger btn-sm" data-confirm="Delete?">Del</button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @reclaims == [] do %>
          <div class="empty-state">
            <p>{if @selected_company_id == "", do: "Select a company to view reclaims.", else: "No reclaim records found."}</p>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit Reclaim", else: "Add Reclaim"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <input type="hidden" name="reclaim[company_id]" value={@selected_company_id} />
              <div class="form-group">
                <label class="form-label">Jurisdiction *</label>
                <input type="text" name="reclaim[jurisdiction]" class="form-input"
                  value={if @editing_item, do: @editing_item.jurisdiction, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Tax Year *</label>
                <input type="number" name="reclaim[tax_year]" class="form-input"
                  value={if @editing_item, do: @editing_item.tax_year, else: Date.utc_today().year} required />
              </div>
              <div class="form-group">
                <label class="form-label">Income Type *</label>
                <select name="reclaim[income_type]" class="form-select" required>
                  <option value="">Select type</option>
                  <%= for t <- ~w(dividend interest royalty) do %>
                    <option value={t} selected={@editing_item && @editing_item.income_type == t}>{t}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Gross Amount *</label>
                <input type="number" name="reclaim[gross_amount]" class="form-input" step="any"
                  value={if @editing_item, do: @editing_item.gross_amount, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Withholding Rate * (0-1)</label>
                <input type="number" name="reclaim[withholding_rate]" class="form-input" step="0.001" min="0" max="1"
                  value={if @editing_item, do: @editing_item.withholding_rate, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Amount Withheld *</label>
                <input type="number" name="reclaim[amount_withheld]" class="form-input" step="any"
                  value={if @editing_item, do: @editing_item.amount_withheld, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Treaty Rate (0-1)</label>
                <input type="number" name="reclaim[treaty_rate]" class="form-input" step="0.001" min="0" max="1"
                  value={if @editing_item, do: @editing_item.treaty_rate, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Reclaimable Amount</label>
                <input type="number" name="reclaim[reclaimable_amount]" class="form-input" step="any"
                  value={if @editing_item, do: @editing_item.reclaimable_amount, else: "0"} />
              </div>
              <div class="form-group">
                <label class="form-label">Reclaimed Amount</label>
                <input type="number" name="reclaim[reclaimed_amount]" class="form-input" step="any"
                  value={if @editing_item, do: @editing_item.reclaimed_amount, else: "0"} />
              </div>
              <div class="form-group">
                <label class="form-label">Status</label>
                <select name="reclaim[status]" class="form-select">
                  <%= for s <- ~w(pending filed partial received denied) do %>
                    <option value={s} selected={@editing_item && @editing_item.status == s}>{s}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Filed Date</label>
                <input type="date" name="reclaim[filed_date]" class="form-input"
                  value={if @editing_item, do: @editing_item.filed_date, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Received Date</label>
                <input type="date" name="reclaim[received_date]" class="form-input"
                  value={if @editing_item, do: @editing_item.received_date, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="reclaim[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">
                  {if @show_form == :edit, do: "Update", else: "Add Reclaim"}
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
    case socket.assigns.selected_company_id do
      "" ->
        assign(socket, reclaims: [], summary: nil)

      id ->
        company_id = String.to_integer(id)
        reclaims = Tax.list_withholding_reclaims(company_id)
        summary = Tax.reclaim_summary(company_id)
        assign(socket, reclaims: reclaims, summary: summary)
    end
  end

  defp status_tag("pending"), do: "tag-lemon"
  defp status_tag("filed"), do: "tag-sky"
  defp status_tag("partial"), do: "tag-coral"
  defp status_tag("received"), do: "tag-jade"
  defp status_tag("denied"), do: "tag-red"
  defp status_tag(_), do: ""

  defp format_pct(%Decimal{} = n), do: n |> Decimal.mult(100) |> Decimal.round(1) |> Decimal.to_string()
  defp format_pct(_), do: "0"

  defp format_number(%Decimal{} = n),
    do: n |> Decimal.round(2) |> Decimal.to_string() |> add_commas()

  defp format_number(_), do: "0"

  defp add_commas(str) do
    case String.split(str, ".") do
      [int_part, dec_part] ->
        formatted_int = int_part |> String.reverse() |> String.replace(~r/(\d{3})(?=\d)/, "\\1,") |> String.reverse()
        "#{formatted_int}.#{dec_part}"

      [int_part] ->
        int_part |> String.reverse() |> String.replace(~r/(\d{3})(?=\d)/, "\\1,") |> String.reverse()
    end
  end
end
