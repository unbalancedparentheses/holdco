defmodule HoldcoWeb.BankAccountsLive.Show do
  use HoldcoWeb, :live_view

  alias Holdco.{Banking, Corporate, Portfolio}
  alias Holdco.Money

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    account = Banking.get_bank_account!(String.to_integer(id))
    company = if account.company_id, do: Corporate.get_company!(account.company_id), else: nil

    transactions =
      Banking.list_transactions()
      |> Enum.filter(&(&1.company_id == account.company_id && &1.currency == account.currency))

    inflow =
      transactions
      |> Enum.filter(&(&1.transaction_type == "credit"))
      |> Enum.reduce(Decimal.new(0), fn tx, acc -> Money.add(acc, Money.to_decimal(tx.amount)) end)

    outflow =
      transactions
      |> Enum.filter(&(&1.transaction_type == "debit"))
      |> Enum.reduce(Decimal.new(0), fn tx, acc -> Money.add(acc, Money.abs(Money.to_decimal(tx.amount))) end)

    net = Money.sub(inflow, outflow)

    usd_balance = Portfolio.to_usd(account.balance, account.currency)

    monthly_data =
      transactions
      |> Enum.group_by(fn tx -> String.slice(to_string(tx.date), 0, 7) end)
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.take(-12)

    {:ok,
     assign(socket,
       page_title: account.bank_name,
       account: account,
       company: company,
       transactions: transactions,
       inflow: inflow,
       outflow: outflow,
       net: net,
       usd_balance: usd_balance,
       monthly_data: monthly_data
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>{@account.bank_name}</h1>
          <p class="deck">Bank account details</p>
        </div>
        <.link navigate={~p"/bank-accounts"} class="btn btn-secondary">Back to Accounts</.link>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Balance</div>
        <div class="metric-value">${format_number(@account.balance || 0)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Currency</div>
        <div class="metric-value">{@account.currency}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Type</div>
        <div class="metric-value">{@account.account_type}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Inflow</div>
        <div class="metric-value num-positive">{format_currency(@inflow, @account.currency)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Outflow</div>
        <div class="metric-value num-negative">{format_currency(@outflow, @account.currency)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Net Flow</div>
        <div class={"metric-value #{if Money.negative?(@net), do: "num-negative", else: "num-positive"}"}>{format_currency(@net, @account.currency)}</div>
      </div>
      <%= if @account.currency != "USD" do %>
        <div class="metric-cell">
          <div class="metric-label">USD Equivalent</div>
          <div class="metric-value">${format_number(@usd_balance)}</div>
        </div>
      <% end %>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Account Details</h2>
      </div>
      <div class="panel" style="padding: 1rem;">
        <dl class="detail-list">
          <div class="detail-row">
            <dt>Bank Name</dt>
            <dd>{@account.bank_name}</dd>
          </div>
          <div class="detail-row">
            <dt>Account Number</dt>
            <dd class="td-mono">{@account.account_number || "---"}</dd>
          </div>
          <div class="detail-row">
            <dt>IBAN</dt>
            <dd class="td-mono">{@account.iban || "---"}</dd>
          </div>
          <div class="detail-row">
            <dt>SWIFT</dt>
            <dd class="td-mono">{@account.swift || "---"}</dd>
          </div>
          <div class="detail-row">
            <dt>Company</dt>
            <dd>
              <%= if @company do %>
                <.link navigate={~p"/companies/#{@company.id}"} class="td-link">{@company.name}</.link>
              <% else %>
                ---
              <% end %>
            </dd>
          </div>
        </dl>
      </div>
    </div>

    <div class="section">
      <div class="section-head"><h2>Monthly Flow</h2></div>
      <div class="panel">
        <div id="bank-monthly-chart" phx-hook="ChartHook"
          data-chart-type="bar"
          data-chart-data={Jason.encode!(monthly_chart_data(@monthly_data))}
          data-chart-options={Jason.encode!(%{plugins: %{legend: %{position: "top"}}, scales: %{y: %{beginAtZero: true}}})}
          style="height: 260px;">
          <canvas></canvas>
        </div>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Related Transactions</h2>
        <span class="count">{length(@transactions)}</span>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Date</th>
              <th>Type</th>
              <th>Description</th>
              <th class="th-num">Amount</th>
              <th>Currency</th>
            </tr>
          </thead>
          <tbody>
            <%= for tx <- @transactions do %>
              <tr>
                <td class="td-mono">{tx.date}</td>
                <td><span class="tag tag-ink">{tx.transaction_type}</span></td>
                <td class="td-name">{tx.description}</td>
                <td class={"td-num #{if tx.transaction_type == "debit" or Money.negative?(tx.amount), do: "num-negative", else: "num-positive"}"}>
                  {format_currency(tx.amount, tx.currency)}
                </td>
                <td>{tx.currency}</td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @transactions == [] do %>
          <div class="empty-state">No transactions for this company.</div>
        <% end %>
      </div>
    </div>
    """
  end

  defp format_number(%Decimal{} = n),
    do: n |> Decimal.round(0) |> Decimal.to_string() |> add_commas()

  defp format_number(n) when is_float(n),
    do: Money.to_float(Money.round(n, 0)) |> :erlang.float_to_binary(decimals: 0) |> add_commas()

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

  defp monthly_chart_data(monthly_data) do
    labels = Enum.map(monthly_data, &elem(&1, 0))

    credits =
      Enum.map(monthly_data, fn {_month, txs} ->
        txs
        |> Enum.filter(&(&1.transaction_type == "credit"))
        |> Enum.reduce(0, fn tx, acc -> acc + Money.to_float(tx.amount) end)
      end)

    debits =
      Enum.map(monthly_data, fn {_month, txs} ->
        txs
        |> Enum.filter(&(&1.transaction_type == "debit"))
        |> Enum.reduce(0, fn tx, acc -> acc + abs(Money.to_float(tx.amount)) end)
      end)

    %{
      labels: labels,
      datasets: [
        %{label: "Inflow", data: credits, backgroundColor: "rgba(95, 143, 110, 0.7)"},
        %{label: "Outflow", data: debits, backgroundColor: "rgba(176, 96, 94, 0.7)"}
      ]
    }
  end
end
