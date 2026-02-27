defmodule HoldcoWeb.DebtMaturityLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Finance, Portfolio}
  alias Holdco.Money

  @impl true
  def mount(_params, _session, socket) do
    liabilities = Finance.list_liabilities()

    active_liabilities = Enum.filter(liabilities, &(&1.status == "active"))

    total_debt =
      Enum.reduce(active_liabilities, Decimal.new(0), fn l, acc ->
        Money.add(acc, Money.to_decimal(Portfolio.to_usd(l.principal || 0, l.currency)))
      end)

    today = Date.utc_today()
    maturity_buckets = build_maturity_buckets(active_liabilities, today)
    nearest = find_nearest_maturity(active_liabilities, today)
    avg_maturity = calculate_avg_maturity(active_liabilities, today)

    {:ok,
     assign(socket,
       page_title: "Debt Maturity",
       liabilities: liabilities,
       active_liabilities: active_liabilities,
       total_debt: total_debt,
       maturity_buckets: maturity_buckets,
       nearest_maturity: nearest,
       avg_maturity_years: avg_maturity,
       today: today
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <h1>Debt Maturity</h1>
      <p class="deck">
        Liability maturity timeline showing debt obligations by time horizon
      </p>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Debt (USD)</div>
        <div class="metric-value num-negative">${format_number(@total_debt)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Active Liabilities</div>
        <div class="metric-value">{length(@active_liabilities)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Avg Maturity</div>
        <div class="metric-value">
          <%= if @avg_maturity_years do %>
            {Money.to_float(Money.round(@avg_maturity_years, 1))} yr
          <% else %>
            N/A
          <% end %>
        </div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Nearest Maturity</div>
        <div class="metric-value">
          <%= if @nearest_maturity do %>
            {@nearest_maturity}
          <% else %>
            N/A
          <% end %>
        </div>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Maturity Timeline</h2>
      </div>
      <div class="panel" style="padding: 1rem;">
        <div
          id="maturity-timeline-chart"
          phx-hook="ChartHook"
          data-chart-type="bar"
          data-chart-data={Jason.encode!(maturity_chart_data(@maturity_buckets))}
          data-chart-options={
            Jason.encode!(%{
              plugins: %{legend: %{display: false}},
              scales: %{
                y: %{
                  beginAtZero: true,
                  title: %{display: true, text: "USD Value"}
                }
              }
            })
          }
          style="height: 300px;"
        >
          <canvas></canvas>
        </div>
      </div>
    </div>

    <div class="grid-2">
      <div class="section">
        <div class="section-head">
          <h2>Maturity Buckets</h2>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Time Horizon</th>
                <th class="th-num">Count</th>
                <th class="th-num">Total (USD)</th>
                <th class="th-num">% of Total</th>
              </tr>
            </thead>
            <tbody>
              <%= for bucket <- @maturity_buckets do %>
                <% pct = if Money.gt?(@total_debt, 0), do: Money.mult(Money.div(bucket.usd_total, @total_debt), 100), else: Decimal.new(0) %>
                <tr>
                  <td class="td-name">
                    <span class={"tag #{bucket_tag(bucket.label)}"}>{bucket.label}</span>
                  </td>
                  <td class="td-num">{bucket.count}</td>
                  <td class="td-num num-negative">${format_number(bucket.usd_total)}</td>
                  <td class="td-num">{Money.to_float(Money.round(pct, 1))}%</td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>

      <div class="section">
        <div class="section-head">
          <h2>Debt Composition</h2>
        </div>
        <div class="panel" style="padding: 1rem;">
          <div
            id="debt-composition-chart"
            phx-hook="ChartHook"
            data-chart-type="pie"
            data-chart-data={Jason.encode!(composition_chart_data(@active_liabilities))}
            data-chart-options={
              Jason.encode!(%{
                plugins: %{legend: %{position: "right"}}
              })
            }
            style="height: 250px;"
          >
            <canvas></canvas>
          </div>
        </div>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>All Liabilities</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Creditor</th>
              <th>Type</th>
              <th>Company</th>
              <th class="th-num">Principal</th>
              <th>Currency</th>
              <th class="th-num">Interest Rate</th>
              <th>Maturity Date</th>
              <th>Status</th>
              <th>Time Bucket</th>
            </tr>
          </thead>
          <tbody>
            <%= for l <- @liabilities do %>
              <tr>
                <td class="td-name">{l.creditor}</td>
                <td><span class="tag tag-ink">{l.liability_type}</span></td>
                <td>
                  <%= if l.company do %>
                    <.link navigate={~p"/companies/#{l.company.id}"} class="td-link">
                      {l.company.name}
                    </.link>
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td class="td-num num-negative">{format_number(l.principal || 0)}</td>
                <td>{l.currency}</td>
                <td class="td-num">
                  <%= if l.interest_rate do %>
                    {Money.to_float(Money.round(l.interest_rate, 2))}%
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td class="td-mono">{l.maturity_date || "---"}</td>
                <td>
                  <span class={"tag #{status_tag(l.status)}"}>{l.status}</span>
                </td>
                <td>
                  <% bucket = maturity_bucket_label(l.maturity_date, @today) %>
                  <span class={"tag #{bucket_tag(bucket)}"}>{bucket}</span>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @liabilities == [] do %>
          <div class="empty-state">
            No liabilities recorded. Add liabilities in the Financials section to see debt maturity analysis.
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # -- Helpers --

  defp build_maturity_buckets(liabilities, today) do
    buckets = %{
      "0-1 Year" => [],
      "1-3 Years" => [],
      "3-5 Years" => [],
      "5+ Years" => [],
      "No Maturity" => []
    }

    filled =
      Enum.reduce(liabilities, buckets, fn l, acc ->
        bucket = maturity_bucket_label(l.maturity_date, today)
        Map.update!(acc, bucket, &[l | &1])
      end)

    order = ["0-1 Year", "1-3 Years", "3-5 Years", "5+ Years", "No Maturity"]

    Enum.map(order, fn label ->
      items = Map.get(filled, label, [])

      usd_total =
        Enum.reduce(items, Decimal.new(0), fn l, acc ->
          Money.add(acc, Money.to_decimal(Portfolio.to_usd(l.principal || 0, l.currency)))
        end)

      %{label: label, count: length(items), usd_total: usd_total}
    end)
  end

  defp maturity_bucket_label(nil, _today), do: "No Maturity"
  defp maturity_bucket_label("", _today), do: "No Maturity"

  defp maturity_bucket_label(maturity_date, today) do
    case Date.from_iso8601(maturity_date) do
      {:ok, mat_date} ->
        days_diff = Date.diff(mat_date, today)
        years = days_diff / 365.25

        cond do
          years <= 1 -> "0-1 Year"
          years <= 3 -> "1-3 Years"
          years <= 5 -> "3-5 Years"
          true -> "5+ Years"
        end

      _ ->
        "No Maturity"
    end
  end

  defp find_nearest_maturity(liabilities, today) do
    today_str = Date.to_iso8601(today)

    liabilities
    |> Enum.filter(&(&1.maturity_date != nil and &1.maturity_date != "" and &1.maturity_date >= today_str))
    |> Enum.sort_by(& &1.maturity_date)
    |> case do
      [first | _] -> first.maturity_date
      [] -> nil
    end
  end

  defp calculate_avg_maturity(liabilities, today) do
    dated =
      liabilities
      |> Enum.filter(&(&1.maturity_date != nil and &1.maturity_date != ""))
      |> Enum.map(fn l ->
        case Date.from_iso8601(l.maturity_date) do
          {:ok, mat_date} -> Date.diff(mat_date, today) / 365.25
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    if dated != [] do
      Enum.sum(dated) / length(dated)
    else
      nil
    end
  end

  defp maturity_chart_data(buckets) do
    colors = ["#cc0000", "#c08060", "#b89040", "#4a8c87", "#888888"]

    %{
      labels: Enum.map(buckets, & &1.label),
      datasets: [
        %{
          label: "Debt Maturing (USD)",
          data: Enum.map(buckets, &Money.to_float(&1.usd_total)),
          backgroundColor: Enum.take(colors, length(buckets))
        }
      ]
    }
  end

  defp composition_chart_data(liabilities) do
    by_type =
      liabilities
      |> Enum.group_by(& &1.liability_type)
      |> Enum.map(fn {type, items} ->
        total =
          Enum.reduce(items, Decimal.new(0), fn l, acc ->
            Money.add(acc, Money.to_decimal(Portfolio.to_usd(l.principal || 0, l.currency)))
          end)

        %{type: type || "Unknown", total: total}
      end)
      |> Enum.sort_by(&Money.to_float(&1.total), :desc)

    colors = ["#4a8c87", "#6b87a0", "#5f8f6e", "#8a5a6a", "#c08060", "#b89040", "#b0605e"]

    %{
      labels: Enum.map(by_type, & &1.type),
      datasets: [
        %{
          data: Enum.map(by_type, &Money.to_float(&1.total)),
          backgroundColor: Enum.take(Stream.cycle(colors), length(by_type))
        }
      ]
    }
  end

  defp bucket_tag("0-1 Year"), do: "tag-crimson"
  defp bucket_tag("1-3 Years"), do: "tag-lemon"
  defp bucket_tag("3-5 Years"), do: "tag-jade"
  defp bucket_tag("5+ Years"), do: "tag-jade"
  defp bucket_tag(_), do: "tag-ink"

  defp status_tag("active"), do: "tag-crimson"
  defp status_tag("paid"), do: "tag-jade"
  defp status_tag("restructured"), do: "tag-lemon"
  defp status_tag(_), do: "tag-ink"

  defp format_number(%Decimal{} = n),
    do: n |> Decimal.round(0) |> Decimal.to_string() |> add_commas()

  defp format_number(n) when is_float(n),
    do: Money.to_float(Money.round(n, 0)) |> :erlang.float_to_binary(decimals: 0) |> add_commas()

  defp format_number(n) when is_integer(n), do: Integer.to_string(n) |> add_commas()
  defp format_number(_), do: "0"

  defp add_commas(str) do
    str |> String.reverse() |> String.replace(~r/(\d{3})(?=\d)/, "\\1,") |> String.reverse()
  end
end
