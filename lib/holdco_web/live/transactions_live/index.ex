defmodule HoldcoWeb.TransactionsLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Banking, Corporate}
  alias Holdco.Money

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Holdco.Platform.subscribe("banking")

    transactions = Banking.list_transactions()
    companies = Corporate.list_companies()

    inflows =
      transactions
      |> Enum.filter(&Money.positive?(&1.amount))
      |> Enum.reduce(Decimal.new(0), fn tx, acc -> Money.add(acc, tx.amount) end)

    outflows =
      transactions
      |> Enum.filter(&Money.negative?(&1.amount))
      |> Enum.reduce(Decimal.new(0), fn tx, acc -> Money.add(acc, tx.amount) end)

    {:ok,
     assign(socket,
       page_title: "Transactions",
       transactions: transactions,
       companies: companies,
       inflows: inflows,
       outflows: outflows,
       selected_company_id: "",
       show_form: false,
       editing_item: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("show_form", _, socket),
    do: {:noreply, assign(socket, show_form: :add, editing_item: nil)}

  def handle_event("close_form", _, socket),
    do: {:noreply, assign(socket, show_form: false, editing_item: nil)}

  def handle_event("edit", %{"id" => id}, socket) do
    transaction = Banking.get_transaction!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: transaction)}
  end

  def handle_event("filter_company", %{"company_id" => id}, socket) do
    company_id = if id == "", do: nil, else: String.to_integer(id)

    transactions =
      Banking.list_transactions()
      |> then(fn txs ->
        if company_id, do: Enum.filter(txs, &(&1.company_id == company_id)), else: txs
      end)

    inflows =
      transactions
      |> Enum.filter(&Money.positive?(&1.amount))
      |> Enum.reduce(Decimal.new(0), fn tx, acc -> Money.add(acc, tx.amount) end)

    outflows =
      transactions
      |> Enum.filter(&Money.negative?(&1.amount))
      |> Enum.reduce(Decimal.new(0), fn tx, acc -> Money.add(acc, tx.amount) end)

    {:noreply,
     assign(socket,
       selected_company_id: id,
       transactions: transactions,
       inflows: inflows,
       outflows: outflows
     )}
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

  def handle_event("save", %{"transaction" => params}, socket) do
    case Banking.create_transaction(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket) |> put_flash(:info, "Transaction added") |> assign(show_form: false)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add transaction")}
    end
  end

  def handle_event("update", %{"transaction" => params}, socket) do
    transaction = socket.assigns.editing_item

    case Banking.update_transaction(transaction, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Transaction updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update transaction")}
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

    inflows =
      transactions
      |> Enum.filter(&Money.positive?(&1.amount))
      |> Enum.reduce(Decimal.new(0), fn tx, acc -> Money.add(acc, tx.amount) end)

    outflows =
      transactions
      |> Enum.filter(&Money.negative?(&1.amount))
      |> Enum.reduce(Decimal.new(0), fn tx, acc -> Money.add(acc, tx.amount) end)

    assign(socket, transactions: transactions, inflows: inflows, outflows: outflows)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Transactions</h1>
          <p class="deck">{length(@transactions)} transactions across all entities</p>
        </div>
        <div style="display: flex; gap: 0.5rem; align-items: center;">
          <a href={~p"/export/transactions.csv"} class="btn btn-secondary">
            Export CSV
          </a>
          <%= if @can_write do %>
            <.link navigate={~p"/import?type=transactions"} class="btn btn-secondary">
              Import CSV
            </.link>
            <button class="btn btn-primary" phx-click="show_form">Add Transaction</button>
          <% end %>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div style="margin-bottom: 1rem;">
      <form phx-change="filter_company" style="display: flex; align-items: center; gap: 0.5rem;">
        <label class="form-label" style="margin: 0; font-size: 0.85rem;">Company</label>
        <select name="company_id" class="form-select" style="width: auto; padding: 0.3rem 0.5rem;">
          <option value="">All Companies</option>
          <%= for c <- @companies do %>
            <option value={c.id} selected={to_string(c.id) == @selected_company_id}>{c.name}</option>
          <% end %>
        </select>
      </form>
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Inflows</div>
        <div class="metric-value num-positive">${format_number(@inflows)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Total Outflows</div>
        <div class="metric-value num-negative">${format_number(Money.abs(@outflows))}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Net</div>
        <div class={"metric-value #{if Money.gte?(Money.add(@inflows, @outflows), 0), do: "num-positive", else: "num-negative"}"}>
          ${format_number(Money.add(@inflows, @outflows))}
        </div>
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
        <h2>All Transactions</h2>
      </div>
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
                <td class="td-mono">{tx.date}</td>
                <td><span class="tag tag-ink">{tx.transaction_type}</span></td>
                <td class="td-name"><.link navigate={~p"/transactions/#{tx.id}"} class="td-link">{tx.description}</.link></td>
                <td>{tx.counterparty}</td>
                <td class={"td-num #{if Money.negative?(tx.amount), do: "num-negative", else: "num-positive"}"}>
                  {format_currency(tx.amount, tx.currency)}
                </td>
                <td>{tx.currency}</td>
                <td>
                  <%= if tx.company do %>
                    <.link navigate={~p"/companies/#{tx.company.id}"} class="td-link">{tx.company.name}</.link>
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit" phx-value-id={tx.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button
                        phx-click="delete"
                        phx-value-id={tx.id}
                        class="btn btn-danger btn-sm"
                        data-confirm="Delete?"
                      >
                        Del
                      </button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @transactions == [] do %>
          <div class="empty-state">
            <p>No transactions yet.</p>
            <p style="color: var(--muted); font-size: 0.9rem;">Transactions record money flowing in and out of your entities.</p>
            <%= if @can_write do %>
              <div style="margin-top: 0.75rem;">
                <button class="btn btn-primary btn-sm" phx-click="show_form">Add your first transaction</button>
                <span style="margin: 0 0.5rem; color: var(--muted);">or</span>
                <.link navigate={~p"/import?type=transactions"} class="btn btn-secondary btn-sm">Import from CSV</.link>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit Transaction", else: "Add Transaction"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="transaction[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={@editing_item && @editing_item.company_id == c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Date *</label>
                <input type="text" name="transaction[date]" class="form-input" placeholder="YYYY-MM-DD" required value={if @editing_item, do: @editing_item.date} />
              </div>
              <div class="form-group">
                <label class="form-label">Type *</label>
                <input type="text" name="transaction[transaction_type]" class="form-input" required value={if @editing_item, do: @editing_item.transaction_type} />
              </div>
              <div class="form-group">
                <label class="form-label">Amount *</label>
                <input type="number" name="transaction[amount]" class="form-input" step="any" required value={if @editing_item, do: @editing_item.amount} />
              </div>
              <div class="form-group">
                <label class="form-label">Currency</label>
                <input type="text" name="transaction[currency]" class="form-input" value={if @editing_item, do: @editing_item.currency, else: "USD"} />
              </div>
              <div class="form-group">
                <label class="form-label">Description</label>
                <input type="text" name="transaction[description]" class="form-input" value={if @editing_item, do: @editing_item.description} />
              </div>
              <div class="form-group">
                <label class="form-label">Counterparty</label>
                <input type="text" name="transaction[counterparty]" class="form-input" value={if @editing_item, do: @editing_item.counterparty} />
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">{if @show_form == :edit, do: "Save Changes", else: "Add Transaction"}</button>
                <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp format_number(%Decimal{} = n),
    do: :erlang.float_to_binary(Money.to_float(n), decimals: 0) |> add_commas()

  defp format_number(n) when is_float(n),
    do: :erlang.float_to_binary(n, decimals: 0) |> add_commas()

  defp format_number(n) when is_integer(n), do: Integer.to_string(n) |> add_commas()
  defp format_number(_), do: "0"

  defp add_commas(str) do
    str |> String.reverse() |> String.replace(~r/(\d{3})(?=\d)/, "\\1,") |> String.reverse()
  end

  defp format_currency(nil, _currency), do: "0"

  defp format_currency(amount, currency) do
    sign = if Money.negative?(amount), do: "-", else: ""
    "#{sign}#{format_number(Money.abs(amount))} #{currency}"
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

    inflows =
      Enum.map(by_month, fn {_, txs} ->
        txs
        |> Enum.filter(&Money.positive?(&1.amount))
        |> Enum.reduce(Decimal.new(0), fn t, a -> Money.add(a, t.amount) end)
        |> Money.to_float()
      end)

    outflows =
      Enum.map(by_month, fn {_, txs} ->
        txs
        |> Enum.filter(&Money.negative?(&1.amount))
        |> Enum.reduce(Decimal.new(0), fn t, a -> Money.add(a, Money.abs(t.amount)) end)
        |> Money.to_float()
      end)

    %{
      labels: labels,
      datasets: [
        %{label: "Inflows", data: inflows, backgroundColor: "#5f8f6e"},
        %{label: "Outflows", data: outflows, backgroundColor: "#b0605e"}
      ]
    }
  end
end
