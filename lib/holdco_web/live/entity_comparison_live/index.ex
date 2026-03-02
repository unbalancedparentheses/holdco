defmodule HoldcoWeb.EntityComparisonLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Corporate, Finance, Money}

  @impl true
  def mount(_params, _session, socket) do
    companies = Corporate.list_companies()

    {:ok,
     assign(socket,
       page_title: "Entity Comparison",
       companies: companies,
       selected_ids: [],
       selected_companies: [],
       active_tab: "balance_sheet",
       balance_sheets: %{},
       income_statements: %{}
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("toggle_company", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)
    current = socket.assigns.selected_ids

    new_ids =
      if id in current do
        List.delete(current, id)
      else
        if length(current) >= 4 do
          current
        else
          current ++ [id]
        end
      end

    socket = load_comparison_data(socket, new_ids)
    {:noreply, socket}
  end

  def handle_event("remove_company", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)
    new_ids = List.delete(socket.assigns.selected_ids, id)
    socket = load_comparison_data(socket, new_ids)
    {:noreply, socket}
  end

  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, active_tab: tab)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <h1>Entity Comparison</h1>
      <p class="deck">
        Compare balance sheets, income statements, and financial ratios side-by-side across 2 to 4 entities
      </p>
      <hr class="page-title-rule" />
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Select Entities (2-4)</h2>
      </div>
      <div class="panel" style="padding: 1rem;">
        <div style="display: flex; flex-wrap: wrap; gap: 0.5rem; margin-bottom: 1rem;">
          <%= for c <- @companies do %>
            <button
              phx-click="toggle_company"
              phx-value-id={c.id}
              class={"btn #{if c.id in @selected_ids, do: "btn-primary", else: "btn-secondary"}"}
              style="font-size: 0.85rem;"
            >
              {c.name}
              <%= if c.id in @selected_ids do %>
                &#10003;
              <% end %>
            </button>
          <% end %>
        </div>
        <%= if @selected_companies != [] do %>
          <div style="display: flex; gap: 0.5rem; flex-wrap: wrap;">
            <span style="color: #888; font-size: 0.85rem; padding-top: 0.3rem;">Selected:</span>
            <%= for c <- @selected_companies do %>
              <span class="tag tag-jade" style="display: inline-flex; align-items: center; gap: 0.25rem;">
                {c.name}
                <button
                  phx-click="remove_company"
                  phx-value-id={c.id}
                  style="background: none; border: none; cursor: pointer; font-size: 0.9rem; padding: 0; line-height: 1;"
                >
                  &times;
                </button>
              </span>
            <% end %>
          </div>
        <% end %>
        <%= if length(@selected_ids) >= 4 do %>
          <div style="color: #888; font-size: 0.8rem; margin-top: 0.5rem;">
            Maximum 4 entities selected.
          </div>
        <% end %>
      </div>
    </div>

    <%= if length(@selected_ids) >= 2 do %>
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
            phx-value-tab="ratios"
            class={"btn #{if @active_tab == "ratios", do: "btn-primary", else: "btn-secondary"}"}
          >
            Ratios
          </button>
        </div>

        <%= if @active_tab == "balance_sheet" do %>
          <div class="panel">
            <h3 style="padding: 1rem 1rem 0; font-family: 'Source Serif 4', Georgia, serif;">Assets</h3>
            <table>
              <thead>
                <tr>
                  <th>Account</th>
                  <%= for c <- @selected_companies do %>
                    <th class="th-num">{c.name}</th>
                  <% end %>
                </tr>
              </thead>
              <tbody>
                <% asset_rows = merge_bs_rows(@balance_sheets, @selected_ids, :assets) %>
                <%= for row <- asset_rows do %>
                  <tr>
                    <td class="td-name">{row.name}</td>
                    <%= for id <- @selected_ids do %>
                      <td class="td-num">{format_number(row.values[id] || 0)}</td>
                    <% end %>
                  </tr>
                <% end %>
                <tr style="font-weight: 700; border-top: 2px solid #ccc;">
                  <td>Total Assets</td>
                  <%= for id <- @selected_ids do %>
                    <% bs = Map.get(@balance_sheets, id, %{}) %>
                    <td class="td-num num-positive">{format_number(Map.get(bs, :total_assets, 0))}</td>
                  <% end %>
                </tr>
              </tbody>
            </table>

            <h3 style="padding: 1rem 1rem 0; font-family: 'Source Serif 4', Georgia, serif;">Liabilities</h3>
            <table>
              <thead>
                <tr>
                  <th>Account</th>
                  <%= for c <- @selected_companies do %>
                    <th class="th-num">{c.name}</th>
                  <% end %>
                </tr>
              </thead>
              <tbody>
                <% liab_rows = merge_bs_rows(@balance_sheets, @selected_ids, :liabilities) %>
                <%= for row <- liab_rows do %>
                  <tr>
                    <td class="td-name">{row.name}</td>
                    <%= for id <- @selected_ids do %>
                      <td class="td-num">{format_number(row.values[id] || 0)}</td>
                    <% end %>
                  </tr>
                <% end %>
                <tr style="font-weight: 700; border-top: 2px solid #ccc;">
                  <td>Total Liabilities</td>
                  <%= for id <- @selected_ids do %>
                    <% bs = Map.get(@balance_sheets, id, %{}) %>
                    <td class="td-num num-negative">{format_number(Map.get(bs, :total_liabilities, 0))}</td>
                  <% end %>
                </tr>
              </tbody>
            </table>

            <h3 style="padding: 1rem 1rem 0; font-family: 'Source Serif 4', Georgia, serif;">Equity</h3>
            <table>
              <thead>
                <tr>
                  <th>Account</th>
                  <%= for c <- @selected_companies do %>
                    <th class="th-num">{c.name}</th>
                  <% end %>
                </tr>
              </thead>
              <tbody>
                <% equity_rows = merge_bs_rows(@balance_sheets, @selected_ids, :equity) %>
                <%= for row <- equity_rows do %>
                  <tr>
                    <td class="td-name">{row.name}</td>
                    <%= for id <- @selected_ids do %>
                      <td class="td-num">{format_number(row.values[id] || 0)}</td>
                    <% end %>
                  </tr>
                <% end %>
                <tr style="font-weight: 700; border-top: 2px solid #ccc;">
                  <td>Total Equity</td>
                  <%= for id <- @selected_ids do %>
                    <% bs = Map.get(@balance_sheets, id, %{}) %>
                    <td class="td-num">{format_number(Map.get(bs, :total_equity, 0))}</td>
                  <% end %>
                </tr>
              </tbody>
            </table>
          </div>
        <% end %>

        <%= if @active_tab == "income_statement" do %>
          <div class="panel">
            <h3 style="padding: 1rem 1rem 0; font-family: 'Source Serif 4', Georgia, serif;">Revenue</h3>
            <table>
              <thead>
                <tr>
                  <th>Account</th>
                  <%= for c <- @selected_companies do %>
                    <th class="th-num">{c.name}</th>
                  <% end %>
                </tr>
              </thead>
              <tbody>
                <% rev_rows = merge_is_rows(@income_statements, @selected_ids, :revenue) %>
                <%= for row <- rev_rows do %>
                  <tr>
                    <td class="td-name">{row.name}</td>
                    <%= for id <- @selected_ids do %>
                      <td class="td-num num-positive">{format_number(row.values[id] || 0)}</td>
                    <% end %>
                  </tr>
                <% end %>
                <tr style="font-weight: 700; border-top: 2px solid #ccc;">
                  <td>Total Revenue</td>
                  <%= for id <- @selected_ids do %>
                    <% is = Map.get(@income_statements, id, %{}) %>
                    <td class="td-num num-positive">{format_number(Map.get(is, :total_revenue, 0))}</td>
                  <% end %>
                </tr>
              </tbody>
            </table>

            <h3 style="padding: 1rem 1rem 0; font-family: 'Source Serif 4', Georgia, serif;">Expenses</h3>
            <table>
              <thead>
                <tr>
                  <th>Account</th>
                  <%= for c <- @selected_companies do %>
                    <th class="th-num">{c.name}</th>
                  <% end %>
                </tr>
              </thead>
              <tbody>
                <% exp_rows = merge_is_rows(@income_statements, @selected_ids, :expenses) %>
                <%= for row <- exp_rows do %>
                  <tr>
                    <td class="td-name">{row.name}</td>
                    <%= for id <- @selected_ids do %>
                      <td class="td-num num-negative">{format_number(row.values[id] || 0)}</td>
                    <% end %>
                  </tr>
                <% end %>
                <tr style="font-weight: 700; border-top: 2px solid #ccc;">
                  <td>Total Expenses</td>
                  <%= for id <- @selected_ids do %>
                    <% is = Map.get(@income_statements, id, %{}) %>
                    <td class="td-num num-negative">{format_number(Map.get(is, :total_expenses, 0))}</td>
                  <% end %>
                </tr>
              </tbody>
            </table>

            <table style="margin-top: 1rem;">
              <tbody>
                <tr style="font-weight: 700; border-top: 3px double #999;">
                  <td style="font-size: 1.05rem;">Net Income</td>
                  <%= for id <- @selected_ids do %>
                    <% is = Map.get(@income_statements, id, %{}) %>
                    <% net = Map.get(is, :net_income, 0) %>
                    <td class={"td-num #{if Money.gte?(net, 0), do: "num-positive", else: "num-negative"}"} style="font-size: 1.05rem;">
                      {format_number(net)}
                    </td>
                  <% end %>
                </tr>
              </tbody>
            </table>
          </div>
        <% end %>

        <%= if @active_tab == "ratios" do %>
          <div class="panel">
            <h3 style="padding: 1rem 1rem 0; font-family: 'Source Serif 4', Georgia, serif;">Financial Ratios</h3>
            <%
              ratios = compute_ratios(@balance_sheets, @income_statements, @selected_ids)
              current_ratios = Enum.map(@selected_ids, fn id -> Map.get(ratios, id, %{})[:current_ratio] end)
              net_margins = Enum.map(@selected_ids, fn id -> Map.get(ratios, id, %{})[:net_margin] end)
              cr_best = best_ratio(current_ratios)
              cr_worst = worst_ratio(current_ratios)
              nm_best = best_ratio(net_margins)
              nm_worst = worst_ratio(net_margins)
            %>
            <table>
              <thead>
                <tr>
                  <th>Ratio</th>
                  <%= for c <- @selected_companies do %>
                    <th class="th-num">{c.name}</th>
                  <% end %>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <td class="td-name">Current Ratio</td>
                  <%= for {id, idx} <- Enum.with_index(@selected_ids) do %>
                    <% val = Map.get(ratios, id, %{})[:current_ratio] %>
                    <td class="td-num" style={ratio_highlight(idx, cr_best, cr_worst)}>
                      {format_ratio(val)}
                    </td>
                  <% end %>
                </tr>
                <tr>
                  <td class="td-name">Net Margin (%)</td>
                  <%= for {id, idx} <- Enum.with_index(@selected_ids) do %>
                    <% val = Map.get(ratios, id, %{})[:net_margin] %>
                    <td class="td-num" style={ratio_highlight(idx, nm_best, nm_worst)}>
                      {format_ratio(val)}<%= if val, do: "%" %>
                    </td>
                  <% end %>
                </tr>
              </tbody>
            </table>
            <p style="color: var(--muted); font-size: 0.85rem; padding: 1rem;">
              Current Ratio = Total Current Assets / Total Current Liabilities. Net Margin = (Revenue - Expenses) / Revenue * 100.
              <span style="color: #2e7d32;">Green</span> = best,
              <span style="color: #c62828;">Red</span> = worst among selected entities.
            </p>
          </div>
        <% end %>
      </div>
    <% else %>
      <div class="section">
        <div class="panel">
          <div class="empty-state">
            Select at least 2 entities above to compare their financial statements side-by-side.
          </div>
        </div>
      </div>
    <% end %>

    <div style="margin-top: 2rem; padding-top: 1rem; border-top: 1px solid var(--rule);">
      <span style="font-size: 0.75rem; font-weight: 600; text-transform: uppercase; letter-spacing: 0.05em; color: var(--ink-faint);">Related</span>
      <div style="display: flex; gap: 1rem; margin-top: 0.5rem; flex-wrap: wrap;">
        <.link navigate={~p"/consolidated"} class="td-link" style="font-size: 0.85rem;">Consolidated</.link>
        <.link navigate={~p"/financials"} class="td-link" style="font-size: 0.85rem;">Financials</.link>
      </div>
    </div>
    """
  end

  # -- Data Loading --

  defp load_comparison_data(socket, selected_ids) do
    companies = socket.assigns.companies
    selected_companies = Enum.filter(companies, &(&1.id in selected_ids))

    balance_sheets =
      Map.new(selected_ids, fn id ->
        {id, Finance.balance_sheet(id)}
      end)

    income_statements =
      Map.new(selected_ids, fn id ->
        {id, Finance.income_statement(id)}
      end)

    assign(socket,
      selected_ids: selected_ids,
      selected_companies: selected_companies,
      balance_sheets: balance_sheets,
      income_statements: income_statements
    )
  end

  # -- Row Merging --

  defp merge_bs_rows(balance_sheets, selected_ids, section) do
    all_accounts =
      selected_ids
      |> Enum.flat_map(fn id ->
        bs = Map.get(balance_sheets, id, %{})
        accounts = Map.get(bs, section, [])
        Enum.map(accounts, fn a -> {a.code, a.name} end)
      end)
      |> Enum.uniq_by(fn {code, _name} -> code end)
      |> Enum.sort_by(fn {code, _name} -> code end)

    Enum.map(all_accounts, fn {code, name} ->
      values =
        Map.new(selected_ids, fn id ->
          bs = Map.get(balance_sheets, id, %{})
          accounts = Map.get(bs, section, [])
          account = Enum.find(accounts, fn a -> a.code == code end)
          {id, if(account, do: account.balance, else: 0)}
        end)

      %{code: code, name: "#{code} - #{name}", values: values}
    end)
  end

  defp merge_is_rows(income_statements, selected_ids, section) do
    all_accounts =
      selected_ids
      |> Enum.flat_map(fn id ->
        is = Map.get(income_statements, id, %{})
        accounts = Map.get(is, section, [])
        Enum.map(accounts, fn a -> {a.code, a.name} end)
      end)
      |> Enum.uniq_by(fn {code, _name} -> code end)
      |> Enum.sort_by(fn {code, _name} -> code end)

    Enum.map(all_accounts, fn {code, name} ->
      values =
        Map.new(selected_ids, fn id ->
          is = Map.get(income_statements, id, %{})
          accounts = Map.get(is, section, [])
          account = Enum.find(accounts, fn a -> a.code == code end)
          {id, if(account, do: account.amount, else: 0)}
        end)

      %{code: code, name: "#{code} - #{name}", values: values}
    end)
  end

  # -- Formatting --

  defp format_number(%Decimal{} = n),
    do: n |> Decimal.round(0) |> Decimal.to_string() |> add_commas()

  defp format_number(n) when is_float(n),
    do: :erlang.float_to_binary(n, decimals: 0) |> add_commas()

  defp format_number(n) when is_integer(n), do: Integer.to_string(n) |> add_commas()
  defp format_number(_), do: "0"

  defp add_commas(str) do
    str |> String.reverse() |> String.replace(~r/(\d{3})(?=\d)/, "\\1,") |> String.reverse()
  end

  # -- Ratios --

  defp compute_ratios(balance_sheets, income_statements, selected_ids) do
    Map.new(selected_ids, fn id ->
      bs = Map.get(balance_sheets, id, %{})
      is = Map.get(income_statements, id, %{})

      total_assets = Map.get(bs, :total_assets, 0)
      total_liabilities = Map.get(bs, :total_liabilities, 0)
      total_revenue = Map.get(is, :total_revenue, 0)
      total_expenses = Map.get(is, :total_expenses, 0)

      current_ratio =
        if is_positive?(total_liabilities) do
          safe_div(total_assets, total_liabilities)
        else
          nil
        end

      net_margin =
        if is_positive?(total_revenue) do
          net = safe_sub(total_revenue, total_expenses)
          safe_div(net, total_revenue) |> safe_mult(100)
        else
          nil
        end

      {id, %{current_ratio: current_ratio, net_margin: net_margin}}
    end)
  end

  defp is_positive?(%Decimal{} = d), do: Decimal.gt?(d, 0)
  defp is_positive?(n) when is_number(n), do: n > 0
  defp is_positive?(_), do: false

  defp safe_div(%Decimal{} = a, %Decimal{} = b), do: Decimal.div(a, b) |> Decimal.round(2)
  defp safe_div(a, b) when is_number(a) and is_number(b) and b != 0, do: Float.round(a / b, 2)
  defp safe_div(a, b), do: safe_div(to_dec(a), to_dec(b))

  defp safe_sub(%Decimal{} = a, %Decimal{} = b), do: Decimal.sub(a, b)
  defp safe_sub(a, b), do: safe_sub(to_dec(a), to_dec(b))

  defp safe_mult(%Decimal{} = a, n), do: Decimal.mult(a, Decimal.new(n)) |> Decimal.round(1)
  defp safe_mult(a, n) when is_number(a), do: Float.round(a * n, 1)
  defp safe_mult(a, n), do: safe_mult(to_dec(a), n)

  defp to_dec(%Decimal{} = d), do: d
  defp to_dec(n) when is_float(n), do: Decimal.from_float(n)
  defp to_dec(n) when is_integer(n), do: Decimal.new(n)
  defp to_dec(_), do: Decimal.new(0)

  defp format_ratio(nil), do: "N/A"
  defp format_ratio(%Decimal{} = d), do: Decimal.to_string(Decimal.round(d, 2))
  defp format_ratio(n) when is_number(n), do: :erlang.float_to_binary(n / 1, decimals: 2)
  defp format_ratio(_), do: "N/A"

  defp best_ratio(values) do
    nums = values |> Enum.with_index() |> Enum.reject(fn {v, _} -> is_nil(v) end)
    if nums == [], do: nil, else: nums |> Enum.max_by(fn {v, _} -> to_dec(v) end) |> elem(1)
  end

  defp worst_ratio(values) do
    nums = values |> Enum.with_index() |> Enum.reject(fn {v, _} -> is_nil(v) end)
    if nums == [], do: nil, else: nums |> Enum.min_by(fn {v, _} -> to_dec(v) end) |> elem(1)
  end

  defp ratio_highlight(idx, best, worst) do
    cond do
      best == worst -> ""
      idx == best -> "background: rgba(46, 125, 50, 0.12); color: #2e7d32; font-weight: 600;"
      idx == worst -> "background: rgba(198, 40, 40, 0.12); color: #c62828; font-weight: 600;"
      true -> ""
    end
  end
end
