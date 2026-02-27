defmodule HoldcoWeb.AgingReportLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.Banking
  alias Holdco.Money

  @buckets [
    {:current, "Current (0-30d)", 0, 30},
    {:days_30, "31-60 days", 31, 60},
    {:days_60, "61-90 days", 61, 90},
    {:days_90, "91-120 days", 91, 120},
    {:days_120, "120+ days", 121, :infinity}
  ]

  @impl true
  def mount(_params, _session, socket) do
    transactions = Banking.list_transactions()
    mode = "ar"
    grouped = group_by_aging(transactions, mode)
    totals = bucket_totals(grouped)

    {:ok,
     assign(socket,
       page_title: "AR/AP Aging Report",
       transactions: transactions,
       mode: mode,
       grouped: grouped,
       totals: totals
     )}
  end

  @impl true
  def handle_event("toggle_mode", %{"mode" => mode}, socket) do
    grouped = group_by_aging(socket.assigns.transactions, mode)
    totals = bucket_totals(grouped)

    {:noreply, assign(socket, mode: mode, grouped: grouped, totals: totals)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>AR/AP Aging Report</h1>
          <p class="deck">
            {if @mode == "ar", do: "Accounts Receivable", else: "Accounts Payable"} grouped by age bucket
          </p>
        </div>
        <form phx-change="toggle_mode" style="display: flex; align-items: center; gap: 0.5rem;">
          <label class="form-label" style="margin: 0; font-size: 0.85rem;">Report Type</label>
          <select name="mode" class="form-select" style="width: auto; padding: 0.3rem 0.5rem;">
            <option value="ar" selected={@mode == "ar"}>Receivables (AR)</option>
            <option value="ap" selected={@mode == "ap"}>Payables (AP)</option>
          </select>
        </form>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total</div>
        <div class={"metric-value #{if Money.gte?(grand_total(@totals), 0), do: "num-positive", else: "num-negative"}"}>
          ${format_number(Money.abs(grand_total(@totals)))}
        </div>
      </div>
      <%= for {key, label, _, _} <- buckets() do %>
        <div class="metric-cell">
          <div class="metric-label">{label}</div>
          <div class="metric-value">${format_number(Money.abs(Map.get(@totals, key, Decimal.new(0))))}</div>
        </div>
      <% end %>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Aging Distribution</h2>
      </div>
      <div class="panel" style="padding: 1rem;">
        <div
          id="aging-chart"
          phx-hook="ChartHook"
          phx-update="ignore"
          data-chart-type="bar"
          data-chart-data={Jason.encode!(aging_chart_data(@totals, @mode))}
          data-chart-options={
            Jason.encode!(%{
              plugins: %{legend: %{display: true}},
              scales: %{
                x: %{stacked: true},
                y: %{stacked: true, beginAtZero: true}
              }
            })
          }
          style="height: 300px;"
        >
          <canvas></canvas>
        </div>
      </div>
    </div>

    <%= for {key, label, _, _} <- buckets() do %>
      <% bucket_txns = Map.get(@grouped, key, []) %>
      <%= if bucket_txns != [] do %>
        <div class="section">
          <div class="section-head">
            <h2>{label}</h2>
            <span class="count">{length(bucket_txns)} transactions</span>
          </div>
          <div class="panel">
            <table>
              <thead>
                <tr>
                  <th>Date</th>
                  <th>Description</th>
                  <th>Counterparty</th>
                  <th>Company</th>
                  <th>Days Old</th>
                  <th class="th-num">Amount</th>
                </tr>
              </thead>
              <tbody>
                <%= for tx <- bucket_txns do %>
                  <tr>
                    <td class="td-mono">{tx.date}</td>
                    <td class="td-name">{tx.description}</td>
                    <td>{tx.counterparty}</td>
                    <td>
                      <%= if tx.company do %>
                        <.link navigate={~p"/companies/#{tx.company.id}"} class="td-link">{tx.company.name}</.link>
                      <% else %>
                        ---
                      <% end %>
                    </td>
                    <td class="td-mono">{days_old(tx.date)}</td>
                    <td class={"td-num #{if Money.gte?(tx.amount, 0), do: "num-positive", else: "num-negative"}"}>
                      {format_currency(tx.amount, tx.currency)}
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
      <% end %>
    <% end %>

    <%= if Enum.all?(Map.values(@grouped), &(&1 == [])) do %>
      <div class="section">
        <div class="panel">
          <div class="empty-state">
            <p>No {if @mode == "ar", do: "receivable", else: "payable"} transactions found.</p>
            <p style="color: var(--muted); font-size: 0.9rem;">
              Transactions with {if @mode == "ar", do: "positive", else: "negative"} amounts will appear here grouped by age.
            </p>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp buckets, do: @buckets

  defp group_by_aging(transactions, mode) do
    today = Date.utc_today()

    filtered =
      transactions
      |> Enum.filter(fn tx ->
        case mode do
          "ar" -> tx.amount != nil and Money.positive?(tx.amount)
          "ap" -> tx.amount != nil and Money.negative?(tx.amount)
          _ -> false
        end
      end)

    Enum.reduce(@buckets, %{}, fn {key, _label, min_days, max_days}, acc ->
      bucket_txns =
        Enum.filter(filtered, fn tx ->
          age = days_old_int(tx.date, today)

          cond do
            max_days == :infinity -> age >= min_days
            true -> age >= min_days and age <= max_days
          end
        end)

      Map.put(acc, key, bucket_txns)
    end)
  end

  defp bucket_totals(grouped) do
    Enum.reduce(grouped, %{}, fn {key, txns}, acc ->
      total = Enum.reduce(txns, Decimal.new(0), fn tx, sum -> Money.add(sum, Money.abs(tx.amount)) end)
      Map.put(acc, key, total)
    end)
  end

  defp grand_total(totals) do
    totals |> Map.values() |> Money.sum()
  end

  defp days_old(date_str) do
    days_old_int(date_str, Date.utc_today())
  end

  defp days_old_int(nil, _today), do: 0

  defp days_old_int(date_str, today) do
    case Date.from_iso8601(date_str) do
      {:ok, date} -> max(Date.diff(today, date), 0)
      _ -> 0
    end
  end

  defp aging_chart_data(totals, mode) do
    labels = Enum.map(@buckets, fn {_key, label, _, _} -> label end)

    values =
      Enum.map(@buckets, fn {key, _, _, _} ->
        Money.to_float(Money.round(Map.get(totals, key, Decimal.new(0)), 2))
      end)

    color = if mode == "ar", do: "#4a8c87", else: "#cc0000"

    %{
      labels: labels,
      datasets: [
        %{
          label: if(mode == "ar", do: "Receivables", else: "Payables"),
          data: values,
          backgroundColor: color
        }
      ]
    }
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
end
