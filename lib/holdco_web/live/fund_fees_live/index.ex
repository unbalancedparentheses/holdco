defmodule HoldcoWeb.FundFeesLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Fund, Corporate, Money}

  @impl true
  def mount(_params, _session, socket) do
    companies = Corporate.list_companies()
    fees = Fund.list_fund_fees()

    {:ok,
     assign(socket,
       page_title: "Fund Fees",
       companies: companies,
       fees: fees,
       selected_company_id: "",
       show_form: false,
       show_calculate: false,
       editing_item: nil,
       fee_summary: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("filter_company", %{"company_id" => id}, socket) do
    company_id = if id == "", do: nil, else: String.to_integer(id)
    fees = Fund.list_fund_fees(company_id)
    summary = if company_id, do: Fund.fee_summary(company_id), else: nil

    {:noreply,
     assign(socket,
       selected_company_id: id,
       fees: fees,
       fee_summary: summary
     )}
  end

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: :add, editing_item: nil)}
  end

  def handle_event("show_calculate", _, socket) do
    {:noreply, assign(socket, show_calculate: true)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false, show_calculate: false, editing_item: nil)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    fee = Fund.get_fund_fee!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: fee)}
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

  def handle_event("calculate_fee", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("save", %{"fund_fee" => params}, socket) do
    case Fund.create_fund_fee(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Fund fee added")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add fund fee")}
    end
  end

  def handle_event("update", %{"fund_fee" => params}, socket) do
    fee = socket.assigns.editing_item

    case Fund.update_fund_fee(fee, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Fund fee updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update fund fee")}
    end
  end

  def handle_event("calculate_fee", %{"calc" => params}, socket) do
    company_id = String.to_integer(params["company_id"])
    rate_pct = params["rate_pct"]
    basis = params["basis"]
    {:ok, period_start} = Date.from_iso8601(params["period_start"])
    {:ok, period_end} = Date.from_iso8601(params["period_end"])

    fee_data = Fund.calculate_management_fee(company_id, rate_pct, basis, period_start, period_end)

    case Fund.create_fund_fee(fee_data) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Management fee calculated and recorded")
         |> assign(show_calculate: false)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create management fee")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    fee = Fund.get_fund_fee!(String.to_integer(id))

    case Fund.delete_fund_fee(fee) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Fund fee deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete fund fee")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Fund Fees</h1>
          <p class="deck">Management fees, performance fees, and other fund expenses</p>
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
            <button class="btn btn-secondary" phx-click="show_calculate">Calculate Fee</button>
            <button class="btn btn-primary" phx-click="show_form">Add Fee</button>
          <% end %>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <%= if @fee_summary do %>
      <div class="metrics-strip">
        <div class="metric-cell">
          <div class="metric-label">Total Fees</div>
          <div class="metric-value">${format_decimal(@fee_summary.total)}</div>
        </div>
        <div class="metric-cell">
          <div class="metric-label">Fee Count</div>
          <div class="metric-value">{@fee_summary.count}</div>
        </div>
        <%= for {type, amount} <- @fee_summary.by_type do %>
          <div class="metric-cell">
            <div class="metric-label">{String.capitalize(type)}</div>
            <div class="metric-value">${format_decimal(amount)}</div>
          </div>
        <% end %>
      </div>
    <% end %>

    <div class="section">
      <div class="section-head">
        <h2>Fees</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Type</th>
              <th>Company</th>
              <th>Description</th>
              <th class="th-num">Amount</th>
              <th>Period</th>
              <th>Basis</th>
              <th class="th-num">Rate</th>
              <th>Status</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for fee <- @fees do %>
              <tr>
                <td><span class={"tag #{fee_type_tag(fee.fee_type)}"}>{fee.fee_type}</span></td>
                <td>
                  <%= if fee.company do %>
                    <.link navigate={~p"/companies/#{fee.company.id}"} class="td-link">{fee.company.name}</.link>
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td>{fee.description || "---"}</td>
                <td class="td-num">{format_decimal(fee.amount)}</td>
                <td class="td-mono">
                  <%= if fee.period_start && fee.period_end do %>
                    {fee.period_start} to {fee.period_end}
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td>{fee.basis || "---"}</td>
                <td class="td-num">{if fee.rate_pct, do: "#{format_decimal(fee.rate_pct)}%", else: "---"}</td>
                <td><span class={"tag #{fee_status_tag(fee.status)}"}>{fee.status}</span></td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit" phx-value-id={fee.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete" phx-value-id={fee.id} class="btn btn-danger btn-sm" data-confirm="Delete this fee?">Del</button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @fees == [] do %>
          <div class="empty-state">
            <p>No fund fees found.</p>
            <p style="color: var(--muted); font-size: 0.9rem;">
              Track management fees, performance fees, and other fund expenses.
            </p>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit Fee", else: "Add Fee"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="fund_fee[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={@editing_item && @editing_item.company_id == c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Fee Type *</label>
                <select name="fund_fee[fee_type]" class="form-select" required>
                  <%= for t <- ~w(management performance admin custody legal audit other) do %>
                    <option value={t} selected={@editing_item && @editing_item.fee_type == t}>{String.capitalize(t)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Description</label>
                <input type="text" name="fund_fee[description]" class="form-input" value={if @editing_item, do: @editing_item.description, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Amount *</label>
                <input type="number" name="fund_fee[amount]" class="form-input" step="any" value={if @editing_item, do: @editing_item.amount, else: "0"} required />
              </div>
              <div class="form-group">
                <label class="form-label">Currency</label>
                <input type="text" name="fund_fee[currency]" class="form-input" value={if @editing_item, do: @editing_item.currency, else: "USD"} />
              </div>
              <div class="form-group">
                <label class="form-label">Period Start</label>
                <input type="date" name="fund_fee[period_start]" class="form-input" value={if @editing_item, do: @editing_item.period_start, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Period End</label>
                <input type="date" name="fund_fee[period_end]" class="form-input" value={if @editing_item, do: @editing_item.period_end, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Basis</label>
                <select name="fund_fee[basis]" class="form-select">
                  <option value="">None</option>
                  <%= for b <- ~w(nav committed_capital invested_capital fixed) do %>
                    <option value={b} selected={@editing_item && @editing_item.basis == b}>{String.replace(b, "_", " ") |> String.capitalize()}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Rate (%)</label>
                <input type="number" name="fund_fee[rate_pct]" class="form-input" step="any" value={if @editing_item, do: @editing_item.rate_pct, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Status</label>
                <select name="fund_fee[status]" class="form-select">
                  <%= for s <- ~w(accrued invoiced paid waived) do %>
                    <option value={s} selected={@editing_item && @editing_item.status == s}>{String.capitalize(s)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Paid Date</label>
                <input type="date" name="fund_fee[paid_date]" class="form-input" value={if @editing_item, do: @editing_item.paid_date, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="fund_fee[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">{if @show_form == :edit, do: "Update", else: "Add Fee"}</button>
                <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>

    <%= if @show_calculate do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>Calculate Management Fee</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit="calculate_fee">
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="calc[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Rate (%) *</label>
                <input type="number" name="calc[rate_pct]" class="form-input" step="any" value="2.0" required />
              </div>
              <div class="form-group">
                <label class="form-label">Basis *</label>
                <select name="calc[basis]" class="form-select" required>
                  <option value="nav">NAV</option>
                  <option value="committed_capital">Committed Capital</option>
                  <option value="invested_capital">Invested Capital</option>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Period Start *</label>
                <input type="date" name="calc[period_start]" class="form-input" required />
              </div>
              <div class="form-group">
                <label class="form-label">Period End *</label>
                <input type="date" name="calc[period_end]" class="form-input" required />
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Calculate & Save</button>
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
    company_id =
      case socket.assigns.selected_company_id do
        "" -> nil
        id -> String.to_integer(id)
      end

    fees = Fund.list_fund_fees(company_id)
    summary = if company_id, do: Fund.fee_summary(company_id), else: nil
    assign(socket, fees: fees, fee_summary: summary)
  end

  defp fee_type_tag("management"), do: "tag-sky"
  defp fee_type_tag("performance"), do: "tag-jade"
  defp fee_type_tag("admin"), do: "tag-slate"
  defp fee_type_tag("custody"), do: "tag-lemon"
  defp fee_type_tag(_), do: "tag-slate"

  defp fee_status_tag("accrued"), do: "tag-lemon"
  defp fee_status_tag("invoiced"), do: "tag-sky"
  defp fee_status_tag("paid"), do: "tag-jade"
  defp fee_status_tag("waived"), do: "tag-slate"
  defp fee_status_tag(_), do: "tag-slate"

  defp format_decimal(nil), do: "---"
  defp format_decimal(%Decimal{} = d), do: d |> Decimal.round(2) |> Decimal.to_string()
  defp format_decimal(n) when is_number(n), do: Money.format(n)
  defp format_decimal(_), do: "---"
end
