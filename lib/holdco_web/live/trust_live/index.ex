defmodule HoldcoWeb.TrustLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.Finance
  alias Holdco.Corporate
  alias Holdco.Finance.TrustAccount
  alias Holdco.Finance.TrustTransaction

  @impl true
  def mount(_params, _session, socket) do
    companies = Corporate.list_companies()
    accounts = Finance.list_trust_accounts()

    {:ok,
     assign(socket,
       page_title: "Trust Accounting",
       companies: companies,
       accounts: accounts,
       selected_account: nil,
       transactions: [],
       balance: Decimal.new(0),
       income_summary: [],
       show_form: false,
       show_tx_form: false,
       editing_item: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: :add, editing_item: nil)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false, show_tx_form: false, editing_item: nil)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    account = Finance.get_trust_account!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: account)}
  end

  def handle_event("view_transactions", %{"id" => id}, socket) do
    account_id = String.to_integer(id)
    account = Finance.get_trust_account!(account_id)
    transactions = Finance.list_trust_transactions(account_id)
    balance = Finance.trust_balance(account_id)
    income_summary = Finance.trust_income_summary(account_id)

    {:noreply,
     assign(socket,
       selected_account: account,
       transactions: transactions,
       balance: balance,
       income_summary: income_summary
     )}
  end

  def handle_event("back_to_list", _, socket) do
    {:noreply, assign(socket, selected_account: nil, transactions: [], balance: Decimal.new(0), income_summary: [])}
  end

  def handle_event("show_tx_form", _, socket) do
    {:noreply, assign(socket, show_tx_form: true)}
  end

  def handle_event("save", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("update", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("delete", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("save_tx", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("save", %{"trust_account" => params}, socket) do
    case Finance.create_trust_account(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Trust account created")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create trust account")}
    end
  end

  def handle_event("update", %{"trust_account" => params}, socket) do
    account = socket.assigns.editing_item

    case Finance.update_trust_account(account, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Trust account updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update trust account")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    account = Finance.get_trust_account!(String.to_integer(id))

    case Finance.delete_trust_account(account) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Trust account deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete trust account")}
    end
  end

  def handle_event("save_tx", %{"trust_transaction" => params}, socket) do
    params = Map.put(params, "trust_account_id", socket.assigns.selected_account.id)

    case Finance.create_trust_transaction(params) do
      {:ok, _} ->
        account_id = socket.assigns.selected_account.id
        transactions = Finance.list_trust_transactions(account_id)
        balance = Finance.trust_balance(account_id)
        income_summary = Finance.trust_income_summary(account_id)

        {:noreply,
         socket
         |> assign(transactions: transactions, balance: balance, income_summary: income_summary, show_tx_form: false)
         |> put_flash(:info, "Transaction recorded")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to record transaction")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Trust Accounting</h1>
          <p class="deck">Manage trust accounts, transactions, and distributions</p>
        </div>
        <%= if @can_write && !@selected_account do %>
          <button class="btn btn-primary" phx-click="show_form">Add Trust Account</button>
        <% end %>
      </div>
      <hr class="page-title-rule" />
    </div>

    <%= if @selected_account do %>
      <div style="margin-bottom: 1rem;">
        <button class="btn btn-secondary" phx-click="back_to_list">Back to List</button>
      </div>

      <div class="metrics-strip">
        <div class="metric-cell">
          <div class="metric-label">Trust</div>
          <div class="metric-value">{@selected_account.trust_name}</div>
        </div>
        <div class="metric-cell">
          <div class="metric-label">Balance</div>
          <div class="metric-value">{Decimal.to_string(@balance)}</div>
        </div>
        <div class="metric-cell">
          <div class="metric-label">Transactions</div>
          <div class="metric-value">{length(@transactions)}</div>
        </div>
      </div>

      <%= if @income_summary != [] do %>
        <div class="section">
          <div class="section-head"><h2>Income Summary</h2></div>
          <div class="panel">
            <table>
              <thead><tr><th>Type</th><th class="th-num">Total</th></tr></thead>
              <tbody>
                <%= for row <- @income_summary do %>
                  <tr>
                    <td>{humanize(row.transaction_type)}</td>
                    <td class="td-num">{Decimal.to_string(row.total)}</td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
      <% end %>

      <div class="section">
        <div class="section-head">
          <h2>Transactions</h2>
          <%= if @can_write do %>
            <button class="btn btn-primary btn-sm" phx-click="show_tx_form">Add Transaction</button>
          <% end %>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr><th>Date</th><th>Type</th><th>Category</th><th class="th-num">Amount</th><th>Description</th><th>Approved By</th></tr>
            </thead>
            <tbody>
              <%= for tx <- @transactions do %>
                <tr>
                  <td class="td-mono">{tx.transaction_date}</td>
                  <td><span class={"tag #{tx_type_tag(tx.transaction_type)}"}>{humanize(tx.transaction_type)}</span></td>
                  <td>{humanize(tx.category || "---")}</td>
                  <td class="td-num">{Decimal.to_string(tx.amount)}</td>
                  <td>{tx.description || "---"}</td>
                  <td>{tx.approved_by || "---"}</td>
                </tr>
              <% end %>
            </tbody>
          </table>
          <%= if @transactions == [] do %>
            <div class="empty-state"><p>No transactions recorded yet.</p></div>
          <% end %>
        </div>
      </div>

      <%= if @show_tx_form do %>
        <div class="dialog-overlay" phx-click="close_form">
          <div class="dialog-panel" phx-click="noop">
            <div class="dialog-header"><h3>Add Transaction</h3></div>
            <div class="dialog-body">
              <form phx-submit="save_tx">
                <div class="form-group">
                  <label class="form-label">Type *</label>
                  <select name="trust_transaction[transaction_type]" class="form-select" required>
                    <%= for t <- TrustTransaction.transaction_types() do %>
                      <option value={t}>{humanize(t)}</option>
                    <% end %>
                  </select>
                </div>
                <div class="form-group">
                  <label class="form-label">Amount *</label>
                  <input type="number" name="trust_transaction[amount]" class="form-input" step="0.01" required />
                </div>
                <div class="form-group">
                  <label class="form-label">Date *</label>
                  <input type="date" name="trust_transaction[transaction_date]" class="form-input" required />
                </div>
                <div class="form-group">
                  <label class="form-label">Category</label>
                  <select name="trust_transaction[category]" class="form-select">
                    <%= for c <- TrustTransaction.categories() do %>
                      <option value={c}>{humanize(c)}</option>
                    <% end %>
                  </select>
                </div>
                <div class="form-group">
                  <label class="form-label">Description</label>
                  <input type="text" name="trust_transaction[description]" class="form-input" />
                </div>
                <div class="form-group">
                  <label class="form-label">Counterparty</label>
                  <input type="text" name="trust_transaction[counterparty]" class="form-input" />
                </div>
                <div class="form-group">
                  <label class="form-label">Approved By</label>
                  <input type="text" name="trust_transaction[approved_by]" class="form-input" />
                </div>
                <div class="form-group">
                  <label class="form-label">Notes</label>
                  <textarea name="trust_transaction[notes]" class="form-input"></textarea>
                </div>
                <div class="form-actions">
                  <button type="submit" class="btn btn-primary">Record Transaction</button>
                  <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
                </div>
              </form>
            </div>
          </div>
        </div>
      <% end %>
    <% else %>
      <div class="metrics-strip">
        <div class="metric-cell">
          <div class="metric-label">Total Accounts</div>
          <div class="metric-value">{length(@accounts)}</div>
        </div>
        <div class="metric-cell">
          <div class="metric-label">Active</div>
          <div class="metric-value">{Enum.count(@accounts, &(&1.status == "active"))}</div>
        </div>
        <div class="metric-cell">
          <div class="metric-label">Pending</div>
          <div class="metric-value">{Enum.count(@accounts, &(&1.status == "pending"))}</div>
        </div>
      </div>

      <div class="section">
        <div class="section-head"><h2>All Trust Accounts</h2></div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Trust Name</th><th>Type</th><th>Trustee</th><th>Grantor</th>
                <th>Jurisdiction</th><th>Status</th><th></th>
              </tr>
            </thead>
            <tbody>
              <%= for a <- @accounts do %>
                <tr>
                  <td class="td-name">
                    <a href="#" phx-click="view_transactions" phx-value-id={a.id} style="text-decoration: underline;">{a.trust_name}</a>
                  </td>
                  <td><span class={"tag #{type_tag(a.trust_type)}"}>{humanize(a.trust_type)}</span></td>
                  <td>{a.trustee_name}</td>
                  <td>{a.grantor_name || "---"}</td>
                  <td>{a.jurisdiction || "---"}</td>
                  <td><span class={"tag #{status_tag(a.status)}"}>{humanize(a.status)}</span></td>
                  <td>
                    <%= if @can_write do %>
                      <div style="display: flex; gap: 0.25rem;">
                        <button phx-click="edit" phx-value-id={a.id} class="btn btn-secondary btn-sm">Edit</button>
                        <button phx-click="delete" phx-value-id={a.id} class="btn btn-danger btn-sm" data-confirm="Delete this trust account?">Del</button>
                      </div>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
          <%= if @accounts == [] do %>
            <div class="empty-state">
              <p>No trust accounts found.</p>
              <%= if @can_write do %>
                <button class="btn btn-primary" phx-click="show_form">Add Your First Trust Account</button>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    <% end %>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit Trust Account", else: "Add Trust Account"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="trust_account[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={@editing_item && @editing_item.company_id == c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Trust Name *</label>
                <input type="text" name="trust_account[trust_name]" class="form-input" value={if @editing_item, do: @editing_item.trust_name, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Trust Type *</label>
                <select name="trust_account[trust_type]" class="form-select" required>
                  <%= for t <- TrustAccount.trust_types() do %>
                    <option value={t} selected={@editing_item && @editing_item.trust_type == t}>{humanize(t)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Trustee Name *</label>
                <input type="text" name="trust_account[trustee_name]" class="form-input" value={if @editing_item, do: @editing_item.trustee_name, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Grantor Name</label>
                <input type="text" name="trust_account[grantor_name]" class="form-input" value={if @editing_item, do: @editing_item.grantor_name, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Jurisdiction</label>
                <input type="text" name="trust_account[jurisdiction]" class="form-input" value={if @editing_item, do: @editing_item.jurisdiction, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Date Established</label>
                <input type="date" name="trust_account[date_established]" class="form-input" value={if @editing_item, do: @editing_item.date_established, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Corpus Value</label>
                <input type="number" name="trust_account[corpus_value]" class="form-input" step="0.01" value={if @editing_item && @editing_item.corpus_value, do: Decimal.to_string(@editing_item.corpus_value), else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Distribution Schedule</label>
                <select name="trust_account[distribution_schedule]" class="form-select">
                  <%= for s <- TrustAccount.distribution_schedules() do %>
                    <option value={s} selected={@editing_item && @editing_item.distribution_schedule == s}>{humanize(s)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Status</label>
                <select name="trust_account[status]" class="form-select">
                  <%= for s <- TrustAccount.statuses() do %>
                    <option value={s} selected={@editing_item && @editing_item.status == s}>{humanize(s)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Tax ID</label>
                <input type="text" name="trust_account[tax_id]" class="form-input" value={if @editing_item, do: @editing_item.tax_id, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="trust_account[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">{if @show_form == :edit, do: "Update", else: "Add Trust Account"}</button>
                <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp reload(socket) do
    assign(socket, accounts: Finance.list_trust_accounts())
  end

  defp humanize(str), do: str |> String.replace("_", " ") |> String.split(" ") |> Enum.map(&String.capitalize/1) |> Enum.join(" ")

  defp type_tag("revocable"), do: "tag-sky"
  defp type_tag("irrevocable"), do: "tag-jade"
  defp type_tag("charitable"), do: "tag-lemon"
  defp type_tag(_), do: ""

  defp status_tag("active"), do: "tag-jade"
  defp status_tag("pending"), do: "tag-lemon"
  defp status_tag("suspended"), do: "tag-lemon"
  defp status_tag("terminated"), do: ""
  defp status_tag(_), do: ""

  defp tx_type_tag("contribution"), do: "tag-jade"
  defp tx_type_tag("distribution"), do: "tag-sky"
  defp tx_type_tag("income"), do: "tag-jade"
  defp tx_type_tag("expense"), do: "tag-lemon"
  defp tx_type_tag("fee"), do: "tag-lemon"
  defp tx_type_tag("tax_payment"), do: ""
  defp tx_type_tag(_), do: ""
end
