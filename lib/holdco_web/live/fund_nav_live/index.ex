defmodule HoldcoWeb.FundNavLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Fund, Corporate, Money}

  @impl true
  def mount(_params, _session, socket) do
    companies = Corporate.list_companies()
    navs = Fund.list_fund_navs()

    {:ok,
     assign(socket,
       page_title: "Fund NAV",
       companies: companies,
       navs: navs,
       selected_company_id: "",
       show_form: false,
       editing_item: nil,
       nav_calculation: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("filter_company", %{"company_id" => id}, socket) do
    company_id = if id == "", do: nil, else: String.to_integer(id)
    navs = Fund.list_fund_navs(company_id)

    {:noreply,
     assign(socket,
       selected_company_id: id,
       navs: navs,
       nav_calculation: nil
     )}
  end

  def handle_event("calculate_nav", %{"company_id" => id}, socket) do
    company_id = String.to_integer(id)
    calculation = Fund.calculate_fund_nav(company_id)
    {:noreply, assign(socket, nav_calculation: calculation)}
  end

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: :add, editing_item: nil)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false, editing_item: nil)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    nav = Fund.get_fund_nav!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: nav)}
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

  def handle_event("save", %{"fund_nav" => params}, socket) do
    case Fund.create_fund_nav(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Fund NAV record added")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add Fund NAV record")}
    end
  end

  def handle_event("update", %{"fund_nav" => params}, socket) do
    nav = socket.assigns.editing_item

    case Fund.update_fund_nav(nav, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Fund NAV record updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update Fund NAV record")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    nav = Fund.get_fund_nav!(String.to_integer(id))

    case Fund.delete_fund_nav(nav) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Fund NAV record deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete Fund NAV record")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Fund NAV</h1>
          <p class="deck">Net Asset Value history and calculations</p>
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
          <%= if @selected_company_id != "" do %>
            <button class="btn btn-secondary" phx-click="calculate_nav" phx-value-company_id={@selected_company_id}>Calculate NAV</button>
          <% end %>
          <%= if @can_write do %>
            <button class="btn btn-primary" phx-click="show_form">Add NAV Record</button>
          <% end %>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <%= if @nav_calculation do %>
      <div class="metrics-strip">
        <div class="metric-cell">
          <div class="metric-label">Total Assets</div>
          <div class="metric-value">${format_decimal(@nav_calculation.total_assets)}</div>
        </div>
        <div class="metric-cell">
          <div class="metric-label">Total Liabilities</div>
          <div class="metric-value num-negative">${format_decimal(@nav_calculation.total_liabilities)}</div>
        </div>
        <div class="metric-cell">
          <div class="metric-label">Net Asset Value</div>
          <div class="metric-value">${format_decimal(@nav_calculation.net_asset_value)}</div>
        </div>
        <div class="metric-cell">
          <div class="metric-label">NAV per Unit</div>
          <div class="metric-value">${format_decimal(@nav_calculation.nav_per_unit)}</div>
        </div>
      </div>
    <% end %>

    <div class="section">
      <div class="section-head">
        <h2>NAV History</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Date</th>
              <th>Company</th>
              <th class="th-num">Total Assets</th>
              <th class="th-num">Total Liabilities</th>
              <th class="th-num">NAV</th>
              <th class="th-num">NAV/Unit</th>
              <th class="th-num">Units</th>
              <th>Currency</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for nav <- @navs do %>
              <tr>
                <td class="td-mono">{nav.nav_date}</td>
                <td>
                  <%= if nav.company do %>
                    <.link navigate={~p"/companies/#{nav.company.id}"} class="td-link">{nav.company.name}</.link>
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td class="td-num">{format_decimal(nav.total_assets)}</td>
                <td class="td-num">{format_decimal(nav.total_liabilities)}</td>
                <td class="td-num">{format_decimal(nav.net_asset_value)}</td>
                <td class="td-num">{format_decimal(nav.nav_per_unit)}</td>
                <td class="td-num">{format_decimal(nav.units_outstanding)}</td>
                <td>{nav.currency}</td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit" phx-value-id={nav.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete" phx-value-id={nav.id} class="btn btn-danger btn-sm" data-confirm="Delete this NAV record?">Del</button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @navs == [] do %>
          <div class="empty-state">
            <p>No NAV records found.</p>
            <p style="color: var(--muted); font-size: 0.9rem;">
              Track net asset values over time for your funds.
            </p>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit NAV Record", else: "Add NAV Record"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="fund_nav[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={@editing_item && @editing_item.company_id == c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">NAV Date *</label>
                <input type="date" name="fund_nav[nav_date]" class="form-input" value={if @editing_item, do: @editing_item.nav_date, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Total Assets</label>
                <input type="number" name="fund_nav[total_assets]" class="form-input" step="any" value={if @editing_item, do: @editing_item.total_assets, else: "0"} />
              </div>
              <div class="form-group">
                <label class="form-label">Total Liabilities</label>
                <input type="number" name="fund_nav[total_liabilities]" class="form-input" step="any" value={if @editing_item, do: @editing_item.total_liabilities, else: "0"} />
              </div>
              <div class="form-group">
                <label class="form-label">Net Asset Value</label>
                <input type="number" name="fund_nav[net_asset_value]" class="form-input" step="any" value={if @editing_item, do: @editing_item.net_asset_value, else: "0"} />
              </div>
              <div class="form-group">
                <label class="form-label">NAV per Unit</label>
                <input type="number" name="fund_nav[nav_per_unit]" class="form-input" step="any" value={if @editing_item, do: @editing_item.nav_per_unit, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Units Outstanding</label>
                <input type="number" name="fund_nav[units_outstanding]" class="form-input" step="any" value={if @editing_item, do: @editing_item.units_outstanding, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Currency</label>
                <input type="text" name="fund_nav[currency]" class="form-input" value={if @editing_item, do: @editing_item.currency, else: "USD"} />
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="fund_nav[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">{if @show_form == :edit, do: "Update", else: "Add Record"}</button>
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
    company_id =
      case socket.assigns.selected_company_id do
        "" -> nil
        id -> String.to_integer(id)
      end

    navs = Fund.list_fund_navs(company_id)
    assign(socket, navs: navs)
  end

  defp format_decimal(nil), do: "---"
  defp format_decimal(%Decimal{} = d), do: d |> Decimal.round(2) |> Decimal.to_string()
  defp format_decimal(n) when is_number(n), do: Money.format(n)
  defp format_decimal(_), do: "---"
end
