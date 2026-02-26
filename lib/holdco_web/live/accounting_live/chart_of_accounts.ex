defmodule HoldcoWeb.AccountingLive.ChartOfAccounts do
  use HoldcoWeb, :live_view

  alias Holdco.{Finance, Corporate}

  @account_types ~w(asset liability equity revenue expense)

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Finance.subscribe()

    companies = Corporate.list_companies()
    accounts = Finance.list_accounts()
    tree = build_tree(accounts)

    {:ok,
     assign(socket,
       page_title: "Chart of Accounts",
       accounts: accounts,
       companies: companies,
       selected_company_id: "",
       tree: tree,
       account_types: @account_types,
       show_form: false,
       type_counts: count_by_type(accounts)
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("show_form", _, socket), do: {:noreply, assign(socket, show_form: true)}
  def handle_event("close_form", _, socket), do: {:noreply, assign(socket, show_form: false)}

  def handle_event("save", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("delete", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("filter_company", %{"company_id" => id}, socket) do
    company_id = if id == "", do: nil, else: String.to_integer(id)
    accounts = Finance.list_accounts(company_id)

    {:noreply,
     assign(socket,
       selected_company_id: id,
       accounts: accounts,
       tree: build_tree(accounts),
       type_counts: count_by_type(accounts)
     )}
  end

  def handle_event("save", %{"account" => params}, socket) do
    params = if params["parent_id"] == "", do: Map.delete(params, "parent_id"), else: params
    params = if params["company_id"] == "", do: Map.delete(params, "company_id"), else: params

    case Finance.create_account(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket) |> put_flash(:info, "Account created") |> assign(show_form: false)}

      {:error, _cs} ->
        {:noreply, put_flash(socket, :error, "Failed to create account")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    account = Finance.get_account!(String.to_integer(id))

    case Finance.delete_account(account) do
      {:ok, _} ->
        {:noreply, reload(socket) |> put_flash(:info, "Account deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Cannot delete account (may have children or journal lines)")}
    end
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, reload(socket)}

  defp reload(socket) do
    company_id =
      case socket.assigns.selected_company_id do
        "" -> nil
        id -> String.to_integer(id)
      end

    accounts = Finance.list_accounts(company_id)

    assign(socket,
      accounts: accounts,
      tree: build_tree(accounts),
      type_counts: count_by_type(accounts)
    )
  end

  defp build_tree(accounts) do
    roots = Enum.filter(accounts, &is_nil(&1.parent_id))
    children_map = Enum.group_by(accounts, & &1.parent_id)
    Enum.flat_map(roots, &flatten_node(&1, children_map, 0))
  end

  defp flatten_node(account, children_map, depth) do
    children = Map.get(children_map, account.id, [])
    [{account, depth} | Enum.flat_map(children, &flatten_node(&1, children_map, depth + 1))]
  end

  defp count_by_type(accounts) do
    Enum.frequencies_by(accounts, & &1.account_type)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Chart of Accounts</h1>
          <p class="deck">All accounts organized by type and hierarchy</p>
        </div>
        <div>
          <%= if @can_write do %>
            <button class="btn btn-primary" phx-click="show_form">Add Account</button>
          <% end %>
        </div>
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
        <div class="metric-label">Assets</div>
        <div class="metric-value">{Map.get(@type_counts, "asset", 0)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Liabilities</div>
        <div class="metric-value">{Map.get(@type_counts, "liability", 0)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Equity</div>
        <div class="metric-value">{Map.get(@type_counts, "equity", 0)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Revenue</div>
        <div class="metric-value">{Map.get(@type_counts, "revenue", 0)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Expenses</div>
        <div class="metric-value">{Map.get(@type_counts, "expense", 0)}</div>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Accounts</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Code</th>
              <th>Name</th>
              <th>Type</th>
              <th>Currency</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for {account, depth} <- @tree do %>
              <tr>
                <td class="td-mono">{account.code}</td>
                <td>
                  <span style={"padding-left: #{depth * 1.5}rem"}>
                    <%= if depth > 0 do %>
                      <span style="color: var(--color-muted);">&mdash;</span>
                    <% end %>
                    {account.name}
                  </span>
                </td>
                <td><span class={"badge badge-#{account.account_type}"}>{account.account_type}</span></td>
                <td>{account.currency}</td>
                <td>
                  <%= if @can_write do %>
                    <button
                      phx-click="delete"
                      phx-value-id={account.id}
                      class="btn btn-danger btn-sm"
                      data-confirm="Delete this account?"
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
          <div class="empty-state">No accounts yet. Add your first account to get started.</div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click="noop">
          <div class="modal-header">
            <h3>Add Account</h3>
          </div>
          <div class="modal-body">
            <form phx-submit="save">
              <div class="form-group">
                <label class="form-label">Company</label>
                <select name="account[company_id]" class="form-select">
                  <option value="">No company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={to_string(c.id) == @selected_company_id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Code *</label>
                <input type="text" name="account[code]" class="form-input" placeholder="e.g. 1000" required />
              </div>
              <div class="form-group">
                <label class="form-label">Name *</label>
                <input type="text" name="account[name]" class="form-input" placeholder="e.g. Cash" required />
              </div>
              <div class="form-group">
                <label class="form-label">Type *</label>
                <select name="account[account_type]" class="form-select" required>
                  <option value="">Select type</option>
                  <%= for t <- @account_types do %>
                    <option value={t}>{String.capitalize(t)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Parent Account</label>
                <select name="account[parent_id]" class="form-select">
                  <option value="">None (top-level)</option>
                  <%= for a <- @accounts do %>
                    <option value={a.id}>{a.code} — {a.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Currency</label>
                <input type="text" name="account[currency]" class="form-input" value="USD" />
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="account[notes]" class="form-input"></textarea>
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
end
