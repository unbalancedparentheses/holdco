defmodule HoldcoWeb.DefiPositionLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Analytics, Corporate}
  alias Holdco.Analytics.DefiPosition

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Analytics.subscribe()
    companies = Corporate.list_companies()
    positions = Analytics.list_defi_positions()

    {:ok,
     assign(socket,
       page_title: "DeFi Positions",
       companies: companies,
       positions: positions,
       chain_filter: nil,
       protocol_filter: nil,
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
    position = Analytics.get_defi_position!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: position)}
  end

  def handle_event("filter_chain", %{"chain" => ""}, socket) do
    {:noreply, assign(socket, chain_filter: nil) |> reload()}
  end

  def handle_event("filter_chain", %{"chain" => chain}, socket) do
    {:noreply, assign(socket, chain_filter: chain) |> reload()}
  end

  def handle_event("filter_protocol", %{"protocol" => ""}, socket) do
    {:noreply, assign(socket, protocol_filter: nil) |> reload()}
  end

  def handle_event("filter_protocol", %{"protocol" => protocol}, socket) do
    {:noreply, assign(socket, protocol_filter: protocol) |> reload()}
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

  def handle_event("save", %{"defi_position" => params}, socket) do
    case Analytics.create_defi_position(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "DeFi position created")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create DeFi position")}
    end
  end

  def handle_event("update", %{"defi_position" => params}, socket) do
    position = socket.assigns.editing_item

    case Analytics.update_defi_position(position, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "DeFi position updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update DeFi position")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    position = Analytics.get_defi_position!(String.to_integer(id))

    case Analytics.delete_defi_position(position) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "DeFi position deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete DeFi position")}
    end
  end

  @impl true
  def handle_info({event, _record}, socket)
      when event in [:defi_positions_created, :defi_positions_updated, :defi_positions_deleted] do
    {:noreply, reload(socket)}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>DeFi Positions</h1>
          <p class="deck">Track DeFi protocol positions across chains</p>
        </div>
        <%= if @can_write do %>
          <button class="btn btn-primary" phx-click="show_form">Add Position</button>
        <% end %>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Positions</div>
        <div class="metric-value">{length(@positions)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Active</div>
        <div class="metric-value">{Enum.count(@positions, &(&1.status == "active"))}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Total Value</div>
        <div class="metric-value">{@positions |> Enum.filter(&(&1.status == "active" && &1.current_value)) |> Enum.reduce(Decimal.new(0), fn p, acc -> Decimal.add(acc, p.current_value) end) |> Decimal.to_string()}</div>
      </div>
    </div>

    <div class="section">
      <div class="section-head" style="display: flex; gap: 1rem; align-items: center;">
        <h2>All DeFi Positions</h2>
        <form phx-change="filter_chain" style="display: inline;">
          <select name="chain" class="form-select form-select-sm">
            <option value="">All Chains</option>
            <%= for c <- DefiPosition.chains() do %>
              <option value={c} selected={@chain_filter == c}>{humanize(c)}</option>
            <% end %>
          </select>
        </form>
        <form phx-change="filter_protocol" style="display: inline;">
          <select name="protocol" class="form-select form-select-sm">
            <option value="">All Protocols</option>
            <%= for p <- @positions |> Enum.map(& &1.protocol_name) |> Enum.uniq() |> Enum.sort() do %>
              <option value={p} selected={@protocol_filter == p}>{p}</option>
            <% end %>
          </select>
        </form>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Company</th><th>Protocol</th><th>Chain</th><th>Type</th>
              <th>Asset</th><th>Deposited</th><th>Current Value</th><th>APY</th>
              <th>Status</th><th></th>
            </tr>
          </thead>
          <tbody>
            <%= for p <- filtered_positions(@positions, @chain_filter, @protocol_filter) do %>
              <tr>
                <td>{if p.company, do: p.company.name, else: "---"}</td>
                <td class="td-name">{p.protocol_name}</td>
                <td><span class="tag tag-sky">{humanize(p.chain)}</span></td>
                <td>{humanize(p.position_type)}</td>
                <td class="td-mono">{p.asset_pair || "---"}</td>
                <td class="td-num">{if p.deposited_amount, do: Decimal.to_string(p.deposited_amount), else: "---"}</td>
                <td class="td-num">{if p.current_value, do: Decimal.to_string(p.current_value), else: "---"}</td>
                <td class="td-num">{if p.apy_current, do: "#{Decimal.to_string(p.apy_current)}%", else: "---"}</td>
                <td><span class={"tag #{status_tag(p.status)}"}>{humanize(p.status)}</span></td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit" phx-value-id={p.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete" phx-value-id={p.id} class="btn btn-danger btn-sm" data-confirm="Delete this position?">Del</button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if filtered_positions(@positions, @chain_filter, @protocol_filter) == [] do %>
          <div class="empty-state">
            <p>No DeFi positions found.</p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_form">Add Your First Position</button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit DeFi Position", else: "Add DeFi Position"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="defi_position[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={@editing_item && @editing_item.company_id == c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Protocol Name *</label>
                <input type="text" name="defi_position[protocol_name]" class="form-input" value={if @editing_item, do: @editing_item.protocol_name, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Chain *</label>
                <select name="defi_position[chain]" class="form-select" required>
                  <%= for c <- DefiPosition.chains() do %>
                    <option value={c} selected={@editing_item && @editing_item.chain == c}>{humanize(c)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Position Type *</label>
                <select name="defi_position[position_type]" class="form-select" required>
                  <%= for t <- DefiPosition.position_types() do %>
                    <option value={t} selected={@editing_item && @editing_item.position_type == t}>{humanize(t)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Asset Pair</label>
                <input type="text" name="defi_position[asset_pair]" class="form-input" value={if @editing_item, do: @editing_item.asset_pair, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Deposited Amount</label>
                <input type="number" name="defi_position[deposited_amount]" class="form-input" step="0.01" value={if @editing_item && @editing_item.deposited_amount, do: Decimal.to_string(@editing_item.deposited_amount), else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Current Value</label>
                <input type="number" name="defi_position[current_value]" class="form-input" step="0.01" value={if @editing_item && @editing_item.current_value, do: Decimal.to_string(@editing_item.current_value), else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">APY (%)</label>
                <input type="number" name="defi_position[apy_current]" class="form-input" step="0.01" value={if @editing_item && @editing_item.apy_current, do: Decimal.to_string(@editing_item.apy_current), else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Currency</label>
                <input type="text" name="defi_position[currency]" class="form-input" value={if @editing_item, do: @editing_item.currency, else: "USD"} />
              </div>
              <div class="form-group">
                <label class="form-label">Wallet Address</label>
                <input type="text" name="defi_position[wallet_address]" class="form-input" value={if @editing_item, do: @editing_item.wallet_address, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Contract Address</label>
                <input type="text" name="defi_position[contract_address]" class="form-input" value={if @editing_item, do: @editing_item.contract_address, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Status</label>
                <select name="defi_position[status]" class="form-select">
                  <%= for s <- DefiPosition.statuses() do %>
                    <option value={s} selected={@editing_item && @editing_item.status == s}>{humanize(s)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Entry Date</label>
                <input type="date" name="defi_position[entry_date]" class="form-input" value={if @editing_item, do: @editing_item.entry_date, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="defi_position[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">{if @show_form == :edit, do: "Update Position", else: "Add Position"}</button>
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
    assign(socket, positions: Analytics.list_defi_positions())
  end

  defp filtered_positions(positions, nil, nil), do: positions
  defp filtered_positions(positions, chain, nil) when is_binary(chain),
    do: Enum.filter(positions, &(&1.chain == chain))
  defp filtered_positions(positions, nil, protocol) when is_binary(protocol),
    do: Enum.filter(positions, &(&1.protocol_name == protocol))
  defp filtered_positions(positions, chain, protocol),
    do: Enum.filter(positions, &(&1.chain == chain && &1.protocol_name == protocol))

  defp humanize(str), do: str |> String.replace("_", " ") |> String.split(" ") |> Enum.map(&String.capitalize/1) |> Enum.join(" ")

  defp status_tag("active"), do: "tag-jade"
  defp status_tag("closed"), do: "tag-lemon"
  defp status_tag("liquidated"), do: "tag-rose"
  defp status_tag(_), do: ""
end
