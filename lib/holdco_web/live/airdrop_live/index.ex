defmodule HoldcoWeb.AirdropLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Analytics, Corporate}
  alias Holdco.Analytics.Airdrop

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Analytics.subscribe()
    companies = Corporate.list_companies()
    airdrops = Analytics.list_airdrops()

    {:ok,
     assign(socket,
       page_title: "Airdrops & Forks",
       companies: companies,
       airdrops: airdrops,
       type_filter: nil,
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
    airdrop = Analytics.get_airdrop!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: airdrop)}
  end

  def handle_event("filter_type", %{"type" => ""}, socket) do
    {:noreply, assign(socket, type_filter: nil) |> reload()}
  end

  def handle_event("filter_type", %{"type" => type}, socket) do
    {:noreply, assign(socket, type_filter: type) |> reload()}
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

  def handle_event("save", %{"airdrop" => params}, socket) do
    case Analytics.create_airdrop(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Airdrop created")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create airdrop")}
    end
  end

  def handle_event("update", %{"airdrop" => params}, socket) do
    airdrop = socket.assigns.editing_item

    case Analytics.update_airdrop(airdrop, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Airdrop updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update airdrop")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    airdrop = Analytics.get_airdrop!(String.to_integer(id))

    case Analytics.delete_airdrop(airdrop) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Airdrop deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete airdrop")}
    end
  end

  @impl true
  def handle_info({event, _record}, socket)
      when event in [:airdrops_created, :airdrops_updated, :airdrops_deleted] do
    {:noreply, reload(socket)}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Airdrops & Forks</h1>
          <p class="deck">Track airdrops, forks, token splits, and migrations</p>
        </div>
        <%= if @can_write do %>
          <button class="btn btn-primary" phx-click="show_form">Add Event</button>
        <% end %>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Events</div>
        <div class="metric-value">{length(@airdrops)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Unclaimed</div>
        <div class="metric-value">{Enum.count(@airdrops, &(&1.claimed == false && &1.eligible == true))}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Total Current Value</div>
        <div class="metric-value">{@airdrops |> Enum.filter(& &1.current_value) |> Enum.reduce(Decimal.new(0), fn a, acc -> Decimal.add(acc, a.current_value) end) |> Decimal.to_string()}</div>
      </div>
    </div>

    <div class="section">
      <div class="section-head" style="display: flex; gap: 1rem; align-items: center;">
        <h2>All Events</h2>
        <form phx-change="filter_type" style="display: inline;">
          <select name="type" class="form-select form-select-sm">
            <option value="">All Types</option>
            <%= for t <- Airdrop.event_types() do %>
              <option value={t} selected={@type_filter == t}>{humanize(t)}</option>
            <% end %>
          </select>
        </form>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Company</th><th>Type</th><th>Token</th><th>Chain</th>
              <th>Amount</th><th>Value at Receipt</th><th>Current Value</th>
              <th>Claimed</th><th>Tax Treated</th><th></th>
            </tr>
          </thead>
          <tbody>
            <%= for a <- filtered_airdrops(@airdrops, @type_filter) do %>
              <tr>
                <td>{if a.company, do: a.company.name, else: "---"}</td>
                <td><span class={"tag #{type_tag(a.event_type)}"}>{humanize(a.event_type)}</span></td>
                <td class="td-name">{a.token_name}</td>
                <td><span class="tag tag-sky">{humanize(a.chain)}</span></td>
                <td class="td-num">{if a.amount, do: Decimal.to_string(a.amount), else: "---"}</td>
                <td class="td-num">{if a.value_at_receipt, do: Decimal.to_string(a.value_at_receipt), else: "---"}</td>
                <td class="td-num">{if a.current_value, do: Decimal.to_string(a.current_value), else: "---"}</td>
                <td><span class={"tag #{if a.claimed, do: "tag-jade", else: "tag-lemon"}"}>{if a.claimed, do: "Yes", else: "No"}</span></td>
                <td>{if a.tax_treated, do: "Yes", else: "No"}</td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit" phx-value-id={a.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete" phx-value-id={a.id} class="btn btn-danger btn-sm" data-confirm="Delete this event?">Del</button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if filtered_airdrops(@airdrops, @type_filter) == [] do %>
          <div class="empty-state">
            <p>No airdrop or fork events found.</p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_form">Add Your First Event</button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit Event", else: "Add Event"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="airdrop[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={@editing_item && @editing_item.company_id == c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Event Type *</label>
                <select name="airdrop[event_type]" class="form-select" required>
                  <%= for t <- Airdrop.event_types() do %>
                    <option value={t} selected={@editing_item && @editing_item.event_type == t}>{humanize(t)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Token Name *</label>
                <input type="text" name="airdrop[token_name]" class="form-input" value={if @editing_item, do: @editing_item.token_name, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Chain *</label>
                <select name="airdrop[chain]" class="form-select" required>
                  <%= for c <- Airdrop.chains() do %>
                    <option value={c} selected={@editing_item && @editing_item.chain == c}>{humanize(c)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Amount</label>
                <input type="number" name="airdrop[amount]" class="form-input" step="0.000001" value={if @editing_item && @editing_item.amount, do: Decimal.to_string(@editing_item.amount), else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Value at Receipt</label>
                <input type="number" name="airdrop[value_at_receipt]" class="form-input" step="0.01" value={if @editing_item && @editing_item.value_at_receipt, do: Decimal.to_string(@editing_item.value_at_receipt), else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Current Value</label>
                <input type="number" name="airdrop[current_value]" class="form-input" step="0.01" value={if @editing_item && @editing_item.current_value, do: Decimal.to_string(@editing_item.current_value), else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Currency</label>
                <input type="text" name="airdrop[currency]" class="form-input" value={if @editing_item, do: @editing_item.currency, else: "USD"} />
              </div>
              <div class="form-group">
                <label class="form-label">Wallet Address</label>
                <input type="text" name="airdrop[wallet_address]" class="form-input" value={if @editing_item, do: @editing_item.wallet_address, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Received Date</label>
                <input type="date" name="airdrop[received_date]" class="form-input" value={if @editing_item, do: @editing_item.received_date, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Claimed</label>
                <select name="airdrop[claimed]" class="form-select">
                  <option value="false" selected={!@editing_item || !@editing_item.claimed}>No</option>
                  <option value="true" selected={@editing_item && @editing_item.claimed}>Yes</option>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Eligible</label>
                <select name="airdrop[eligible]" class="form-select">
                  <option value="true" selected={!@editing_item || @editing_item.eligible}>Yes</option>
                  <option value="false" selected={@editing_item && !@editing_item.eligible}>No</option>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Tax Treated</label>
                <select name="airdrop[tax_treated]" class="form-select">
                  <option value="false" selected={!@editing_item || !@editing_item.tax_treated}>No</option>
                  <option value="true" selected={@editing_item && @editing_item.tax_treated}>Yes</option>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="airdrop[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">{if @show_form == :edit, do: "Update Event", else: "Add Event"}</button>
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
    assign(socket, airdrops: Analytics.list_airdrops())
  end

  defp filtered_airdrops(airdrops, nil), do: airdrops
  defp filtered_airdrops(airdrops, type), do: Enum.filter(airdrops, &(&1.event_type == type))

  defp humanize(str), do: str |> String.replace("_", " ") |> String.split(" ") |> Enum.map(&String.capitalize/1) |> Enum.join(" ")

  defp type_tag("airdrop"), do: "tag-jade"
  defp type_tag("fork"), do: "tag-sky"
  defp type_tag("token_split"), do: "tag-lemon"
  defp type_tag("migration"), do: "tag-rose"
  defp type_tag(_), do: ""
end
