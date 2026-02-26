defmodule HoldcoWeb.ConsolidatedLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Corporate, Finance}

  @impl true
  def mount(_params, _session, socket) do
    companies = Corporate.list_companies()
    transfers = Finance.list_inter_company_transfers()

    entity_data = load_entity_data(companies)
    eliminations = build_eliminations(transfers)
    consolidated_bs = build_consolidated_balance_sheet(entity_data, eliminations, companies)
    consolidated_is = build_consolidated_income_statement(entity_data, eliminations, companies)

    {:ok,
     assign(socket,
       page_title: "Consolidated Financial Statements",
       companies: companies,
       entity_data: entity_data,
       transfers: transfers,
       eliminations: eliminations,
       consolidated_bs: consolidated_bs,
       consolidated_is: consolidated_is,
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
      <h1>Consolidated Financial Statements</h1>
      <p class="deck">
        Group-level balance sheet and income statement with intercompany eliminations and non-controlling interest
      </p>
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
                <td class={"td-num #{if @consolidated_is.net_income >= 0, do: "num-positive", else: "num-negative"}"} style="font-size: 1.05rem;">
                  ${format_number(@consolidated_is.net_income)}
                </td>
              </tr>
              <tr>
                <td>Attributable to Parent</td>
                <td></td>
                <td></td>
                <td></td>
                <td class="td-num">${format_number(@consolidated_is.net_income - @consolidated_is.nci_share)}</td>
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
                  ${format_number(Enum.reduce(@transfers, 0.0, fn t, acc -> acc + (t.amount || 0) end))}
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
                <% nci_value = entity_equity * nci_pct / 100.0 %>
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

  # -- Data Loading --

  defp load_entity_data(companies) do
    Map.new(companies, fn c ->
      bs = Finance.balance_sheet(c.id)
      is = Finance.income_statement(c.id)
      {c.id, %{balance_sheet: bs, income_statement: is}}
    end)
  end

  # -- Eliminations --

  defp build_eliminations(transfers) do
    Enum.reduce(transfers, 0.0, fn t, acc ->
      acc + (t.amount || 0.0)
    end)
  end

  # -- Consolidated Balance Sheet --

  defp build_consolidated_balance_sheet(entity_data, _elimination_total, companies) do
    ownership_map = Map.new(companies, fn c -> {c.id, c.ownership_pct || 100} end)

    assets = merge_consolidated_rows(entity_data, companies, :balance_sheet, :assets, ownership_map)
    liabilities = merge_consolidated_rows(entity_data, companies, :balance_sheet, :liabilities, ownership_map)
    equity = merge_consolidated_rows(entity_data, companies, :balance_sheet, :equity, ownership_map)

    total_assets = Enum.reduce(assets, 0.0, fn r, acc -> acc + r.consolidated end)
    total_liabilities = Enum.reduce(liabilities, 0.0, fn r, acc -> acc + r.consolidated end)
    total_equity = Enum.reduce(equity, 0.0, fn r, acc -> acc + r.consolidated end)

    total_nci =
      Enum.reduce(companies, 0.0, fn c, acc ->
        nci_pct = max(100 - (c.ownership_pct || 100), 0)
        entity_eq = entity_bs_total(entity_data, c.id, :equity)
        acc + entity_eq * nci_pct / 100.0
      end)

    total_eliminations =
      Enum.reduce(assets ++ liabilities ++ equity, 0.0, fn r, acc -> acc + r.elimination end)

    %{
      assets: assets,
      liabilities: liabilities,
      equity: equity,
      total_assets: total_assets,
      total_liabilities: total_liabilities,
      total_equity: total_equity,
      total_nci: total_nci,
      total_eliminations: total_eliminations
    }
  end

  # -- Consolidated Income Statement --

  defp build_consolidated_income_statement(entity_data, _elimination_total, companies) do
    ownership_map = Map.new(companies, fn c -> {c.id, c.ownership_pct || 100} end)

    revenue = merge_consolidated_is_rows(entity_data, companies, :revenue, ownership_map)
    expenses = merge_consolidated_is_rows(entity_data, companies, :expenses, ownership_map)

    total_revenue = Enum.reduce(revenue, 0.0, fn r, acc -> acc + r.consolidated end)
    total_expenses = Enum.reduce(expenses, 0.0, fn r, acc -> acc + r.consolidated end)
    net_income = total_revenue - total_expenses

    nci_share =
      Enum.reduce(companies, 0.0, fn c, acc ->
        nci_pct = max(100 - (c.ownership_pct || 100), 0)
        entity_net = entity_is_total(entity_data, c.id, :total_revenue) - entity_is_total(entity_data, c.id, :total_expenses)
        acc + entity_net * nci_pct / 100.0
      end)

    %{
      revenue: revenue,
      expenses: expenses,
      total_revenue: total_revenue,
      total_expenses: total_expenses,
      net_income: net_income,
      nci_share: nci_share
    }
  end

  # -- Row Merging (Balance Sheet) --

  defp merge_consolidated_rows(entity_data, companies, statement, section, ownership_map) do
    all_accounts =
      companies
      |> Enum.flat_map(fn c ->
        data = Map.get(entity_data, c.id, %{})
        bs = Map.get(data, statement, %{})
        accounts = Map.get(bs, section, [])
        Enum.map(accounts, fn a -> {a.code, a.name} end)
      end)
      |> Enum.uniq_by(fn {code, _} -> code end)
      |> Enum.sort_by(fn {code, _} -> code end)

    Enum.map(all_accounts, fn {code, name} ->
      by_entity =
        Map.new(companies, fn c ->
          data = Map.get(entity_data, c.id, %{})
          bs = Map.get(data, statement, %{})
          accounts = Map.get(bs, section, [])
          account = Enum.find(accounts, fn a -> a.code == code end)
          {c.id, if(account, do: account.balance, else: 0)}
        end)

      raw_sum = Enum.reduce(by_entity, 0.0, fn {_id, val}, acc -> acc + val end)

      # NCI portion: sum of non-controlling shares
      nci =
        Enum.reduce(companies, 0.0, fn c, acc ->
          nci_pct = max(100 - Map.get(ownership_map, c.id, 100), 0)
          entity_val = Map.get(by_entity, c.id, 0)
          acc + entity_val * nci_pct / 100.0
        end)

      consolidated = raw_sum - nci

      %{
        code: code,
        name: "#{code} - #{name}",
        by_entity: by_entity,
        elimination: 0.0,
        nci: nci,
        consolidated: consolidated
      }
    end)
  end

  # -- Row Merging (Income Statement) --

  defp merge_consolidated_is_rows(entity_data, companies, section, ownership_map) do
    all_accounts =
      companies
      |> Enum.flat_map(fn c ->
        data = Map.get(entity_data, c.id, %{})
        is = Map.get(data, :income_statement, %{})
        accounts = Map.get(is, section, [])
        Enum.map(accounts, fn a -> {a.code, a.name} end)
      end)
      |> Enum.uniq_by(fn {code, _} -> code end)
      |> Enum.sort_by(fn {code, _} -> code end)

    Enum.map(all_accounts, fn {code, name} ->
      by_entity =
        Map.new(companies, fn c ->
          data = Map.get(entity_data, c.id, %{})
          is = Map.get(data, :income_statement, %{})
          accounts = Map.get(is, section, [])
          account = Enum.find(accounts, fn a -> a.code == code end)
          {c.id, if(account, do: account.amount, else: 0)}
        end)

      raw_sum = Enum.reduce(by_entity, 0.0, fn {_id, val}, acc -> acc + val end)

      nci =
        Enum.reduce(companies, 0.0, fn c, acc ->
          nci_pct = max(100 - Map.get(ownership_map, c.id, 100), 0)
          entity_val = Map.get(by_entity, c.id, 0)
          acc + entity_val * nci_pct / 100.0
        end)

      consolidated = raw_sum - nci

      %{
        code: code,
        name: "#{code} - #{name}",
        by_entity: by_entity,
        elimination: 0.0,
        nci: nci,
        consolidated: consolidated
      }
    end)
  end

  # -- Helpers --

  defp entity_bs_total(entity_data, company_id, section) do
    data = Map.get(entity_data, company_id, %{})
    bs = Map.get(data, :balance_sheet, %{})
    total_key = :"total_#{section}"
    Map.get(bs, total_key, 0.0)
  end

  defp entity_is_total(entity_data, company_id, field) do
    data = Map.get(entity_data, company_id, %{})
    is = Map.get(data, :income_statement, %{})
    Map.get(is, field, 0.0)
  end

  defp sum_field_list(rows, field) do
    Enum.reduce(rows, 0.0, fn r, acc -> acc + Map.get(r, field, 0.0) end)
  end

  defp short_name(name) when is_binary(name) do
    if String.length(name) > 12, do: String.slice(name, 0, 12) <> "..", else: name
  end

  defp short_name(_), do: "---"

  # -- Formatting --

  defp format_number(n) when is_float(n),
    do: :erlang.float_to_binary(n, decimals: 0) |> add_commas()

  defp format_number(n) when is_integer(n), do: Integer.to_string(n) |> add_commas()
  defp format_number(_), do: "0"

  defp add_commas(str) do
    str |> String.reverse() |> String.replace(~r/(\d{3})(?=\d)/, "\\1,") |> String.reverse()
  end
end
