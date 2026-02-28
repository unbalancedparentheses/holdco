defmodule HoldcoWeb.TaxOptimizerLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Tax, Corporate, Money}

  @impl true
  def mount(_params, _session, socket) do
    companies = Corporate.list_companies()
    jurisdictions = Tax.list_jurisdictions()

    {:ok,
     assign(socket,
       page_title: "Tax Optimizer",
       companies: companies,
       jurisdictions: jurisdictions,
       selected_company_id: "",
       optimization_result: nil,
       show_form: false,
       editing_item: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("select_company", %{"company_id" => id}, socket) do
    {:noreply, assign(socket, selected_company_id: id, optimization_result: nil)}
  end

  def handle_event("optimize", _, socket) do
    case socket.assigns.selected_company_id do
      "" ->
        {:noreply, put_flash(socket, :error, "Please select a company first")}

      id ->
        company_id = String.to_integer(id)
        result = Tax.optimize_tax_structure(company_id)
        {:noreply, assign(socket, optimization_result: result)}
    end
  end

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: :add, editing_item: nil)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false, editing_item: nil)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    jurisdiction = Tax.get_jurisdiction!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: jurisdiction)}
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

  def handle_event("save", %{"jurisdiction" => params}, socket) do
    case Tax.create_jurisdiction(params) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Jurisdiction added")
         |> assign(show_form: false, editing_item: nil, jurisdictions: Tax.list_jurisdictions())}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add jurisdiction")}
    end
  end

  def handle_event("update", %{"jurisdiction" => params}, socket) do
    jurisdiction = socket.assigns.editing_item

    case Tax.update_jurisdiction(jurisdiction, params) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Jurisdiction updated")
         |> assign(show_form: false, editing_item: nil, jurisdictions: Tax.list_jurisdictions())}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update jurisdiction")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    jurisdiction = Tax.get_jurisdiction!(String.to_integer(id))

    case Tax.delete_jurisdiction(jurisdiction) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Jurisdiction deleted")
         |> assign(jurisdictions: Tax.list_jurisdictions())}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete jurisdiction")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Tax Optimizer</h1>
          <p class="deck">Multi-jurisdiction tax rate management and optimization</p>
        </div>
        <div style="display: flex; gap: 0.5rem; align-items: center;">
          <form phx-change="select_company" style="display: flex; align-items: center; gap: 0.5rem;">
            <label class="form-label" style="margin: 0; font-size: 0.85rem;">Company</label>
            <select name="company_id" class="form-select" style="width: auto; padding: 0.3rem 0.5rem;">
              <option value="">Select Company</option>
              <%= for c <- @companies do %>
                <option value={c.id} selected={to_string(c.id) == @selected_company_id}>{c.name}</option>
              <% end %>
            </select>
          </form>
          <button class="btn btn-primary" phx-click="optimize">Optimize</button>
          <%= if @can_write do %>
            <button class="btn btn-secondary" phx-click="show_form">Add Jurisdiction</button>
          <% end %>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Jurisdictions</div>
        <div class="metric-value">{length(@jurisdictions)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Active</div>
        <div class="metric-value">{Enum.count(@jurisdictions, & &1.is_active)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Avg Tax Rate</div>
        <div class="metric-value">{format_pct(avg_rate(@jurisdictions))}%</div>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Jurisdictions</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>Country</th>
              <th>Tax Type</th>
              <th class="th-num">Rate</th>
              <th>Effective</th>
              <th>Expiry</th>
              <th>Active</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for j <- @jurisdictions do %>
              <tr>
                <td class="td-name">{j.name}</td>
                <td>{j.country_code}</td>
                <td><span class={"tag #{type_tag(j.tax_type)}"}>{j.tax_type}</span></td>
                <td class="td-num">{format_pct(j.tax_rate)}%</td>
                <td class="td-mono">{j.effective_date || "---"}</td>
                <td class="td-mono">{j.expiry_date || "---"}</td>
                <td>{if j.is_active, do: "Yes", else: "No"}</td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit" phx-value-id={j.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete" phx-value-id={j.id} class="btn btn-danger btn-sm" data-confirm="Delete this jurisdiction?">Del</button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @jurisdictions == [] do %>
          <div class="empty-state">
            <p>No jurisdictions configured.</p>
            <p style="color: var(--muted); font-size: 0.9rem;">Add jurisdictions to enable tax optimization analysis.</p>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @optimization_result do %>
      <div class="section">
        <div class="section-head">
          <h2>Optimization Results</h2>
        </div>
        <div class="metrics-strip">
          <div class="metric-cell">
            <div class="metric-label">Portfolio Value</div>
            <div class="metric-value">${format_number(@optimization_result.total_portfolio_value)}</div>
          </div>
          <div class="metric-cell">
            <div class="metric-label">Holdings</div>
            <div class="metric-value">{@optimization_result.holdings_count}</div>
          </div>
        </div>

        <div class="panel" style="margin-top: 1rem;">
          <h3 style="margin-bottom: 0.5rem;">Tax Liability by Jurisdiction</h3>
          <table>
            <thead>
              <tr>
                <th>Jurisdiction</th>
                <th>Country</th>
                <th>Tax Type</th>
                <th class="th-num">Rate</th>
                <th class="th-num">Estimated Liability</th>
              </tr>
            </thead>
            <tbody>
              <%= for a <- @optimization_result.jurisdiction_analysis do %>
                <tr>
                  <td class="td-name">{a.jurisdiction_name}</td>
                  <td>{a.country_code}</td>
                  <td>{a.tax_type}</td>
                  <td class="td-num">{format_pct(a.tax_rate)}%</td>
                  <td class="td-num">${format_number(a.estimated_liability)}</td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>

        <%= if @optimization_result.suggestions != [] do %>
          <div class="panel" style="margin-top: 1rem;">
            <h3 style="margin-bottom: 0.5rem;">Optimization Suggestions</h3>
            <table>
              <thead>
                <tr>
                  <th>Tax Type</th>
                  <th>Recommended Jurisdiction</th>
                  <th>Country</th>
                  <th class="th-num">Rate</th>
                  <th class="th-num">Potential Savings</th>
                </tr>
              </thead>
              <tbody>
                <%= for s <- @optimization_result.suggestions do %>
                  <tr>
                    <td>{s.tax_type}</td>
                    <td class="td-name">{s.recommended_jurisdiction}</td>
                    <td>{s.recommended_country}</td>
                    <td class="td-num">{format_pct(s.tax_rate)}%</td>
                    <td class="td-num num-positive">${format_number(s.potential_savings)}</td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% end %>
      </div>
    <% end %>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit Jurisdiction", else: "Add Jurisdiction"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Name *</label>
                <input type="text" name="jurisdiction[name]" class="form-input"
                  value={if @editing_item, do: @editing_item.name, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Country Code *</label>
                <input type="text" name="jurisdiction[country_code]" class="form-input"
                  value={if @editing_item, do: @editing_item.country_code, else: ""} required maxlength="2" />
              </div>
              <div class="form-group">
                <label class="form-label">Tax Rate * (0-1, e.g. 0.25 = 25%)</label>
                <input type="number" name="jurisdiction[tax_rate]" class="form-input" step="0.001" min="0" max="1"
                  value={if @editing_item, do: @editing_item.tax_rate, else: "0.0"} required />
              </div>
              <div class="form-group">
                <label class="form-label">Tax Type *</label>
                <select name="jurisdiction[tax_type]" class="form-select" required>
                  <option value="">Select type</option>
                  <%= for t <- ~w(income capital_gains withholding vat) do %>
                    <option value={t} selected={@editing_item && @editing_item.tax_type == t}>{t}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Effective Date</label>
                <input type="date" name="jurisdiction[effective_date]" class="form-input"
                  value={if @editing_item, do: @editing_item.effective_date, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Expiry Date</label>
                <input type="date" name="jurisdiction[expiry_date]" class="form-input"
                  value={if @editing_item, do: @editing_item.expiry_date, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Active</label>
                <select name="jurisdiction[is_active]" class="form-select">
                  <option value="true" selected={!@editing_item || @editing_item.is_active}>Yes</option>
                  <option value="false" selected={@editing_item && !@editing_item.is_active}>No</option>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="jurisdiction[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">
                  {if @show_form == :edit, do: "Update", else: "Add Jurisdiction"}
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

  defp avg_rate([]), do: Decimal.new(0)

  defp avg_rate(jurisdictions) do
    total = Enum.reduce(jurisdictions, Decimal.new(0), &Money.add(&1.tax_rate, &2))
    Money.div(total, length(jurisdictions))
  end

  defp type_tag("income"), do: "tag-jade"
  defp type_tag("capital_gains"), do: "tag-lemon"
  defp type_tag("withholding"), do: "tag-coral"
  defp type_tag("vat"), do: "tag-sky"
  defp type_tag(_), do: ""

  defp format_pct(%Decimal{} = n), do: n |> Decimal.mult(100) |> Decimal.round(2) |> Decimal.to_string()
  defp format_pct(_), do: "0"

  defp format_number(%Decimal{} = n),
    do: n |> Decimal.round(2) |> Decimal.to_string() |> add_commas()

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
end
