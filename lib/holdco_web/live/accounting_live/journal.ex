defmodule HoldcoWeb.AccountingLive.Journal do
  use HoldcoWeb, :live_view

  alias Holdco.{Finance, Corporate}
  alias Holdco.Money

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Finance.subscribe()

    companies = Corporate.list_companies()
    entries = Finance.list_journal_entries()
    accounts = Finance.list_accounts()

    {:ok,
     assign(socket,
       page_title: "Journal Entries",
       entries: entries,
       accounts: accounts,
       companies: companies,
       selected_company_id: "",
       expanded: MapSet.new(),
       show_form: false,
       line_count: 2,
       form_error: nil,
       filter_account_id: nil,
       filter_account_name: nil
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    account_id = params["account_id"]

    if account_id do
      account_id = String.to_integer(account_id)
      entries = filter_entries_by_account(socket.assigns.entries, account_id)
      account = Enum.find(socket.assigns.accounts, &(&1.id == account_id))
      account_name = if account, do: account.name, else: "Account ##{account_id}"

      {:noreply,
       assign(socket,
         entries: entries,
         filter_account_id: account_id,
         filter_account_name: account_name
       )}
    else
      {:noreply, assign(socket, filter_account_id: nil, filter_account_name: nil)}
    end
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("show_form", _, socket),
    do: {:noreply, assign(socket, show_form: true, line_count: 2, form_error: nil)}

  def handle_event("close_form", _, socket),
    do: {:noreply, assign(socket, show_form: false, form_error: nil)}

  def handle_event("add_line", _, socket),
    do: {:noreply, assign(socket, line_count: socket.assigns.line_count + 1)}

  def handle_event("toggle_entry", %{"id" => id}, socket) do
    id = String.to_integer(id)
    expanded = socket.assigns.expanded

    expanded =
      if MapSet.member?(expanded, id),
        do: MapSet.delete(expanded, id),
        else: MapSet.put(expanded, id)

    {:noreply, assign(socket, expanded: expanded)}
  end

  def handle_event("filter_company", %{"company_id" => id}, socket) do
    company_id = if id == "", do: nil, else: String.to_integer(id)
    entries = Finance.list_journal_entries(company_id)
    accounts = Finance.list_accounts(company_id)

    {:noreply, assign(socket, selected_company_id: id, entries: entries, accounts: accounts)}
  end

  def handle_event("save", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("delete", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("save", %{"entry" => entry_params, "lines" => lines_params}, socket) do
    lines =
      lines_params
      |> Enum.sort_by(fn {k, _v} -> String.to_integer(k) end)
      |> Enum.map(fn {_k, v} -> v end)
      |> Enum.reject(fn l -> (l["account_id"] || "") == "" end)

    total_debit = lines |> Enum.map(&parse_decimal(&1["debit"])) |> Money.sum()
    total_credit = lines |> Enum.map(&parse_decimal(&1["credit"])) |> Money.sum()

    cond do
      length(lines) < 2 ->
        {:noreply, assign(socket, form_error: "At least 2 lines required")}

      Money.gt?(Money.abs(Money.sub(total_debit, total_credit)), "0.01") ->
        {:noreply,
         assign(socket,
           form_error:
             "Debits ($#{format_number(total_debit)}) must equal credits ($#{format_number(total_credit)})"
         )}

      true ->
        entry_params =
          if entry_params["company_id"] == "",
            do: Map.delete(entry_params, "company_id"),
            else: entry_params

        line_attrs =
          Enum.map(lines, fn l ->
            %{
              "account_id" => l["account_id"],
              "debit" => parse_decimal(l["debit"]),
              "credit" => parse_decimal(l["credit"]),
              "notes" => l["notes"]
            }
          end)

        case Finance.create_journal_entry_with_lines(entry_params, line_attrs) do
          {:ok, _entry} ->
            {:noreply,
             reload(socket)
             |> put_flash(:info, "Journal entry created")
             |> assign(show_form: false, form_error: nil)}

          {:error, :unbalanced} ->
            {:noreply, assign(socket, form_error: "Debits must equal credits")}

          {:error, :insufficient_lines} ->
            {:noreply, assign(socket, form_error: "At least 2 lines required")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to create journal entry")}
        end
    end
  end

  def handle_event("save", %{"entry" => entry_params}, socket) do
    # No lines submitted
    handle_event("save", %{"entry" => entry_params, "lines" => %{}}, socket)
  end

  def handle_event("delete", %{"id" => id}, socket) do
    entry = Finance.get_journal_entry!(String.to_integer(id))

    Enum.each(entry.lines, fn line ->
      Finance.delete_journal_line(line)
    end)

    Finance.delete_journal_entry(entry)
    {:noreply, reload(socket) |> put_flash(:info, "Journal entry deleted")}
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, reload(socket)}

  defp reload(socket) do
    company_id =
      case socket.assigns.selected_company_id do
        "" -> nil
        id -> String.to_integer(id)
      end

    entries = Finance.list_journal_entries(company_id)
    accounts = Finance.list_accounts(company_id)

    entries =
      if socket.assigns[:filter_account_id] do
        filter_entries_by_account(entries, socket.assigns.filter_account_id)
      else
        entries
      end

    assign(socket, entries: entries, accounts: accounts)
  end

  defp filter_entries_by_account(entries, account_id) do
    Enum.filter(entries, fn entry ->
      Enum.any?(entry.lines || [], fn line -> line.account_id == account_id end)
    end)
  end

  defp parse_decimal(nil), do: Decimal.new(0)
  defp parse_decimal(""), do: Decimal.new(0)
  defp parse_decimal(val), do: Money.to_decimal(val)

  defp entry_totals(entry) do
    lines = entry.lines || []
    total_debit = Enum.reduce(lines, Decimal.new(0), fn line, acc -> Money.add(acc, line.debit) end)
    total_credit = Enum.reduce(lines, Decimal.new(0), fn line, acc -> Money.add(acc, line.credit) end)
    {total_debit, total_credit}
  end

  defp format_number(%Decimal{} = n),
    do: :erlang.float_to_binary(Money.to_float(n), decimals: 2) |> add_commas()

  defp format_number(n) when is_float(n),
    do: :erlang.float_to_binary(n, decimals: 2) |> add_commas()

  defp format_number(n) when is_integer(n), do: Integer.to_string(n) |> add_commas()
  defp format_number(_), do: "0.00"

  defp add_commas(str) do
    case String.split(str, ".") do
      [int, dec] ->
        int |> String.reverse() |> String.replace(~r/(\d{3})(?=\d)/, "\\1,") |> String.reverse()
        |> Kernel.<>("." <> dec)

      [int] ->
        int |> String.reverse() |> String.replace(~r/(\d{3})(?=\d)/, "\\1,") |> String.reverse()
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Journal Entries</h1>
          <p class="deck">Double-entry bookkeeping records</p>
        </div>
        <div style="display: flex; gap: 0.5rem; align-items: center;">
          <a href={~p"/export/journal-entries.csv"} class="btn btn-secondary">Export CSV</a>
          <%= if @can_write do %>
            <button class="btn btn-primary" phx-click="show_form">New Journal Entry</button>
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

    <%= if @filter_account_id do %>
      <div style="margin-bottom: 1rem; padding: 0.5rem 0.75rem; background: var(--color-bg-alt, #f0f0f0); border-radius: 4px; display: flex; align-items: center; gap: 0.5rem;">
        <span>Filtered by account: <strong>{@filter_account_name}</strong></span>
        <.link navigate={~p"/accounts/journal"} class="btn btn-secondary btn-sm">Clear filter</.link>
      </div>
    <% end %>

    <div class="section">
      <div class="section-head">
        <h2>All Entries</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th></th>
              <th>Date</th>
              <th>Reference</th>
              <th>Description</th>
              <th class="th-num">Debit</th>
              <th class="th-num">Credit</th>
              <th class="th-num">Lines</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for entry <- @entries do %>
              <% {total_debit, total_credit} = entry_totals(entry) %>
              <% is_expanded = MapSet.member?(@expanded, entry.id) %>
              <tr style="cursor: pointer;" phx-click="toggle_entry" phx-value-id={entry.id}>
                <td style="width: 1.5rem;"><%= if is_expanded, do: "&#9660;", else: "&#9654;" %></td>
                <td class="td-mono">{entry.date}</td>
                <td>{entry.reference || "—"}</td>
                <td>{entry.description}</td>
                <td class="td-num">{format_number(total_debit)}</td>
                <td class="td-num">{format_number(total_credit)}</td>
                <td class="td-num">{length(entry.lines || [])}</td>
                <td>
                  <%= if @can_write do %>
                    <button
                      phx-click="delete"
                      phx-value-id={entry.id}
                      class="btn btn-danger btn-sm"
                      data-confirm="Delete this journal entry and all its lines?"
                    >
                      Del
                    </button>
                  <% end %>
                </td>
              </tr>
              <%= if is_expanded do %>
                <%= for line <- (entry.lines || []) do %>
                  <tr style="background: var(--color-bg-alt, #f8f9fa);">
                    <td></td>
                    <td></td>
                    <td class="td-mono" style="font-size: 0.85rem;">
                      {if line.account, do: line.account.code, else: "—"}
                    </td>
                    <td style="font-size: 0.85rem;">
                      {if line.account, do: line.account.name, else: "Unknown"}
                      <%= if line.notes && line.notes != "" do %>
                        <span style="color: var(--color-muted); margin-left: 0.5rem;">({line.notes})</span>
                      <% end %>
                    </td>
                    <td class="td-num" style="font-size: 0.85rem;">
                      <%= if Money.gt?(line.debit, 0), do: format_number(line.debit) %>
                    </td>
                    <td class="td-num" style="font-size: 0.85rem;">
                      <%= if Money.gt?(line.credit, 0), do: format_number(line.credit) %>
                    </td>
                    <td></td>
                    <td></td>
                  </tr>
                <% end %>
              <% end %>
            <% end %>
          </tbody>
        </table>
        <%= if @entries == [] do %>
          <div class="empty-state">No journal entries yet.</div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop" style="max-width: 700px;">
          <div class="dialog-header">
            <h3>New Journal Entry</h3>
          </div>
          <div class="dialog-body">
            <%= if @form_error do %>
              <div class="alert alert-error" style="margin-bottom: 1rem; padding: 0.75rem; background: #fee; border: 1px solid #c00; border-radius: 4px; color: #c00;">
                {@form_error}
              </div>
            <% end %>
            <form phx-submit="save">
              <div class="form-group">
                <label class="form-label">Company</label>
                <select name="entry[company_id]" class="form-select">
                  <option value="">No company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={to_string(c.id) == @selected_company_id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div style="display: grid; grid-template-columns: 1fr 1fr 2fr; gap: 0.75rem;">
                <div class="form-group">
                  <label class="form-label">Date *</label>
                  <input type="date" name="entry[date]" class="form-input" required />
                </div>
                <div class="form-group">
                  <label class="form-label">Reference</label>
                  <input type="text" name="entry[reference]" class="form-input" placeholder="e.g. JE-001" />
                </div>
                <div class="form-group">
                  <label class="form-label">Description *</label>
                  <input type="text" name="entry[description]" class="form-input" required />
                </div>
              </div>

              <h4 style="margin: 1rem 0 0.5rem;">Lines</h4>
              <table style="width: 100%; font-size: 0.9rem;">
                <thead>
                  <tr>
                    <th>Account</th>
                    <th style="width: 120px;">Debit</th>
                    <th style="width: 120px;">Credit</th>
                    <th style="width: 120px;">Notes</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for i <- 0..(@line_count - 1) do %>
                    <tr>
                      <td>
                        <select name={"lines[#{i}][account_id]"} class="form-select" style="font-size: 0.85rem;">
                          <option value="">Select account</option>
                          <%= for a <- @accounts do %>
                            <option value={a.id}>{a.code} — {a.name}</option>
                          <% end %>
                        </select>
                      </td>
                      <td>
                        <input type="number" name={"lines[#{i}][debit]"} class="form-input" step="any" value="0" style="font-size: 0.85rem;" />
                      </td>
                      <td>
                        <input type="number" name={"lines[#{i}][credit]"} class="form-input" step="any" value="0" style="font-size: 0.85rem;" />
                      </td>
                      <td>
                        <input type="text" name={"lines[#{i}][notes]"} class="form-input" style="font-size: 0.85rem;" />
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
              <button type="button" phx-click="add_line" class="btn btn-secondary btn-sm" style="margin-top: 0.5rem;">
                + Add Line
              </button>

              <div class="form-actions" style="margin-top: 1rem;">
                <button type="submit" class="btn btn-primary">Create Entry</button>
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
