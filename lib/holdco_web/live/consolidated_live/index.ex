defmodule HoldcoWeb.ConsolidatedLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.Finance.Consolidation
  alias Holdco.Money

  @impl true
  def mount(_params, _session, socket) do
    data = Consolidation.build()

    {:ok,
     assign(socket,
       page_title: "Consolidated Financial Statements",
       companies: data.companies,
       entity_data: data.entity_data,
       transfers: data.transfers,
       eliminations: data.eliminations,
       consolidated_bs: data.balance_sheet,
       consolidated_is: data.income_statement,
       active_tab: "balance_sheet"
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, active_tab: tab)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Consolidated Financial Statements</h1>
          <p class="deck">
            Group-level balance sheet and income statement with intercompany eliminations and non-controlling interest
          </p>
        </div>
        <a href="/export/consolidated.csv" class="btn btn-secondary" style="white-space: nowrap;">Export CSV</a>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Entities</div>
        <div class="metric-value">{length(@companies)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Total Assets (Consol.)</div>
        <div class="metric-value num-positive">${format_number(@consolidated_bs.total_assets)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Total Equity (Consol.)</div>
        <div class="metric-value">${format_number(@consolidated_bs.total_equity)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Intercompany Eliminations</div>
        <div class="metric-value num-negative">${format_number(@consolidated_bs.total_eliminations)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">NCI (Non-Controlling)</div>
        <div class="metric-value">${format_number(@consolidated_bs.total_nci)}</div>
      </div>
    </div>

    <div class="section">
      <div class="section-head" style="display: flex; gap: 0.5rem;">
        <button
          phx-click="switch_tab"
          phx-value-tab="balance_sheet"
          class={"btn #{if @active_tab == "balance_sheet", do: "btn-primary", else: "btn-secondary"}"}
        >
          Balance Sheet
        </button>
        <button
          phx-click="switch_tab"
          phx-value-tab="income_statement"
          class={"btn #{if @active_tab == "income_statement", do: "btn-primary", else: "btn-secondary"}"}
        >
          Income Statement
        </button>
        <button
          phx-click="switch_tab"
          phx-value-tab="eliminations"
          class={"btn #{if @active_tab == "eliminations", do: "btn-primary", else: "btn-secondary"}"}
        >
          Eliminations
        </button>
      </div>
    </div>

    <%= if @active_tab == "balance_sheet" do %>
      <div class="section">
        <div class="section-head">
          <h2>Consolidated Balance Sheet</h2>
        </div>
        <div class="panel">
          <h3 style="padding: 1rem 1rem 0; font-family: 'Source Serif 4', Georgia, serif;">Assets</h3>
          <table>
            <thead>
              <tr>
                <th>Account</th>
                <%= for c <- @companies do %>
                  <th class="th-num" style="font-size: 0.8rem;">{short_name(c.name)}</th>
                <% end %>
                <th class="th-num">Elim.</th>
                <th class="th-num">NCI</th>
                <th class="th-num" style="font-weight: 700;">Consolidated</th>
              </tr>
            </thead>
            <tbody>
              <%= for row <- @consolidated_bs.assets do %>
                <tr>
                  <td class="td-name">{row.name}</td>
                  <%= for c <- @companies do %>
                    <td class="td-num">{format_number(Map.get(row.by_entity, c.id, 0))}</td>
                  <% end %>
                  <td class="td-num num-negative">{format_number(row.elimination)}</td>
                  <td class="td-num">{format_number(row.nci)}</td>
                  <td class="td-num" style="font-weight: 600;">{format_number(row.consolidated)}</td>
                </tr>
              <% end %>
              <tr style="font-weight: 700; border-top: 2px solid #ccc;">
                <td>Total Assets</td>
                <%= for c <- @companies do %>
                  <td class="td-num">{format_number(entity_bs_total(@entity_data, c.id, :assets))}</td>
                <% end %>
                <td class="td-num num-negative">{format_number(sum_field_list(@consolidated_bs.assets, :elimination))}</td>
                <td class="td-num">{format_number(sum_field_list(@consolidated_bs.assets, :nci))}</td>
                <td class="td-num num-positive" style="font-weight: 700;">${format_number(@consolidated_bs.total_assets)}</td>
              </tr>
            </tbody>
          </table>

          <h3 style="padding: 1rem 1rem 0; font-family: 'Source Serif 4', Georgia, serif;">Liabilities</h3>
          <table>
            <thead>
              <tr>
                <th>Account</th>
                <%= for c <- @companies do %>
                  <th class="th-num" style="font-size: 0.8rem;">{short_name(c.name)}</th>
                <% end %>
                <th class="th-num">Elim.</th>
                <th class="th-num">NCI</th>
                <th class="th-num" style="font-weight: 700;">Consolidated</th>
              </tr>
            </thead>
            <tbody>
              <%= for row <- @consolidated_bs.liabilities do %>
                <tr>
                  <td class="td-name">{row.name}</td>
                  <%= for c <- @companies do %>
                    <td class="td-num">{format_number(Map.get(row.by_entity, c.id, 0))}</td>
                  <% end %>
                  <td class="td-num num-negative">{format_number(row.elimination)}</td>
                  <td class="td-num">{format_number(row.nci)}</td>
                  <td class="td-num" style="font-weight: 600;">{format_number(row.consolidated)}</td>
                </tr>
              <% end %>
              <tr style="font-weight: 700; border-top: 2px solid #ccc;">
                <td>Total Liabilities</td>
                <%= for c <- @companies do %>
                  <td class="td-num">{format_number(entity_bs_total(@entity_data, c.id, :liabilities))}</td>
                <% end %>
                <td class="td-num num-negative">{format_number(sum_field_list(@consolidated_bs.liabilities, :elimination))}</td>
                <td class="td-num">{format_number(sum_field_list(@consolidated_bs.liabilities, :nci))}</td>
                <td class="td-num num-negative" style="font-weight: 700;">${format_number(@consolidated_bs.total_liabilities)}</td>
              </tr>
            </tbody>
          </table>

          <h3 style="padding: 1rem 1rem 0; font-family: 'Source Serif 4', Georgia, serif;">Equity</h3>
          <table>
            <thead>
              <tr>
                <th>Account</th>
                <%= for c <- @companies do %>
                  <th class="th-num" style="font-size: 0.8rem;">{short_name(c.name)}</th>
                <% end %>
                <th class="th-num">Elim.</th>
                <th class="th-num">NCI</th>
                <th class="th-num" style="font-weight: 700;">Consolidated</th>
              </tr>
            </thead>
            <tbody>
              <%= for row <- @consolidated_bs.equity do %>
                <tr>
                  <td class="td-name">{row.name}</td>
                  <%= for c <- @companies do %>
                    <td class="td-num">{format_number(Map.get(row.by_entity, c.id, 0))}</td>
                  <% end %>
                  <td class="td-num num-negative">{format_number(row.elimination)}</td>
                  <td class="td-num">{format_number(row.nci)}</td>
                  <td class="td-num" style="font-weight: 600;">{format_number(row.consolidated)}</td>
                </tr>
              <% end %>
              <tr style="font-weight: 700; border-top: 2px solid #ccc;">
                <td>Total Equity</td>
                <%= for c <- @companies do %>
                  <td class="td-num">{format_number(entity_bs_total(@entity_data, c.id, :equity))}</td>
                <% end %>
                <td class="td-num num-negative">{format_number(sum_field_list(@consolidated_bs.equity, :elimination))}</td>
                <td class="td-num">{format_number(sum_field_list(@consolidated_bs.equity, :nci))}</td>
                <td class="td-num" style="font-weight: 700;">${format_number(@consolidated_bs.total_equity)}</td>
              </tr>
            </tbody>
          </table>

          <table style="margin-top: 1rem;">
            <tbody>
              <tr style="font-weight: 700; border-top: 3px double #999;">
                <td style="font-size: 1.05rem;">Non-Controlling Interest</td>
                <td class="td-num" style="font-size: 1.05rem;" colspan={length(@companies) + 3}>
                  ${format_number(@consolidated_bs.total_nci)}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    <% end %>

    <%= if @active_tab == "income_statement" do %>
      <div class="section">
        <div class="section-head">
          <h2>Consolidated Income Statement</h2>
        </div>
        <div class="panel">
          <h3 style="padding: 1rem 1rem 0; font-family: 'Source Serif 4', Georgia, serif;">Revenue</h3>
          <table>
            <thead>
              <tr>
                <th>Account</th>
                <%= for c <- @companies do %>
                  <th class="th-num" style="font-size: 0.8rem;">{short_name(c.name)}</th>
                <% end %>
                <th class="th-num">Elim.</th>
                <th class="th-num">NCI</th>
                <th class="th-num" style="font-weight: 700;">Consolidated</th>
              </tr>
            </thead>
            <tbody>
              <%= for row <- @consolidated_is.revenue do %>
                <tr>
                  <td class="td-name">{row.name}</td>
                  <%= for c <- @companies do %>
                    <td class="td-num num-positive">{format_number(Map.get(row.by_entity, c.id, 0))}</td>
                  <% end %>
                  <td class="td-num num-negative">{format_number(row.elimination)}</td>
                  <td class="td-num">{format_number(row.nci)}</td>
                  <td class="td-num num-positive" style="font-weight: 600;">{format_number(row.consolidated)}</td>
                </tr>
              <% end %>
              <tr style="font-weight: 700; border-top: 2px solid #ccc;">
                <td>Total Revenue</td>
                <%= for c <- @companies do %>
                  <td class="td-num num-positive">{format_number(entity_is_total(@entity_data, c.id, :total_revenue))}</td>
                <% end %>
                <td class="td-num num-negative">{format_number(sum_field_list(@consolidated_is.revenue, :elimination))}</td>
                <td class="td-num">{format_number(sum_field_list(@consolidated_is.revenue, :nci))}</td>
                <td class="td-num num-positive" style="font-weight: 700;">${format_number(@consolidated_is.total_revenue)}</td>
              </tr>
            </tbody>
          </table>

          <h3 style="padding: 1rem 1rem 0; font-family: 'Source Serif 4', Georgia, serif;">Expenses</h3>
          <table>
            <thead>
              <tr>
                <th>Account</th>
                <%= for c <- @companies do %>
                  <th class="th-num" style="font-size: 0.8rem;">{short_name(c.name)}</th>
                <% end %>
                <th class="th-num">Elim.</th>
                <th class="th-num">NCI</th>
                <th class="th-num" style="font-weight: 700;">Consolidated</th>
              </tr>
            </thead>
            <tbody>
              <%= for row <- @consolidated_is.expenses do %>
                <tr>
                  <td class="td-name">{row.name}</td>
                  <%= for c <- @companies do %>
                    <td class="td-num num-negative">{format_number(Map.get(row.by_entity, c.id, 0))}</td>
                  <% end %>
                  <td class="td-num num-negative">{format_number(row.elimination)}</td>
                  <td class="td-num">{format_number(row.nci)}</td>
                  <td class="td-num num-negative" style="font-weight: 600;">{format_number(row.consolidated)}</td>
                </tr>
              <% end %>
              <tr style="font-weight: 700; border-top: 2px solid #ccc;">
                <td>Total Expenses</td>
                <%= for c <- @companies do %>
                  <td class="td-num num-negative">{format_number(entity_is_total(@entity_data, c.id, :total_expenses))}</td>
                <% end %>
                <td class="td-num num-negative">{format_number(sum_field_list(@consolidated_is.expenses, :elimination))}</td>
                <td class="td-num">{format_number(sum_field_list(@consolidated_is.expenses, :nci))}</td>
                <td class="td-num num-negative" style="font-weight: 700;">${format_number(@consolidated_is.total_expenses)}</td>
              </tr>
            </tbody>
          </table>

          <table style="margin-top: 1rem;">
            <tbody>
              <tr style="font-weight: 700; border-top: 3px double #999;">
                <td style="font-size: 1.05rem;">Net Income (Consolidated)</td>
                <td></td>
                <td></td>
                <td></td>
                <td class={"td-num #{if Money.gte?(@consolidated_is.net_income, 0), do: "num-positive", else: "num-negative"}"} style="font-size: 1.05rem;">
                  ${format_number(@consolidated_is.net_income)}
                </td>
              </tr>
              <tr>
                <td>Attributable to Parent</td>
                <td></td>
                <td></td>
                <td></td>
                <td class="td-num">${format_number(Money.sub(@consolidated_is.net_income, @consolidated_is.nci_share))}</td>
              </tr>
              <tr>
                <td>Attributable to NCI</td>
                <td></td>
                <td></td>
                <td></td>
                <td class="td-num">${format_number(@consolidated_is.nci_share)}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    <% end %>

    <div style="margin-top: 2rem; padding-top: 1rem; border-top: 1px solid var(--rule);">
      <span style="font-size: 0.75rem; font-weight: 600; text-transform: uppercase; letter-spacing: 0.05em; color: var(--ink-faint);">Related</span>
      <div style="display: flex; gap: 1rem; margin-top: 0.5rem; flex-wrap: wrap;">
        <.link navigate={~p"/financials"} class="td-link" style="font-size: 0.85rem;">Financials</.link>
        <.link navigate={~p"/accounts/reports"} class="td-link" style="font-size: 0.85rem;">Accounting Reports</.link>
      </div>
    </div>

    <%= if @active_tab == "eliminations" do %>
      <div class="section">
        <div class="section-head">
          <h2>Intercompany Eliminations</h2>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Date</th>
                <th>From Entity</th>
                <th>To Entity</th>
                <th>Description</th>
                <th class="th-num">Amount</th>
                <th>Currency</th>
              </tr>
            </thead>
            <tbody>
              <%= for t <- @transfers do %>
                <tr>
                  <td class="td-mono">{t.date}</td>
                  <td>
                    <%= if t.from_company do %>
                      <.link navigate={~p"/companies/#{t.from_company.id}"} class="td-link">
                        {t.from_company.name}
                      </.link>
                    <% else %>
                      ---
                    <% end %>
                  </td>
                  <td>
                    <%= if t.to_company do %>
                      <.link navigate={~p"/companies/#{t.to_company.id}"} class="td-link">
                        {t.to_company.name}
                      </.link>
                    <% else %>
                      ---
                    <% end %>
                  </td>
                  <td class="td-name">{t.description || "---"}</td>
                  <td class="td-num">{format_number(t.amount || 0)}</td>
                  <td>{t.currency || "USD"}</td>
                </tr>
              <% end %>
            </tbody>
            <tfoot>
              <tr style="font-weight: 600; border-top: 2px solid var(--rule);">
                <td colspan="4">Total Eliminations</td>
                <td class="td-num num-negative">
                  ${format_number(Enum.reduce(@transfers, Decimal.new(0), fn t, acc -> Money.add(acc, Money.to_decimal(t.amount)) end))}
                </td>
                <td></td>
              </tr>
            </tfoot>
          </table>
          <%= if @transfers == [] do %>
            <div class="empty-state">
              No intercompany transfers recorded. Intercompany transactions are eliminated during consolidation.
            </div>
          <% end %>
        </div>
      </div>

      <div class="section">
        <div class="section-head">
          <h2>Non-Controlling Interest by Entity</h2>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Entity</th>
                <th class="th-num">Ownership %</th>
                <th class="th-num">NCI %</th>
                <th class="th-num">Entity Equity</th>
                <th class="th-num">NCI Value</th>
              </tr>
            </thead>
            <tbody>
              <%= for c <- @companies do %>
                <% ownership = c.ownership_pct || 100 %>
                <% nci_pct = max(100 - ownership, 0) %>
                <% entity_equity = entity_bs_total(@entity_data, c.id, :equity) %>
                <% nci_value = Money.div(Money.mult(entity_equity, nci_pct), 100) %>
                <tr>
                  <td class="td-name">
                    <.link navigate={~p"/companies/#{c.id}"} class="td-link">{c.name}</.link>
                  </td>
                  <td class="td-num">{ownership}%</td>
                  <td class="td-num">
                    <%= if nci_pct > 0 do %>
                      <span class="tag tag-lemon">{nci_pct}%</span>
                    <% else %>
                      <span class="tag tag-jade">0%</span>
                    <% end %>
                  </td>
                  <td class="td-num">{format_number(entity_equity)}</td>
                  <td class="td-num">{format_number(nci_value)}</td>
                </tr>
              <% end %>
            </tbody>
            <tfoot>
              <tr style="font-weight: 600; border-top: 2px solid var(--rule);">
                <td colspan="4">Total NCI</td>
                <td class="td-num">${format_number(@consolidated_bs.total_nci)}</td>
              </tr>
            </tfoot>
          </table>
        </div>
      </div>
    <% end %>
    """
  end

  # -- Helpers delegated to Consolidation module --

  defp entity_bs_total(entity_data, company_id, section),
    do: Consolidation.entity_bs_total(entity_data, company_id, section)

  defp entity_is_total(entity_data, company_id, field),
    do: Consolidation.entity_is_total(entity_data, company_id, field)

  defp sum_field_list(rows, field),
    do: Consolidation.sum_field_list(rows, field)

  defp short_name(name) when is_binary(name) do
    if String.length(name) > 12, do: String.slice(name, 0, 12) <> "..", else: name
  end

  defp short_name(_), do: "---"

  # -- Formatting --

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
