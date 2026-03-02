defmodule HoldcoWeb.HoldingsLive.Show do
  use HoldcoWeb, :live_view

  alias Holdco.{Assets, Banking, Portfolio, Pricing}
  alias Holdco.Money

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket), do: Holdco.Platform.subscribe("portfolio")

    holding = Assets.get_holding!(id)
    lots = Assets.list_cost_basis_lots(holding.id)
    gains = compute_gains(holding, lots)
    current_value = Portfolio.holding_value(holding)
    price_history = load_price_history(holding.ticker)

    total_portfolio_value = Enum.reduce(Assets.list_holdings(), Decimal.new(0), fn h, acc -> Money.add(acc, Portfolio.holding_value(h)) end)
    portfolio_weight = if Money.gt?(total_portfolio_value, 0), do: Money.to_float(Money.round(Money.mult(Money.div(current_value, total_portfolio_value), 100), 1)), else: 0.0

    related_transactions = Banking.list_transactions()
      |> Enum.filter(&(&1.asset_holding_id == holding.id))
      |> Enum.take(20)

    {:ok,
     assign(socket,
       page_title: holding.asset,
       holding: holding,
       lots: lots,
       gains: gains,
       current_value: current_value,
       price_history: price_history,
       portfolio_weight: portfolio_weight,
       related_transactions: related_transactions
     )}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info(_, socket) do
    holding = Assets.get_holding!(socket.assigns.holding.id)
    lots = Assets.list_cost_basis_lots(holding.id)
    gains = compute_gains(holding, lots)
    current_value = Portfolio.holding_value(holding)
    price_history = load_price_history(holding.ticker)

    total_portfolio_value = Enum.reduce(Assets.list_holdings(), Decimal.new(0), fn h, acc -> Money.add(acc, Portfolio.holding_value(h)) end)
    portfolio_weight = if Money.gt?(total_portfolio_value, 0), do: Money.to_float(Money.round(Money.mult(Money.div(current_value, total_portfolio_value), 100), 1)), else: 0.0

    related_transactions = Banking.list_transactions()
      |> Enum.filter(&(&1.asset_holding_id == holding.id))
      |> Enum.take(20)

    {:noreply,
     assign(socket,
       holding: holding,
       lots: lots,
       gains: gains,
       current_value: current_value,
       price_history: price_history,
       portfolio_weight: portfolio_weight,
       related_transactions: related_transactions
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>{@holding.asset}</h1>
          <p class="deck">
            <%= if @holding.ticker do %>
              <span class="td-mono" style="margin-right: 0.5rem;">{@holding.ticker}</span>
            <% end %>
            <span class="tag tag-ink">{@holding.asset_type}</span>
          </p>
        </div>
        <.link navigate={~p"/holdings"} class="btn btn-secondary">Back to Positions</.link>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Current Value</div>
        <div class="metric-value">{format_usd(@current_value)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Quantity</div>
        <div class="metric-value">
          {format_number(@holding.quantity || 0.0)}
          <%= if @holding.unit do %>
            <span style="font-size: 0.75em; opacity: 0.7;">{@holding.unit}</span>
          <% end %>
        </div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Unrealized G/L</div>
        <div class="metric-value" style={gain_color(@gains.unrealized)}>
          {format_gain(@gains.unrealized)}
        </div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Realized G/L</div>
        <div class="metric-value" style={gain_color(@gains.realized)}>
          {format_gain(@gains.realized)}
        </div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Portfolio Weight</div>
        <div class="metric-value">{@portfolio_weight}%</div>
      </div>
    </div>

    <%= if @holding.ticker && @price_history != [] do %>
      <div class="section">
        <div class="section-head">
          <h2>Price History</h2>
          <span class="count">{length(@price_history)} data points</span>
        </div>
        <div class="panel" style="padding: 1rem;">
          <div
            id="price-history-chart"
            phx-hook="ChartHook"
            data-chart-type="line"
            data-chart-data={Jason.encode!(price_chart_data(@price_history, @holding.ticker))}
            data-chart-options={
              Jason.encode!(%{
                plugins: %{legend: %{display: false}},
                scales: %{y: %{beginAtZero: false}}
              })
            }
            style="height: 280px;"
          >
            <canvas></canvas>
          </div>
        </div>
      </div>
    <% end %>

    <div class="grid-2">
      <div class="section">
        <div class="section-head">
          <h2>Cost Basis Lots</h2>
          <span class="count">{length(@lots)} lots</span>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Purchase Date</th>
                <th class="th-num">Qty</th>
                <th class="th-num">Price/Unit</th>
                <th class="th-num">Cost Basis</th>
                <th class="th-num">Sold Qty</th>
                <th class="th-num">Sold Price</th>
                <th class="th-num">G/L</th>
              </tr>
            </thead>
            <tbody>
              <%= for lot <- @lots do %>
                <tr>
                  <td>{lot.purchase_date || "---"}</td>
                  <td class="td-num">{format_decimal(lot.quantity)}</td>
                  <td class="td-num">{format_usd(lot.price_per_unit)}</td>
                  <td class="td-num">
                    {format_usd(Money.mult(Money.to_decimal(lot.quantity), Money.to_decimal(lot.price_per_unit)))}
                  </td>
                  <td class="td-num">{format_decimal(lot.sold_quantity)}</td>
                  <td class="td-num">
                    <%= if Money.positive?(Money.to_decimal(lot.sold_quantity)) do %>
                      {format_usd(lot.sold_price)}
                    <% else %>
                      ---
                    <% end %>
                  </td>
                  <td class="td-num" style={gain_color(lot_gain(lot))}>
                    {format_gain(lot_gain(lot))}
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
          <%= if @lots == [] do %>
            <div class="empty-state">No cost basis lots recorded.</div>
          <% end %>
        </div>
      </div>

      <div class="section">
        <div class="section-head">
          <h2>Details</h2>
        </div>
        <div class="panel" style="padding: 1rem;">
          <dl style="display: grid; grid-template-columns: auto 1fr; gap: 0.5rem 1rem;">
            <dt style="font-weight: 600; opacity: 0.7;">Asset Name</dt>
            <dd>{@holding.asset}</dd>

            <dt style="font-weight: 600; opacity: 0.7;">Ticker</dt>
            <dd class="td-mono">{@holding.ticker || "---"}</dd>

            <dt style="font-weight: 600; opacity: 0.7;">Asset Type</dt>
            <dd><span class="tag tag-ink">{@holding.asset_type}</span></dd>

            <dt style="font-weight: 600; opacity: 0.7;">Currency</dt>
            <dd>{@holding.currency}</dd>

            <dt style="font-weight: 600; opacity: 0.7;">Unit</dt>
            <dd>{@holding.unit || "---"}</dd>

            <dt style="font-weight: 600; opacity: 0.7;">Company</dt>
            <dd>
              <%= if @holding.company do %>
                <.link navigate={~p"/companies/#{@holding.company.id}"}>
                  {@holding.company.name}
                </.link>
              <% else %>
                ---
              <% end %>
            </dd>

            <dt style="font-weight: 600; opacity: 0.7;">Custodian</dt>
            <dd>
              <%= if @holding.custodian do %>
                {@holding.custodian.bank}
                <span style="opacity: 0.6;">({@holding.custodian.account_number})</span>
              <% else %>
                ---
              <% end %>
            </dd>

            <dt style="font-weight: 600; opacity: 0.7;">Total Cost Basis</dt>
            <dd>{format_usd(@gains.cost_basis)}</dd>

            <dt style="font-weight: 600; opacity: 0.7;">Total Gain/Loss</dt>
            <dd style={gain_color(Money.add(@gains.unrealized, @gains.realized))}>
              {format_gain(Money.add(@gains.unrealized, @gains.realized))}
            </dd>
          </dl>
        </div>
      </div>
    </div>

    <%= if @related_transactions != [] do %>
      <div class="section">
        <div class="section-head">
          <h2>Related Transactions</h2>
          <span class="count">{length(@related_transactions)}</span>
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
              <%= for tx <- @related_transactions do %>
                <tr>
                  <td class="td-mono">
                    <.link navigate={~p"/transactions/#{tx.id}"} class="td-link">{tx.date}</.link>
                  </td>
                  <td><span class="tag tag-ink">{tx.transaction_type}</span></td>
                  <td class="td-name">{tx.description}</td>
                  <td class={"td-num #{if Money.negative?(tx.amount), do: "num-negative", else: "num-positive"}"}>
                    {format_usd(tx.amount)}
                  </td>
                  <td>{tx.currency}</td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    <% end %>
    """
  end

  # -- Data helpers --

  defp load_price_history(nil), do: []
  defp load_price_history(""), do: []

  defp load_price_history(ticker) do
    Pricing.get_price_history(ticker, 90)
  end

  defp compute_gains(holding, lots) do
    current_value = Money.to_decimal(Portfolio.holding_value(holding))

    cost_basis =
      lots
      |> Enum.reduce(Decimal.new(0), fn lot, acc ->
        remaining = Money.sub(Money.to_decimal(lot.quantity), Money.to_decimal(lot.sold_quantity))
        if Money.positive?(remaining), do: Money.add(acc, Money.mult(remaining, Money.to_decimal(lot.price_per_unit))), else: acc
      end)

    unrealized = Money.sub(current_value, cost_basis)

    realized =
      lots
      |> Enum.filter(&Money.positive?(Money.to_decimal(&1.sold_quantity)))
      |> Enum.reduce(Decimal.new(0), fn lot, acc ->
        proceeds = Money.mult(Money.to_decimal(lot.sold_quantity), Money.to_decimal(lot.sold_price))
        cost = Money.mult(Money.to_decimal(lot.sold_quantity), Money.to_decimal(lot.price_per_unit))
        Money.add(acc, Money.sub(proceeds, cost))
      end)

    %{cost_basis: cost_basis, unrealized: unrealized, realized: realized}
  end

  defp lot_gain(lot) do
    sold_qty = Money.to_decimal(lot.sold_quantity)

    if Money.positive?(sold_qty) do
      proceeds = Money.mult(sold_qty, Money.to_decimal(lot.sold_price))
      cost = Money.mult(sold_qty, Money.to_decimal(lot.price_per_unit))
      Money.sub(proceeds, cost)
    else
      Decimal.new(0)
    end
  end

  # -- Chart helpers --

  defp price_chart_data(history, ticker) do
    sorted = Enum.sort_by(history, & &1.inserted_at, DateTime)

    %{
      labels:
        Enum.map(sorted, fn p ->
          Calendar.strftime(p.inserted_at, "%Y-%m-%d")
        end),
      datasets: [
        %{
          label: ticker,
          data: Enum.map(sorted, &Money.to_float(&1.price)),
          borderColor: "#0d7680",
          backgroundColor: "rgba(13, 118, 128, 0.1)",
          fill: true,
          tension: 0.3,
          pointRadius: 2
        }
      ]
    }
  end

  # -- Formatting helpers --

  defp format_usd(nil), do: "$0.00"

  defp format_usd(%Decimal{} = n) do
    formatted = Money.abs(n) |> Decimal.round(2) |> Decimal.to_string() |> add_commas()
    if Money.negative?(n), do: "-$" <> formatted, else: "$" <> formatted
  end

  defp format_usd(n) when is_float(n), do: format_usd(Money.to_decimal(n))
  defp format_usd(n) when is_integer(n), do: format_usd(Money.to_decimal(n))
  defp format_usd(_), do: "$0.00"

  defp format_gain(%Decimal{} = n) do
    formatted = Money.abs(n) |> Decimal.round(2) |> Decimal.to_string() |> add_commas()
    if Money.gte?(n, 0), do: "+$" <> formatted, else: "-$" <> formatted
  end

  defp format_gain(n) when is_float(n), do: format_gain(Money.to_decimal(n))
  defp format_gain(_), do: "$0.00"

  defp format_number(%Decimal{} = n),
    do: n |> Decimal.round(2) |> Decimal.to_string() |> add_commas()

  defp format_number(n) when is_float(n),
    do: Money.to_float(Money.round(n, 2)) |> :erlang.float_to_binary(decimals: 2) |> add_commas()

  defp format_number(n) when is_integer(n), do: Integer.to_string(n) |> add_commas()
  defp format_number(_), do: "0"

  defp format_decimal(nil), do: "---"

  defp format_decimal(%Decimal{} = n) do
    if Decimal.equal?(n, 0) do
      "0"
    else
      n
      |> Decimal.round(4)
      |> Decimal.to_string()
      |> String.trim_trailing("0")
      |> String.trim_trailing(".")
    end
  end

  defp format_decimal(n) when is_float(n), do: format_decimal(Money.to_decimal(n))
  defp format_decimal(n) when n == 0, do: "0"
  defp format_decimal(n), do: to_string(n)

  defp add_commas(str) do
    # Split on decimal point, add commas to integer part only
    case String.split(str, ".") do
      [int_part, dec_part] ->
        int_part
        |> String.reverse()
        |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
        |> String.reverse()
        |> Kernel.<>("." <> dec_part)

      [int_part] ->
        int_part
        |> String.reverse()
        |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
        |> String.reverse()
    end
  end

  defp gain_color(%Decimal{} = n) do
    cond do
      Money.positive?(n) -> "color: #00994d;"
      Money.negative?(n) -> "color: #cc0000;"
      true -> ""
    end
  end

  defp gain_color(n) when is_float(n) and n > 0, do: "color: #00994d;"
  defp gain_color(n) when is_float(n) and n < 0, do: "color: #cc0000;"
  defp gain_color(_), do: ""
end
