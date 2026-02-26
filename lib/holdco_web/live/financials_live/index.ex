defmodule HoldcoWeb.FinancialsLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Finance, Corporate, Portfolio}

  @currencies ~w(USD EUR GBP ARS BRL CHF JPY CAD AUD)

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Holdco.Platform.subscribe("finance")

    financials = Finance.list_financials()
    companies = Corporate.list_companies()
    transfers = Finance.list_inter_company_transfers()
    display_currency = "USD"
    {cons_rev, cons_exp, cons_liab} = consolidated_totals(financials, display_currency)

    {:ok,
     assign(socket,
       page_title: "Financials",
       financials: financials,
       companies: companies,
       total_revenue: cons_rev,
       total_expenses: cons_exp,
       total_liabilities: cons_liab,
       transfers: transfers,
       show_form: false,
       show_transfer_form: false,
       display_currency: display_currency,
       currencies: @currencies
     )}
  end

  @impl true
  def handle_event("show_form", _, socket), do: {:noreply, assign(socket, show_form: true)}
  def handle_event("close_form", _, socket), do: {:noreply, assign(socket, show_form: false)}

  def handle_event("show_transfer_form", _, socket),
    do: {:noreply, assign(socket, show_transfer_form: true)}

  def handle_event("close_transfer_form", _, socket),
    do: {:noreply, assign(socket, show_transfer_form: false)}

  def handle_event("change_currency", %{"currency" => currency}, socket) do
    {cons_rev, cons_exp, cons_liab} = consolidated_totals(socket.assigns.financials, currency)

    {:noreply,
     assign(socket,
       display_currency: currency,
       total_revenue: cons_rev,
       total_expenses: cons_exp,
       total_liabilities: cons_liab
     )}
  end

  def handle_event("save", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("delete", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("save_transfer", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("delete_transfer", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("save", %{"financial" => params}, socket) do
    case Finance.create_financial(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket) |> put_flash(:info, "Financial record added") |> assign(show_form: false)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add record")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    financial = Finance.get_financial!(String.to_integer(id))
    Finance.delete_financial(financial)
    {:noreply, reload(socket) |> put_flash(:info, "Financial record deleted")}
  end

  def handle_event("save_transfer", %{"transfer" => params}, socket) do
    case Finance.create_inter_company_transfer(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Transfer created")
         |> assign(show_transfer_form: false)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create transfer")}
    end
  end

  def handle_event("delete_transfer", %{"id" => id}, socket) do
    transfer = Finance.get_inter_company_transfer!(String.to_integer(id))
    Finance.delete_inter_company_transfer(transfer)
    {:noreply, reload(socket) |> put_flash(:info, "Transfer deleted")}
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, reload(socket)}

  defp reload(socket) do
    financials = Finance.list_financials()
    transfers = Finance.list_inter_company_transfers()
    ccy = socket.assigns.display_currency
    {cons_rev, cons_exp, cons_liab} = consolidated_totals(financials, ccy)

    assign(socket,
      financials: financials,
      total_revenue: cons_rev,
      total_expenses: cons_exp,
      total_liabilities: cons_liab,
      transfers: transfers
    )
  end

  defp consolidated_totals(financials, target_currency) do
    {rev, exp} =
      Enum.reduce(financials, {0.0, 0.0}, fn f, {r, e} ->
        rate = convert_rate(f.currency, target_currency)
        {r + (f.revenue || 0.0) * rate, e + (f.expenses || 0.0) * rate}
      end)

    liab =
      Finance.list_liabilities()
      |> Enum.filter(&(&1.status == "active"))
      |> Enum.reduce(0.0, fn l, acc ->
        acc + (l.principal || 0.0) * convert_rate(l.currency, target_currency)
      end)

    {rev, exp, liab}
  end

  defp convert_rate(from, to) when from == to, do: 1.0

  defp convert_rate(from, to) do
    from_usd = Portfolio.get_fx_rate(from)
    to_usd = Portfolio.get_fx_rate(to)
    if to_usd > 0, do: from_usd / to_usd, else: 1.0
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Financials</h1>
          <p class="deck">
            P&L across all companies and periods (consolidated in {@display_currency})
          </p>
        </div>
        <div style="display: flex; gap: 0.5rem; align-items: center;">
          <form phx-change="change_currency" style="display: flex; align-items: center; gap: 0.5rem;">
            <label class="form-label" style="margin: 0; font-size: 0.85rem;">Currency</label>
            <select name="currency" class="form-select" style="width: auto; padding: 0.3rem 0.5rem;">
              <%= for ccy <- @currencies do %>
                <option value={ccy} selected={ccy == @display_currency}>{ccy}</option>
              <% end %>
            </select>
          </form>
          <%= if @can_write do %>
            <button class="btn btn-primary" phx-click="show_form">Add Period</button>
          <% end %>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <% sym = currency_symbol(@display_currency) %>
    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Revenue</div>
        <div class="metric-value num-positive">{sym}{format_number(@total_revenue)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Total Expenses</div>
        <div class="metric-value num-negative">{sym}{format_number(@total_expenses)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Net Income</div>
        <div class={"metric-value #{if @total_revenue - @total_expenses >= 0, do: "num-positive", else: "num-negative"}"}>
          {sym}{format_number(@total_revenue - @total_expenses)}
        </div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Total Liabilities</div>
        <div class="metric-value num-negative">{sym}{format_number(@total_liabilities)}</div>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>P&L Trend</h2>
      </div>
      <div class="panel" style="padding: 1rem;">
        <div
          id="pl-chart"
          phx-hook="ChartHook"
          data-chart-type="bar"
          data-chart-data={Jason.encode!(pl_chart_data(@financials))}
          data-chart-options={
            Jason.encode!(%{plugins: %{legend: %{display: true}}, scales: %{y: %{beginAtZero: true}}})
          }
          style="height: 250px;"
        >
          <canvas></canvas>
        </div>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>All Periods</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Period</th>
              <th>Company</th>
              <th class="th-num">Revenue</th>
              <th class="th-num">Expenses</th>
              <th class="th-num">Net</th>
              <th>Currency</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for f <- @financials do %>
              <% net = (f.revenue || 0) - (f.expenses || 0) %>
              <tr>
                <td class="td-mono">{f.period}</td>
                <td>{if f.company, do: f.company.name, else: "---"}</td>
                <td class="td-num num-positive">{format_number(f.revenue || 0)}</td>
                <td class="td-num num-negative">{format_number(f.expenses || 0)}</td>
                <td class={"td-num #{if net >= 0, do: "num-positive", else: "num-negative"}"}>
                  {format_number(net)}
                </td>
                <td>{f.currency}</td>
                <td>
                  <%= if @can_write do %>
                    <button
                      phx-click="delete"
                      phx-value-id={f.id}
                      class="btn btn-danger btn-sm"
                      data-confirm="Delete?"
                    >
                      Del
                    </button>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @financials == [] do %>
          <div class="empty-state">No financial records yet.</div>
        <% end %>
      </div>
    </div>

    <div class="section">
      <div
        class="section-head"
        style="display: flex; justify-content: space-between; align-items: center;"
      >
        <h2>Intercompany Transfers</h2>
        <%= if @can_write do %>
          <button class="btn btn-primary btn-sm" phx-click="show_transfer_form">Add Transfer</button>
        <% end %>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Date</th>
              <th>From</th>
              <th>To</th>
              <th class="th-num">Amount</th>
              <th>Currency</th>
              <th>Description</th>
              <th>Status</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for t <- @transfers do %>
              <tr>
                <td class="td-mono">{t.date}</td>
                <td class="td-name">{if t.from_company, do: t.from_company.name, else: "---"}</td>
                <td class="td-name">{if t.to_company, do: t.to_company.name, else: "---"}</td>
                <td class="td-num">{format_number(t.amount || 0)}</td>
                <td>{t.currency}</td>
                <td>{t.description}</td>
                <td>{t.status}</td>
                <td>
                  <%= if @can_write do %>
                    <button
                      phx-click="delete_transfer"
                      phx-value-id={t.id}
                      class="btn btn-danger btn-sm"
                      data-confirm="Delete?"
                    >
                      Del
                    </button>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @transfers == [] do %>
          <div class="empty-state">No intercompany transfers yet.</div>
        <% end %>
      </div>
    </div>

    <%= if @show_transfer_form do %>
      <div class="modal-overlay" phx-click="close_transfer_form">
        <div class="modal" phx-click-away="close_transfer_form">
          <div class="modal-header">
            <h3>Add Intercompany Transfer</h3>
          </div>
          <div class="modal-body">
            <form phx-submit="save_transfer">
              <div class="form-group">
                <label class="form-label">From Company *</label>
                <select name="transfer[from_company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">To Company *</label>
                <select name="transfer[to_company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Amount *</label>
                <input type="number" name="transfer[amount]" class="form-input" step="any" required />
              </div>
              <div class="form-group">
                <label class="form-label">Currency</label>
                <input type="text" name="transfer[currency]" class="form-input" value="USD" />
              </div>
              <div class="form-group">
                <label class="form-label">Date *</label>
                <input type="date" name="transfer[date]" class="form-input" required />
              </div>
              <div class="form-group">
                <label class="form-label">Description</label><textarea
                  name="transfer[description]"
                  class="form-input"
                ></textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Add Transfer</button>
                <button type="button" phx-click="close_transfer_form" class="btn btn-secondary">
                  Cancel
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>

    <%= if @show_form do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click-away="close_form">
          <div class="modal-header">
            <h3>Add Financial Period</h3>
          </div>
          <div class="modal-body">
            <form phx-submit="save">
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="financial[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Period *</label>
                <input
                  type="text"
                  name="financial[period]"
                  class="form-input"
                  placeholder="e.g. 2025-Q1"
                  required
                />
              </div>
              <div class="form-group">
                <label class="form-label">Revenue</label>
                <input
                  type="number"
                  name="financial[revenue]"
                  class="form-input"
                  step="any"
                  value="0"
                />
              </div>
              <div class="form-group">
                <label class="form-label">Expenses</label>
                <input
                  type="number"
                  name="financial[expenses]"
                  class="form-input"
                  step="any"
                  value="0"
                />
              </div>
              <div class="form-group">
                <label class="form-label">Currency</label>
                <input type="text" name="financial[currency]" class="form-input" value="USD" />
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label><textarea
                  name="financial[notes]"
                  class="form-input"
                ></textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Add Period</button>
                <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp currency_symbol("USD"), do: "$"
  defp currency_symbol("EUR"), do: "€"
  defp currency_symbol("GBP"), do: "£"
  defp currency_symbol("JPY"), do: "¥"
  defp currency_symbol("CHF"), do: "CHF "
  defp currency_symbol(ccy), do: "#{ccy} "

  defp format_number(n) when is_float(n),
    do: :erlang.float_to_binary(n, decimals: 0) |> add_commas()

  defp format_number(n) when is_integer(n), do: Integer.to_string(n) |> add_commas()
  defp format_number(_), do: "0"

  defp add_commas(str) do
    str |> String.reverse() |> String.replace(~r/(\d{3})(?=\d)/, "\\1,") |> String.reverse()
  end

  defp pl_chart_data(financials) do
    sorted = financials |> Enum.sort_by(& &1.period)

    %{
      labels: Enum.map(sorted, & &1.period),
      datasets: [
        %{label: "Revenue", data: Enum.map(sorted, & &1.revenue), backgroundColor: "#00994d"},
        %{label: "Expenses", data: Enum.map(sorted, & &1.expenses), backgroundColor: "#cc0000"}
      ]
    }
  end
end
