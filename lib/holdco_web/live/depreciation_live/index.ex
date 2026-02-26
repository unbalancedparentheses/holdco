defmodule HoldcoWeb.DepreciationLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Depreciation, Corporate}

  @impl true
  def mount(_params, _session, socket) do
    companies = Corporate.list_companies()
    assets = Depreciation.list_fixed_assets()
    metrics = compute_metrics(assets)

    {:ok,
     assign(socket,
       page_title: "Depreciation Schedule",
       companies: companies,
       assets: assets,
       metrics: metrics,
       selected_company_id: "",
       selected_asset: nil,
       schedule: [],
       show_form: false,
       editing_item: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("filter_company", %{"company_id" => id}, socket) do
    company_id = if id == "", do: nil, else: String.to_integer(id)
    assets = Depreciation.list_fixed_assets(company_id)
    metrics = compute_metrics(assets)

    {:noreply,
     assign(socket,
       selected_company_id: id,
       assets: assets,
       metrics: metrics,
       selected_asset: nil,
       schedule: []
     )}
  end

  def handle_event("select_asset", %{"id" => id}, socket) do
    asset = Depreciation.get_fixed_asset!(String.to_integer(id))
    schedule = Depreciation.schedule(asset)

    {:noreply, assign(socket, selected_asset: asset, schedule: schedule)}
  end

  def handle_event("close_schedule", _, socket) do
    {:noreply, assign(socket, selected_asset: nil, schedule: [])}
  end

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: :add, editing_item: nil)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false, editing_item: nil)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    asset = Depreciation.get_fixed_asset!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: asset)}
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

  def handle_event("save", %{"fixed_asset" => params}, socket) do
    case Depreciation.create_fixed_asset(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Fixed asset added")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add fixed asset")}
    end
  end

  def handle_event("update", %{"fixed_asset" => params}, socket) do
    asset = socket.assigns.editing_item

    case Depreciation.update_fixed_asset(asset, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Fixed asset updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update fixed asset")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    asset = Depreciation.get_fixed_asset!(String.to_integer(id))

    case Depreciation.delete_fixed_asset(asset) do
      {:ok, _} ->
        selected =
          if socket.assigns.selected_asset && socket.assigns.selected_asset.id == asset.id,
            do: nil,
            else: socket.assigns.selected_asset

        {:noreply,
         reload(socket)
         |> put_flash(:info, "Fixed asset deleted")
         |> assign(selected_asset: selected, schedule: if(selected, do: socket.assigns.schedule, else: []))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete fixed asset")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Depreciation Schedule</h1>
          <p class="deck">Fixed asset depreciation tracking and schedules</p>
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
            <button class="btn btn-primary" phx-click="show_form">Add Asset</button>
          <% end %>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Asset Value</div>
        <div class="metric-value">${format_number(@metrics.total_value)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Accumulated Depreciation</div>
        <div class="metric-value num-negative">${format_number(@metrics.total_depreciation)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Net Book Value</div>
        <div class="metric-value">${format_number(@metrics.net_book_value)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Fixed Assets</div>
        <div class="metric-value">{length(@assets)}</div>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Fixed Assets</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>Company</th>
              <th>Purchase Date</th>
              <th class="th-num">Purchase Price</th>
              <th>Useful Life</th>
              <th class="th-num">Salvage Value</th>
              <th>Method</th>
              <th>Current Book Value</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for asset <- @assets do %>
              <tr>
                <td>
                  <button
                    phx-click="select_asset"
                    phx-value-id={asset.id}
                    class="td-link td-name"
                    style="background: none; border: none; cursor: pointer; padding: 0; font: inherit; text-align: left;"
                  >
                    {asset.name}
                  </button>
                </td>
                <td>
                  <%= if asset.company do %>
                    <.link navigate={~p"/companies/#{asset.company.id}"} class="td-link">{asset.company.name}</.link>
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td class="td-mono">{asset.purchase_date}</td>
                <td class="td-num">{format_number(asset.purchase_price || 0.0)}</td>
                <td class="td-mono">{asset.useful_life_months || 0} months</td>
                <td class="td-num">{format_number(asset.salvage_value || 0.0)}</td>
                <td>
                  <span class={"tag #{method_tag(asset.depreciation_method)}"}>
                    {humanize_method(asset.depreciation_method)}
                  </span>
                </td>
                <td class="td-num">{format_number(current_book_value(asset))}</td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button
                        phx-click="edit"
                        phx-value-id={asset.id}
                        class="btn btn-secondary btn-sm"
                      >
                        Edit
                      </button>
                      <button
                        phx-click="delete"
                        phx-value-id={asset.id}
                        class="btn btn-danger btn-sm"
                        data-confirm="Delete this asset?"
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
        <%= if @assets == [] do %>
          <div class="empty-state">
            <p>No fixed assets found.</p>
            <p style="color: var(--muted); font-size: 0.9rem;">
              Track buildings, equipment, vehicles, and other fixed assets along with their depreciation schedules.
            </p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_form">Add Your First Asset</button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @selected_asset do %>
      <div class="section">
        <div class="section-head" style="display: flex; justify-content: space-between; align-items: center;">
          <h2>Depreciation Schedule: {@selected_asset.name}</h2>
          <button phx-click="close_schedule" class="btn btn-secondary btn-sm">Close</button>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Month</th>
                <th>Date</th>
                <th class="th-num">Depreciation</th>
                <th class="th-num">Accumulated</th>
                <th class="th-num">Book Value</th>
              </tr>
            </thead>
            <tbody>
              <%= for row <- @schedule do %>
                <tr>
                  <td class="td-mono">{row.month}</td>
                  <td class="td-mono">{row.date}</td>
                  <td class="td-num num-negative">{format_number(row.depreciation)}</td>
                  <td class="td-num">{format_number(row.accumulated)}</td>
                  <td class="td-num">{format_number(row.book_value)}</td>
                </tr>
              <% end %>
            </tbody>
          </table>
          <%= if @schedule == [] do %>
            <div class="empty-state">No depreciation schedule available for this asset.</div>
          <% end %>
        </div>
      </div>
    <% end %>

    <%= if @show_form do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click="noop">
          <div class="modal-header">
            <h3>{if @show_form == :edit, do: "Edit Fixed Asset", else: "Add Fixed Asset"}</h3>
          </div>
          <div class="modal-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Name *</label>
                <input
                  type="text"
                  name="fixed_asset[name]"
                  class="form-input"
                  value={if @editing_item, do: @editing_item.name, else: ""}
                  required
                />
              </div>
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="fixed_asset[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option
                      value={c.id}
                      selected={@editing_item && @editing_item.company_id == c.id}
                    >
                      {c.name}
                    </option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Purchase Date</label>
                <input
                  type="date"
                  name="fixed_asset[purchase_date]"
                  class="form-input"
                  value={if @editing_item, do: @editing_item.purchase_date, else: ""}
                />
              </div>
              <div class="form-group">
                <label class="form-label">Purchase Price</label>
                <input
                  type="number"
                  name="fixed_asset[purchase_price]"
                  class="form-input"
                  step="any"
                  value={if @editing_item, do: @editing_item.purchase_price, else: "0"}
                />
              </div>
              <div class="form-group">
                <label class="form-label">Useful Life (months)</label>
                <input
                  type="number"
                  name="fixed_asset[useful_life_months]"
                  class="form-input"
                  value={if @editing_item, do: @editing_item.useful_life_months, else: "60"}
                />
              </div>
              <div class="form-group">
                <label class="form-label">Salvage Value</label>
                <input
                  type="number"
                  name="fixed_asset[salvage_value]"
                  class="form-input"
                  step="any"
                  value={if @editing_item, do: @editing_item.salvage_value, else: "0"}
                />
              </div>
              <div class="form-group">
                <label class="form-label">Depreciation Method</label>
                <select
                  name="fixed_asset[depreciation_method]"
                  class="form-select"
                >
                  <option
                    value="straight_line"
                    selected={!@editing_item || @editing_item.depreciation_method == "straight_line"}
                  >
                    Straight Line
                  </option>
                  <option
                    value="declining_balance"
                    selected={@editing_item && @editing_item.depreciation_method == "declining_balance"}
                  >
                    Declining Balance
                  </option>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea
                  name="fixed_asset[notes]"
                  class="form-input"
                >{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">
                  {if @show_form == :edit, do: "Update Asset", else: "Add Asset"}
                </button>
                <button type="button" phx-click="close_form" class="btn btn-secondary">
                  Cancel
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp reload(socket) do
    company_id =
      case socket.assigns.selected_company_id do
        "" -> nil
        id -> String.to_integer(id)
      end

    assets = Depreciation.list_fixed_assets(company_id)
    metrics = compute_metrics(assets)
    assign(socket, assets: assets, metrics: metrics)
  end

  defp compute_metrics(assets) do
    today = Date.utc_today()

    {total_value, total_depreciation} =
      Enum.reduce(assets, {0.0, 0.0}, fn asset, {tv, td} ->
        cost = asset.purchase_price || 0.0
        schedule = Depreciation.schedule(asset)

        accumulated =
          case elapsed_months(asset, today) do
            0 ->
              0.0

            months ->
              row = Enum.find(schedule, fn r -> r.month == months end)
              if row, do: row.accumulated, else: List.last(schedule)[:accumulated] || 0.0
          end

        {tv + cost, td + accumulated}
      end)

    %{
      total_value: total_value,
      total_depreciation: total_depreciation,
      net_book_value: total_value - total_depreciation
    }
  end

  defp elapsed_months(asset, today) do
    case parse_date(asset.purchase_date) do
      nil ->
        0

      start_date ->
        diff = Date.diff(today, start_date)
        max(div(diff, 30), 0)
    end
  end

  defp current_book_value(asset) do
    schedule = Depreciation.schedule(asset)
    today = Date.utc_today()
    months = elapsed_months(asset, today)

    cond do
      months <= 0 ->
        asset.purchase_price || 0.0

      schedule == [] ->
        asset.purchase_price || 0.0

      true ->
        row = Enum.find(schedule, fn r -> r.month == months end)
        if row, do: row.book_value, else: List.last(schedule).book_value
    end
  end

  defp parse_date(nil), do: nil

  defp parse_date(date_str) do
    case Date.from_iso8601(date_str) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp method_tag("declining_balance"), do: "tag-lemon"
  defp method_tag(_), do: "tag-jade"

  defp humanize_method("straight_line"), do: "Straight Line"
  defp humanize_method("declining_balance"), do: "Declining Balance"
  defp humanize_method(other), do: other || "Straight Line"

  defp format_number(n) when is_float(n),
    do: :erlang.float_to_binary(n, decimals: 2) |> add_commas()

  defp format_number(n) when is_integer(n), do: Integer.to_string(n) |> add_commas()
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
