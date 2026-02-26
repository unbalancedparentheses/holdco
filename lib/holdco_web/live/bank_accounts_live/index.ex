defmodule HoldcoWeb.BankAccountsLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Banking, Corporate, Treasury}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Holdco.Platform.subscribe("banking")

    accounts = Banking.list_bank_accounts()
    companies = Corporate.list_companies()
    total_balance = Banking.total_balance()
    cash_pools = Treasury.list_cash_pools()

    {:ok,
     assign(socket,
       page_title: "Bank Accounts",
       accounts: accounts,
       companies: companies,
       total_balance: total_balance,
       selected_company_id: "",
       show_form: false,
       cash_pools: cash_pools,
       show_pool_form: false
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("show_form", _, socket), do: {:noreply, assign(socket, show_form: true)}
  def handle_event("close_form", _, socket), do: {:noreply, assign(socket, show_form: false)}

  def handle_event("filter_company", %{"company_id" => id}, socket) do
    company_id = if id == "", do: nil, else: String.to_integer(id)

    accounts =
      Banking.list_bank_accounts()
      |> then(fn accts ->
        if company_id, do: Enum.filter(accts, &(&1.company_id == company_id)), else: accts
      end)

    total_balance = Enum.reduce(accounts, 0.0, fn a, acc -> acc + (a.balance || 0.0) end)

    {:noreply,
     assign(socket,
       selected_company_id: id,
       accounts: accounts,
       total_balance: total_balance
     )}
  end

  def handle_event("save", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("delete", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("save", %{"bank_account" => params}, socket) do
    case Banking.create_bank_account(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket) |> put_flash(:info, "Bank account added") |> assign(show_form: false)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add bank account")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    bank_account = Banking.get_bank_account!(String.to_integer(id))
    Banking.delete_bank_account(bank_account)
    {:noreply, reload(socket) |> put_flash(:info, "Bank account deleted")}
  end

  def handle_event("show_pool_form", _, socket),
    do: {:noreply, assign(socket, show_pool_form: true)}

  def handle_event("close_pool_form", _, socket),
    do: {:noreply, assign(socket, show_pool_form: false)}

  def handle_event("save_pool", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("delete_pool", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("save_pool", %{"pool" => params}, socket) do
    case Treasury.create_cash_pool(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket) |> put_flash(:info, "Cash pool added") |> assign(show_pool_form: false)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add cash pool")}
    end
  end

  def handle_event("delete_pool", %{"id" => id}, socket) do
    pool = Treasury.get_cash_pool!(String.to_integer(id))
    Treasury.delete_cash_pool(pool)
    {:noreply, reload(socket) |> put_flash(:info, "Cash pool deleted")}
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, reload(socket)}

  defp reload(socket) do
    accounts = Banking.list_bank_accounts()
    total_balance = Banking.total_balance()
    cash_pools = Treasury.list_cash_pools()
    assign(socket, accounts: accounts, total_balance: total_balance, cash_pools: cash_pools)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Bank Accounts</h1>
          <p class="deck">{length(@accounts)} accounts across all entities</p>
        </div>
        <%= if @can_write do %>
          <button class="btn btn-primary" phx-click="show_form">Add Account</button>
        <% end %>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div style="margin-bottom: 1rem;">
      <form phx-change="filter_company" style="display: flex; align-items: center; gap: 0.5rem;">
        <label class="form-label" style="margin: 0; font-size: 0.85rem;">Company</label>
        <select name="company_id" class="form-select" style="width: auto; padding: 0.3rem 0.5rem;">
          <option value="">All Companies</option>
          <%= for c <- @companies do %>
            <option value={c.id} selected={to_string(c.id) == @selected_company_id}>{c.name}</option>
          <% end %>
        </select>
      </form>
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Balance</div>
        <div class="metric-value">${format_number(@total_balance)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Accounts</div>
        <div class="metric-value">{length(@accounts)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Currencies</div>
        <div class="metric-value">
          {@accounts |> Enum.map(& &1.currency) |> Enum.uniq() |> length()}
        </div>
      </div>
    </div>

    <div class="grid-2">
      <div class="section">
        <div class="section-head">
          <h2>Balance by Currency</h2>
        </div>
        <div class="panel" style="padding: 1rem;">
          <div
            id="currency-chart"
            phx-hook="ChartHook"
            data-chart-type="doughnut"
            data-chart-data={Jason.encode!(currency_chart_data(@accounts))}
            data-chart-options={Jason.encode!(%{plugins: %{legend: %{position: "right"}}})}
            style="height: 250px;"
          >
            <canvas></canvas>
          </div>
        </div>
      </div>

      <div class="section">
        <div class="section-head">
          <h2>By Currency</h2>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Currency</th>
                <th class="th-num">Count</th>
                <th class="th-num">Total Balance</th>
              </tr>
            </thead>
            <tbody>
              <%= for {currency, accts} <- Enum.group_by(@accounts, & &1.currency) do %>
                <tr>
                  <td>{currency}</td>
                  <td class="td-num">{length(accts)}</td>
                  <td class="td-num">
                    {format_number(Enum.reduce(accts, 0.0, fn a, acc -> acc + (a.balance || 0.0) end))}
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>All Accounts</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Bank</th>
              <th>Account #</th>
              <th>IBAN</th>
              <th>Type</th>
              <th>Currency</th>
              <th class="th-num">Balance</th>
              <th>Company</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for ba <- @accounts do %>
              <tr>
                <td class="td-name">{ba.bank_name}</td>
                <td class="td-mono">{ba.account_number}</td>
                <td class="td-mono">{ba.iban}</td>
                <td>{ba.account_type}</td>
                <td>{ba.currency}</td>
                <td class="td-num">{format_number(ba.balance || 0.0)}</td>
                <td>{if ba.company, do: ba.company.name, else: "---"}</td>
                <td>
                  <%= if @can_write do %>
                    <button
                      phx-click="delete"
                      phx-value-id={ba.id}
                      class="btn btn-danger btn-sm"
                      data-confirm="Delete?"
                    >
                      Del
                    </button>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @accounts == [] do %>
          <div class="empty-state">No bank accounts yet.</div>
        <% end %>
      </div>
    </div>

    <div class="section">
      <div
        class="section-head"
        style="display: flex; justify-content: space-between; align-items: center;"
      >
        <h2>Cash Pools</h2>
        <%= if @can_write do %>
          <button class="btn btn-primary" phx-click="show_pool_form">Add Pool</button>
        <% end %>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>Currency</th>
              <th class="th-num">Target Balance</th>
              <th class="th-num"># Entries</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for pool <- @cash_pools do %>
              <tr>
                <td class="td-name">{pool.name}</td>
                <td>{pool.currency}</td>
                <td class="td-num">{format_number(pool.target_balance || 0.0)}</td>
                <td class="td-num">{length(pool.entries || [])}</td>
                <td>
                  <%= if @can_write do %>
                    <button
                      phx-click="delete_pool"
                      phx-value-id={pool.id}
                      class="btn btn-danger btn-sm"
                      data-confirm="Delete?"
                    >
                      Del
                    </button>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @cash_pools == [] do %>
          <div class="empty-state">No cash pools yet.</div>
        <% end %>
      </div>
    </div>

    <%= if @show_pool_form do %>
      <div class="modal-overlay" phx-click="close_pool_form">
        <div class="modal" phx-click-away="close_pool_form">
          <div class="modal-header">
            <h3>Add Cash Pool</h3>
          </div>
          <div class="modal-body">
            <form phx-submit="save_pool">
              <div class="form-group">
                <label class="form-label">Name *</label>
                <input type="text" name="pool[name]" class="form-input" required />
              </div>
              <div class="form-group">
                <label class="form-label">Currency</label>
                <input type="text" name="pool[currency]" class="form-input" value="USD" />
              </div>
              <div class="form-group">
                <label class="form-label">Target Balance</label>
                <input
                  type="number"
                  name="pool[target_balance]"
                  class="form-input"
                  step="any"
                  value="0"
                />
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label><textarea
                  name="pool[notes]"
                  class="form-input"
                  rows="3"
                ></textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Add Pool</button>
                <button type="button" phx-click="close_pool_form" class="btn btn-secondary">
                  Cancel
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>

    <%= if @show_form do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click="noop">
          <div class="modal-header">
            <h3>Add Bank Account</h3>
          </div>
          <div class="modal-body">
            <form phx-submit="save">
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="bank_account[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Bank Name *</label>
                <input type="text" name="bank_account[bank_name]" class="form-input" required />
              </div>
              <div class="form-group">
                <label class="form-label">Account Number</label>
                <input type="text" name="bank_account[account_number]" class="form-input" />
              </div>
              <div class="form-group">
                <label class="form-label">IBAN</label>
                <input type="text" name="bank_account[iban]" class="form-input" />
              </div>
              <div class="form-group">
                <label class="form-label">SWIFT</label>
                <input type="text" name="bank_account[swift]" class="form-input" />
              </div>
              <div class="form-group">
                <label class="form-label">Currency</label>
                <input type="text" name="bank_account[currency]" class="form-input" value="USD" />
              </div>
              <div class="form-group">
                <label class="form-label">Account Type</label>
                <select name="bank_account[account_type]" class="form-select">
                  <option value="operating">Operating</option>
                  <option value="savings">Savings</option>
                  <option value="escrow">Escrow</option>
                  <option value="trust">Trust</option>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Balance</label>
                <input
                  type="number"
                  name="bank_account[balance]"
                  class="form-input"
                  step="any"
                  value="0"
                />
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Add Account</button>
                <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp format_number(n) when is_float(n),
    do: :erlang.float_to_binary(n, decimals: 0) |> add_commas()

  defp format_number(n) when is_integer(n), do: Integer.to_string(n) |> add_commas()
  defp format_number(_), do: "0"

  defp add_commas(str) do
    str |> String.reverse() |> String.replace(~r/(\d{3})(?=\d)/, "\\1,") |> String.reverse()
  end

  defp currency_chart_data(accounts) do
    by_currency =
      accounts
      |> Enum.group_by(& &1.currency)
      |> Enum.map(fn {cur, accts} ->
        {cur, Enum.reduce(accts, 0.0, fn a, acc -> acc + (a.balance || 0.0) end)}
      end)
      |> Enum.sort_by(fn {_, v} -> -v end)

    colors = ["#0d7680", "#0f5499", "#00994d", "#990f3d", "#ff8833", "#f2a900", "#cc0000"]

    %{
      labels: Enum.map(by_currency, fn {c, _} -> c end),
      datasets: [
        %{
          data: Enum.map(by_currency, fn {_, v} -> v end),
          backgroundColor: Enum.take(colors, length(by_currency))
        }
      ]
    }
  end
end
