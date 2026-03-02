defmodule HoldcoWeb.TaxProvisionLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Tax, Corporate, Money}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Tax.subscribe()

    provisions = Tax.list_tax_provisions()
    companies = Corporate.list_companies()
    current_year = Date.utc_today().year

    {:ok,
     assign(socket,
       page_title: "Tax Provisions",
       provisions: provisions,
       companies: companies,
       selected_company_id: "",
       selected_year: "",
       selected_jurisdiction: "",
       show_form: false,
       editing_item: nil,
       tax_summary: nil,
       calc_result: nil,
       current_year: current_year
     )}
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
    jurisdiction = if params["jurisdiction"] == "", do: nil, else: params["jurisdiction"]

    opts = []
    opts = if company_id, do: [{:company_id, String.to_integer(company_id)} | opts], else: opts
    opts = if year, do: [{:tax_year, String.to_integer(year)} | opts], else: opts
    opts = if jurisdiction, do: [{:jurisdiction, jurisdiction} | opts], else: opts

    provisions = Tax.list_tax_provisions(opts)

    # Calculate summary if company and year selected
    summary =
      if company_id && year do
        Tax.tax_summary(String.to_integer(company_id), String.to_integer(year))
      else
        nil
      end

    {:noreply,
     assign(socket,
       provisions: provisions,
       selected_company_id: params["company_id"] || "",
       selected_year: params["year"] || "",
       selected_jurisdiction: params["jurisdiction"] || "",
       tax_summary: summary
     )}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    provision = Tax.get_tax_provision!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: provision)}
  end

  def handle_event("calculate", %{"calc" => params}, socket) do
    company_id = String.to_integer(params["company_id"])
    tax_year = String.to_integer(params["tax_year"])
    jurisdiction = params["jurisdiction"]
    tax_rate = params["tax_rate"]

    {:ok, result} = Tax.calculate_provision(company_id, tax_year, jurisdiction, tax_rate)
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

  def handle_event("save", %{"provision" => params}, socket) do
    case Tax.create_tax_provision(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Tax provision created")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create provision")}
    end
  end

  def handle_event("update", %{"provision" => params}, socket) do
    provision = socket.assigns.editing_item

    case Tax.update_tax_provision(provision, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Tax provision updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update provision")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    provision = Tax.get_tax_provision!(String.to_integer(id))
    Tax.delete_tax_provision(provision)

    {:noreply,
     reload(socket)
     |> put_flash(:info, "Tax provision deleted")}
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, reload(socket)}

  defp reload(socket) do
    opts = build_filter_opts(socket.assigns)
    assign(socket, provisions: Tax.list_tax_provisions(opts))
  end

  defp build_filter_opts(assigns) do
    opts = []
    opts = if assigns.selected_company_id != "", do: [{:company_id, String.to_integer(assigns.selected_company_id)} | opts], else: opts
    opts = if assigns.selected_year != "", do: [{:tax_year, String.to_integer(assigns.selected_year)} | opts], else: opts
    opts = if assigns.selected_jurisdiction != "", do: [{:jurisdiction, assigns.selected_jurisdiction} | opts], else: opts
    opts
  end

  defp format_decimal(nil), do: "---"
  defp format_decimal(val), do: Money.format(val, 2)

  defp status_tag("estimated"), do: "tag-lemon"
  defp status_tag("accrued"), do: "tag-ink"
  defp status_tag("filed"), do: "tag-jade"
  defp status_tag("paid"), do: "tag-jade"
  defp status_tag("adjusted"), do: "tag-coral"
  defp status_tag(_), do: "tag-ink"

  defp provision_type_label("current"), do: "Current"
  defp provision_type_label("deferred"), do: "Deferred"
  defp provision_type_label(other), do: other

  defp total_tax_amount(provisions) do
    Enum.reduce(provisions, Decimal.new(0), fn p, acc ->
      amt = p.tax_amount || Decimal.new(0)
      Decimal.add(acc, amt)
    end)
  end

  defp jurisdiction_summary(provisions) do
    provisions
    |> Enum.group_by(& &1.jurisdiction)
    |> Enum.sort_by(fn {j, _} -> j end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Tax Provisions</h1>
          <p class="deck">Manage current and deferred tax provisions across jurisdictions</p>
        </div>
        <div style="display: flex; gap: 0.5rem; align-items: center;">
          <%= if @can_write do %>
            <button class="btn btn-primary" phx-click="show_form">Add Provision</button>
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
          <label class="form-label" style="font-size: 0.85rem;">Jurisdiction</label>
          <select name="jurisdiction" class="form-select" style="width: auto; padding: 0.3rem 0.5rem;">
            <option value="">All</option>
            <%= for j <- ~w(US UK DE FR JP SG HK CA AU) do %>
              <option value={j} selected={j == @selected_jurisdiction}>{j}</option>
            <% end %>
          </select>
        </div>
      </form>
    </div>

    <%!-- Always-visible metrics --%>
    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Provisions</div>
        <div class="metric-value">{length(@provisions)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Total Tax Amount</div>
        <div class="metric-value num-negative">{format_decimal(total_tax_amount(@provisions))}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Jurisdictions</div>
        <div class="metric-value">{@provisions |> Enum.map(& &1.jurisdiction) |> Enum.uniq() |> length()}</div>
      </div>
    </div>

    <%!-- Tax Summary Cards (when filtered) --%>
    <%= if @tax_summary do %>
      <div class="metrics-strip">
        <div class="metric-cell">
          <div class="metric-label">Current Provision</div>
          <div class="metric-value">{format_decimal(@tax_summary.total_current_provision)}</div>
        </div>
        <div class="metric-cell">
          <div class="metric-label">Deferred Assets</div>
          <div class="metric-value num-positive">{format_decimal(@tax_summary.total_deferred_assets)}</div>
        </div>
        <div class="metric-cell">
          <div class="metric-label">Deferred Liabilities</div>
          <div class="metric-value num-negative">{format_decimal(@tax_summary.total_deferred_liabilities)}</div>
        </div>
        <div class="metric-cell">
          <div class="metric-label">Effective Rate</div>
          <div class="metric-value">{format_decimal(@tax_summary.effective_tax_rate)}%</div>
        </div>
      </div>
    <% end %>

    <%!-- Calculate Provision --%>
    <%= if @calc_result do %>
      <div class="section">
        <div class="section-head" style="display: flex; justify-content: space-between; align-items: center;">
          <h2>Calculated Provision</h2>
          <button phx-click="close_calculation" class="btn btn-secondary btn-sm">Close</button>
        </div>
        <div class="metrics-strip">
          <div class="metric-cell">
            <div class="metric-label">Taxable Income</div>
            <div class="metric-value">{format_decimal(@calc_result.taxable_income)}</div>
          </div>
          <div class="metric-cell">
            <div class="metric-label">Tax Amount</div>
            <div class="metric-value">{format_decimal(@calc_result.tax_amount)}</div>
          </div>
          <div class="metric-cell">
            <div class="metric-label">Jurisdiction</div>
            <div class="metric-value">{@calc_result.jurisdiction}</div>
          </div>
          <div class="metric-cell">
            <div class="metric-label">Rate</div>
            <div class="metric-value">{format_decimal(@calc_result.tax_rate)}%</div>
          </div>
        </div>
      </div>
    <% end %>

    <%= if @provisions != [] do %>
      <div class="section">
        <div class="section-head"><h2>By Jurisdiction</h2></div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Jurisdiction</th>
                <th class="th-num">Provisions</th>
                <th class="th-num">Total Tax Amount</th>
              </tr>
            </thead>
            <tbody>
              <%= for {jurisdiction, items} <- jurisdiction_summary(@provisions) do %>
                <tr>
                  <td class="td-name">{jurisdiction}</td>
                  <td class="td-num">{length(items)}</td>
                  <td class="td-num num-negative">{format_decimal(total_tax_amount(items))}</td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    <% end %>

    <div class="section">
      <div class="section-head">
        <h2>Provisions</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Year</th>
              <th>Jurisdiction</th>
              <th>Type</th>
              <th>Tax Type</th>
              <th class="th-num">Taxable Income</th>
              <th class="th-num">Tax Rate</th>
              <th class="th-num">Tax Amount</th>
              <th>Status</th>
              <th>Company</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for p <- @provisions do %>
              <tr>
                <td>{p.tax_year}</td>
                <td>{p.jurisdiction}</td>
                <td>{provision_type_label(p.provision_type)}</td>
                <td>{p.tax_type}</td>
                <td class="td-num">{format_decimal(p.taxable_income)}</td>
                <td class="td-num">{format_decimal(p.tax_rate)}%</td>
                <td class="td-num">{format_decimal(p.tax_amount)}</td>
                <td><span class={"tag #{status_tag(p.status)}"}>{p.status}</span></td>
                <td>
                  <%= if p.company do %>
                    <.link navigate={~p"/companies/#{p.company.id}"} class="td-link">{p.company.name}</.link>
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit" phx-value-id={p.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete" phx-value-id={p.id} class="btn btn-danger btn-sm" data-confirm="Delete?">Del</button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @provisions == [] do %>
          <div class="empty-state">
            <p>No tax provisions found.</p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_form">Add Your First Provision</button>
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
            <h3>{if @show_form == :edit, do: "Edit Tax Provision", else: "Add Tax Provision"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="provision[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={@editing_item && @editing_item.company_id == c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Tax Year *</label>
                <input type="number" name="provision[tax_year]" class="form-input" value={if @editing_item, do: @editing_item.tax_year, else: @current_year} required />
              </div>
              <div class="form-group">
                <label class="form-label">Jurisdiction *</label>
                <select name="provision[jurisdiction]" class="form-select" required>
                  <option value="">Select jurisdiction</option>
                  <%= for j <- ~w(US UK DE FR JP SG HK CA AU) do %>
                    <option value={j} selected={@editing_item && @editing_item.jurisdiction == j}>{j}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Provision Type *</label>
                <select name="provision[provision_type]" class="form-select" required>
                  <option value="">Select type</option>
                  <%= for t <- ~w(current deferred) do %>
                    <option value={t} selected={@editing_item && @editing_item.provision_type == t}>{provision_type_label(t)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Tax Type</label>
                <select name="provision[tax_type]" class="form-select">
                  <%= for t <- ~w(income capital_gains withholding vat other) do %>
                    <option value={t} selected={@editing_item && @editing_item.tax_type == t}>{t}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Taxable Income</label>
                <input type="number" step="0.01" name="provision[taxable_income]" class="form-input" value={if @editing_item, do: @editing_item.taxable_income, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Tax Rate (%)</label>
                <input type="number" step="0.01" name="provision[tax_rate]" class="form-input" value={if @editing_item, do: @editing_item.tax_rate, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Tax Amount</label>
                <input type="number" step="0.01" name="provision[tax_amount]" class="form-input" value={if @editing_item, do: @editing_item.tax_amount, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Status</label>
                <select name="provision[status]" class="form-select">
                  <%= for s <- ~w(estimated accrued filed paid adjusted) do %>
                    <option value={s} selected={@editing_item && @editing_item.status == s}>{s}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Due Date</label>
                <input type="date" name="provision[due_date]" class="form-input" value={if @editing_item && @editing_item.due_date, do: Date.to_string(@editing_item.due_date), else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="provision[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">
                  {if @show_form == :edit, do: "Update Provision", else: "Add Provision"}
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
