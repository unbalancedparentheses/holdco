defmodule HoldcoWeb.BankAccountsLive.Show do
  use HoldcoWeb, :live_view

  alias Holdco.{Banking, Corporate}
  alias Holdco.Money

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    account = Banking.get_bank_account!(String.to_integer(id))
    company = if account.company_id, do: Corporate.get_company!(account.company_id), else: nil

    transactions =
      Banking.list_transactions()
      |> Enum.filter(&(&1.company_id == account.company_id))

    {:ok,
     assign(socket,
       page_title: account.bank_name,
       account: account,
       company: company,
       transactions: transactions
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
end
