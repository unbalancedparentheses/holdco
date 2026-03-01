defmodule HoldcoWeb.BankReconciliationLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.Integrations
  alias Holdco.Integrations.Reconciliation
  alias Holdco.Money

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Integrations.subscribe()

    configs = Integrations.list_active_bank_feed_configs()

    selected_config_id =
      case configs do
        [first | _] -> first.id
        [] -> nil
      end

    socket =
      socket
      |> assign(
        page_title: "Bank Reconciliation",
        configs: configs,
        selected_config_id: selected_config_id,
        filter_status: "unmatched",
        filter_date_from: "",
        filter_date_to: "",
        selected_feed_txn_id: nil
      )
      |> load_data()

    {:ok, socket}
  end

  @impl true
  def handle_event("select_config", %{"config_id" => config_id}, socket) do
    config_id = if config_id == "", do: nil, else: String.to_integer(config_id)

    {:noreply,
     socket
     |> assign(selected_config_id: config_id, selected_feed_txn_id: nil)
     |> load_data()}
  end

  def handle_event("filter_status", %{"status" => status}, socket) do
    {:noreply,
     socket
     |> assign(filter_status: status, selected_feed_txn_id: nil)
     |> load_data()}
  end

  def handle_event("filter_dates", %{"date_from" => from, "date_to" => to}, socket) do
    {:noreply,
     socket
     |> assign(filter_date_from: from, filter_date_to: to)
     |> load_data()}
  end

  def handle_event("auto_match", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("auto_match", _params, socket) do
    case socket.assigns.selected_config_id do
      nil ->
        {:noreply, put_flash(socket, :error, "No bank feed config selected")}

      config_id ->
        matches = Reconciliation.auto_match(config_id)

        {:noreply,
         socket
         |> put_flash(:info, "Auto-matched #{length(matches)} transactions")
         |> load_data()}
    end
  end

  def handle_event("select_feed_txn", %{"id" => id}, socket) do
    feed_txn_id = String.to_integer(id)

    candidates =
      if socket.assigns.selected_feed_txn_id == feed_txn_id do
        # Deselect
        []
      else
        Reconciliation.candidates(feed_txn_id)
      end

    selected = if socket.assigns.selected_feed_txn_id == feed_txn_id, do: nil, else: feed_txn_id

    {:noreply,
     assign(socket,
       selected_feed_txn_id: selected,
       candidates: candidates
     )}
  end

  def handle_event("manual_match", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("manual_match", %{"feed_id" => feed_id, "book_id" => book_id}, socket) do
    feed_id = String.to_integer(feed_id)
    book_id = String.to_integer(book_id)

    case Reconciliation.manual_match(feed_id, book_id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Transaction matched")
         |> assign(selected_feed_txn_id: nil, candidates: [])
         |> load_data()}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to match transaction")}
    end
  end

  def handle_event("unmatch", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("unmatch", %{"id" => id}, socket) do
    feed_id = String.to_integer(id)

    case Reconciliation.unmatch(feed_id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Match removed")
         |> load_data()}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to unmatch transaction")}
    end
  end

  @impl true
  def handle_info({:bank_feed_transactions_created, _}, socket), do: {:noreply, load_data(socket)}
  def handle_info({:bank_feed_transactions_updated, _}, socket), do: {:noreply, load_data(socket)}
  def handle_info(_, socket), do: {:noreply, socket}

  defp load_data(socket) do
    config_id = socket.assigns.selected_config_id

    if config_id do
      summary = Reconciliation.reconciliation_summary(config_id)

      feed_txns =
        case socket.assigns.filter_status do
          "unmatched" -> Integrations.list_unmatched_bank_feed_transactions(config_id)
          "matched" -> list_matched_feed_transactions(config_id)
          _ -> Integrations.list_bank_feed_transactions(config_id)
        end
        |> filter_by_dates(socket.assigns.filter_date_from, socket.assigns.filter_date_to)

      assign(socket,
        summary: summary,
        feed_txns: feed_txns,
        candidates: []
      )
    else
      assign(socket,
        summary: %{total: 0, matched: 0, unmatched: 0},
        feed_txns: [],
        candidates: []
      )
    end
  end

  defp list_matched_feed_transactions(feed_config_id) do
    import Ecto.Query
    alias Holdco.Integrations.BankFeedTransaction

    from(bft in BankFeedTransaction,
      where: bft.feed_config_id == ^feed_config_id and bft.is_matched == true,
      order_by: [desc: bft.date]
    )
    |> Holdco.Repo.all()
  end

  defp filter_by_dates(txns, "", ""), do: txns
  defp filter_by_dates(txns, from, to) do
    txns
    |> then(fn list ->
      if from != "" do
        Enum.filter(list, fn t -> t.date >= from end)
      else
        list
      end
    end)
    |> then(fn list ->
      if to != "" do
        Enum.filter(list, fn t -> t.date <= to end)
      else
        list
      end
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Bank Reconciliation</h1>
          <p class="deck">Match bank feed transactions to book entries</p>
        </div>
        <%= if @can_write and @selected_config_id do %>
          <button class="btn btn-primary" phx-click="auto_match">Auto-Match All</button>
        <% end %>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div style="display: flex; gap: 1rem; margin-bottom: 1rem; flex-wrap: wrap; align-items: flex-end;">
      <div>
        <label class="form-label" style="font-size: 0.85rem;">Bank Feed</label>
        <form phx-change="select_config">
          <select name="config_id" class="form-select" style="width: auto; padding: 0.3rem 0.5rem;">
            <option value="">Select feed...</option>
            <%= for c <- @configs do %>
              <option value={c.id} selected={c.id == @selected_config_id}>
                {c.institution_name || c.provider} - {if c.bank_account, do: c.bank_account.bank_name, else: "N/A"}
              </option>
            <% end %>
          </select>
        </form>
      </div>

      <div>
        <label class="form-label" style="font-size: 0.85rem;">Status</label>
        <form phx-change="filter_status">
          <select name="status" class="form-select" style="width: auto; padding: 0.3rem 0.5rem;">
            <option value="unmatched" selected={@filter_status == "unmatched"}>Unmatched</option>
            <option value="matched" selected={@filter_status == "matched"}>Matched</option>
            <option value="all" selected={@filter_status == "all"}>All</option>
          </select>
        </form>
      </div>

      <div>
        <label class="form-label" style="font-size: 0.85rem;">Date Range</label>
        <form phx-change="filter_dates" style="display: flex; gap: 0.5rem;">
          <input type="date" name="date_from" class="form-input" style="width: auto; padding: 0.3rem 0.5rem;" value={@filter_date_from} />
          <input type="date" name="date_to" class="form-input" style="width: auto; padding: 0.3rem 0.5rem;" value={@filter_date_to} />
        </form>
      </div>
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Transactions</div>
        <div class="metric-value">{@summary.total}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Matched</div>
        <div class="metric-value" style="color: var(--color-jade, #2d6a4f);">{@summary.matched}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Unmatched</div>
        <div class="metric-value" style="color: var(--color-crimson, #c0392b);">{@summary.unmatched}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Match Rate</div>
        <div class="metric-value">
          {if @summary.total > 0, do: "#{round(@summary.matched / @summary.total * 100)}%", else: "---"}
        </div>
      </div>
    </div>

    <div class="grid-2">
      <div class="section">
        <div class="section-head">
          <h2>Bank Feed Transactions</h2>
          <span class="count">{length(@feed_txns)} shown</span>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Date</th>
                <th>Description</th>
                <th class="th-num">Amount</th>
                <th>Status</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <%= for txn <- @feed_txns do %>
                <tr
                  style={"cursor: pointer; #{if @selected_feed_txn_id == txn.id, do: "background: rgba(74, 140, 135, 0.1);", else: ""}"}
                  phx-click="select_feed_txn"
                  phx-value-id={txn.id}
                >
                  <td class="td-mono">{txn.date}</td>
                  <td class="td-name" title={txn.description}>{truncate(txn.description, 40)}</td>
                  <td class={"td-num #{amount_class(txn.amount)}"}>
                    {format_amount(txn.amount, txn.currency)}
                  </td>
                  <td>
                    <%= if txn.is_matched do %>
                      <span class="tag tag-jade">Matched</span>
                    <% else %>
                      <span class="tag tag-lemon">Unmatched</span>
                    <% end %>
                  </td>
                  <td>
                    <%= if txn.is_matched and @can_write do %>
                      <button phx-click="unmatch" phx-value-id={txn.id} class="btn btn-danger btn-sm" data-confirm="Remove match?">
                        Unmatch
                      </button>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
          <%= if @feed_txns == [] do %>
            <div class="empty-state">
              <%= if @selected_config_id do %>
                <p>No transactions for current filters.</p>
              <% else %>
                <p>Select a bank feed to begin reconciliation.</p>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>

      <div class="section">
        <div class="section-head">
          <h2>Candidate Book Entries</h2>
          <span class="count">
            <%= if @selected_feed_txn_id do %>
              {length(@candidates)} candidates
            <% else %>
              Click a feed transaction to see matches
            <% end %>
          </span>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Date</th>
                <th>Description</th>
                <th>Type</th>
                <th class="th-num">Amount</th>
                <th class="th-num">Score</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <%= for {book_txn, score} <- @candidates do %>
                <tr>
                  <td class="td-mono">{book_txn.date}</td>
                  <td class="td-name" title={book_txn.description}>{truncate(book_txn.description, 35)}</td>
                  <td><span class="tag tag-ink">{book_txn.transaction_type}</span></td>
                  <td class={"td-num #{amount_class(book_txn.amount)}"}>
                    {format_amount(book_txn.amount, book_txn.currency)}
                  </td>
                  <td class="td-num">
                    <span class={"tag #{score_tag(score)}"}>{score}</span>
                  </td>
                  <td>
                    <%= if @can_write do %>
                      <button
                        phx-click="manual_match"
                        phx-value-feed_id={@selected_feed_txn_id}
                        phx-value-book_id={book_txn.id}
                        class="btn btn-primary btn-sm"
                      >
                        Match
                      </button>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
          <%= if @selected_feed_txn_id && @candidates == [] do %>
            <div class="empty-state">
              <p>No matching book entries found for the selected transaction.</p>
            </div>
          <% end %>
          <%= if @selected_feed_txn_id == nil do %>
            <div class="empty-state">
              <p>Select an unmatched bank feed transaction on the left to view candidate matches.</p>
            </div>
          <% end %>
        </div>
      </div>
    </div>

    <div style="margin-top: 2rem; padding-top: 1rem; border-top: 1px solid var(--rule);">
      <span style="font-size: 0.75rem; font-weight: 600; text-transform: uppercase; letter-spacing: 0.05em; color: var(--ink-faint);">Related</span>
      <div style="display: flex; gap: 1rem; margin-top: 0.5rem; flex-wrap: wrap;">
        <.link navigate={~p"/bank-accounts"} class="td-link" style="font-size: 0.85rem;">Bank Accounts</.link>
        <.link navigate={~p"/transactions"} class="td-link" style="font-size: 0.85rem;">Transactions</.link>
        <.link navigate={~p"/accounts/journal"} class="td-link" style="font-size: 0.85rem;">Journal Entries</.link>
      </div>
    </div>
    """
  end

  defp truncate(nil, _), do: ""
  defp truncate(str, max) when byte_size(str) <= max, do: str
  defp truncate(str, max), do: String.slice(str, 0, max) <> "..."

  defp format_amount(nil, _currency), do: "0"

  defp format_amount(amount, currency) do
    sign = if Money.negative?(amount), do: "-", else: ""
    abs_val = Money.abs(amount)
    formatted = :erlang.float_to_binary(Money.to_float(abs_val), decimals: 2)
    "#{sign}#{formatted} #{currency}"
  end

  defp amount_class(nil), do: ""
  defp amount_class(amount) do
    if Money.negative?(amount), do: "num-negative", else: "num-positive"
  end

  defp score_tag(score) when score >= 80, do: "tag-jade"
  defp score_tag(score) when score >= 60, do: "tag-lemon"
  defp score_tag(_), do: "tag-crimson"
end
