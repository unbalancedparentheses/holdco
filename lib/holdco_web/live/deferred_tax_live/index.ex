defmodule HoldcoWeb.DeferredTaxLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Tax, Corporate, Money}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Tax.subscribe()

    deferred_taxes = Tax.list_deferred_taxes()
    companies = Corporate.list_companies()
    current_year = Date.utc_today().year

    {:ok,
     assign(socket,
       page_title: "Deferred Taxes",
       deferred_taxes: deferred_taxes,
       companies: companies,
       selected_company_id: "",
       selected_year: "",
       selected_type: "",
       show_form: false,
       editing_item: nil,
       calc_result: nil,
       current_year: current_year,
       total_assets: Decimal.new(0),
       total_liabilities: Decimal.new(0),
       net_position: Decimal.new(0)
     )
     |> compute_totals()}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("show_form", _, socket),
    do: {:noreply, assign(socket, show_form: :add, editing_item: nil)}

  def handle_event("close_form", _, socket),
    do: {:noreply, assign(socket, show_form: false, editing_item: nil, calc_result: nil)}

  def handle_event("filter", params, socket) do
    company_id = if params["company_id"] == "", do: nil, else: params["company_id"]
    year = if params["year"] == "", do: nil, else: params["year"]
    dtype = if params["deferred_type"] == "", do: nil, else: params["deferred_type"]

    opts = []
    opts = if company_id, do: [{:company_id, String.to_integer(company_id)} | opts], else: opts
    opts = if year, do: [{:tax_year, String.to_integer(year)} | opts], else: opts
    opts = if dtype, do: [{:deferred_type, dtype} | opts], else: opts

    deferred_taxes = Tax.list_deferred_taxes(opts)

    {:noreply,
     assign(socket,
       deferred_taxes: deferred_taxes,
       selected_company_id: params["company_id"] || "",
       selected_year: params["year"] || "",
       selected_type: params["deferred_type"] || ""
     )
     |> compute_totals()}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    dt = Tax.get_deferred_tax!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: dt)}
  end

  def handle_event("calculate", %{"calc" => params}, socket) do
    result = Tax.calculate_deferred_tax(params["book_basis"], params["tax_basis"], params["tax_rate"])
    {:noreply, assign(socket, calc_result: result)}
  end

  def handle_event("close_calculation", _, socket) do
    {:noreply, assign(socket, calc_result: nil)}
  end

  # Permission gating
  def handle_event("save", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("update", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("delete", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("save", %{"deferred_tax" => params}, socket) do
    case Tax.create_deferred_tax(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Deferred tax created")
         |> assign(show_form: false, editing_item: nil)
         |> compute_totals()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create deferred tax")}
    end
  end

  def handle_event("update", %{"deferred_tax" => params}, socket) do
    dt = socket.assigns.editing_item

    case Tax.update_deferred_tax(dt, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Deferred tax updated")
         |> assign(show_form: false, editing_item: nil)
         |> compute_totals()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update deferred tax")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    dt = Tax.get_deferred_tax!(String.to_integer(id))
    Tax.delete_deferred_tax(dt)

    {:noreply,
     reload(socket)
     |> put_flash(:info, "Deferred tax deleted")
     |> compute_totals()}
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, reload(socket) |> compute_totals()}

  defp reload(socket) do
    opts = build_filter_opts(socket.assigns)
    assign(socket, deferred_taxes: Tax.list_deferred_taxes(opts))
  end

  defp build_filter_opts(assigns) do
    opts = []
    opts = if assigns.selected_company_id != "", do: [{:company_id, String.to_integer(assigns.selected_company_id)} | opts], else: opts
    opts = if assigns.selected_year != "", do: [{:tax_year, String.to_integer(assigns.selected_year)} | opts], else: opts
    opts = if assigns.selected_type != "", do: [{:deferred_type, assigns.selected_type} | opts], else: opts
    opts
  end

  defp compute_totals(socket) do
    dts = socket.assigns.deferred_taxes

    total_assets =
      dts
      |> Enum.filter(&(&1.deferred_type == "asset"))
      |> Enum.reduce(Decimal.new(0), fn dt, acc -> Money.add(acc, dt.deferred_amount) end)

    total_liabilities =
      dts
      |> Enum.filter(&(&1.deferred_type == "liability"))
      |> Enum.reduce(Decimal.new(0), fn dt, acc -> Money.add(acc, dt.deferred_amount) end)

    net_position = Money.sub(total_assets, total_liabilities)

    assign(socket,
      total_assets: total_assets,
      total_liabilities: total_liabilities,
      net_position: net_position
    )
  end

  defp format_decimal(nil), do: "---"
  defp format_decimal(val), do: Money.format(val, 2)

  defp type_tag("asset"), do: "tag-jade"
  defp type_tag("liability"), do: "tag-coral"
  defp type_tag(_), do: "tag-ink"

  defp source_label(nil), do: "---"
  defp source_label("depreciation"), do: "Depreciation"
  defp source_label("unrealized_gains"), do: "Unrealized Gains"
  defp source_label("accrued_expenses"), do: "Accrued Expenses"
  defp source_label("nol_carryforward"), do: "NOL Carryforward"
  defp source_label("lease_liability"), do: "Lease Liability"
  defp source_label(other), do: other

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Deferred Taxes</h1>
          <p class="deck">Track deferred tax assets and liabilities from temporary differences</p>
        </div>
        <div style="display: flex; gap: 0.5rem; align-items: center;">
          <%= if @can_write do %>
            <button class="btn btn-primary" phx-click="show_form">Add Deferred Tax</button>
          <% end %>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <%!-- Filters --%>
    <div class="section">
      <form phx-change="filter" style="display: flex; gap: 0.75rem; align-items: center; flex-wrap: wrap;">
        <div>
          <label class="form-label" style="font-size: 0.85rem;">Company</label>
          <select name="company_id" class="form-select" style="width: auto; padding: 0.3rem 0.5rem;">
            <option value="">All Companies</option>
            <%= for c <- @companies do %>
              <option value={c.id} selected={to_string(c.id) == @selected_company_id}>{c.name}</option>
            <% end %>
          </select>
        </div>
        <div>
          <label class="form-label" style="font-size: 0.85rem;">Year</label>
          <select name="year" class="form-select" style="width: auto; padding: 0.3rem 0.5rem;">
            <option value="">All Years</option>
            <%= for y <- (@current_year - 5)..(@current_year + 1) do %>
              <option value={y} selected={to_string(y) == @selected_year}>{y}</option>
            <% end %>
          </select>
        </div>
        <div>
          <label class="form-label" style="font-size: 0.85rem;">Type</label>
          <select name="deferred_type" class="form-select" style="width: auto; padding: 0.3rem 0.5rem;">
            <option value="">All Types</option>
            <option value="asset" selected={@selected_type == "asset"}>Asset</option>
            <option value="liability" selected={@selected_type == "liability"}>Liability</option>
          </select>
        </div>
      </form>
    </div>

    <%!-- Summary --%>
    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Items</div>
        <div class="metric-value">{length(@deferred_taxes)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Deferred Assets</div>
        <div class="metric-value num-positive">{format_decimal(@total_assets)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Deferred Liabilities</div>
        <div class="metric-value num-negative">{format_decimal(@total_liabilities)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Net Position</div>
        <div class="metric-value">{format_decimal(@net_position)}</div>
      </div>
    </div>

    <%!-- Calculator --%>
    <div class="section">
      <div class="section-head">
        <h2>Calculate Deferred Tax</h2>
      </div>
      <div class="panel" style="padding: 1rem;">
        <form phx-submit="calculate" style="display: flex; gap: 0.75rem; align-items: flex-end; flex-wrap: wrap;">
          <div class="form-group" style="margin-bottom: 0;">
            <label class="form-label" style="font-size: 0.85rem;">Book Basis</label>
            <input type="number" step="0.01" name="calc[book_basis]" class="form-input" style="width: 160px;" required />
          </div>
          <div class="form-group" style="margin-bottom: 0;">
            <label class="form-label" style="font-size: 0.85rem;">Tax Basis</label>
            <input type="number" step="0.01" name="calc[tax_basis]" class="form-input" style="width: 160px;" required />
          </div>
          <div class="form-group" style="margin-bottom: 0;">
            <label class="form-label" style="font-size: 0.85rem;">Tax Rate (%)</label>
            <input type="number" step="0.01" name="calc[tax_rate]" class="form-input" style="width: 120px;" required />
          </div>
          <button type="submit" class="btn btn-primary">Calculate</button>
        </form>

        <%= if @calc_result do %>
          <div class="metrics-strip" style="margin-top: 1rem;">
            <div class="metric-cell">
              <div class="metric-label">Temporary Difference</div>
              <div class="metric-value">{format_decimal(@calc_result.temporary_difference)}</div>
            </div>
            <div class="metric-cell">
              <div class="metric-label">Deferred Amount</div>
              <div class="metric-value">{format_decimal(@calc_result.deferred_amount)}</div>
            </div>
            <div class="metric-cell">
              <div class="metric-label">Type</div>
              <div class="metric-value">
                <span class={"tag #{type_tag(@calc_result.deferred_type)}"}>{@calc_result.deferred_type}</span>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Deferred Tax Items</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Year</th>
              <th>Description</th>
              <th>Type</th>
              <th>Source</th>
              <th class="th-num">Book Basis</th>
              <th class="th-num">Tax Basis</th>
              <th class="th-num">Temp Diff</th>
              <th class="th-num">Deferred Amt</th>
              <th>Company</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for dt <- @deferred_taxes do %>
              <tr>
                <td>{dt.tax_year}</td>
                <td class="td-name">{dt.description}</td>
                <td><span class={"tag #{type_tag(dt.deferred_type)}"}>{dt.deferred_type}</span></td>
                <td>{source_label(dt.source)}</td>
                <td class="td-num">{format_decimal(dt.book_basis)}</td>
                <td class="td-num">{format_decimal(dt.tax_basis)}</td>
                <td class="td-num">{format_decimal(dt.temporary_difference)}</td>
                <td class="td-num">{format_decimal(dt.deferred_amount)}</td>
                <td>
                  <%= if dt.company do %>
                    <.link navigate={~p"/companies/#{dt.company.id}"} class="td-link">{dt.company.name}</.link>
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit" phx-value-id={dt.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete" phx-value-id={dt.id} class="btn btn-danger btn-sm" data-confirm="Delete?">Del</button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @deferred_taxes == [] do %>
          <div class="empty-state">
            <p>No deferred tax items found.</p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_form">Add Your First Deferred Tax</button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%!-- Add/Edit Form Modal --%>
    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit Deferred Tax", else: "Add Deferred Tax"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="deferred_tax[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={@editing_item && @editing_item.company_id == c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Tax Year *</label>
                <input type="number" name="deferred_tax[tax_year]" class="form-input" value={if @editing_item, do: @editing_item.tax_year, else: @current_year} required />
              </div>
              <div class="form-group">
                <label class="form-label">Description *</label>
                <input type="text" name="deferred_tax[description]" class="form-input" value={if @editing_item, do: @editing_item.description, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Deferred Type *</label>
                <select name="deferred_tax[deferred_type]" class="form-select" required>
                  <option value="">Select type</option>
                  <option value="asset" selected={@editing_item && @editing_item.deferred_type == "asset"}>Asset</option>
                  <option value="liability" selected={@editing_item && @editing_item.deferred_type == "liability"}>Liability</option>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Source</label>
                <select name="deferred_tax[source]" class="form-select">
                  <option value="">-- None --</option>
                  <%= for s <- ~w(depreciation unrealized_gains accrued_expenses nol_carryforward lease_liability) do %>
                    <option value={s} selected={@editing_item && @editing_item.source == s}>{source_label(s)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Book Basis</label>
                <input type="number" step="0.01" name="deferred_tax[book_basis]" class="form-input" value={if @editing_item, do: @editing_item.book_basis, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Tax Basis</label>
                <input type="number" step="0.01" name="deferred_tax[tax_basis]" class="form-input" value={if @editing_item, do: @editing_item.tax_basis, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Temporary Difference</label>
                <input type="number" step="0.01" name="deferred_tax[temporary_difference]" class="form-input" value={if @editing_item, do: @editing_item.temporary_difference, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Tax Rate (%)</label>
                <input type="number" step="0.01" name="deferred_tax[tax_rate]" class="form-input" value={if @editing_item, do: @editing_item.tax_rate, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Deferred Amount</label>
                <input type="number" step="0.01" name="deferred_tax[deferred_amount]" class="form-input" value={if @editing_item, do: @editing_item.deferred_amount, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="deferred_tax[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">
                  {if @show_form == :edit, do: "Update Deferred Tax", else: "Add Deferred Tax"}
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
end
