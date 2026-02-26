defmodule HoldcoWeb.TransactionsLive.Show do
  use HoldcoWeb, :live_view

  alias Holdco.{Banking, Corporate}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    transaction = Banking.get_transaction!(String.to_integer(id))
    company = if transaction.company_id, do: Corporate.get_company!(transaction.company_id), else: nil

    {:ok,
     assign(socket,
       page_title: transaction.description || "Transaction",
       transaction: transaction,
       company: company
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
        <div class={"metric-value #{if (@transaction.amount || 0) < 0, do: "num-negative", else: "num-positive"}"}>
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
    """
  end

  defp format_number(n) when is_float(n),
    do: :erlang.float_to_binary(n, decimals: 0) |> add_commas()

  defp format_number(n) when is_integer(n), do: Integer.to_string(n) |> add_commas()
  defp format_number(_), do: "0"

  defp add_commas(str) do
    str |> String.reverse() |> String.replace(~r/(\d{3})(?=\d)/, "\\1,") |> String.reverse()
  end

  defp format_currency(nil, _currency), do: "0"

  defp format_currency(amount, currency) do
    sign = if amount < 0, do: "-", else: ""
    "#{sign}#{format_number(abs(amount))} #{currency}"
  end
end
