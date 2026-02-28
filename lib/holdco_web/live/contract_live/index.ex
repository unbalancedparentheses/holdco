defmodule HoldcoWeb.ContractLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.Corporate
  alias Holdco.Corporate.Contract

  @impl true
  def mount(_params, _session, socket) do
    companies = Corporate.list_companies()
    contracts = Corporate.list_contracts()
    summary = Corporate.contract_summary()
    expiring = Corporate.expiring_contracts(30)
    by_counterparty = Corporate.contracts_by_counterparty()

    {:ok,
     assign(socket,
       page_title: "Contracts",
       companies: companies,
       contracts: contracts,
       summary: summary,
       expiring: expiring,
       by_counterparty: by_counterparty,
       selected_company_id: "",
       show_form: false,
       editing_item: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("filter_company", %{"company_id" => id}, socket) do
    company_id = if id == "", do: nil, else: String.to_integer(id)
    contracts = Corporate.list_contracts(company_id)
    summary = Corporate.contract_summary(company_id)
    by_counterparty = Corporate.contracts_by_counterparty(company_id)

    {:noreply,
     assign(socket,
       selected_company_id: id,
       contracts: contracts,
       summary: summary,
       by_counterparty: by_counterparty
     )}
  end

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: :add, editing_item: nil)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false, editing_item: nil)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    contract = Corporate.get_contract!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: contract)}
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

  def handle_event("save", %{"contract" => params}, socket) do
    case Corporate.create_contract(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Contract added")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add contract")}
    end
  end

  def handle_event("update", %{"contract" => params}, socket) do
    contract = socket.assigns.editing_item

    case Corporate.update_contract(contract, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Contract updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update contract")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    contract = Corporate.get_contract!(String.to_integer(id))

    case Corporate.delete_contract(contract) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Contract deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete contract")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Contract Management</h1>
          <p class="deck">Track contracts, renewals, and counterparty relationships</p>
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
            <button class="btn btn-primary" phx-click="show_form">Add Contract</button>
          <% end %>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Contracts</div>
        <div class="metric-value">{length(@contracts)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Total Value</div>
        <div class="metric-value">${format_number(@summary.total_value)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Expiring (30d)</div>
        <div class="metric-value num-negative">{length(@expiring)}</div>
      </div>
    </div>

    <%= if @expiring != [] do %>
      <div class="section">
        <div class="section-head"><h2>Expiring Contracts (Next 30 Days)</h2></div>
        <div class="panel">
          <table>
            <thead>
              <tr><th>Title</th><th>Counterparty</th><th>Company</th><th>End Date</th><th>Auto Renew</th></tr>
            </thead>
            <tbody>
              <%= for c <- @expiring do %>
                <tr>
                  <td class="td-name">{c.title}</td>
                  <td>{c.counterparty}</td>
                  <td>{if c.company, do: c.company.name, else: "---"}</td>
                  <td class="td-mono">{c.end_date}</td>
                  <td>{if c.auto_renew, do: "Yes", else: "No"}</td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    <% end %>

    <%= if @by_counterparty != [] do %>
      <div class="section">
        <div class="section-head"><h2>By Counterparty</h2></div>
        <div class="panel">
          <table>
            <thead>
              <tr><th>Counterparty</th><th class="th-num">Contracts</th><th class="th-num">Total Value</th></tr>
            </thead>
            <tbody>
              <%= for row <- @by_counterparty do %>
                <tr>
                  <td>{row.counterparty}</td>
                  <td class="td-num">{row.count}</td>
                  <td class="td-num">${format_number(row.total_value || 0)}</td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    <% end %>

    <div class="section">
      <div class="section-head"><h2>All Contracts</h2></div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Title</th><th>Counterparty</th><th>Type</th><th>Status</th>
              <th>Start</th><th>End</th><th class="th-num">Value</th><th></th>
            </tr>
          </thead>
          <tbody>
            <%= for c <- @contracts do %>
              <tr>
                <td class="td-name">{c.title}</td>
                <td>{c.counterparty}</td>
                <td><span class="tag tag-sky">{humanize(c.contract_type)}</span></td>
                <td><span class={"tag #{status_tag(c.status)}"}>{humanize(c.status)}</span></td>
                <td class="td-mono">{c.start_date || "---"}</td>
                <td class="td-mono">{c.end_date || "---"}</td>
                <td class="td-num">{if c.value, do: "#{c.currency} #{c.value}", else: "---"}</td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit" phx-value-id={c.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete" phx-value-id={c.id} class="btn btn-danger btn-sm" data-confirm="Delete this contract?">Del</button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @contracts == [] do %>
          <div class="empty-state">
            <p>No contracts found.</p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_form">Add Your First Contract</button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit Contract", else: "Add Contract"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Title *</label>
                <input type="text" name="contract[title]" class="form-input" value={if @editing_item, do: @editing_item.title, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="contract[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={@editing_item && @editing_item.company_id == c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Counterparty *</label>
                <input type="text" name="contract[counterparty]" class="form-input" value={if @editing_item, do: @editing_item.counterparty, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Contract Type</label>
                <select name="contract[contract_type]" class="form-select">
                  <%= for t <- Contract.contract_types() do %>
                    <option value={t} selected={@editing_item && @editing_item.contract_type == t}>{humanize(t)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Status</label>
                <select name="contract[status]" class="form-select">
                  <%= for s <- Contract.statuses() do %>
                    <option value={s} selected={@editing_item && @editing_item.status == s}>{humanize(s)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Start Date</label>
                <input type="date" name="contract[start_date]" class="form-input" value={if @editing_item, do: @editing_item.start_date, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">End Date</label>
                <input type="date" name="contract[end_date]" class="form-input" value={if @editing_item, do: @editing_item.end_date, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Value</label>
                <input type="number" name="contract[value]" class="form-input" step="any" value={if @editing_item, do: @editing_item.value, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Currency</label>
                <input type="text" name="contract[currency]" class="form-input" value={if @editing_item, do: @editing_item.currency, else: "USD"} />
              </div>
              <div class="form-group">
                <label class="form-label">Auto Renew</label>
                <select name="contract[auto_renew]" class="form-select">
                  <option value="false" selected={!(@editing_item && @editing_item.auto_renew)}>No</option>
                  <option value="true" selected={@editing_item && @editing_item.auto_renew}>Yes</option>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Renewal Notice Days</label>
                <input type="number" name="contract[renewal_notice_days]" class="form-input" value={if @editing_item, do: @editing_item.renewal_notice_days, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Key Terms</label>
                <textarea name="contract[key_terms]" class="form-input">{if @editing_item, do: @editing_item.key_terms, else: ""}</textarea>
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="contract[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">{if @show_form == :edit, do: "Update Contract", else: "Add Contract"}</button>
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

    contracts = Corporate.list_contracts(company_id)
    summary = Corporate.contract_summary(company_id)
    expiring = Corporate.expiring_contracts(30)
    by_counterparty = Corporate.contracts_by_counterparty(company_id)
    assign(socket, contracts: contracts, summary: summary, expiring: expiring, by_counterparty: by_counterparty)
  end

  defp humanize(str), do: str |> String.replace("_", " ") |> String.split(" ") |> Enum.map(&String.capitalize/1) |> Enum.join(" ")

  defp status_tag("active"), do: "tag-jade"
  defp status_tag("draft"), do: "tag-lemon"
  defp status_tag("under_review"), do: "tag-lemon"
  defp status_tag("expiring"), do: "tag-rose"
  defp status_tag("expired"), do: "tag-rose"
  defp status_tag("terminated"), do: "tag-rose"
  defp status_tag("renewed"), do: "tag-sky"
  defp status_tag(_), do: ""

  defp format_number(%Decimal{} = n), do: n |> Decimal.round(2) |> Decimal.to_string()
  defp format_number(n) when is_number(n), do: to_string(n)
  defp format_number(_), do: "0"
end
