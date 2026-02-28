defmodule HoldcoWeb.BankGuaranteeLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.Finance
  alias Holdco.Finance.BankGuarantee

  @impl true
  def mount(_params, _session, socket) do
    companies = Holdco.Corporate.list_companies()
    guarantees = Finance.list_bank_guarantees()
    summary = Finance.guarantee_summary()
    active = Finance.active_guarantees()

    {:ok,
     assign(socket,
       page_title: "Bank Guarantees & LOC",
       companies: companies,
       guarantees: guarantees,
       summary: summary,
       active_guarantees: active,
       selected_company_id: "",
       show_form: false,
       editing_item: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("filter_company", %{"company_id" => id}, socket) do
    company_id = if id == "", do: nil, else: String.to_integer(id)
    guarantees = Finance.list_bank_guarantees(company_id)
    summary = Finance.guarantee_summary(company_id)
    active = Finance.active_guarantees(company_id)
    {:noreply, assign(socket, selected_company_id: id, guarantees: guarantees, summary: summary, active_guarantees: active)}
  end

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: :add, editing_item: nil)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false, editing_item: nil)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    bg = Finance.get_bank_guarantee!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: bg)}
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

  def handle_event("save", %{"bank_guarantee" => params}, socket) do
    case Finance.create_bank_guarantee(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Bank guarantee added")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add bank guarantee")}
    end
  end

  def handle_event("update", %{"bank_guarantee" => params}, socket) do
    bg = socket.assigns.editing_item

    case Finance.update_bank_guarantee(bg, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Bank guarantee updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update bank guarantee")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    bg = Finance.get_bank_guarantee!(String.to_integer(id))

    case Finance.delete_bank_guarantee(bg) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Bank guarantee deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete bank guarantee")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Bank Guarantees & Letters of Credit</h1>
          <p class="deck">Track guarantees, LOCs, and their status</p>
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
            <button class="btn btn-primary" phx-click="show_form">Add Guarantee</button>
          <% end %>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Guarantees</div>
        <div class="metric-value">{length(@guarantees)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Active</div>
        <div class="metric-value">{length(@active_guarantees)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Total Amount</div>
        <div class="metric-value">${format_number(@summary.total_amount)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Active Amount</div>
        <div class="metric-value">${format_number(@summary.active_amount)}</div>
      </div>
    </div>

    <%= if @summary.by_type != [] do %>
      <div class="section">
        <div class="section-head"><h2>By Type</h2></div>
        <div class="panel">
          <table>
            <thead>
              <tr><th>Type</th><th class="th-num">Count</th><th class="th-num">Total Amount</th></tr>
            </thead>
            <tbody>
              <%= for row <- @summary.by_type do %>
                <tr>
                  <td>{humanize(row.guarantee_type)}</td>
                  <td class="td-num">{row.count}</td>
                  <td class="td-num">${format_number(row.total_amount)}</td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    <% end %>

    <div class="section">
      <div class="section-head"><h2>All Guarantees</h2></div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Type</th><th>Bank</th><th>Beneficiary</th><th>Company</th>
              <th>Ref #</th><th class="th-num">Amount</th><th>Issue</th><th>Expiry</th><th>Status</th><th></th>
            </tr>
          </thead>
          <tbody>
            <%= for bg <- @guarantees do %>
              <tr>
                <td><span class="tag tag-sky">{humanize(bg.guarantee_type)}</span></td>
                <td>{bg.issuing_bank}</td>
                <td>{bg.beneficiary}</td>
                <td>{if bg.company, do: bg.company.name, else: "---"}</td>
                <td class="td-mono">{bg.reference_number || "---"}</td>
                <td class="td-num">{bg.currency} {format_number(bg.amount)}</td>
                <td class="td-mono">{bg.issue_date || "---"}</td>
                <td class="td-mono">{bg.expiry_date || "---"}</td>
                <td><span class={"tag #{bg_status_tag(bg.status)}"}>{humanize(bg.status)}</span></td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit" phx-value-id={bg.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete" phx-value-id={bg.id} class="btn btn-danger btn-sm" data-confirm="Delete this guarantee?">Del</button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @guarantees == [] do %>
          <div class="empty-state">
            <p>No bank guarantees found.</p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_form">Add Your First Guarantee</button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit Guarantee", else: "Add Guarantee"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="bank_guarantee[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={@editing_item && @editing_item.company_id == c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Type *</label>
                <select name="bank_guarantee[guarantee_type]" class="form-select" required>
                  <%= for t <- BankGuarantee.guarantee_types() do %>
                    <option value={t} selected={@editing_item && @editing_item.guarantee_type == t}>{humanize(t)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Issuing Bank *</label>
                <input type="text" name="bank_guarantee[issuing_bank]" class="form-input" value={if @editing_item, do: @editing_item.issuing_bank, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Beneficiary *</label>
                <input type="text" name="bank_guarantee[beneficiary]" class="form-input" value={if @editing_item, do: @editing_item.beneficiary, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Reference Number</label>
                <input type="text" name="bank_guarantee[reference_number]" class="form-input" value={if @editing_item, do: @editing_item.reference_number, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Amount *</label>
                <input type="number" name="bank_guarantee[amount]" class="form-input" step="any" value={if @editing_item, do: @editing_item.amount, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Currency</label>
                <input type="text" name="bank_guarantee[currency]" class="form-input" value={if @editing_item, do: @editing_item.currency, else: "USD"} />
              </div>
              <div class="form-group">
                <label class="form-label">Issue Date</label>
                <input type="date" name="bank_guarantee[issue_date]" class="form-input" value={if @editing_item, do: @editing_item.issue_date, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Expiry Date</label>
                <input type="date" name="bank_guarantee[expiry_date]" class="form-input" value={if @editing_item, do: @editing_item.expiry_date, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Status</label>
                <select name="bank_guarantee[status]" class="form-select">
                  <%= for s <- BankGuarantee.statuses() do %>
                    <option value={s} selected={@editing_item && @editing_item.status == s}>{humanize(s)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Annual Fee %</label>
                <input type="number" name="bank_guarantee[annual_fee_pct]" class="form-input" step="any" value={if @editing_item, do: @editing_item.annual_fee_pct, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Collateral Description</label>
                <textarea name="bank_guarantee[collateral_description]" class="form-input">{if @editing_item, do: @editing_item.collateral_description, else: ""}</textarea>
              </div>
              <div class="form-group">
                <label class="form-label">Purpose</label>
                <input type="text" name="bank_guarantee[purpose]" class="form-input" value={if @editing_item, do: @editing_item.purpose, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="bank_guarantee[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">{if @show_form == :edit, do: "Update", else: "Add Guarantee"}</button>
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

    guarantees = Finance.list_bank_guarantees(company_id)
    summary = Finance.guarantee_summary(company_id)
    active = Finance.active_guarantees(company_id)
    assign(socket, guarantees: guarantees, summary: summary, active_guarantees: active)
  end

  defp humanize(str), do: str |> String.replace("_", " ") |> String.split(" ") |> Enum.map(&String.capitalize/1) |> Enum.join(" ")

  defp bg_status_tag("active"), do: "tag-jade"
  defp bg_status_tag("expired"), do: "tag-rose"
  defp bg_status_tag("called"), do: "tag-rose"
  defp bg_status_tag("released"), do: ""
  defp bg_status_tag("renewed"), do: "tag-sky"
  defp bg_status_tag(_), do: ""

  defp format_number(%Decimal{} = n), do: n |> Decimal.round(2) |> Decimal.to_string()
  defp format_number(n) when is_number(n), do: to_string(n)
  defp format_number(_), do: "---"
end
