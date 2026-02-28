defmodule HoldcoWeb.CharitableGivingLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.Finance
  alias Holdco.Corporate
  alias Holdco.Finance.CharitableGift

  @impl true
  def mount(_params, _session, socket) do
    companies = Corporate.list_companies()
    gifts = Finance.list_charitable_gifts()
    current_year = Date.utc_today().year

    {:ok,
     assign(socket,
       page_title: "Charitable Giving",
       companies: companies,
       gifts: gifts,
       selected_year: current_year,
       show_form: false,
       editing_item: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("filter_year", %{"year" => year}, socket) do
    year = if year == "", do: nil, else: String.to_integer(year)
    gifts = if year, do: filter_by_year(Finance.list_charitable_gifts(), year), else: Finance.list_charitable_gifts()
    {:noreply, assign(socket, gifts: gifts, selected_year: year)}
  end

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: :add, editing_item: nil)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false, editing_item: nil)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    gift = Finance.get_charitable_gift!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: gift)}
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

  def handle_event("save", %{"charitable_gift" => params}, socket) do
    case Finance.create_charitable_gift(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Charitable gift recorded")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to record charitable gift")}
    end
  end

  def handle_event("update", %{"charitable_gift" => params}, socket) do
    gift = socket.assigns.editing_item

    case Finance.update_charitable_gift(gift, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Charitable gift updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update charitable gift")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    gift = Finance.get_charitable_gift!(String.to_integer(id))

    case Finance.delete_charitable_gift(gift) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Charitable gift deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete charitable gift")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Charitable Giving</h1>
          <p class="deck">Track donations, pledges, and tax deductions</p>
        </div>
        <div style="display: flex; gap: 0.5rem; align-items: center;">
          <form phx-change="filter_year" style="display: flex; align-items: center; gap: 0.5rem;">
            <label class="form-label" style="margin: 0; font-size: 0.85rem;">Year</label>
            <select name="year" class="form-select" style="width: auto; padding: 0.3rem 0.5rem;">
              <option value="">All Years</option>
              <%= for y <- year_range() do %>
                <option value={y} selected={@selected_year == y}>{y}</option>
              <% end %>
            </select>
          </form>
          <%= if @can_write do %>
            <button class="btn btn-primary" phx-click="show_form">Record Gift</button>
          <% end %>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Gifts</div>
        <div class="metric-value">{length(@gifts)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Tax Deductible</div>
        <div class="metric-value">{Enum.count(@gifts, & &1.tax_deductible)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Pledges</div>
        <div class="metric-value">{Enum.count(@gifts, &(&1.gift_type == "pledge"))}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Unfulfilled Pledges</div>
        <div class="metric-value num-negative">{Enum.count(@gifts, &(&1.gift_type == "pledge" && !&1.pledge_fulfilled))}</div>
      </div>
    </div>

    <div class="section">
      <div class="section-head"><h2>All Gifts</h2></div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Recipient</th><th>Type</th><th>Gift Type</th><th class="th-num">Amount</th>
              <th>Date</th><th>Tax Year</th><th>Deductible</th><th>Ack'd</th><th></th>
            </tr>
          </thead>
          <tbody>
            <%= for g <- @gifts do %>
              <tr>
                <td class="td-name">{g.recipient_name}</td>
                <td><span class="tag tag-sky">{humanize(g.recipient_type || "other")}</span></td>
                <td><span class={"tag #{gift_type_tag(g.gift_type)}"}>{humanize(g.gift_type || "cash")}</span></td>
                <td class="td-num">{Decimal.to_string(g.amount)}</td>
                <td class="td-mono">{g.gift_date}</td>
                <td class="td-mono">{g.tax_year || "---"}</td>
                <td>{if g.tax_deductible, do: "Yes", else: "No"}</td>
                <td>{if g.acknowledgment_received, do: "Yes", else: "No"}</td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit" phx-value-id={g.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete" phx-value-id={g.id} class="btn btn-danger btn-sm" data-confirm="Delete this gift?">Del</button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @gifts == [] do %>
          <div class="empty-state">
            <p>No charitable gifts recorded.</p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_form">Record Your First Gift</button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit Charitable Gift", else: "Record Charitable Gift"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="charitable_gift[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={@editing_item && @editing_item.company_id == c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Recipient Name *</label>
                <input type="text" name="charitable_gift[recipient_name]" class="form-input" value={if @editing_item, do: @editing_item.recipient_name, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Recipient Type</label>
                <select name="charitable_gift[recipient_type]" class="form-select">
                  <%= for t <- CharitableGift.recipient_types() do %>
                    <option value={t} selected={@editing_item && @editing_item.recipient_type == t}>{humanize(t)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">EIN Number</label>
                <input type="text" name="charitable_gift[ein_number]" class="form-input" value={if @editing_item, do: @editing_item.ein_number, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Amount *</label>
                <input type="number" name="charitable_gift[amount]" class="form-input" step="0.01" value={if @editing_item && @editing_item.amount, do: Decimal.to_string(@editing_item.amount), else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Gift Type</label>
                <select name="charitable_gift[gift_type]" class="form-select">
                  <%= for t <- CharitableGift.gift_types() do %>
                    <option value={t} selected={@editing_item && @editing_item.gift_type == t}>{humanize(t)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Gift Date *</label>
                <input type="date" name="charitable_gift[gift_date]" class="form-input" value={if @editing_item, do: @editing_item.gift_date, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Tax Year</label>
                <input type="number" name="charitable_gift[tax_year]" class="form-input" value={if @editing_item, do: @editing_item.tax_year, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Tax Deductible</label>
                <select name="charitable_gift[tax_deductible]" class="form-select">
                  <option value="true" selected={!@editing_item || @editing_item.tax_deductible}>Yes</option>
                  <option value="false" selected={@editing_item && !@editing_item.tax_deductible}>No</option>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Fair Market Value</label>
                <input type="number" name="charitable_gift[fair_market_value]" class="form-input" step="0.01" value={if @editing_item && @editing_item.fair_market_value, do: Decimal.to_string(@editing_item.fair_market_value), else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Restricted Purpose</label>
                <input type="text" name="charitable_gift[restricted_purpose]" class="form-input" value={if @editing_item, do: @editing_item.restricted_purpose, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="charitable_gift[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">{if @show_form == :edit, do: "Update", else: "Record Gift"}</button>
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
    assign(socket, gifts: Finance.list_charitable_gifts())
  end

  defp filter_by_year(gifts, year) do
    Enum.filter(gifts, &(&1.tax_year == year))
  end

  defp year_range do
    current = Date.utc_today().year
    Enum.to_list((current - 5)..current)
  end

  defp humanize(str), do: str |> String.replace("_", " ") |> String.split(" ") |> Enum.map(&String.capitalize/1) |> Enum.join(" ")

  defp gift_type_tag("cash"), do: "tag-jade"
  defp gift_type_tag("securities"), do: "tag-sky"
  defp gift_type_tag("pledge"), do: "tag-lemon"
  defp gift_type_tag(_), do: ""
end
