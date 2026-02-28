defmodule HoldcoWeb.OnChainLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Analytics, Corporate}
  alias Holdco.Analytics.OnChainRecord

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Analytics.subscribe()
    companies = Corporate.list_companies()
    records = Analytics.list_on_chain_records()

    {:ok,
     assign(socket,
       page_title: "On-Chain Verification",
       companies: companies,
       records: records,
       chain_filter: nil,
       show_form: false,
       editing_item: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: :add, editing_item: nil)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false, editing_item: nil)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    record = Analytics.get_on_chain_record!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: record)}
  end

  def handle_event("filter_chain", %{"chain" => ""}, socket) do
    {:noreply, assign(socket, chain_filter: nil) |> reload()}
  end

  def handle_event("filter_chain", %{"chain" => chain}, socket) do
    {:noreply, assign(socket, chain_filter: chain) |> reload()}
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

  def handle_event("save", %{"on_chain_record" => params}, socket) do
    case Analytics.create_on_chain_record(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "On-chain record created")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create on-chain record")}
    end
  end

  def handle_event("update", %{"on_chain_record" => params}, socket) do
    record = socket.assigns.editing_item

    case Analytics.update_on_chain_record(record, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "On-chain record updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update on-chain record")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    record = Analytics.get_on_chain_record!(String.to_integer(id))

    case Analytics.delete_on_chain_record(record) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "On-chain record deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete on-chain record")}
    end
  end

  @impl true
  def handle_info({event, _record}, socket)
      when event in [:on_chain_records_created, :on_chain_records_updated, :on_chain_records_deleted] do
    {:noreply, reload(socket)}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>On-Chain Verification</h1>
          <p class="deck">Verify and match blockchain transactions</p>
        </div>
        <%= if @can_write do %>
          <button class="btn btn-primary" phx-click="show_form">Add Record</button>
        <% end %>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Records</div>
        <div class="metric-value">{length(@records)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Confirmed</div>
        <div class="metric-value">{Enum.count(@records, &(&1.verification_status == "confirmed"))}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Pending</div>
        <div class="metric-value">{Enum.count(@records, &(&1.verification_status == "pending"))}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Failed</div>
        <div class="metric-value">{Enum.count(@records, &(&1.verification_status == "failed"))}</div>
      </div>
    </div>

    <div class="section">
      <div class="section-head" style="display: flex; gap: 1rem; align-items: center;">
        <h2>All On-Chain Records</h2>
        <form phx-change="filter_chain" style="display: inline;">
          <select name="chain" class="form-select form-select-sm">
            <option value="">All Chains</option>
            <%= for c <- OnChainRecord.chains() do %>
              <option value={c} selected={@chain_filter == c}>{humanize(c)}</option>
            <% end %>
          </select>
        </form>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Company</th><th>Chain</th><th>TX Hash</th><th>Block</th>
              <th>From</th><th>To</th><th>Amount</th><th>Status</th><th>Matched</th><th></th>
            </tr>
          </thead>
          <tbody>
            <%= for r <- filtered_records(@records, @chain_filter) do %>
              <tr>
                <td>{if r.company, do: r.company.name, else: "---"}</td>
                <td><span class="tag tag-sky">{humanize(r.chain)}</span></td>
                <td class="td-mono" style="max-width: 120px; overflow: hidden; text-overflow: ellipsis;">{r.tx_hash}</td>
                <td class="td-num">{r.block_number || "---"}</td>
                <td class="td-mono" style="max-width: 100px; overflow: hidden; text-overflow: ellipsis;">{r.from_address || "---"}</td>
                <td class="td-mono" style="max-width: 100px; overflow: hidden; text-overflow: ellipsis;">{r.to_address || "---"}</td>
                <td class="td-num">{if r.amount, do: Decimal.to_string(r.amount), else: "---"}</td>
                <td><span class={"tag #{verification_tag(r.verification_status)}"}>{humanize(r.verification_status)}</span></td>
                <td>{if r.matched_transaction_id, do: "Yes", else: "No"}</td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit" phx-value-id={r.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete" phx-value-id={r.id} class="btn btn-danger btn-sm" data-confirm="Delete this record?">Del</button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if filtered_records(@records, @chain_filter) == [] do %>
          <div class="empty-state">
            <p>No on-chain records found.</p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_form">Add Your First Record</button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit On-Chain Record", else: "Add On-Chain Record"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="on_chain_record[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={@editing_item && @editing_item.company_id == c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Chain *</label>
                <select name="on_chain_record[chain]" class="form-select" required>
                  <%= for c <- OnChainRecord.chains() do %>
                    <option value={c} selected={@editing_item && @editing_item.chain == c}>{humanize(c)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">TX Hash *</label>
                <input type="text" name="on_chain_record[tx_hash]" class="form-input" value={if @editing_item, do: @editing_item.tx_hash, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Block Number</label>
                <input type="number" name="on_chain_record[block_number]" class="form-input" value={if @editing_item, do: @editing_item.block_number, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">From Address</label>
                <input type="text" name="on_chain_record[from_address]" class="form-input" value={if @editing_item, do: @editing_item.from_address, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">To Address</label>
                <input type="text" name="on_chain_record[to_address]" class="form-input" value={if @editing_item, do: @editing_item.to_address, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Amount</label>
                <input type="number" name="on_chain_record[amount]" class="form-input" step="0.000001" value={if @editing_item && @editing_item.amount, do: Decimal.to_string(@editing_item.amount), else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Currency</label>
                <input type="text" name="on_chain_record[currency]" class="form-input" value={if @editing_item, do: @editing_item.currency, else: "USD"} />
              </div>
              <div class="form-group">
                <label class="form-label">Verification Status</label>
                <select name="on_chain_record[verification_status]" class="form-select">
                  <%= for s <- OnChainRecord.verification_statuses() do %>
                    <option value={s} selected={@editing_item && @editing_item.verification_status == s}>{humanize(s)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Gas Fee</label>
                <input type="number" name="on_chain_record[gas_fee]" class="form-input" step="0.000001" value={if @editing_item && @editing_item.gas_fee, do: Decimal.to_string(@editing_item.gas_fee), else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="on_chain_record[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">{if @show_form == :edit, do: "Update Record", else: "Add Record"}</button>
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
    assign(socket, records: Analytics.list_on_chain_records())
  end

  defp filtered_records(records, nil), do: records
  defp filtered_records(records, chain), do: Enum.filter(records, &(&1.chain == chain))

  defp humanize(str), do: str |> String.replace("_", " ") |> String.split(" ") |> Enum.map(&String.capitalize/1) |> Enum.join(" ")

  defp verification_tag("confirmed"), do: "tag-jade"
  defp verification_tag("pending"), do: "tag-lemon"
  defp verification_tag("failed"), do: "tag-rose"
  defp verification_tag("mismatch"), do: "tag-rose"
  defp verification_tag(_), do: ""
end
