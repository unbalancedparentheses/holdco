defmodule HoldcoWeb.TransactionsLive.Show do
  use HoldcoWeb, :live_view

  alias Holdco.{Banking, Corporate, Finance, Platform, Assets}
  alias Holdco.Money

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    transaction = Banking.get_transaction!(String.to_integer(id))
    company = if transaction.company_id, do: Corporate.get_company!(transaction.company_id), else: nil

    related_journal_entries =
      Finance.list_journal_entries(transaction.company_id)
      |> Enum.filter(fn je -> je.date == transaction.date end)
      |> Enum.take(10)

    counterparty_transactions =
      if transaction.counterparty do
        Banking.list_transactions()
        |> Enum.filter(fn tx -> tx.counterparty == transaction.counterparty and tx.id != transaction.id end)
        |> Enum.take(10)
      else
        []
      end

    linked_holding =
      if transaction.asset_holding_id do
        try do
          Assets.get_holding!(transaction.asset_holding_id)
        rescue
          _ -> nil
        end
      else
        nil
      end

    audit_logs = Platform.list_audit_logs(%{table_name: "transactions", limit: 20})

    {:ok,
     assign(socket,
       page_title: transaction.description || "Transaction",
       transaction: transaction,
       company: company,
       related_journal_entries: related_journal_entries,
       counterparty_transactions: counterparty_transactions,
       linked_holding: linked_holding,
       audit_logs: audit_logs
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Transaction Detail</h1>
          <p class="deck">{@transaction.description}</p>
        </div>
        <.link navigate={~p"/transactions"} class="btn btn-secondary">Back to Transactions</.link>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Amount</div>
        <div class={"metric-value #{if @transaction.transaction_type == "debit" or Money.negative?(@transaction.amount), do: "num-negative", else: "num-positive"}"}>
          {format_currency(@transaction.amount, @transaction.currency)}
        </div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Type</div>
        <div class="metric-value">{@transaction.transaction_type}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Date</div>
        <div class="metric-value">{@transaction.date}</div>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Details</h2>
      </div>
      <div class="panel" style="padding: 1rem;">
        <dl class="detail-list">
          <div class="detail-row">
            <dt>Description</dt>
            <dd>{@transaction.description || "---"}</dd>
          </div>
          <div class="detail-row">
            <dt>Counterparty</dt>
            <dd>{@transaction.counterparty || "---"}</dd>
          </div>
          <div class="detail-row">
            <dt>Currency</dt>
            <dd>{@transaction.currency}</dd>
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

    <%= if @linked_holding do %>
      <div class="section">
        <div class="section-head"><h2>Linked Holding</h2></div>
        <div class="panel" style="padding: 1rem;">
          <.link navigate={~p"/holdings/#{@linked_holding.id}"} class="td-link">{@linked_holding.asset} ({@linked_holding.ticker})</.link>
          — {format_number(@linked_holding.quantity)} units
        </div>
      </div>
    <% end %>

    <%= if @transaction.counterparty && @counterparty_transactions != [] do %>
      <div class="section">
        <div class="section-head">
          <h2>Other Transactions with {@transaction.counterparty}</h2>
          <span class="count">{length(@counterparty_transactions)}</span>
        </div>
        <div class="panel">
          <table>
            <thead><tr><th>Date</th><th>Type</th><th>Description</th><th class="th-num">Amount</th></tr></thead>
            <tbody>
              <%= for tx <- @counterparty_transactions do %>
                <tr>
                  <td class="td-mono"><.link navigate={~p"/transactions/#{tx.id}"} class="td-link">{tx.date}</.link></td>
                  <td><span class="tag tag-ink">{tx.transaction_type}</span></td>
                  <td class="td-name">{tx.description}</td>
                  <td class={"td-num #{if tx.transaction_type == "debit" or Money.negative?(tx.amount), do: "num-negative", else: "num-positive"}"}>{format_currency(tx.amount, tx.currency)}</td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    <% end %>

    <%= if @related_journal_entries != [] do %>
      <div class="section">
        <div class="section-head">
          <h2>Related Journal Entries</h2>
          <span class="count">{length(@related_journal_entries)}</span>
        </div>
        <div class="panel">
          <table>
            <thead><tr><th>Date</th><th>Reference</th><th>Description</th><th>Lines</th></tr></thead>
            <tbody>
              <%= for je <- @related_journal_entries do %>
                <tr>
                  <td class="td-mono">{je.date}</td>
                  <td class="td-mono">{je.reference || "---"}</td>
                  <td class="td-name">{je.description}</td>
                  <td>{length(je.lines)}</td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    <% end %>

    <%= if @audit_logs != [] do %>
      <div class="section">
        <div class="section-head">
          <h2>Audit Trail</h2>
          <span class="count">{length(@audit_logs)}</span>
        </div>
        <div class="panel">
          <table>
            <thead><tr><th>Action</th><th>User</th><th>Time</th></tr></thead>
            <tbody>
              <%= for log <- @audit_logs do %>
                <tr>
                  <td><span class="tag tag-ink">{log.action}</span></td>
                  <td>{if log.user, do: log.user.email, else: "system"}</td>
                  <td class="td-mono">{Calendar.strftime(log.inserted_at, "%Y-%m-%d %H:%M")}</td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    <% end %>
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
