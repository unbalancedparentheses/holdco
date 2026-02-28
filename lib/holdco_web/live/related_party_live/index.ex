defmodule HoldcoWeb.RelatedPartyLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.Corporate
  alias Holdco.Corporate.RelatedPartyTransaction

  @impl true
  def mount(_params, _session, socket) do
    companies = Corporate.list_companies()
    transactions = Corporate.list_related_party_transactions()
    summary = Corporate.related_party_summary()

    {:ok,
     assign(socket,
       page_title: "Related Party Transactions",
       companies: companies,
       transactions: transactions,
       summary: summary,
       selected_company_id: "",
       show_form: false,
       editing_item: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("filter_company", %{"company_id" => id}, socket) do
    company_id = if id == "", do: nil, else: String.to_integer(id)
    transactions = Corporate.list_related_party_transactions(company_id)
    summary = Corporate.related_party_summary(company_id)

    {:noreply,
     assign(socket,
       selected_company_id: id,
       transactions: transactions,
       summary: summary
     )}
  end

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: :add, editing_item: nil)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false, editing_item: nil)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    txn = Corporate.get_related_party_transaction!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: txn)}
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

  def handle_event("save", %{"related_party_transaction" => params}, socket) do
    case Corporate.create_related_party_transaction(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Transaction added")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add transaction")}
    end
  end

  def handle_event("update", %{"related_party_transaction" => params}, socket) do
    txn = socket.assigns.editing_item

    case Corporate.update_related_party_transaction(txn, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Transaction updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update transaction")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    txn = Corporate.get_related_party_transaction!(String.to_integer(id))

    case Corporate.delete_related_party_transaction(txn) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Transaction deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete transaction")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Related Party Transactions</h1>
          <p class="deck">Register and monitor related party transactions for compliance</p>
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
            <button class="btn btn-primary" phx-click="show_form">Add Transaction</button>
          <% end %>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Transactions</div>
        <div class="metric-value">{length(@transactions)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Total Amount</div>
        <div class="metric-value">${format_number(@summary.total_amount)}</div>
      </div>
    </div>

    <%= if @summary.by_relationship != [] do %>
      <div class="section">
        <div class="section-head"><h2>By Relationship Type</h2></div>
        <div class="panel">
          <table>
            <thead>
              <tr><th>Relationship</th><th class="th-num">Count</th><th class="th-num">Total Amount</th></tr>
            </thead>
            <tbody>
              <%= for row <- @summary.by_relationship do %>
                <tr>
                  <td><span class="tag tag-sky">{humanize(row.relationship)}</span></td>
                  <td class="td-num">{row.count}</td>
                  <td class="td-num">${format_number(row.total_amount || 0)}</td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    <% end %>

    <div class="section">
      <div class="section-head"><h2>All Transactions</h2></div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Related Party</th><th>Relationship</th><th>Type</th><th>Date</th>
              <th class="th-num">Amount</th><th>Arm's Length</th><th>Disclosure</th><th></th>
            </tr>
          </thead>
          <tbody>
            <%= for t <- @transactions do %>
              <tr>
                <td class="td-name">{t.related_party_name}</td>
                <td><span class="tag tag-sky">{humanize(t.relationship)}</span></td>
                <td>{humanize(t.transaction_type)}</td>
                <td class="td-mono">{t.transaction_date}</td>
                <td class="td-num">{t.currency} {t.amount}</td>
                <td>{if t.arm_length_confirmation, do: "Yes", else: "No"}</td>
                <td><span class={"tag #{disclosure_tag(t.disclosure_status)}"}>{humanize(t.disclosure_status)}</span></td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit" phx-value-id={t.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete" phx-value-id={t.id} class="btn btn-danger btn-sm" data-confirm="Delete this transaction?">Del</button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @transactions == [] do %>
          <div class="empty-state">
            <p>No related party transactions found.</p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_form">Add Your First Transaction</button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit Transaction", else: "Add Transaction"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="related_party_transaction[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={@editing_item && @editing_item.company_id == c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Related Party Name *</label>
                <input type="text" name="related_party_transaction[related_party_name]" class="form-input" value={if @editing_item, do: @editing_item.related_party_name, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Relationship *</label>
                <select name="related_party_transaction[relationship]" class="form-select" required>
                  <option value="">Select</option>
                  <%= for r <- RelatedPartyTransaction.relationships() do %>
                    <option value={r} selected={@editing_item && @editing_item.relationship == r}>{humanize(r)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Transaction Type *</label>
                <select name="related_party_transaction[transaction_type]" class="form-select" required>
                  <option value="">Select</option>
                  <%= for t <- RelatedPartyTransaction.transaction_types() do %>
                    <option value={t} selected={@editing_item && @editing_item.transaction_type == t}>{humanize(t)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Transaction Date *</label>
                <input type="date" name="related_party_transaction[transaction_date]" class="form-input" value={if @editing_item, do: @editing_item.transaction_date, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Amount *</label>
                <input type="number" name="related_party_transaction[amount]" class="form-input" step="any" value={if @editing_item, do: @editing_item.amount, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Currency</label>
                <input type="text" name="related_party_transaction[currency]" class="form-input" value={if @editing_item, do: @editing_item.currency, else: "USD"} />
              </div>
              <div class="form-group">
                <label class="form-label">Terms Description</label>
                <textarea name="related_party_transaction[terms_description]" class="form-input">{if @editing_item, do: @editing_item.terms_description, else: ""}</textarea>
              </div>
              <div class="form-group">
                <label class="form-label">Arm's Length Confirmation</label>
                <select name="related_party_transaction[arm_length_confirmation]" class="form-select">
                  <option value="false" selected={!(@editing_item && @editing_item.arm_length_confirmation)}>No</option>
                  <option value="true" selected={@editing_item && @editing_item.arm_length_confirmation}>Yes</option>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Board Approval Date</label>
                <input type="date" name="related_party_transaction[board_approval_date]" class="form-input" value={if @editing_item, do: @editing_item.board_approval_date, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Board Approval Reference</label>
                <input type="text" name="related_party_transaction[board_approval_reference]" class="form-input" value={if @editing_item, do: @editing_item.board_approval_reference, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Disclosure Status</label>
                <select name="related_party_transaction[disclosure_status]" class="form-select">
                  <%= for s <- RelatedPartyTransaction.disclosure_statuses() do %>
                    <option value={s} selected={@editing_item && @editing_item.disclosure_status == s}>{humanize(s)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="related_party_transaction[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">{if @show_form == :edit, do: "Update", else: "Add Transaction"}</button>
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
    company_id = case socket.assigns.selected_company_id do
      "" -> nil
      id -> String.to_integer(id)
    end

    transactions = Corporate.list_related_party_transactions(company_id)
    summary = Corporate.related_party_summary(company_id)
    assign(socket, transactions: transactions, summary: summary)
  end

  defp humanize(str), do: str |> String.replace("_", " ") |> String.split(" ") |> Enum.map(&String.capitalize/1) |> Enum.join(" ")

  defp disclosure_tag("disclosed"), do: "tag-jade"
  defp disclosure_tag("pending"), do: "tag-lemon"
  defp disclosure_tag("not_required"), do: ""
  defp disclosure_tag(_), do: ""

  defp format_number(%Decimal{} = n), do: n |> Decimal.round(2) |> Decimal.to_string()
  defp format_number(n) when is_number(n), do: to_string(n)
  defp format_number(_), do: "0"
end
