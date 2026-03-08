defmodule HoldcoWeb.RecurringTransactionsLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Finance, Corporate}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Finance.subscribe()

    companies = Corporate.list_companies()
    transactions = Finance.list_recurring_transactions()
    accounts = Finance.list_accounts()

    {:ok,
     assign(socket,
       page_title: "Recurring Transactions",
       companies: companies,
       transactions: transactions,
       accounts: accounts,
       selected_company_id: "",
       show_form: false,
       editing_item: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("filter_company", %{"company_id" => id}, socket) do
    company_id = if id == "", do: nil, else: String.to_integer(id)
    transactions = Finance.list_recurring_transactions(company_id)
    accounts = Finance.list_accounts(company_id)
    {:noreply, assign(socket, selected_company_id: id, transactions: transactions, accounts: accounts)}
  end

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: :add, editing_item: nil)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false, editing_item: nil)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    rt = Finance.get_recurring_transaction!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: rt)}
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

  def handle_event("save", %{"rt" => params}, socket) do
    case Finance.create_recurring_transaction(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Recurring transaction created")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create recurring transaction")}
    end
  end

  def handle_event("update", %{"rt" => params}, socket) do
    rt = socket.assigns.editing_item

    case Finance.update_recurring_transaction(rt, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Recurring transaction updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update recurring transaction")}
    end
  end

  def handle_event("toggle_active", %{"id" => id}, socket) do
    rt = Finance.get_recurring_transaction!(String.to_integer(id))

    case Finance.update_recurring_transaction(rt, %{is_active: !rt.is_active}) do
      {:ok, _} ->
        status = if rt.is_active, do: "deactivated", else: "activated"
        {:noreply, reload(socket) |> put_flash(:info, "Recurring transaction #{status}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to toggle status")}
    end
  end

  def handle_event("run_all_due", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("run_all_due", _params, socket) do
    due = Finance.list_due_recurring_transactions()

    results =
      Enum.map(due, fn rt ->
        if rt.debit_account_id && rt.credit_account_id do
          today = Date.utc_today() |> Date.to_iso8601()

          entry_attrs = %{
            "company_id" => rt.company_id,
            "date" => today,
            "description" => "Recurring: #{rt.description}",
            "reference" => "RT-#{rt.id}"
          }

          lines_attrs = [
            %{"account_id" => rt.debit_account_id, "debit" => rt.amount, "credit" => Decimal.new(0)},
            %{"account_id" => rt.credit_account_id, "debit" => Decimal.new(0), "credit" => rt.amount}
          ]

          case Finance.create_journal_entry_with_lines(entry_attrs, lines_attrs) do
            {:ok, _} ->
              Finance.advance_next_run_date(rt)
              :ok

            {:error, _} ->
              Finance.advance_next_run_date(rt)
              :error
          end
        else
          Finance.advance_next_run_date(rt)
          :skipped
        end
      end)

    posted = Enum.count(results, &(&1 == :ok))
    skipped = Enum.count(results, &(&1 == :skipped))

    msg =
      cond do
        posted > 0 and skipped > 0 -> "Posted #{posted} entries, skipped #{skipped} (no accounts)"
        posted > 0 -> "Posted #{posted} journal entries"
        skipped > 0 -> "Skipped #{skipped} (no accounts configured)"
        true -> "No recurring transactions were due"
      end

    {:noreply, reload(socket) |> put_flash(:info, msg)}
  end

  def handle_event("run_now", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("run_now", %{"id" => id}, socket) do
    rt = Finance.get_recurring_transaction!(String.to_integer(id))
    today = Date.utc_today() |> Date.to_iso8601()

    entry_attrs = %{
      "company_id" => rt.company_id,
      "date" => today,
      "description" => "Recurring: #{rt.description}",
      "reference" => "RT-#{rt.id}"
    }

    if rt.debit_account_id && rt.credit_account_id do
      lines_attrs = [
        %{
          "account_id" => rt.debit_account_id,
          "debit" => rt.amount,
          "credit" => Decimal.new(0)
        },
        %{
          "account_id" => rt.credit_account_id,
          "debit" => Decimal.new(0),
          "credit" => rt.amount
        }
      ]

      case Finance.create_journal_entry_with_lines(entry_attrs, lines_attrs) do
        {:ok, _entry} ->
          Finance.advance_next_run_date(rt)

          {:noreply,
           reload(socket)
           |> put_flash(:info, "Transaction generated and next run date advanced")}

        {:error, :period_locked} ->
          {:noreply, put_flash(socket, :error, "Cannot create entry: period is locked")}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "Failed to generate transaction")}
      end
    else
      {:noreply,
       put_flash(socket, :error, "Cannot run: debit and credit accounts must be configured")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    rt = Finance.get_recurring_transaction!(String.to_integer(id))

    case Finance.delete_recurring_transaction(rt) do
      {:ok, _} ->
        {:noreply, reload(socket) |> put_flash(:info, "Recurring transaction deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete recurring transaction")}
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

    transactions = Finance.list_recurring_transactions(company_id)
    accounts = Finance.list_accounts(company_id)
    assign(socket, transactions: transactions, accounts: accounts)
  end

  defp frequency_label("daily"), do: "Daily"
  defp frequency_label("weekly"), do: "Weekly"
  defp frequency_label("monthly"), do: "Monthly"
  defp frequency_label("quarterly"), do: "Quarterly"
  defp frequency_label("yearly"), do: "Yearly"
  defp frequency_label(other), do: other || "Unknown"

  defp type_tag("expense"), do: "tag-crimson"
  defp type_tag("revenue"), do: "tag-jade"
  defp type_tag("transfer"), do: "tag-lemon"
  defp type_tag(_), do: "tag-ink"

  defp monthly_multiplier("daily"), do: Decimal.new("30")
  defp monthly_multiplier("weekly"), do: Decimal.from_float(4.33)
  defp monthly_multiplier("monthly"), do: Decimal.new("1")
  defp monthly_multiplier("quarterly"), do: Decimal.from_float(0.333)
  defp monthly_multiplier("yearly"), do: Decimal.from_float(0.0833)
  defp monthly_multiplier(_), do: Decimal.new("1")

  defp total_monthly_volume(transactions) do
    transactions
    |> Enum.filter(& &1.is_active)
    |> Enum.reduce(Decimal.new(0), fn rt, acc ->
      amt = rt.amount || Decimal.new(0)
      mult = monthly_multiplier(rt.frequency)
      Decimal.add(acc, Decimal.mult(amt, mult))
    end)
    |> Decimal.round(2)
  end

  defp overdue_count(transactions) do
    today = Date.utc_today()

    Enum.count(transactions, fn rt ->
      rt.is_active && rt.next_run_date &&
        case parse_date(rt.next_run_date) do
          {:ok, d} -> Date.compare(d, today) == :lt
          _ -> false
        end
    end)
  end

  defp due_soon_count(transactions) do
    today = Date.utc_today()
    seven_days = Date.add(today, 7)

    Enum.count(transactions, fn rt ->
      rt.is_active && rt.next_run_date &&
        case parse_date(rt.next_run_date) do
          {:ok, d} -> Date.compare(d, today) in [:gt, :eq] and Date.compare(d, seven_days) in [:lt, :eq]
          _ -> false
        end
    end)
  end

  defp parse_date(%Date{} = d), do: {:ok, d}
  defp parse_date(str) when is_binary(str), do: Date.from_iso8601(str)
  defp parse_date(_), do: :error

  defp rt_row_style(rt) do
    today = Date.utc_today()

    if rt.is_active && rt.next_run_date do
      case parse_date(rt.next_run_date) do
        {:ok, d} ->
          if Date.compare(d, today) == :lt, do: "background: rgba(198, 40, 40, 0.06);", else: ""

        _ ->
          ""
      end
    else
      ""
    end
  end

  defp format_number(%Decimal{} = n),
    do: n |> Decimal.round(2) |> Decimal.to_string() |> add_commas()

  defp format_number(n) when is_float(n),
    do: :erlang.float_to_binary(n, decimals: 2) |> add_commas()

  defp format_number(n) when is_integer(n), do: Integer.to_string(n) |> add_commas()
  defp format_number(_), do: "0.00"

  defp add_commas(str) do
    case String.split(str, ".") do
      [int_part, dec_part] ->
        formatted_int =
          int_part
          |> String.reverse()
          |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
          |> String.reverse()

        "#{formatted_int}.#{dec_part}"

      [int_part] ->
        int_part
        |> String.reverse()
        |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
        |> String.reverse()
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Recurring Transactions</h1>
          <p class="deck">Automate repetitive journal entries on a set schedule</p>
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
            <button class="btn btn-secondary" phx-click="run_all_due" data-confirm="Post journal entries for all due recurring transactions?">Run All Due</button>
            <button class="btn btn-primary" phx-click="show_form">New Recurring Transaction</button>
          <% end %>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total</div>
        <div class="metric-value">{length(@transactions)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Active</div>
        <div class="metric-value">{Enum.count(@transactions, & &1.is_active)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Inactive</div>
        <div class="metric-value">{Enum.count(@transactions, &(!&1.is_active))}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Total Monthly Volume</div>
        <div class="metric-value">${format_number(total_monthly_volume(@transactions))}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Overdue</div>
        <div class="metric-value" style="color: var(--color-crimson, #c0392b);">{overdue_count(@transactions)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Due Soon (7d)</div>
        <div class="metric-value">{due_soon_count(@transactions)}</div>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>All Recurring Transactions</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Description</th>
              <th>Company</th>
              <th>Type</th>
              <th class="th-num">Amount</th>
              <th>Frequency</th>
              <th class="td-mono">Next Run</th>
              <th class="td-mono">Last Run</th>
              <th>Debit Account</th>
              <th>Credit Account</th>
              <th>Active</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for rt <- @transactions do %>
              <tr style={rt_row_style(rt)}>
                <td class="td-name">{rt.description}</td>
                <td>
                  <%= if rt.company do %>
                    <.link navigate={~p"/companies/#{rt.company.id}"} class="td-link">{rt.company.name}</.link>
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td>
                  <%= if rt.transaction_type do %>
                    <span class={"tag #{type_tag(rt.transaction_type)}"}>{rt.transaction_type}</span>
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td class="td-num">{format_number(rt.amount)} {rt.currency}</td>
                <td>{frequency_label(rt.frequency)}</td>
                <td class="td-mono">{rt.next_run_date || "---"}</td>
                <td class="td-mono">{rt.last_run_date || "---"}</td>
                <td style="font-size: 0.85rem;">
                  {if rt.debit_account, do: "#{rt.debit_account.code} - #{rt.debit_account.name}", else: "---"}
                </td>
                <td style="font-size: 0.85rem;">
                  {if rt.credit_account, do: "#{rt.credit_account.code} - #{rt.credit_account.name}", else: "---"}
                </td>
                <td>
                  <button
                    phx-click="toggle_active"
                    phx-value-id={rt.id}
                    class={"tag #{if rt.is_active, do: "tag-jade", else: "tag-ruby"}"}
                    style="background: none; border: none; cursor: pointer; font: inherit;"
                  >
                    {if rt.is_active, do: "Active", else: "Inactive"}
                  </button>
                </td>
                <td>
                  <div style="display: flex; gap: 0.25rem;">
                    <%= if @can_write && rt.is_active do %>
                      <button
                        phx-click="run_now"
                        phx-value-id={rt.id}
                        class="btn btn-secondary btn-sm"
                        data-confirm="Generate a journal entry from this recurring transaction now?"
                      >
                        Run Now
                      </button>
                    <% end %>
                    <%= if @can_write do %>
                      <button
                        phx-click="edit"
                        phx-value-id={rt.id}
                        class="btn btn-secondary btn-sm"
                      >
                        Edit
                      </button>
                      <button
                        phx-click="delete"
                        phx-value-id={rt.id}
                        class="btn btn-danger btn-sm"
                        data-confirm="Delete this recurring transaction?"
                      >
                        Del
                      </button>
                    <% end %>
                  </div>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @transactions == [] do %>
          <div class="empty-state">
            <p>No recurring transactions defined.</p>
            <p style="color: var(--muted); font-size: 0.9rem;">
              Set up recurring journal entries for rent, subscriptions, payroll, and other regular transactions.
            </p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_form">Create Your First Recurring Transaction</button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop" style="max-width: 650px;">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit Recurring Transaction", else: "New Recurring Transaction"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="rt[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={@editing_item && @editing_item.company_id == c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Description *</label>
                <input
                  type="text"
                  name="rt[description]"
                  class="form-input"
                  value={if @editing_item, do: @editing_item.description, else: ""}
                  required
                />
              </div>
              <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 0.75rem;">
                <div class="form-group">
                  <label class="form-label">Amount *</label>
                  <input
                    type="number"
                    name="rt[amount]"
                    class="form-input"
                    step="any"
                    value={if @editing_item, do: @editing_item.amount, else: ""}
                    required
                  />
                </div>
                <div class="form-group">
                  <label class="form-label">Currency</label>
                  <select name="rt[currency]" class="form-select">
                    <%= for cur <- ~w(USD EUR GBP CHF JPY AUD CAD) do %>
                      <option
                        value={cur}
                        selected={(@editing_item && @editing_item.currency == cur) || (!@editing_item && cur == "USD")}
                      >
                        {cur}
                      </option>
                    <% end %>
                  </select>
                </div>
              </div>
              <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 0.75rem;">
                <div class="form-group">
                  <label class="form-label">Frequency *</label>
                  <select name="rt[frequency]" class="form-select" required>
                    <%= for f <- ~w(daily weekly monthly quarterly yearly) do %>
                      <option value={f} selected={@editing_item && @editing_item.frequency == f}>{frequency_label(f)}</option>
                    <% end %>
                  </select>
                </div>
                <div class="form-group">
                  <label class="form-label">Transaction Type</label>
                  <select name="rt[transaction_type]" class="form-select">
                    <option value="">Select type</option>
                    <%= for t <- ~w(expense revenue transfer) do %>
                      <option value={t} selected={@editing_item && @editing_item.transaction_type == t}>{t}</option>
                    <% end %>
                  </select>
                </div>
              </div>
              <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 0.75rem;">
                <div class="form-group">
                  <label class="form-label">Start Date *</label>
                  <input
                    type="date"
                    name="rt[start_date]"
                    class="form-input"
                    value={if @editing_item, do: @editing_item.start_date, else: ""}
                    required
                  />
                </div>
                <div class="form-group">
                  <label class="form-label">End Date</label>
                  <input
                    type="date"
                    name="rt[end_date]"
                    class="form-input"
                    value={if @editing_item, do: @editing_item.end_date, else: ""}
                  />
                </div>
              </div>
              <div class="form-group">
                <label class="form-label">Next Run Date *</label>
                <input
                  type="date"
                  name="rt[next_run_date]"
                  class="form-input"
                  value={if @editing_item, do: @editing_item.next_run_date, else: ""}
                  required
                />
              </div>
              <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 0.75rem;">
                <div class="form-group">
                  <label class="form-label">Debit Account</label>
                  <select name="rt[debit_account_id]" class="form-select">
                    <option value="">Select account</option>
                    <%= for a <- @accounts do %>
                      <option value={a.id} selected={@editing_item && @editing_item.debit_account_id == a.id}>
                        {a.code} - {a.name}
                      </option>
                    <% end %>
                  </select>
                </div>
                <div class="form-group">
                  <label class="form-label">Credit Account</label>
                  <select name="rt[credit_account_id]" class="form-select">
                    <option value="">Select account</option>
                    <%= for a <- @accounts do %>
                      <option value={a.id} selected={@editing_item && @editing_item.credit_account_id == a.id}>
                        {a.code} - {a.name}
                      </option>
                    <% end %>
                  </select>
                </div>
              </div>
              <div class="form-group">
                <label class="form-label">Counterparty</label>
                <input
                  type="text"
                  name="rt[counterparty]"
                  class="form-input"
                  value={if @editing_item, do: @editing_item.counterparty, else: ""}
                />
              </div>
              <div class="form-group">
                <label class="form-label">
                  <input
                    type="checkbox"
                    name="rt[auto_post]"
                    value="true"
                    checked={@editing_item && @editing_item.auto_post}
                  />
                  Auto-post journal entries
                </label>
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="rt[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">
                  {if @show_form == :edit, do: "Update", else: "Create"}
                </button>
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
