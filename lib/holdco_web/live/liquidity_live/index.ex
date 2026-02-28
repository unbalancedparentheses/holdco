defmodule HoldcoWeb.LiquidityLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Analytics, Corporate}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Analytics.subscribe()

    companies = Corporate.list_companies()
    coverages = Analytics.list_liquidity_coverages()
    latest = List.first(coverages)

    {:ok,
     assign(socket,
       page_title: "Liquidity Coverage",
       companies: companies,
       coverages: coverages,
       latest: latest,
       selected_company_id: ""
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("filter_company", %{"company_id" => id}, socket) do
    company_id = if id == "", do: nil, else: String.to_integer(id)
    coverages = Analytics.list_liquidity_coverages(company_id)
    latest = List.first(coverages)

    {:noreply,
     assign(socket,
       selected_company_id: id,
       coverages: coverages,
       latest: latest
     )}
  end

  # Permission gating
  def handle_event("recalculate", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("delete", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("recalculate", _params, socket) do
    company_id =
      case socket.assigns.selected_company_id do
        "" -> nil
        id -> String.to_integer(id)
      end

    case Analytics.calculate_lcr(company_id) do
      {:ok, lc} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "LCR calculated: #{format_ratio(lc.lcr_ratio)}% (#{lc.status})")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to calculate LCR")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    lc = Analytics.get_liquidity_coverage!(String.to_integer(id))
    Analytics.delete_liquidity_coverage(lc)

    {:noreply,
     reload(socket)
     |> put_flash(:info, "Record deleted")}
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, reload(socket)}

  defp reload(socket) do
    company_id =
      case socket.assigns.selected_company_id do
        "" -> nil
        id -> String.to_integer(id)
      end

    coverages = Analytics.list_liquidity_coverages(company_id)
    latest = List.first(coverages)
    assign(socket, coverages: coverages, latest: latest)
  end

  defp format_money(nil), do: "$0.00"
  defp format_money(%Decimal{} = d), do: "$#{Decimal.round(d, 2) |> Decimal.to_string()}"
  defp format_money(val), do: "$#{val}"

  defp format_ratio(nil), do: "0.00"
  defp format_ratio(%Decimal{} = d), do: Decimal.round(d, 2) |> Decimal.to_string()
  defp format_ratio(val), do: to_string(val)

  defp status_color("adequate"), do: "tag-jade"
  defp status_color("warning"), do: "tag-lemon"
  defp status_color("critical"), do: "tag-crimson"
  defp status_color(_), do: "tag-ink"

  defp status_class("adequate"), do: "num-positive"
  defp status_class("warning"), do: ""
  defp status_class("critical"), do: "num-negative"
  defp status_class(_), do: ""

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Liquidity Coverage Ratio</h1>
          <p class="deck">Monitor HQLA levels and liquidity adequacy</p>
        </div>
        <div style="display: flex; gap: 0.5rem; align-items: center;">
          <form phx-change="filter_company" style="display: flex; align-items: center; gap: 0.5rem;">
            <label class="form-label" style="margin: 0; font-size: 0.85rem;">Company</label>
            <select name="company_id" class="form-select" style="width: auto; padding: 0.3rem 0.5rem;">
              <option value="">All Companies</option>
              <%= for c <- @companies do %>
                <option value={c.id} selected={to_string(c.id) == @selected_company_id}>{c.name}</option>
              <% end %>
            </select>
          </form>
          <%= if @can_write do %>
            <button class="btn btn-primary" phx-click="recalculate">Recalculate LCR</button>
          <% end %>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <%!-- Warning banner if LCR < 100% --%>
    <%= if @latest && @latest.status != "adequate" do %>
      <div class={"alert-banner alert-#{@latest.status}"} style={"padding: 0.75rem 1rem; margin-bottom: 1rem; border-radius: 4px; border: 1px solid #{if @latest.status == "critical", do: "#dc3545", else: "#ffc107"}; background: #{if @latest.status == "critical", do: "#fff5f5", else: "#fff8e1"};"}>
        <strong>
          <%= if @latest.status == "critical" do %>
            LCR is critically low at {format_ratio(@latest.lcr_ratio)}%. Regulatory minimum is 100%.
          <% else %>
            LCR warning: {format_ratio(@latest.lcr_ratio)}% is below the 100% regulatory threshold.
          <% end %>
        </strong>
      </div>
    <% end %>

    <%!-- Current LCR Summary --%>
    <%= if @latest do %>
      <div class="metrics-strip">
        <div class="metric-cell">
          <div class="metric-label">Total HQLA</div>
          <div class="metric-value">{format_money(@latest.total_hqla)}</div>
        </div>
        <div class="metric-cell">
          <div class="metric-label">Net Cash Outflows (30d)</div>
          <div class="metric-value">{format_money(@latest.net_cash_outflows_30d)}</div>
        </div>
        <div class="metric-cell">
          <div class="metric-label">LCR Ratio</div>
          <div class={"metric-value #{status_class(@latest.status)}"}>{format_ratio(@latest.lcr_ratio)}%</div>
        </div>
        <div class="metric-cell">
          <div class="metric-label">Status</div>
          <div class="metric-value"><span class={"tag #{status_color(@latest.status)}"}>{@latest.status}</span></div>
        </div>
      </div>

      <div class="grid-2" style="margin-top: 1rem;">
        <div class="section">
          <div class="section-head">
            <h2>HQLA Breakdown</h2>
          </div>
          <div class="panel" style="padding: 1rem;">
            <table>
              <thead>
                <tr>
                  <th>Level</th>
                  <th>Description</th>
                  <th>Haircut</th>
                  <th class="th-num">Amount</th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <td><span class="tag tag-jade">Level 1</span></td>
                  <td>Cash & deposits</td>
                  <td>0%</td>
                  <td class="td-num">{format_money(@latest.hqla_level1)}</td>
                </tr>
                <tr>
                  <td><span class="tag tag-ink">Level 2A</span></td>
                  <td>Government / agency bonds</td>
                  <td>15%</td>
                  <td class="td-num">{format_money(@latest.hqla_level2a)}</td>
                </tr>
                <tr>
                  <td><span class="tag tag-ink">Level 2B</span></td>
                  <td>Corporate bonds</td>
                  <td>50%</td>
                  <td class="td-num">{format_money(@latest.hqla_level2b)}</td>
                </tr>
                <tr style="font-weight: 600; border-top: 2px solid var(--rule);">
                  <td colspan="3">Total HQLA</td>
                  <td class="td-num">{format_money(@latest.total_hqla)}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <div class="section">
          <div class="section-head">
            <h2>Calculation Details</h2>
          </div>
          <div class="panel" style="padding: 1rem;">
            <table>
              <tbody>
                <tr>
                  <td>Calculation Date</td>
                  <td class="td-mono">{@latest.calculation_date}</td>
                </tr>
                <tr>
                  <td>Total HQLA</td>
                  <td class="td-num">{format_money(@latest.total_hqla)}</td>
                </tr>
                <tr>
                  <td>Net Cash Outflows (30d)</td>
                  <td class="td-num">{format_money(@latest.net_cash_outflows_30d)}</td>
                </tr>
                <tr style="font-weight: 600;">
                  <td>LCR Ratio</td>
                  <td class={"td-num #{status_class(@latest.status)}"}>{format_ratio(@latest.lcr_ratio)}%</td>
                </tr>
                <tr>
                  <td>Status</td>
                  <td><span class={"tag #{status_color(@latest.status)}"}>{@latest.status}</span></td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    <% else %>
      <div class="section">
        <div class="panel">
          <div class="empty-state">
            <p>No LCR calculations yet.</p>
            <p style="color: var(--muted); font-size: 0.9rem;">
              Click "Recalculate LCR" to compute your liquidity coverage ratio from current bank balances, holdings, and liabilities.
            </p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="recalculate">Calculate LCR Now</button>
            <% end %>
          </div>
        </div>
      </div>
    <% end %>

    <%!-- History Table --%>
    <div class="section" style="margin-top: 1.5rem;">
      <div class="section-head">
        <h2>History</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Date</th>
              <th class="th-num">HQLA L1</th>
              <th class="th-num">HQLA L2A</th>
              <th class="th-num">HQLA L2B</th>
              <th class="th-num">Total HQLA</th>
              <th class="th-num">Outflows (30d)</th>
              <th class="th-num">LCR %</th>
              <th>Status</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for lc <- @coverages do %>
              <tr>
                <td class="td-mono">{lc.calculation_date}</td>
                <td class="td-num">{format_money(lc.hqla_level1)}</td>
                <td class="td-num">{format_money(lc.hqla_level2a)}</td>
                <td class="td-num">{format_money(lc.hqla_level2b)}</td>
                <td class="td-num">{format_money(lc.total_hqla)}</td>
                <td class="td-num">{format_money(lc.net_cash_outflows_30d)}</td>
                <td class={"td-num #{status_class(lc.status)}"}>{format_ratio(lc.lcr_ratio)}%</td>
                <td><span class={"tag #{status_color(lc.status)}"}>{lc.status}</span></td>
                <td>
                  <%= if @can_write do %>
                    <button phx-click="delete" phx-value-id={lc.id} class="btn btn-danger btn-sm" data-confirm="Delete this record?">Del</button>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @coverages == [] do %>
          <div class="empty-state">No historical calculations to display.</div>
        <% end %>
      </div>
    </div>
    """
  end
end
