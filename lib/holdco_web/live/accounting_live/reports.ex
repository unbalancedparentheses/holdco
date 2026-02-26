defmodule HoldcoWeb.AccountingLive.Reports do
  use HoldcoWeb, :live_view

  alias Holdco.{Finance, Corporate}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Finance.subscribe()

    today = Date.utc_today()
    date_from = Date.to_iso8601(%{today | month: 1, day: 1})
    date_to = Date.to_iso8601(today)
    companies = Corporate.list_companies()

    {:ok,
     assign(socket,
       page_title: "Accounting Reports",
       active_tab: "trial_balance",
       companies: companies,
       selected_company_id: "",
       trial_balance: Finance.trial_balance(),
       balance_sheet: Finance.balance_sheet(),
       income_statement: Finance.income_statement(nil, date_from, date_to),
       date_from: date_from,
       date_to: date_to
     )}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, active_tab: tab)}
  end

  def handle_event("filter_company", %{"company_id" => id}, socket) do
    company_id = if id == "", do: nil, else: String.to_integer(id)
    from = socket.assigns.date_from
    to = socket.assigns.date_to

    {:noreply,
     assign(socket,
       selected_company_id: id,
       trial_balance: Finance.trial_balance(company_id),
       balance_sheet: Finance.balance_sheet(company_id),
       income_statement: Finance.income_statement(company_id, from, to)
     )}
  end

  def handle_event("filter_dates", %{"date_from" => from, "date_to" => to}, socket) do
    company_id =
      case socket.assigns.selected_company_id do
        "" -> nil
        id -> String.to_integer(id)
      end

    income_statement = Finance.income_statement(company_id, from, to)
    {:noreply, assign(socket, date_from: from, date_to: to, income_statement: income_statement)}
  end

  @impl true
  def handle_info(_, socket) do
    from = socket.assigns.date_from
    to = socket.assigns.date_to

    company_id =
      case socket.assigns.selected_company_id do
        "" -> nil
        id -> String.to_integer(id)
      end

    {:noreply,
     assign(socket,
       trial_balance: Finance.trial_balance(company_id),
       balance_sheet: Finance.balance_sheet(company_id),
       income_statement: Finance.income_statement(company_id, from, to)
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div>
        <h1>Accounting Reports</h1>
        <p class="deck">Trial Balance, Balance Sheet, and Income Statement</p>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div style="margin-bottom: 1rem;">
      <form phx-change="filter_company" style="display: flex; align-items: center; gap: 0.5rem;">
        <label class="form-label" style="margin: 0; font-size: 0.85rem;">Company</label>
        <select name="company_id" class="form-select" style="width: auto; padding: 0.3rem 0.5rem;">
          <option value="">All Companies (Consolidated)</option>
          <%= for c <- @companies do %>
            <option value={c.id} selected={to_string(c.id) == @selected_company_id}>{c.name}</option>
          <% end %>
        </select>
      </form>
    </div>

    <div style="display: flex; gap: 0.5rem; margin-bottom: 1rem;">
      <button
        class={"btn #{if @active_tab == "trial_balance", do: "btn-primary", else: "btn-secondary"}"}
        phx-click="switch_tab"
        phx-value-tab="trial_balance"
      >
        Trial Balance
      </button>
      <button
        class={"btn #{if @active_tab == "balance_sheet", do: "btn-primary", else: "btn-secondary"}"}
        phx-click="switch_tab"
        phx-value-tab="balance_sheet"
      >
        Balance Sheet
      </button>
      <button
        class={"btn #{if @active_tab == "income_statement", do: "btn-primary", else: "btn-secondary"}"}
        phx-click="switch_tab"
        phx-value-tab="income_statement"
      >
        Income Statement
      </button>
    </div>

    <%= if @active_tab == "trial_balance" do %>
      <.trial_balance_tab data={@trial_balance} />
    <% end %>

    <%= if @active_tab == "balance_sheet" do %>
      <.balance_sheet_tab data={@balance_sheet} />
    <% end %>

    <%= if @active_tab == "income_statement" do %>
      <.income_statement_tab data={@income_statement} date_from={@date_from} date_to={@date_to} />
    <% end %>
    """
  end

  defp trial_balance_tab(assigns) do
    total_debit = Enum.reduce(assigns.data, 0.0, &(&1.total_debit + &2))
    total_credit = Enum.reduce(assigns.data, 0.0, &(&1.total_credit + &2))
    balanced = abs(total_debit - total_credit) < 0.01
    assigns = assign(assigns, total_debit: total_debit, total_credit: total_credit, balanced: balanced)

    ~H"""
    <div class="section">
      <div class="section-head" style="display: flex; justify-content: space-between; align-items: center;">
        <h2>Trial Balance</h2>
        <span class={"badge #{if @balanced, do: "badge-asset", else: "badge-expense"}"}>
          <%= if @balanced, do: "Balanced", else: "UNBALANCED" %>
        </span>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Code</th>
              <th>Account</th>
              <th>Type</th>
              <th class="th-num">Debit</th>
              <th class="th-num">Credit</th>
              <th class="th-num">Balance</th>
            </tr>
          </thead>
          <tbody>
            <%= for row <- @data do %>
              <tr>
                <td class="td-mono">{row.code}</td>
                <td><.link navigate={~p"/accounts/journal?account_id=#{row.id}"} class="td-link">{row.name}</.link></td>
                <td><span class={"badge badge-#{row.account_type}"}>{row.account_type}</span></td>
                <td class="td-num">{format_number(row.total_debit)}</td>
                <td class="td-num">{format_number(row.total_credit)}</td>
                <td class={"td-num #{if row.balance >= 0, do: "num-positive", else: "num-negative"}"}>
                  {format_number(row.balance)}
                </td>
              </tr>
            <% end %>
          </tbody>
          <tfoot>
            <tr style="font-weight: bold; border-top: 2px solid var(--color-border);">
              <td></td>
              <td>Total</td>
              <td></td>
              <td class="td-num">{format_number(@total_debit)}</td>
              <td class="td-num">{format_number(@total_credit)}</td>
              <td class="td-num">{format_number(@total_debit - @total_credit)}</td>
            </tr>
          </tfoot>
        </table>
        <%= if @data == [] do %>
          <div class="empty-state">No account activity. Create journal entries to see the trial balance.</div>
        <% end %>
      </div>
    </div>
    """
  end

  defp balance_sheet_tab(assigns) do
    ~H"""
    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Assets</div>
        <div class="metric-value num-positive">${format_number(@data.total_assets)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Total Liabilities</div>
        <div class="metric-value num-negative">${format_number(@data.total_liabilities)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Total Equity</div>
        <div class="metric-value">${format_number(@data.total_equity)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">A = L + E</div>
        <% diff = @data.total_assets - (@data.total_liabilities + @data.total_equity) %>
        <div class={"metric-value #{if abs(diff) < 0.01, do: "num-positive", else: "num-negative"}"}>
          <%= if abs(diff) < 0.01, do: "Balanced", else: format_number(diff) %>
        </div>
      </div>
    </div>

    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem;">
      <div class="section">
        <div class="section-head"><h2>Assets</h2></div>
        <div class="panel">
          <table>
            <thead>
              <tr><th>Code</th><th>Account</th><th class="th-num">Balance</th></tr>
            </thead>
            <tbody>
              <%= for a <- @data.assets do %>
                <tr>
                  <td class="td-mono">{a.code}</td>
                  <td><.link navigate={~p"/accounts/journal?account_id=#{a.id}"} class="td-link">{a.name}</.link></td>
                  <td class="td-num">{format_number(a.balance)}</td>
                </tr>
              <% end %>
            </tbody>
            <tfoot>
              <tr style="font-weight: bold; border-top: 2px solid var(--color-border);">
                <td></td><td>Total Assets</td>
                <td class="td-num">{format_number(@data.total_assets)}</td>
              </tr>
            </tfoot>
          </table>
          <%= if @data.assets == [] do %>
            <div class="empty-state">No asset accounts with activity.</div>
          <% end %>
        </div>
      </div>

      <div>
        <div class="section">
          <div class="section-head"><h2>Liabilities</h2></div>
          <div class="panel">
            <table>
              <thead>
                <tr><th>Code</th><th>Account</th><th class="th-num">Balance</th></tr>
              </thead>
              <tbody>
                <%= for l <- @data.liabilities do %>
                  <tr>
                    <td class="td-mono">{l.code}</td>
                    <td><.link navigate={~p"/accounts/journal?account_id=#{l.id}"} class="td-link">{l.name}</.link></td>
                    <td class="td-num">{format_number(l.balance)}</td>
                  </tr>
                <% end %>
              </tbody>
              <tfoot>
                <tr style="font-weight: bold; border-top: 2px solid var(--color-border);">
                  <td></td><td>Total Liabilities</td>
                  <td class="td-num">{format_number(@data.total_liabilities)}</td>
                </tr>
              </tfoot>
            </table>
            <%= if @data.liabilities == [] do %>
              <div class="empty-state">No liability accounts with activity.</div>
            <% end %>
          </div>
        </div>

        <div class="section">
          <div class="section-head"><h2>Equity</h2></div>
          <div class="panel">
            <table>
              <thead>
                <tr><th>Code</th><th>Account</th><th class="th-num">Balance</th></tr>
              </thead>
              <tbody>
                <%= for e <- @data.equity do %>
                  <tr>
                    <td class="td-mono">{e.code}</td>
                    <td><.link navigate={~p"/accounts/journal?account_id=#{e.id}"} class="td-link">{e.name}</.link></td>
                    <td class="td-num">{e.balance |> format_number()}</td>
                  </tr>
                <% end %>
              </tbody>
              <tfoot>
                <tr style="font-weight: bold; border-top: 2px solid var(--color-border);">
                  <td></td><td>Total Equity</td>
                  <td class="td-num">{format_number(@data.total_equity)}</td>
                </tr>
              </tfoot>
            </table>
            <%= if @data.equity == [] do %>
              <div class="empty-state">No equity accounts with activity.</div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp income_statement_tab(assigns) do
    ~H"""
    <div style="margin-bottom: 1rem;">
      <form phx-change="filter_dates" style="display: flex; gap: 0.75rem; align-items: center;">
        <div class="form-group" style="margin: 0;">
          <label class="form-label" style="margin: 0; font-size: 0.85rem;">From</label>
          <input type="date" name="date_from" value={@date_from} class="form-input" style="padding: 0.3rem 0.5rem;" />
        </div>
        <div class="form-group" style="margin: 0;">
          <label class="form-label" style="margin: 0; font-size: 0.85rem;">To</label>
          <input type="date" name="date_to" value={@date_to} class="form-input" style="padding: 0.3rem 0.5rem;" />
        </div>
      </form>
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Revenue</div>
        <div class="metric-value num-positive">${format_number(@data.total_revenue)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Total Expenses</div>
        <div class="metric-value num-negative">${format_number(@data.total_expenses)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Net Income</div>
        <div class={"metric-value #{if @data.net_income >= 0, do: "num-positive", else: "num-negative"}"}>
          ${format_number(@data.net_income)}
        </div>
      </div>
    </div>

    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem;">
      <div class="section">
        <div class="section-head"><h2>Revenue</h2></div>
        <div class="panel">
          <table>
            <thead>
              <tr><th>Code</th><th>Account</th><th class="th-num">Amount</th></tr>
            </thead>
            <tbody>
              <%= for r <- @data.revenue do %>
                <tr>
                  <td class="td-mono">{r.code}</td>
                  <td><.link navigate={~p"/accounts/journal?account_id=#{r.id}"} class="td-link">{r.name}</.link></td>
                  <td class="td-num num-positive">{format_number(r.amount)}</td>
                </tr>
              <% end %>
            </tbody>
            <tfoot>
              <tr style="font-weight: bold; border-top: 2px solid var(--color-border);">
                <td></td><td>Total Revenue</td>
                <td class="td-num num-positive">{format_number(@data.total_revenue)}</td>
              </tr>
            </tfoot>
          </table>
          <%= if @data.revenue == [] do %>
            <div class="empty-state">No revenue recorded for this period.</div>
          <% end %>
        </div>
      </div>

      <div class="section">
        <div class="section-head"><h2>Expenses</h2></div>
        <div class="panel">
          <table>
            <thead>
              <tr><th>Code</th><th>Account</th><th class="th-num">Amount</th></tr>
            </thead>
            <tbody>
              <%= for e <- @data.expenses do %>
                <tr>
                  <td class="td-mono">{e.code}</td>
                  <td><.link navigate={~p"/accounts/journal?account_id=#{e.id}"} class="td-link">{e.name}</.link></td>
                  <td class="td-num num-negative">{format_number(e.amount)}</td>
                </tr>
              <% end %>
            </tbody>
            <tfoot>
              <tr style="font-weight: bold; border-top: 2px solid var(--color-border);">
                <td></td><td>Total Expenses</td>
                <td class="td-num num-negative">{format_number(@data.total_expenses)}</td>
              </tr>
            </tfoot>
          </table>
          <%= if @data.expenses == [] do %>
            <div class="empty-state">No expenses recorded for this period.</div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp format_number(n) when is_float(n),
    do: :erlang.float_to_binary(n, decimals: 2) |> add_commas()

  defp format_number(n) when is_integer(n), do: Integer.to_string(n) <> ".00" |> add_commas()
  defp format_number(_), do: "0.00"

  defp add_commas(str) do
    case String.split(str, ".") do
      [int, dec] ->
        (int |> String.reverse() |> String.replace(~r/(\d{3})(?=\d)/, "\\1,") |> String.reverse()) <>
          "." <> dec

      [int] ->
        int |> String.reverse() |> String.replace(~r/(\d{3})(?=\d)/, "\\1,") |> String.reverse()
    end
  end
end
