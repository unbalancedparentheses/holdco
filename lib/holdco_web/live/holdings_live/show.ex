defmodule HoldcoWeb.HoldingsLive.Show do
  use HoldcoWeb, :live_view

  alias Holdco.{Assets, Portfolio, Pricing}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket), do: Holdco.Platform.subscribe("portfolio")

    holding = Assets.get_holding!(id)
    lots = Assets.list_cost_basis_lots(holding.id)
    gains = compute_gains(holding, lots)
    current_value = Portfolio.holding_value(holding)
    price_history = load_price_history(holding.ticker)

    {:ok,
     assign(socket,
       page_title: holding.asset,
       holding: holding,
       lots: lots,
       gains: gains,
       current_value: current_value,
       price_history: price_history
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

    {:noreply,
     assign(socket,
       holding: holding,
       lots: lots,
       gains: gains,
       current_value: current_value,
       price_history: price_history
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
        <.link navigate={~p"/holdings"} class="btn btn-secondary">Back to Holdings</.link>
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
                    {format_usd((lot.quantity || 0.0) * (lot.price_per_unit || 0.0))}
                  </td>
                  <td class="td-num">{format_decimal(lot.sold_quantity)}</td>
                  <td class="td-num">
                    <%= if (lot.sold_quantity || 0.0) > 0 do %>
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
            <dd style={gain_color(@gains.unrealized + @gains.realized)}>
              {format_gain(@gains.unrealized + @gains.realized)}
            </dd>
          </dl>
        </div>
      </div>
    </div>
    """
  end

  # -- Data helpers --

  defp load_price_history(nil), do: []
  defp load_price_history(""), do: []

  defp load_price_history(ticker) do
    Pricing.get_price_history(ticker, 90)
  end

  defp compute_gains(holding, lots) do
    current_value = Portfolio.holding_value(holding)

    cost_basis =
      lots
      |> Enum.reduce(0.0, fn lot, acc ->
        remaining = (lot.quantity || 0.0) - (lot.sold_quantity || 0.0)
        if remaining > 0, do: acc + remaining * (lot.price_per_unit || 0.0), else: acc
      end)

    unrealized = current_value - cost_basis

    realized =
      lots
      |> Enum.filter(&((&1.sold_quantity || 0.0) > 0))
      |> Enum.reduce(0.0, fn lot, acc ->
        proceeds = (lot.sold_quantity || 0.0) * (lot.sold_price || 0.0)
        cost = (lot.sold_quantity || 0.0) * (lot.price_per_unit || 0.0)
        acc + (proceeds - cost)
      end)

    %{cost_basis: cost_basis, unrealized: unrealized, realized: realized}
  end

  defp lot_gain(lot) do
    sold_qty = lot.sold_quantity || 0.0

    if sold_qty > 0 do
      proceeds = sold_qty * (lot.sold_price || 0.0)
      cost = sold_qty * (lot.price_per_unit || 0.0)
      proceeds - cost
    else
      0.0
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
          data: Enum.map(sorted, & &1.price),
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

  defp format_usd(n) when is_float(n) do
    formatted = :erlang.float_to_binary(abs(n), decimals: 2) |> add_commas()
    if n < 0, do: "-$" <> formatted, else: "$" <> formatted
  end

  defp format_usd(n) when is_integer(n), do: format_usd(n * 1.0)
  defp format_usd(_), do: "$0.00"

  defp format_gain(n) when is_float(n) and n >= 0,
    do: "+$" <> (:erlang.float_to_binary(n, decimals: 2) |> add_commas())

  defp format_gain(n) when is_float(n),
    do: "-$" <> (:erlang.float_to_binary(abs(n), decimals: 2) |> add_commas())

  defp format_gain(_), do: "$0.00"

  defp format_number(n) when is_float(n),
    do: :erlang.float_to_binary(n, decimals: 2) |> add_commas()

  defp format_number(n) when is_integer(n), do: Integer.to_string(n) |> add_commas()
  defp format_number(_), do: "0"

  defp format_decimal(nil), do: "---"
  defp format_decimal(n) when n == 0.0, do: "0"

  defp format_decimal(n) when is_float(n),
    do:
      :erlang.float_to_binary(n, decimals: 4)
      |> String.trim_trailing("0")
      |> String.trim_trailing(".")

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

  defp gain_color(n) when is_float(n) and n > 0, do: "color: #00994d;"
  defp gain_color(n) when is_float(n) and n < 0, do: "color: #cc0000;"
  defp gain_color(_), do: ""
end
