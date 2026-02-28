defmodule HoldcoWeb.IpAssetLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.Corporate
  alias Holdco.Corporate.IpAsset

  @impl true
  def mount(_params, _session, socket) do
    companies = Corporate.list_companies()
    assets = Corporate.list_ip_assets()
    summary = Corporate.ip_portfolio_summary()
    expiring = Corporate.expiring_ip_assets(90)

    {:ok,
     assign(socket,
       page_title: "IP Assets",
       companies: companies,
       assets: assets,
       summary: summary,
       expiring: expiring,
       selected_company_id: "",
       show_form: false,
       editing_item: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("filter_company", %{"company_id" => id}, socket) do
    company_id = if id == "", do: nil, else: String.to_integer(id)
    assets = Corporate.list_ip_assets(company_id)
    summary = Corporate.ip_portfolio_summary(company_id)

    {:noreply,
     assign(socket,
       selected_company_id: id,
       assets: assets,
       summary: summary
     )}
  end

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: :add, editing_item: nil)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false, editing_item: nil)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    asset = Corporate.get_ip_asset!(String.to_integer(id))
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

  def handle_event("save", %{"ip_asset" => params}, socket) do
    case Corporate.create_ip_asset(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "IP asset added")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add IP asset")}
    end
  end

  def handle_event("update", %{"ip_asset" => params}, socket) do
    asset = socket.assigns.editing_item

    case Corporate.update_ip_asset(asset, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "IP asset updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update IP asset")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    asset = Corporate.get_ip_asset!(String.to_integer(id))

    case Corporate.delete_ip_asset(asset) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "IP asset deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete IP asset")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>IP Asset Register</h1>
          <p class="deck">Patents, trademarks, domains, and intellectual property portfolio</p>
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
            <button class="btn btn-primary" phx-click="show_form">Add IP Asset</button>
          <% end %>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Assets</div>
        <div class="metric-value">{length(@assets)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Total Valuation</div>
        <div class="metric-value">${format_number(@summary.total_valuation)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Annual Cost</div>
        <div class="metric-value">${format_number(@summary.total_annual_cost)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Expiring (90d)</div>
        <div class="metric-value num-negative">{length(@expiring)}</div>
      </div>
    </div>

    <%= if @summary.by_type != [] do %>
      <div class="section">
        <div class="section-head"><h2>Portfolio Summary</h2></div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Asset Type</th>
                <th class="th-num">Count</th>
                <th class="th-num">Total Valuation</th>
              </tr>
            </thead>
            <tbody>
              <%= for row <- @summary.by_type do %>
                <tr>
                  <td><span class="tag tag-sky">{humanize_asset_type(row.asset_type)}</span></td>
                  <td class="td-num">{row.count}</td>
                  <td class="td-num">${format_number(row.total_valuation || 0)}</td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    <% end %>

    <%= if @expiring != [] do %>
      <div class="section">
        <div class="section-head"><h2>Expiry Calendar (Next 90 Days)</h2></div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Name</th>
                <th>Company</th>
                <th>Type</th>
                <th>Expiry Date</th>
                <th>Jurisdiction</th>
              </tr>
            </thead>
            <tbody>
              <%= for ip <- @expiring do %>
                <tr>
                  <td class="td-name">{ip.name}</td>
                  <td>{if ip.company, do: ip.company.name, else: "---"}</td>
                  <td><span class="tag tag-sky">{humanize_asset_type(ip.asset_type)}</span></td>
                  <td class="td-mono">{ip.expiry_date}</td>
                  <td>{ip.jurisdiction || "---"}</td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    <% end %>

    <div class="section">
      <div class="section-head"><h2>All IP Assets</h2></div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>Company</th>
              <th>Type</th>
              <th>Status</th>
              <th>Registration #</th>
              <th>Jurisdiction</th>
              <th>Expiry</th>
              <th class="th-num">Valuation</th>
              <th class="th-num">Annual Cost</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for ip <- @assets do %>
              <tr>
                <td class="td-name">{ip.name}</td>
                <td>{if ip.company, do: ip.company.name, else: "---"}</td>
                <td><span class="tag tag-sky">{humanize_asset_type(ip.asset_type)}</span></td>
                <td><span class={"tag #{ip_status_tag(ip.status)}"}>{humanize_ip_status(ip.status)}</span></td>
                <td class="td-mono">{ip.registration_number || "---"}</td>
                <td>{ip.jurisdiction || "---"}</td>
                <td class="td-mono">{ip.expiry_date || "---"}</td>
                <td class="td-num">{if ip.valuation, do: "#{ip.currency} #{ip.valuation}", else: "---"}</td>
                <td class="td-num">{if ip.annual_cost, do: "#{ip.currency} #{ip.annual_cost}", else: "---"}</td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit" phx-value-id={ip.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete" phx-value-id={ip.id} class="btn btn-danger btn-sm" data-confirm="Delete this asset?">Del</button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @assets == [] do %>
          <div class="empty-state">
            <p>No IP assets found.</p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_form">Add Your First IP Asset</button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit IP Asset", else: "Add IP Asset"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Name *</label>
                <input type="text" name="ip_asset[name]" class="form-input"
                  value={if @editing_item, do: @editing_item.name, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="ip_asset[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={@editing_item && @editing_item.company_id == c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Asset Type</label>
                <select name="ip_asset[asset_type]" class="form-select">
                  <%= for t <- IpAsset.asset_types() do %>
                    <option value={t} selected={@editing_item && @editing_item.asset_type == t}>{humanize_asset_type(t)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Status</label>
                <select name="ip_asset[status]" class="form-select">
                  <%= for s <- IpAsset.statuses() do %>
                    <option value={s} selected={@editing_item && @editing_item.status == s}>{humanize_ip_status(s)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Registration Number</label>
                <input type="text" name="ip_asset[registration_number]" class="form-input"
                  value={if @editing_item, do: @editing_item.registration_number, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Jurisdiction</label>
                <input type="text" name="ip_asset[jurisdiction]" class="form-input"
                  value={if @editing_item, do: @editing_item.jurisdiction, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Filing Date</label>
                <input type="date" name="ip_asset[filing_date]" class="form-input"
                  value={if @editing_item, do: @editing_item.filing_date, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Grant Date</label>
                <input type="date" name="ip_asset[grant_date]" class="form-input"
                  value={if @editing_item, do: @editing_item.grant_date, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Expiry Date</label>
                <input type="date" name="ip_asset[expiry_date]" class="form-input"
                  value={if @editing_item, do: @editing_item.expiry_date, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Owner Entity</label>
                <input type="text" name="ip_asset[owner_entity]" class="form-input"
                  value={if @editing_item, do: @editing_item.owner_entity, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Valuation</label>
                <input type="number" name="ip_asset[valuation]" class="form-input" step="any"
                  value={if @editing_item, do: @editing_item.valuation, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Annual Cost</label>
                <input type="number" name="ip_asset[annual_cost]" class="form-input" step="any"
                  value={if @editing_item, do: @editing_item.annual_cost, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Currency</label>
                <input type="text" name="ip_asset[currency]" class="form-input"
                  value={if @editing_item, do: @editing_item.currency, else: "USD"} />
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="ip_asset[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">
                  {if @show_form == :edit, do: "Update Asset", else: "Add Asset"}
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

  defp reload(socket) do
    company_id =
      case socket.assigns.selected_company_id do
        "" -> nil
        id -> String.to_integer(id)
      end

    assets = Corporate.list_ip_assets(company_id)
    summary = Corporate.ip_portfolio_summary(company_id)
    expiring = Corporate.expiring_ip_assets(90)
    assign(socket, assets: assets, summary: summary, expiring: expiring)
  end

  defp humanize_asset_type("patent"), do: "Patent"
  defp humanize_asset_type("trademark"), do: "Trademark"
  defp humanize_asset_type("copyright"), do: "Copyright"
  defp humanize_asset_type("trade_secret"), do: "Trade Secret"
  defp humanize_asset_type("domain"), do: "Domain"
  defp humanize_asset_type("software_license"), do: "Software License"
  defp humanize_asset_type(other), do: other || "Patent"

  defp humanize_ip_status("pending"), do: "Pending"
  defp humanize_ip_status("active"), do: "Active"
  defp humanize_ip_status("expired"), do: "Expired"
  defp humanize_ip_status("abandoned"), do: "Abandoned"
  defp humanize_ip_status("transferred"), do: "Transferred"
  defp humanize_ip_status(other), do: other || "Pending"

  defp ip_status_tag("active"), do: "tag-jade"
  defp ip_status_tag("pending"), do: "tag-lemon"
  defp ip_status_tag("expired"), do: "tag-rose"
  defp ip_status_tag("abandoned"), do: "tag-rose"
  defp ip_status_tag("transferred"), do: "tag-sky"
  defp ip_status_tag(_), do: "tag-lemon"

  defp format_number(%Decimal{} = n),
    do: n |> Decimal.round(2) |> Decimal.to_string() |> add_commas()

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
