defmodule HoldcoWeb.CapitalGainsLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.Tax.CapitalGains
  alias Holdco.Money

  @methods [
    {"fifo", "FIFO"},
    {"lifo", "LIFO"},
    {"specific", "Specific Lot"}
  ]

  @short_term_rate Decimal.new("0.37")
  @long_term_rate Decimal.new("0.20")

  @impl true
  def mount(_params, _session, socket) do
    method = :fifo
    results = CapitalGains.compute(method)
    summary = compute_summary(results)

    {:ok,
     assign(socket,
       page_title: "Capital Gains",
       method: "fifo",
       results: results,
       summary: summary
     )}
  end

  @impl true
  def handle_event("change_method", %{"method" => method_str}, socket) do
    method = String.to_existing_atom(method_str)
    results = CapitalGains.compute(method)
    summary = compute_summary(results)

    {:noreply, assign(socket, method: method_str, results: results, summary: summary)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Capital Gains Tax</h1>
          <p class="deck">Realized and unrealized gains analysis by cost basis method</p>
        </div>
        <form phx-change="change_method" style="display: flex; align-items: center; gap: 0.5rem;">
          <label class="form-label" style="margin: 0; font-size: 0.85rem;">Method</label>
          <select name="method" class="form-select" style="width: auto; padding: 0.3rem 0.5rem;">
            <%= for {val, label} <- methods() do %>
              <option value={val} selected={val == @method}>{label}</option>
            <% end %>
          </select>
        </form>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Short-Term Gains</div>
        <div class={"metric-value #{gain_class(@summary.total_short_term)}"}>
          ${format_number(@summary.total_short_term)}
        </div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Long-Term Gains</div>
        <div class={"metric-value #{gain_class(@summary.total_long_term)}"}>
          ${format_number(@summary.total_long_term)}
        </div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Total Gains</div>
        <div class={"metric-value #{gain_class(@summary.total_short_term + @summary.total_long_term)}"}>
          ${format_number(@summary.total_short_term + @summary.total_long_term)}
        </div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Est. Tax (ST @ 37%, LT @ 20%)</div>
        <div class="metric-value num-negative">
          ${format_number(@summary.estimated_tax)}
        </div>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Holdings Detail</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Asset</th>
              <th>Company</th>
              <th class="th-num">ST Realized</th>
              <th class="th-num">ST Unrealized</th>
              <th class="th-num">LT Realized</th>
              <th class="th-num">LT Unrealized</th>
              <th class="th-num">Total Gain</th>
            </tr>
          </thead>
          <tbody>
            <%= for r <- @results do %>
              <tr>
                <td class="td-name">
                  <.link navigate={~p"/holdings/#{r.holding_id}"} class="td-link">
                    {r.asset}
                    <%= if r.ticker && r.ticker != "" do %>
                      <span style="color: var(--muted); font-size: 0.85rem;">({r.ticker})</span>
                    <% end %>
                  </.link>
                </td>
                <td>{r.company}</td>
                <td class={"td-num #{gain_class(r.short_term_realized)}"}>{format_number(r.short_term_realized)}</td>
                <td class={"td-num #{gain_class(r.short_term_unrealized)}"}>{format_number(r.short_term_unrealized)}</td>
                <td class={"td-num #{gain_class(r.long_term_realized)}"}>{format_number(r.long_term_realized)}</td>
                <td class={"td-num #{gain_class(r.long_term_unrealized)}"}>{format_number(r.long_term_unrealized)}</td>
                <td class={"td-num #{gain_class(r.total_gain)}"} style="font-weight: 600;">
                  {format_number(r.total_gain)}
                </td>
              </tr>
            <% end %>
          </tbody>
          <tfoot>
            <tr style="font-weight: 600; border-top: 2px solid var(--rule);">
              <td class="td-name">Total</td>
              <td></td>
              <td class={"td-num #{gain_class(sum_field(@results, :short_term_realized))}"}>{format_number(sum_field(@results, :short_term_realized))}</td>
              <td class={"td-num #{gain_class(sum_field(@results, :short_term_unrealized))}"}>{format_number(sum_field(@results, :short_term_unrealized))}</td>
              <td class={"td-num #{gain_class(sum_field(@results, :long_term_realized))}"}>{format_number(sum_field(@results, :long_term_realized))}</td>
              <td class={"td-num #{gain_class(sum_field(@results, :long_term_unrealized))}"}>{format_number(sum_field(@results, :long_term_unrealized))}</td>
              <td class={"td-num #{gain_class(sum_field(@results, :total_gain))}"}>{format_number(sum_field(@results, :total_gain))}</td>
            </tr>
          </tfoot>
        </table>
        <%= if @results == [] do %>
          <div class="empty-state">
            <p>No capital gains data found.</p>
            <p style="color: var(--muted); font-size: 0.9rem;">
              Capital gains are computed from holdings with cost basis lots. Add holdings with purchase history to see gains analysis.
            </p>
          </div>
        <% end %>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Tax Estimation Notes</h2>
      </div>
      <div class="panel" style="padding: 1.5rem;">
        <table>
          <thead>
            <tr>
              <th>Category</th>
              <th class="th-num">Gain</th>
              <th class="th-num">Rate</th>
              <th class="th-num">Est. Tax</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td class="td-name">Short-Term Realized</td>
              <td class="td-num">{format_number(sum_field(@results, :short_term_realized))}</td>
              <td class="td-num">37%</td>
              <td class="td-num">{format_number(max(sum_field(@results, :short_term_realized), 0.0) * 0.37)}</td>
            </tr>
            <tr>
              <td class="td-name">Long-Term Realized</td>
              <td class="td-num">{format_number(sum_field(@results, :long_term_realized))}</td>
              <td class="td-num">20%</td>
              <td class="td-num">{format_number(max(sum_field(@results, :long_term_realized), 0.0) * 0.20)}</td>
            </tr>
            <tr style="font-weight: 600; border-top: 2px solid var(--rule);">
              <td class="td-name">Total Estimated Tax</td>
              <td></td>
              <td></td>
              <td class="td-num num-negative">${format_number(@summary.estimated_tax)}</td>
            </tr>
          </tbody>
        </table>
        <p style="color: var(--muted); font-size: 0.85rem; margin-top: 1rem;">
          Estimates use US federal rates (37% ordinary income for short-term, 20% for long-term).
          Unrealized gains are shown for reference but not included in the tax estimate.
          Consult a tax professional for actual tax liability.
        </p>
      </div>
    </div>
    """
  end

  defp methods, do: @methods

  defp compute_summary(results) do
    total_short_term =
      Enum.reduce(results, Decimal.new(0), fn r, acc ->
        Money.add(acc, Money.add(r.short_term_realized, r.short_term_unrealized))
      end)

    total_long_term =
      Enum.reduce(results, Decimal.new(0), fn r, acc ->
        Money.add(acc, Money.add(r.long_term_realized, r.long_term_unrealized))
      end)

    # Tax estimate: only on realized gains (positive only)
    st_realized = Enum.reduce(results, Decimal.new(0), fn r, acc -> Money.add(acc, r.short_term_realized) end)
    lt_realized = Enum.reduce(results, Decimal.new(0), fn r, acc -> Money.add(acc, r.long_term_realized) end)

    st_taxable = if Money.gt?(st_realized, 0), do: st_realized, else: Decimal.new(0)
    lt_taxable = if Money.gt?(lt_realized, 0), do: lt_realized, else: Decimal.new(0)
    estimated_tax = Money.add(Money.mult(st_taxable, @short_term_rate), Money.mult(lt_taxable, @long_term_rate))

    %{
      total_short_term: total_short_term,
      total_long_term: total_long_term,
      estimated_tax: estimated_tax
    }
  end

  defp sum_field(results, field) do
    Enum.reduce(results, Decimal.new(0), fn r, acc -> Money.add(acc, Map.get(r, field, Decimal.new(0))) end)
  end

  defp gain_class(value) do
    cond do
      Money.positive?(value) -> "num-positive"
      Money.negative?(value) -> "num-negative"
      true -> ""
    end
  end

  defp format_number(%Decimal{} = n),
    do: n |> Decimal.round(2) |> Decimal.to_string() |> add_commas()

  defp format_number(n) when is_float(n),
    do: :erlang.float_to_binary(n, decimals: 2) |> add_commas()

  defp format_number(n) when is_integer(n), do: Integer.to_string(n) |> add_commas()
  defp format_number(_), do: "0"

  defp add_commas(str) do
    # Split on decimal point if present
    case String.split(str, ".") do
      [int_part, dec_part] ->
        formatted_int = int_part |> String.reverse() |> String.replace(~r/(\d{3})(?=\d)/, "\\1,") |> String.reverse()
        "#{formatted_int}.#{dec_part}"

      [int_part] ->
        int_part |> String.reverse() |> String.replace(~r/(\d{3})(?=\d)/, "\\1,") |> String.reverse()
    end
  end
end
