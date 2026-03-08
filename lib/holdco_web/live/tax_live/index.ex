defmodule HoldcoWeb.TaxLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Tax, Corporate, Money}
  alias Holdco.Tax.CapitalGains

  @tabs ~w(provisions capital_gains)
  @cg_methods [{"fifo", "FIFO"}, {"lifo", "LIFO"}, {"specific", "Specific Lot"}]
  @short_term_rate Decimal.new("0.37")
  @long_term_rate Decimal.new("0.20")

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Tax.subscribe()

    provisions = Tax.list_tax_provisions()
    companies = Corporate.list_companies()
    current_year = Date.utc_today().year

    # Capital gains
    cg_results = CapitalGains.compute(:fifo)
    cg_summary = compute_cg_summary(cg_results)

    {:ok,
     assign(socket,
       page_title: "Tax",
       tab: "provisions",
       provisions: provisions,
       companies: companies,
       selected_company_id: "",
       selected_year: "",
       selected_jurisdiction: "",
       show_form: false,
       editing_item: nil,
       tax_summary: nil,
       calc_result: nil,
       current_year: current_year,
       # Capital gains assigns
       cg_method: "fifo",
       cg_results: cg_results,
       cg_summary: cg_summary,
       short_term_rate: @short_term_rate,
       long_term_rate: @long_term_rate
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("switch_tab", %{"tab" => tab}, socket) when tab in @tabs,
    do: {:noreply, assign(socket, tab: tab)}

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

  # Capital gains method switch
  def handle_event("change_method", %{"method" => method_str}, socket) do
    method = String.to_existing_atom(method_str)
    results = CapitalGains.compute(method)
    summary = compute_cg_summary(results)
    {:noreply, assign(socket, cg_method: method_str, cg_results: results, cg_summary: summary)}
  end

  # Permission gating
  def handle_event("save", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("update", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

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

  # Provision helpers
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

  # Capital gains helpers
  defp cg_methods, do: @cg_methods

  defp compute_cg_summary(results) do
    total_short_term =
      Enum.reduce(results, Decimal.new(0), fn r, acc ->
        Money.add(acc, Money.add(r.short_term_realized, r.short_term_unrealized))
      end)

    total_long_term =
      Enum.reduce(results, Decimal.new(0), fn r, acc ->
        Money.add(acc, Money.add(r.long_term_realized, r.long_term_unrealized))
      end)

    st_realized = Enum.reduce(results, Decimal.new(0), fn r, acc -> Money.add(acc, r.short_term_realized) end)
    lt_realized = Enum.reduce(results, Decimal.new(0), fn r, acc -> Money.add(acc, r.long_term_realized) end)

    st_taxable = if Money.gt?(st_realized, 0), do: st_realized, else: Decimal.new(0)
    lt_taxable = if Money.gt?(lt_realized, 0), do: lt_realized, else: Decimal.new(0)
    estimated_tax = Money.add(Money.mult(st_taxable, @short_term_rate), Money.mult(lt_taxable, @long_term_rate))

    %{total_short_term: total_short_term, total_long_term: total_long_term, estimated_tax: estimated_tax}
  end

  defp sum_field(results, field) do
    Enum.reduce(results, Decimal.new(0), fn r, acc -> Money.add(acc, Map.get(r, field, Decimal.new(0))) end)
  end

  defp gain_class(value) do
    cond do
      Money.positive?(value) -> "num-positive"
      Money.negative?(value) -> "num-negative"
      true -> ""
    end
  end

  defp format_number(%Decimal{} = n),
    do: n |> Decimal.round(2) |> Decimal.to_string() |> add_commas()

  defp format_number(n) when is_float(n),
    do: :erlang.float_to_binary(n, decimals: 2) |> add_commas()

  defp format_number(n) when is_integer(n), do: Integer.to_string(n) |> add_commas()
  defp format_number(_), do: "0"

  defp add_commas(str) do
    case String.split(str, ".") do
      [int_part, dec_part] ->
        formatted_int = int_part |> String.reverse() |> String.replace(~r/(\d{3})(?=\d)/, "\\1,") |> String.reverse()
        "#{formatted_int}.#{dec_part}"

      [int_part] ->
        int_part |> String.reverse() |> String.replace(~r/(\d{3})(?=\d)/, "\\1,") |> String.reverse()
    end
  end

  defp holding_period_days(r) do
    acq = Map.get(r, :acquisition_date) || Map.get(r, :purchase_date)
    disp = Map.get(r, :disposal_date) || Map.get(r, :sale_date)

    case {parse_date(acq), parse_date(disp)} do
      {{:ok, a}, {:ok, d}} -> Date.diff(d, a)
      {{:ok, a}, _} -> Date.diff(Date.utc_today(), a)
      _ -> nil
    end
  end

  defp parse_date(nil), do: :error
  defp parse_date(%Date{} = d), do: {:ok, d}
  defp parse_date(str) when is_binary(str), do: Date.from_iso8601(str)
  defp parse_date(_), do: :error

  defp format_holding_period(nil), do: "---"
  defp format_holding_period(days) when days >= 365, do: "#{div(days, 365)}y #{rem(days, 365)}d"
  defp format_holding_period(days), do: "#{days}d"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Tax</h1>
          <p class="deck">Provisions, capital gains, and tax analysis</p>
        </div>
        <div style="display: flex; gap: 0.5rem; align-items: center;">
          <%= if @tab == "provisions" && @can_write do %>
            <button class="btn btn-primary" phx-click="show_form">Add Provision</button>
          <% end %>
          <%= if @tab == "capital_gains" do %>
            <form phx-change="change_method" style="display: flex; align-items: center; gap: 0.5rem;">
              <label class="form-label" style="margin: 0; font-size: 0.85rem;">Method</label>
              <select name="method" class="form-select" style="width: auto; padding: 0.3rem 0.5rem;">
                <%= for {val, label} <- cg_methods() do %>
                  <option value={val} selected={val == @cg_method}>{label}</option>
                <% end %>
              </select>
            </form>
          <% end %>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="tabs" style="margin-bottom: 1.5rem;">
      <button class={"tab #{if @tab == "provisions", do: "active"}"} phx-click="switch_tab" phx-value-tab="provisions">Provisions</button>
      <button class={"tab #{if @tab == "capital_gains", do: "active"}"} phx-click="switch_tab" phx-value-tab="capital_gains">Capital Gains</button>
    </div>

    {render_tab(assigns)}

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

  defp render_tab(%{tab: "provisions"} = assigns) do
    ~H"""
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
    """
  end

  defp render_tab(%{tab: "capital_gains"} = assigns) do
    ~H"""
    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Short-Term Gains</div>
        <div class={"metric-value #{gain_class(@cg_summary.total_short_term)}"}>
          ${format_number(@cg_summary.total_short_term)}
        </div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Long-Term Gains</div>
        <div class={"metric-value #{gain_class(@cg_summary.total_long_term)}"}>
          ${format_number(@cg_summary.total_long_term)}
        </div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Total Gains</div>
        <div class={"metric-value #{gain_class(Money.add(@cg_summary.total_short_term, @cg_summary.total_long_term))}"}>
          ${format_number(Money.add(@cg_summary.total_short_term, @cg_summary.total_long_term))}
        </div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Est. Tax (ST @ 37%, LT @ 20%)</div>
        <div class="metric-value num-negative">
          ${format_number(@cg_summary.estimated_tax)}
        </div>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Holdings Detail</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Asset</th>
              <th>Company</th>
              <th class="th-num">Holding Period</th>
              <th>Term</th>
              <th class="th-num">ST Realized</th>
              <th class="th-num">ST Unrealized</th>
              <th class="th-num">LT Realized</th>
              <th class="th-num">LT Unrealized</th>
              <th class="th-num">Total Gain</th>
            </tr>
          </thead>
          <tbody>
            <%= for r <- @cg_results do %>
              <tr>
                <td class="td-name">
                  <.link navigate={~p"/holdings/#{r.holding_id}"} class="td-link">
                    {r.asset}
                    <%= if r.ticker && r.ticker != "" do %>
                      <span style="color: var(--muted); font-size: 0.85rem;">({r.ticker})</span>
                    <% end %>
                  </.link>
                </td>
                <td>{r.company}</td>
                <% days_held = holding_period_days(r) %>
                <td class="td-num">{format_holding_period(days_held)}</td>
                <td>
                  <%= if days_held do %>
                    <span class={"tag #{if days_held >= 365, do: "tag-jade", else: "tag-lemon"}"}>
                      {if days_held >= 365, do: "Long-Term", else: "Short-Term"}
                    </span>
                  <% else %>
                    <span class="tag tag-ink">N/A</span>
                  <% end %>
                </td>
                <td class={"td-num #{gain_class(r.short_term_realized)}"}>{format_number(r.short_term_realized)}</td>
                <td class={"td-num #{gain_class(r.short_term_unrealized)}"}>{format_number(r.short_term_unrealized)}</td>
                <td class={"td-num #{gain_class(r.long_term_realized)}"}>{format_number(r.long_term_realized)}</td>
                <td class={"td-num #{gain_class(r.long_term_unrealized)}"}>{format_number(r.long_term_unrealized)}</td>
                <td class={"td-num #{gain_class(r.total_gain)}"} style="font-weight: 600;">
                  {format_number(r.total_gain)}
                </td>
              </tr>
            <% end %>
          </tbody>
          <tfoot>
            <tr style="font-weight: 600; border-top: 2px solid var(--rule);">
              <td class="td-name">Total</td>
              <td></td>
              <td></td>
              <td></td>
              <td class={"td-num #{gain_class(sum_field(@cg_results, :short_term_realized))}"}>{format_number(sum_field(@cg_results, :short_term_realized))}</td>
              <td class={"td-num #{gain_class(sum_field(@cg_results, :short_term_unrealized))}"}>{format_number(sum_field(@cg_results, :short_term_unrealized))}</td>
              <td class={"td-num #{gain_class(sum_field(@cg_results, :long_term_realized))}"}>{format_number(sum_field(@cg_results, :long_term_realized))}</td>
              <td class={"td-num #{gain_class(sum_field(@cg_results, :long_term_unrealized))}"}>{format_number(sum_field(@cg_results, :long_term_unrealized))}</td>
              <td class={"td-num #{gain_class(sum_field(@cg_results, :total_gain))}"}>{format_number(sum_field(@cg_results, :total_gain))}</td>
            </tr>
          </tfoot>
        </table>
        <%= if @cg_results == [] do %>
          <div class="empty-state">
            <p>No capital gains data found.</p>
            <p style="color: var(--muted); font-size: 0.9rem;">
              Capital gains are computed from holdings with cost basis lots. Add holdings with purchase history to see gains analysis.
            </p>
          </div>
        <% end %>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Tax Estimation Notes</h2>
      </div>
      <div class="panel" style="padding: 1.5rem;">
        <table>
          <thead>
            <tr>
              <th>Category</th>
              <th class="th-num">Gain</th>
              <th class="th-num">Rate</th>
              <th class="th-num">Est. Tax</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td class="td-name">Short-Term Realized</td>
              <td class="td-num">{format_number(sum_field(@cg_results, :short_term_realized))}</td>
              <td class="td-num">37%</td>
              <td class="td-num">{format_number(Money.mult(Money.max(sum_field(@cg_results, :short_term_realized), 0), @short_term_rate))}</td>
            </tr>
            <tr>
              <td class="td-name">Long-Term Realized</td>
              <td class="td-num">{format_number(sum_field(@cg_results, :long_term_realized))}</td>
              <td class="td-num">20%</td>
              <td class="td-num">{format_number(Money.mult(Money.max(sum_field(@cg_results, :long_term_realized), 0), @long_term_rate))}</td>
            </tr>
            <tr style="font-weight: 600; border-top: 2px solid var(--rule);">
              <td class="td-name">Total Estimated Tax</td>
              <td></td>
              <td></td>
              <td class="td-num num-negative">${format_number(@cg_summary.estimated_tax)}</td>
            </tr>
          </tbody>
        </table>
        <p style="color: var(--muted); font-size: 0.85rem; margin-top: 1rem;">
          Estimates use US federal rates (37% ordinary income for short-term, 20% for long-term).
          Unrealized gains are shown for reference but not included in the tax estimate.
          Consult a tax professional for actual tax liability.
        </p>
      </div>
    </div>
    """
  end
end
