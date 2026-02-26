defmodule HoldcoWeb.TransactionsLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Banking, Corporate}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Holdco.Platform.subscribe("banking")

    transactions = Banking.list_transactions()
    companies = Corporate.list_companies()

    inflows = transactions |> Enum.filter(&((&1.amount || 0) > 0)) |> Enum.reduce(0.0, fn tx, acc -> acc + tx.amount end)
    outflows = transactions |> Enum.filter(&((&1.amount || 0) < 0)) |> Enum.reduce(0.0, fn tx, acc -> acc + tx.amount end)

    {:ok, assign(socket,
      page_title: "Transactions",
      transactions: transactions,
      companies: companies,
      inflows: inflows,
      outflows: outflows,
      show_form: false
    )}
  end

  @impl true
  def handle_event("show_form", _, socket), do: {:noreply, assign(socket, show_form: true)}
  def handle_event("close_form", _, socket), do: {:noreply, assign(socket, show_form: false)}

  def handle_event("save", %{"transaction" => params}, socket) do
    case Banking.create_transaction(params) do
      {:ok, _} -> {:noreply, reload(socket) |> put_flash(:info, "Transaction added") |> assign(show_form: false)}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Failed to add transaction")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    transaction = Banking.get_transaction!(String.to_integer(id))
    Banking.delete_transaction(transaction)
    {:noreply, reload(socket) |> put_flash(:info, "Transaction deleted")}
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, reload(socket)}

  defp reload(socket) do
    transactions = Banking.list_transactions()
    inflows = transactions |> Enum.filter(&((&1.amount || 0) > 0)) |> Enum.reduce(0.0, fn tx, acc -> acc + tx.amount end)
    outflows = transactions |> Enum.filter(&((&1.amount || 0) < 0)) |> Enum.reduce(0.0, fn tx, acc -> acc + tx.amount end)
    assign(socket, transactions: transactions, inflows: inflows, outflows: outflows)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Transactions</h1>
          <p class="deck"><%= length(@transactions) %> transactions across all entities</p>
        </div>
        <button class="btn btn-primary" phx-click="show_form">Add Transaction</button>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Inflows</div>
        <div class="metric-value num-positive">$<%= format_number(@inflows) %></div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Total Outflows</div>
        <div class="metric-value num-negative">$<%= format_number(abs(@outflows)) %></div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Net</div>
        <div class={"metric-value #{if @inflows + @outflows >= 0, do: "num-positive", else: "num-negative"}"}>$<%= format_number(@inflows + @outflows) %></div>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Transaction Flow</h2>
      </div>
      <div class="panel" style="padding: 1rem;">
        <div
          id="tx-chart"
          phx-hook="ChartHook"
          data-chart-type="bar"
          data-chart-data={Jason.encode!(tx_chart_data(@transactions))}
          data-chart-options={Jason.encode!(%{plugins: %{legend: %{display: true}}, scales: %{y: %{beginAtZero: true}}})}
          style="height: 250px;"
        >
          <canvas></canvas>
        </div>
      </div>
    </div>

    <div class="section">
      <div class="section-head"><h2>All Transactions</h2></div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Date</th>
              <th>Type</th>
              <th>Description</th>
              <th>Counterparty</th>
              <th class="th-num">Amount</th>
              <th>Currency</th>
              <th>Company</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for tx <- @transactions do %>
              <tr>
                <td class="td-mono"><%= tx.date %></td>
                <td><span class="tag tag-ink"><%= tx.transaction_type %></span></td>
                <td class="td-name"><%= tx.description %></td>
                <td><%= tx.counterparty %></td>
                <td class={"td-num #{if (tx.amount || 0) < 0, do: "num-negative", else: "num-positive"}"}><%= tx.amount %> <%= tx.currency %></td>
                <td><%= tx.currency %></td>
                <td><%= if tx.company, do: tx.company.name, else: "---" %></td>
                <td><button phx-click="delete" phx-value-id={tx.id} class="btn btn-danger btn-sm" data-confirm="Delete?">Del</button></td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @transactions == [] do %>
          <div class="empty-state">No transactions yet.</div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click-away="close_form">
          <div class="modal-header"><h3>Add Transaction</h3></div>
          <div class="modal-body">
            <form phx-submit="save">
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="transaction[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %><option value={c.id}><%= c.name %></option><% end %>
                </select>
              </div>
              <div class="form-group"><label class="form-label">Date *</label><input type="text" name="transaction[date]" class="form-input" placeholder="YYYY-MM-DD" required /></div>
              <div class="form-group"><label class="form-label">Type *</label><input type="text" name="transaction[transaction_type]" class="form-input" required /></div>
              <div class="form-group"><label class="form-label">Amount *</label><input type="number" name="transaction[amount]" class="form-input" step="any" required /></div>
              <div class="form-group"><label class="form-label">Currency</label><input type="text" name="transaction[currency]" class="form-input" value="USD" /></div>
              <div class="form-group"><label class="form-label">Description</label><input type="text" name="transaction[description]" class="form-input" /></div>
              <div class="form-group"><label class="form-label">Counterparty</label><input type="text" name="transaction[counterparty]" class="form-input" /></div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Add Transaction</button>
                <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp format_number(n) when is_float(n), do: :erlang.float_to_binary(n, decimals: 0) |> add_commas()
  defp format_number(n) when is_integer(n), do: Integer.to_string(n) |> add_commas()
  defp format_number(_), do: "0"

  defp add_commas(str) do
    str |> String.reverse() |> String.replace(~r/(\d{3})(?=\d)/, "\\1,") |> String.reverse()
  end

  defp tx_chart_data(transactions) do
    by_month =
      transactions
      |> Enum.group_by(fn tx ->
        case tx.date do
          nil -> "Unknown"
          d -> String.slice(d, 0, 7)
        end
      end)
      |> Enum.sort_by(fn {k, _} -> k end)

    labels = Enum.map(by_month, fn {k, _} -> k end)
    inflows = Enum.map(by_month, fn {_, txs} -> txs |> Enum.filter(&((&1.amount || 0) > 0)) |> Enum.reduce(0.0, fn t, a -> a + t.amount end) end)
    outflows = Enum.map(by_month, fn {_, txs} -> txs |> Enum.filter(&((&1.amount || 0) < 0)) |> Enum.reduce(0.0, fn t, a -> a + abs(t.amount) end) end)

    %{
      labels: labels,
      datasets: [
        %{label: "Inflows", data: inflows, backgroundColor: "#00994d"},
        %{label: "Outflows", data: outflows, backgroundColor: "#cc0000"}
      ]
    }
  end
end
