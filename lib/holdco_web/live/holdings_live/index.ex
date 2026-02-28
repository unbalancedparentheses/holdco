defmodule HoldcoWeb.HoldingsLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Assets, Corporate, Portfolio}
  alias Holdco.Money

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Holdco.Platform.subscribe("portfolio")

    holdings = Assets.list_holdings()
    companies = Corporate.list_companies()
    allocation = Portfolio.asset_allocation()
    total_value = Enum.reduce(holdings, Decimal.new(0), fn h, acc -> Money.add(acc, Money.to_decimal(h.quantity)) end)

    asset_types =
      case Holdco.Platform.get_setting_value("asset_types") do
        nil -> ~w(equity etf crypto commodity bond real_estate private_equity fund other)
        str -> String.split(str, ",", trim: true) |> Enum.map(&String.trim/1)
      end

    {:ok,
     assign(socket,
       page_title: "Positions",
       all_holdings: holdings,
       holdings: holdings,
       companies: companies,
       allocation: allocation,
       total_value: total_value,
       asset_types: asset_types,
       show_form: false,
       editing_item: nil,
       selected_company_id: "",
       sort_by: "asset",
       sort_dir: "asc"
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("show_form", _, socket),
    do: {:noreply, assign(socket, show_form: :add, editing_item: nil)}

  def handle_event("close_form", _, socket),
    do: {:noreply, assign(socket, show_form: false, editing_item: nil)}

  def handle_event("edit", %{"id" => id}, socket) do
    holding = Assets.get_holding!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: holding)}
  end

  def handle_event("sort", %{"field" => field}, socket) do
    {sort_by, sort_dir} =
      if socket.assigns.sort_by == field do
        {field, if(socket.assigns.sort_dir == "asc", do: "desc", else: "asc")}
      else
        {field, "asc"}
      end

    {:noreply, assign(socket, sort_by: sort_by, sort_dir: sort_dir) |> apply_sort_and_filter()}
  end

  def handle_event("filter_company", %{"company_id" => id}, socket) do
    {:noreply, assign(socket, selected_company_id: id) |> apply_sort_and_filter()}
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

  def handle_event("save", %{"holding" => params}, socket) do
    case Assets.create_holding(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket) |> put_flash(:info, "Position added") |> assign(show_form: false)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add holding")}
    end
  end

  def handle_event("update", %{"holding" => params}, socket) do
    holding = socket.assigns.editing_item

    case Assets.update_holding(holding, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Position updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update holding")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    holding = Assets.get_holding!(String.to_integer(id))
    Assets.delete_holding(holding)
    {:noreply, reload(socket) |> put_flash(:info, "Position deleted")}
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, reload(socket)}

  defp reload(socket) do
    holdings = Assets.list_holdings()
    allocation = Portfolio.asset_allocation()
    total_value = Enum.reduce(holdings, Decimal.new(0), fn h, acc -> Money.add(acc, Money.to_decimal(h.quantity)) end)

    assign(socket,
      all_holdings: holdings,
      allocation: allocation,
      total_value: total_value
    )
    |> apply_sort_and_filter()
  end

  defp apply_sort_and_filter(socket) do
    holdings = socket.assigns.all_holdings
    company_id = socket.assigns.selected_company_id

    filtered =
      if company_id == "" or company_id == nil do
        holdings
      else
        cid = String.to_integer(company_id)
        Enum.filter(holdings, &(&1.company_id == cid))
      end

    sorted = sort_holdings(filtered, socket.assigns.sort_by, socket.assigns.sort_dir)
    assign(socket, holdings: sorted)
  end

  defp sort_holdings(holdings, field, dir) do
    sorter =
      case field do
        "asset" -> &((&1.asset || "") |> String.downcase())
        "ticker" -> &((&1.ticker || "") |> String.downcase())
        "quantity" -> &(&1.quantity || 0.0)
        "type" -> &((&1.asset_type || "") |> String.downcase())
        "currency" -> &((&1.currency || "") |> String.downcase())
        "company" -> &(if(&1.company, do: &1.company.name |> String.downcase(), else: ""))
        _ -> &((&1.asset || "") |> String.downcase())
      end

    sorted = Enum.sort_by(holdings, sorter)
    if dir == "desc", do: Enum.reverse(sorted), else: sorted
  end

  defp sort_indicator(assigns, field) do
    if assigns.sort_by == field do
      if assigns.sort_dir == "asc", do: " ↑", else: " ↓"
    else
      ""
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Positions</h1>
          <p class="deck">{length(@holdings)} positions across all entities</p>
        </div>
        <div style="display: flex; gap: 0.5rem; align-items: center;">
          <a href={~p"/export/holdings.csv"} class="btn btn-secondary">
            Export CSV
          </a>
          <%= if @can_write do %>
            <.link navigate={~p"/import?type=holdings"} class="btn btn-secondary">
              Import CSV
            </.link>
            <button class="btn btn-primary" phx-click="show_form">Add Position</button>
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
        <div class="metric-label">Total Positions</div>
        <div class="metric-value">{length(@holdings)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Total Quantity Value</div>
        <div class="metric-value">{format_number(@total_value)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Asset Types</div>
        <div class="metric-value">{length(@allocation)}</div>
      </div>
    </div>

    <div class="grid-2">
      <div class="section">
        <div class="section-head">
          <h2>Allocation by Type</h2>
        </div>
        <div class="panel" style="padding: 1rem;">
          <% alloc_colors = ["#4a8c87", "#6b87a0", "#5f8f6e", "#8a5a6a", "#c08060", "#b89040", "#b0605e"] %>
          <% alloc_total = Enum.reduce(@allocation, Decimal.new(0), fn a, acc -> Money.add(acc, Money.max(a.value, a.count)) end) %>
          <div class="stacked-bar">
            <%= for {a, color} <- Enum.zip(@allocation, alloc_colors) do %>
              <% val = if Money.gt?(a.value, 0), do: a.value, else: Money.to_decimal(a.count) %>
              <% pct = if Money.gt?(alloc_total, 0), do: Money.to_float(Money.round(Money.mult(Money.div(val, alloc_total), 100), 1)), else: 0 %>
              <div class="stacked-bar-segment" style={"width: #{pct}%; background: #{color};"} title={"#{a.type}: #{pct}%"}>
                <%= if pct > 12 do %>
                  <span class="stacked-bar-label">{a.type}</span>
                <% end %>
              </div>
            <% end %>
          </div>
          <div class="stacked-bar-legend">
            <%= for {a, color} <- Enum.zip(@allocation, alloc_colors) do %>
              <% val = if Money.gt?(a.value, 0), do: a.value, else: Money.to_decimal(a.count) %>
              <% pct = if Money.gt?(alloc_total, 0), do: Money.to_float(Money.round(Money.mult(Money.div(val, alloc_total), 100), 1)), else: 0 %>
              <span class="stacked-bar-legend-item">
                <span class="stacked-bar-swatch" style={"background: #{color};"}></span>
                {a.type} <span class="stacked-bar-pct">{pct}%</span>
              </span>
            <% end %>
          </div>
        </div>
      </div>
      <div class="section">
        <div class="section-head">
          <h2>By Type Summary</h2>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Type</th>
                <th class="th-num">Count</th>
                <th class="th-num">Total Qty</th>
              </tr>
            </thead>
            <tbody>
              <%= for a <- @allocation do %>
                <tr>
                  <td><span class="tag tag-ink">{a.type}</span></td>
                  <td class="td-num">{a.count}</td>
                  <td class="td-num">{format_number(a.value || 0)}</td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>All Positions</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th style="cursor: pointer;" phx-click="sort" phx-value-field="asset">Asset{sort_indicator(assigns, "asset")}</th>
              <th style="cursor: pointer;" phx-click="sort" phx-value-field="ticker">Ticker{sort_indicator(assigns, "ticker")}</th>
              <th class="th-num" style="cursor: pointer;" phx-click="sort" phx-value-field="quantity">Qty{sort_indicator(assigns, "quantity")}</th>
              <th>Unit</th>
              <th style="cursor: pointer;" phx-click="sort" phx-value-field="type">Type{sort_indicator(assigns, "type")}</th>
              <th style="cursor: pointer;" phx-click="sort" phx-value-field="currency">Currency{sort_indicator(assigns, "currency")}</th>
              <th style="cursor: pointer;" phx-click="sort" phx-value-field="company">Company{sort_indicator(assigns, "company")}</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for h <- @holdings do %>
              <tr>
                <td class="td-name">
                  <.link navigate={~p"/holdings/#{h.id}"} class="td-link">{h.asset}</.link>
                </td>
                <td class="td-mono">{h.ticker}</td>
                <td class="td-num">{h.quantity}</td>
                <td>{h.unit}</td>
                <td><span class="tag tag-ink">{h.asset_type}</span></td>
                <td>{h.currency}</td>
                <td>
                  <%= if h.company do %>
                    <.link navigate={~p"/companies/#{h.company.id}"} class="td-link">{h.company.name}</.link>
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit" phx-value-id={h.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button
                        phx-click="delete"
                        phx-value-id={h.id}
                        class="btn btn-danger btn-sm"
                        data-confirm="Delete this holding?"
                      >
                        Del
                      </button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @holdings == [] do %>
          <div class="empty-state">
            <p>No positions yet.</p>
            <p style="color: var(--muted); font-size: 0.9rem;">Positions track portfolio assets across companies — stocks, crypto, real estate, and more.</p>
            <%= if @can_write do %>
              <div style="margin-top: 0.75rem;">
                <button class="btn btn-primary btn-sm" phx-click="show_form">Add your first holding</button>
                <span style="margin: 0 0.5rem; color: var(--muted);">or</span>
                <.link navigate={~p"/import?type=holdings"} class="btn btn-secondary btn-sm">Import from CSV</.link>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit Position", else: "Add Position"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="holding[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={@editing_item && @editing_item.company_id == c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Asset Name *</label>
                <input type="text" name="holding[asset]" class="form-input" required value={if @editing_item, do: @editing_item.asset} />
              </div>
              <div class="form-group">
                <label class="form-label">Ticker</label>
                <input type="text" name="holding[ticker]" class="form-input" value={if @editing_item, do: @editing_item.ticker} />
              </div>
              <div class="form-group">
                <label class="form-label">Quantity</label>
                <input type="number" name="holding[quantity]" class="form-input" step="any" value={if @editing_item, do: @editing_item.quantity} />
              </div>
              <div class="form-group">
                <label class="form-label">Unit</label>
                <input type="text" name="holding[unit]" class="form-input" value={if @editing_item, do: @editing_item.unit} />
              </div>
              <div class="form-group">
                <label class="form-label">Asset Type</label>
                <select name="holding[asset_type]" class="form-select">
                  <%= for t <- @asset_types do %>
                    <option value={t} selected={@editing_item && @editing_item.asset_type == t}>{humanize_type(t)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Currency</label>
                <input type="text" name="holding[currency]" class="form-input" value={if @editing_item, do: @editing_item.currency, else: "USD"} />
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">{if @show_form == :edit, do: "Save Changes", else: "Add Position"}</button>
                <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp format_number(%Decimal{} = n),
    do: n |> Decimal.round(0) |> Decimal.to_string() |> add_commas()

  defp format_number(n) when is_float(n),
    do: Money.to_float(Money.round(n, 0)) |> :erlang.float_to_binary(decimals: 0) |> add_commas()

  defp format_number(n) when is_integer(n), do: Integer.to_string(n) |> add_commas()
  defp format_number(_), do: "0"

  defp add_commas(str) do
    str |> String.reverse() |> String.replace(~r/(\d{3})(?=\d)/, "\\1,") |> String.reverse()
  end

  defp humanize_type(type) do
    type |> String.replace("_", " ") |> String.split(" ") |> Enum.map_join(" ", &String.capitalize/1)
  end
end
