defmodule HoldcoWeb.MultiBookLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Finance, Corporate}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Finance.subscribe()
    companies = Corporate.list_companies()
    books = Finance.list_accounting_books()
    accounts = Finance.list_accounts()

    {:ok,
     assign(socket,
       page_title: "Multi-Book Accounting",
       companies: companies,
       books: books,
       accounts: accounts,
       selected_company_id: "",
       show_book_form: false,
       editing_book: nil,
       show_adjustment_form: false,
       editing_adjustment: nil,
       selected_book: nil,
       adjustments: [],
       trial_balance: nil,
       comparison_books: [],
       comparison_data: nil,
       comparison_date: Date.to_string(Date.utc_today())
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("filter_company", %{"company_id" => id}, socket) do
    company_id = if id == "", do: nil, else: String.to_integer(id)
    books = Finance.list_accounting_books(company_id)

    {:noreply,
     assign(socket,
       selected_company_id: id,
       books: books,
       selected_book: nil,
       adjustments: [],
       trial_balance: nil,
       comparison_data: nil
     )}
  end

  def handle_event("show_book_form", _, socket) do
    {:noreply, assign(socket, show_book_form: :add, editing_book: nil)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_book_form: false, editing_book: nil, show_adjustment_form: false, editing_adjustment: nil)}
  end

  def handle_event("edit_book", %{"id" => id}, socket) do
    book = Finance.get_accounting_book!(String.to_integer(id))
    {:noreply, assign(socket, show_book_form: :edit, editing_book: book)}
  end

  def handle_event("select_book", %{"id" => id}, socket) do
    book = Finance.get_accounting_book!(String.to_integer(id))
    adjustments = Finance.list_book_adjustments(book.id)
    tb = Finance.book_trial_balance(book.id, Date.utc_today())

    {:noreply,
     assign(socket,
       selected_book: book,
       adjustments: adjustments,
       trial_balance: tb
     )}
  end

  def handle_event("close_detail", _, socket) do
    {:noreply, assign(socket, selected_book: nil, adjustments: [], trial_balance: nil)}
  end

  def handle_event("show_adjustment_form", _, socket) do
    {:noreply, assign(socket, show_adjustment_form: true, editing_adjustment: nil)}
  end

  def handle_event("edit_adjustment", %{"id" => id}, socket) do
    adjustment = Finance.get_book_adjustment!(String.to_integer(id))
    {:noreply, assign(socket, show_adjustment_form: true, editing_adjustment: adjustment)}
  end

  # Permission guards
  def handle_event("save_book", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("update_book", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("delete_book", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("save_book", %{"book" => params}, socket) do
    case Finance.create_accounting_book(params) do
      {:ok, _} ->
        {:noreply,
         reload_books(socket)
         |> put_flash(:info, "Accounting book created")
         |> assign(show_book_form: false, editing_book: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create accounting book")}
    end
  end

  def handle_event("update_book", %{"book" => params}, socket) do
    book = socket.assigns.editing_book

    case Finance.update_accounting_book(book, params) do
      {:ok, _} ->
        {:noreply,
         reload_books(socket)
         |> put_flash(:info, "Accounting book updated")
         |> assign(show_book_form: false, editing_book: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update accounting book")}
    end
  end

  def handle_event("delete_book", %{"id" => id}, socket) do
    book = Finance.get_accounting_book!(String.to_integer(id))

    case Finance.delete_accounting_book(book) do
      {:ok, _} ->
        selected =
          if socket.assigns.selected_book && socket.assigns.selected_book.id == book.id,
            do: nil,
            else: socket.assigns.selected_book

        {:noreply,
         reload_books(socket)
         |> put_flash(:info, "Accounting book deleted")
         |> assign(selected_book: selected, adjustments: [], trial_balance: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete accounting book")}
    end
  end

  def handle_event("save_adjustment", %{"adjustment" => params}, socket) do
    book = socket.assigns.selected_book
    params = Map.put(params, "book_id", book.id)

    case Finance.create_book_adjustment(params) do
      {:ok, _} ->
        adjustments = Finance.list_book_adjustments(book.id)
        tb = Finance.book_trial_balance(book.id, Date.utc_today())

        {:noreply,
         socket
         |> put_flash(:info, "Adjustment created")
         |> assign(show_adjustment_form: false, adjustments: adjustments, trial_balance: tb, editing_adjustment: nil)
         |> reload_books()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create adjustment")}
    end
  end

  def handle_event("update_adjustment", %{"adjustment" => params}, socket) do
    adjustment = socket.assigns.editing_adjustment

    case Finance.update_book_adjustment(adjustment, params) do
      {:ok, _} ->
        book = socket.assigns.selected_book
        adjustments = Finance.list_book_adjustments(book.id)
        tb = Finance.book_trial_balance(book.id, Date.utc_today())

        {:noreply,
         socket
         |> put_flash(:info, "Adjustment updated")
         |> assign(show_adjustment_form: false, adjustments: adjustments, trial_balance: tb, editing_adjustment: nil)
         |> reload_books()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update adjustment")}
    end
  end

  def handle_event("delete_adjustment", %{"id" => id}, socket) do
    adjustment = Finance.get_book_adjustment!(String.to_integer(id))

    case Finance.delete_book_adjustment(adjustment) do
      {:ok, _} ->
        book = socket.assigns.selected_book
        adjustments = Finance.list_book_adjustments(book.id)
        tb = Finance.book_trial_balance(book.id, Date.utc_today())

        {:noreply,
         socket
         |> put_flash(:info, "Adjustment deleted")
         |> assign(adjustments: adjustments, trial_balance: tb)
         |> reload_books()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete adjustment")}
    end
  end

  def handle_event("compare_books", %{"book_ids" => book_ids_str, "date" => date}, socket) do
    book_ids =
      book_ids_str
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(&String.to_integer/1)

    date = Date.from_iso8601!(date)

    comparison =
      Enum.map(book_ids, fn book_id ->
        book = Finance.get_accounting_book!(book_id)
        tb = Finance.book_trial_balance(book_id, date)
        %{book: book, trial_balance: tb}
      end)

    {:noreply, assign(socket, comparison_data: comparison, comparison_books: book_ids, comparison_date: Date.to_string(date))}
  end

  @impl true
  def handle_info({event, _record}, socket)
      when event in [
             :accounting_books_created,
             :accounting_books_updated,
             :accounting_books_deleted,
             :book_adjustments_created,
             :book_adjustments_updated,
             :book_adjustments_deleted
           ] do
    {:noreply, reload_books(socket)}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Multi-Book Accounting</h1>
          <p class="deck">Manage IFRS, GAAP, Tax, and Management accounting books</p>
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
            <button class="btn btn-primary" phx-click="show_book_form">New Book</button>
          <% end %>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Accounting Books</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>Book Type</th>
              <th>Currency</th>
              <th>Primary</th>
              <th>Active</th>
              <th>Company</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for b <- @books do %>
              <tr>
                <td class="td-name">{b.name}</td>
                <td><span class={"tag #{book_type_tag(b.book_type)}"}>{b.book_type}</span></td>
                <td class="td-mono">{b.base_currency}</td>
                <td>{if b.is_primary, do: "Yes", else: "No"}</td>
                <td>{if b.is_active, do: "Yes", else: "No"}</td>
                <td>
                  <%= if b.company do %>
                    <.link navigate={~p"/companies/#{b.company.id}"} class="td-link">{b.company.name}</.link>
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td>
                  <div style="display: flex; gap: 0.25rem;">
                    <button phx-click="select_book" phx-value-id={b.id} class="btn btn-secondary btn-sm">View</button>
                    <%= if @can_write do %>
                      <button phx-click="edit_book" phx-value-id={b.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete_book" phx-value-id={b.id} class="btn btn-danger btn-sm" data-confirm="Delete this book?">Del</button>
                    <% end %>
                  </div>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @books == [] do %>
          <div class="empty-state">
            <p>No accounting books found.</p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_book_form">Create First Book</button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%!-- Side-by-side comparison --%>
    <div class="section">
      <div class="section-head">
        <h2>Book Comparison</h2>
      </div>
      <div class="panel" style="padding: 1rem;">
        <form phx-submit="compare_books" style="display: flex; gap: 1rem; align-items: flex-end; flex-wrap: wrap;">
          <div class="form-group" style="margin: 0;">
            <label class="form-label">Book IDs (comma-separated)</label>
            <input type="text" name="book_ids" class="form-input" placeholder="1,2,3"
              value={Enum.join(@comparison_books, ",")} />
          </div>
          <div class="form-group" style="margin: 0;">
            <label class="form-label">As of Date</label>
            <input type="date" name="date" class="form-input" value={@comparison_date} />
          </div>
          <button type="submit" class="btn btn-primary">Compare</button>
        </form>
      </div>

      <%= if @comparison_data do %>
        <div class="panel" style="margin-top: 1rem; overflow-x: auto;">
          <table>
            <thead>
              <tr>
                <th>Account</th>
                <%= for comp <- @comparison_data do %>
                  <th class="th-num">{comp.book.name} Debit</th>
                  <th class="th-num">{comp.book.name} Credit</th>
                  <th class="th-num">{comp.book.name} Balance</th>
                <% end %>
              </tr>
            </thead>
            <tbody>
              <%= if @comparison_data != [] do %>
                <%= for acct <- hd(@comparison_data).trial_balance do %>
                  <tr>
                    <td class="td-name">{acct.code} - {acct.name}</td>
                    <%= for comp <- @comparison_data do %>
                      <% row = Enum.find(comp.trial_balance, fn a -> a.id == acct.id end) %>
                      <%= if row do %>
                        <td class="td-num">{format_number(row.total_debit)}</td>
                        <td class="td-num">{format_number(row.total_credit)}</td>
                        <td class="td-num">{format_number(row.balance)}</td>
                      <% else %>
                        <td class="td-num">0</td>
                        <td class="td-num">0</td>
                        <td class="td-num">0</td>
                      <% end %>
                    <% end %>
                  </tr>
                <% end %>
              <% end %>
            </tbody>
          </table>
        </div>
      <% end %>
    </div>

    <%!-- Selected book detail with adjustments and trial balance --%>
    <%= if @selected_book do %>
      <div class="section">
        <div class="section-head" style="display: flex; justify-content: space-between; align-items: center;">
          <h2>{@selected_book.name} - Adjustments</h2>
          <div style="display: flex; gap: 0.5rem;">
            <%= if @can_write do %>
              <button phx-click="show_adjustment_form" class="btn btn-primary btn-sm">Add Adjustment</button>
            <% end %>
            <button phx-click="close_detail" class="btn btn-secondary btn-sm">Close</button>
          </div>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Date</th>
                <th>Type</th>
                <th>Debit Account</th>
                <th>Credit Account</th>
                <th class="th-num">Amount</th>
                <th>Description</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <%= for adj <- @adjustments do %>
                <tr>
                  <td class="td-mono">{adj.effective_date}</td>
                  <td><span class="tag">{adj.adjustment_type}</span></td>
                  <td>{if adj.debit_account, do: "#{adj.debit_account.code} - #{adj.debit_account.name}", else: "-"}</td>
                  <td>{if adj.credit_account, do: "#{adj.credit_account.code} - #{adj.credit_account.name}", else: "-"}</td>
                  <td class="td-num">{format_number(adj.amount)}</td>
                  <td>{adj.description || "-"}</td>
                  <td>
                    <%= if @can_write do %>
                      <div style="display: flex; gap: 0.25rem;">
                        <button phx-click="edit_adjustment" phx-value-id={adj.id} class="btn btn-secondary btn-sm">Edit</button>
                        <button phx-click="delete_adjustment" phx-value-id={adj.id} class="btn btn-danger btn-sm" data-confirm="Delete?">Del</button>
                      </div>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
          <%= if @adjustments == [] do %>
            <div class="empty-state">No adjustments for this book.</div>
          <% end %>
        </div>
      </div>

      <div class="section">
        <div class="section-head">
          <h2>{@selected_book.name} - Adjusted Trial Balance</h2>
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
              <%= if @trial_balance do %>
                <%= for acct <- @trial_balance do %>
                  <tr>
                    <td class="td-mono">{acct.code}</td>
                    <td class="td-name">{acct.name}</td>
                    <td><span class="tag">{acct.account_type}</span></td>
                    <td class="td-num">{format_number(acct.total_debit)}</td>
                    <td class="td-num">{format_number(acct.total_credit)}</td>
                    <td class="td-num">{format_number(acct.balance)}</td>
                  </tr>
                <% end %>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    <% end %>

    <%!-- Book form dialog --%>
    <%= if @show_book_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_book_form == :edit, do: "Edit Book", else: "New Accounting Book"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_book_form == :edit, do: "update_book", else: "save_book"}>
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="book[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={@editing_book && @editing_book.company_id == c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Name *</label>
                <input type="text" name="book[name]" class="form-input" value={if @editing_book, do: @editing_book.name, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Book Type *</label>
                <select name="book[book_type]" class="form-select" required>
                  <option value="">Select type</option>
                  <%= for t <- ~w(ifrs us_gaap local_gaap tax management) do %>
                    <option value={t} selected={@editing_book && @editing_book.book_type == t}>{t}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Base Currency</label>
                <input type="text" name="book[base_currency]" class="form-input" value={if @editing_book, do: @editing_book.base_currency, else: "USD"} />
              </div>
              <div class="form-group">
                <label class="form-label">
                  <input type="hidden" name="book[is_primary]" value="false" />
                  <input type="checkbox" name="book[is_primary]" value="true" checked={@editing_book && @editing_book.is_primary} /> Primary Book
                </label>
              </div>
              <div class="form-group">
                <label class="form-label">Description</label>
                <textarea name="book[description]" class="form-input">{if @editing_book, do: @editing_book.description, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">{if @show_book_form == :edit, do: "Update", else: "Create"}</button>
                <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>

    <%!-- Adjustment form dialog --%>
    <%= if @show_adjustment_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @editing_adjustment, do: "Edit Adjustment", else: "New Adjustment"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @editing_adjustment, do: "update_adjustment", else: "save_adjustment"}>
              <div class="form-group">
                <label class="form-label">Adjustment Type *</label>
                <select name="adjustment[adjustment_type]" class="form-select" required>
                  <option value="">Select type</option>
                  <%= for t <- ~w(reclassification measurement elimination other) do %>
                    <option value={t} selected={@editing_adjustment && @editing_adjustment.adjustment_type == t}>{t}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Debit Account</label>
                <select name="adjustment[debit_account_id]" class="form-select">
                  <option value="">Select account</option>
                  <%= for a <- @accounts do %>
                    <option value={a.id} selected={@editing_adjustment && @editing_adjustment.debit_account_id == a.id}>{a.code} - {a.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Credit Account</label>
                <select name="adjustment[credit_account_id]" class="form-select">
                  <option value="">Select account</option>
                  <%= for a <- @accounts do %>
                    <option value={a.id} selected={@editing_adjustment && @editing_adjustment.credit_account_id == a.id}>{a.code} - {a.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Amount *</label>
                <input type="number" name="adjustment[amount]" class="form-input" step="any" value={if @editing_adjustment, do: @editing_adjustment.amount, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Effective Date *</label>
                <input type="date" name="adjustment[effective_date]" class="form-input" value={if @editing_adjustment, do: @editing_adjustment.effective_date, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Description</label>
                <textarea name="adjustment[description]" class="form-input">{if @editing_adjustment, do: @editing_adjustment.description, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">{if @editing_adjustment, do: "Update", else: "Create"}</button>
                <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp reload_books(socket) do
    company_id =
      case socket.assigns.selected_company_id do
        "" -> nil
        id -> String.to_integer(id)
      end

    books = Finance.list_accounting_books(company_id)
    assign(socket, books: books)
  end

  defp book_type_tag("ifrs"), do: "tag-sky"
  defp book_type_tag("us_gaap"), do: "tag-jade"
  defp book_type_tag("local_gaap"), do: "tag-lemon"
  defp book_type_tag("tax"), do: "tag-rose"
  defp book_type_tag("management"), do: "tag-sky"
  defp book_type_tag(_), do: ""

  defp format_number(%Decimal{} = n),
    do: n |> Decimal.round(2) |> Decimal.to_string() |> add_commas()

  defp format_number(n) when is_float(n),
    do: :erlang.float_to_binary(n, decimals: 2) |> add_commas()

  defp format_number(n) when is_integer(n), do: Integer.to_string(n) |> add_commas()
  defp format_number(nil), do: "0"
  defp format_number(_), do: "0"

  defp add_commas(str) do
    case String.split(str, ".") do
      [int_part, dec_part] ->
        formatted_int =
          int_part |> String.reverse() |> String.replace(~r/(\d{3})(?=\d)/, "\\1,") |> String.reverse()

        "#{formatted_int}.#{dec_part}"

      [int_part] ->
        int_part |> String.reverse() |> String.replace(~r/(\d{3})(?=\d)/, "\\1,") |> String.reverse()
    end
  end
end
