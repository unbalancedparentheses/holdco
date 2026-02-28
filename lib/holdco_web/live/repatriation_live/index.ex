defmodule HoldcoWeb.RepatriationLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Tax, Corporate, Money}

  @impl true
  def mount(_params, _session, socket) do
    companies = Corporate.list_companies()

    {:ok,
     assign(socket,
       page_title: "Repatriation Planning",
       companies: companies,
       selected_company_id: "",
       plans: [],
       show_form: false,
       editing_item: nil,
       preview: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("filter_company", %{"company_id" => id}, socket) do
    if id == "" do
      {:noreply, assign(socket, selected_company_id: "", plans: [])}
    else
      company_id = String.to_integer(id)
      plans = Tax.list_repatriation_plans(company_id)
      {:noreply, assign(socket, selected_company_id: id, plans: plans)}
    end
  end

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: :add, editing_item: nil, preview: nil)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false, editing_item: nil, preview: nil)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    plan = Tax.get_repatriation_plan!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: plan, preview: nil)}
  end

  def handle_event("calculate_preview", params, socket) do
    plan_params = params["plan"] || params
    preview = Tax.calculate_repatriation(plan_params)
    {:noreply, assign(socket, preview: preview)}
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

  def handle_event("save", %{"plan" => params}, socket) do
    case Tax.create_repatriation_plan(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Repatriation plan created")
         |> assign(show_form: false, editing_item: nil, preview: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create plan")}
    end
  end

  def handle_event("update", %{"plan" => params}, socket) do
    plan = socket.assigns.editing_item

    case Tax.update_repatriation_plan(plan, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Repatriation plan updated")
         |> assign(show_form: false, editing_item: nil, preview: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update plan")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    plan = Tax.get_repatriation_plan!(String.to_integer(id))

    case Tax.delete_repatriation_plan(plan) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Repatriation plan deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete plan")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Repatriation Planning</h1>
          <p class="deck">Plan and track cross-border fund repatriation with withholding tax calculations</p>
        </div>
        <div style="display: flex; gap: 0.5rem; align-items: center;">
          <form phx-change="filter_company" style="display: flex; align-items: center; gap: 0.5rem;">
            <label class="form-label" style="margin: 0; font-size: 0.85rem;">Company</label>
            <select name="company_id" class="form-select" style="width: auto; padding: 0.3rem 0.5rem;">
              <option value="">Select Company</option>
              <%= for c <- @companies do %>
                <option value={c.id} selected={to_string(c.id) == @selected_company_id}>{c.name}</option>
              <% end %>
            </select>
          </form>
          <%= if @can_write && @selected_company_id != "" do %>
            <button class="btn btn-primary" phx-click="show_form">New Plan</button>
          <% end %>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <%= if @plans != [] do %>
      <div class="metrics-strip">
        <div class="metric-cell">
          <div class="metric-label">Total Plans</div>
          <div class="metric-value">{length(@plans)}</div>
        </div>
        <div class="metric-cell">
          <div class="metric-label">Total Amount</div>
          <div class="metric-value">${format_number(sum_field(@plans, :amount))}</div>
        </div>
        <div class="metric-cell">
          <div class="metric-label">Total Withholding</div>
          <div class="metric-value num-negative">${format_number(sum_field(@plans, :withholding_tax_amount))}</div>
        </div>
        <div class="metric-cell">
          <div class="metric-label">Total Net</div>
          <div class="metric-value num-positive">${format_number(sum_field(@plans, :net_amount))}</div>
        </div>
      </div>
    <% end %>

    <div class="section">
      <div class="section-head"><h2>Repatriation Plans</h2></div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Source</th>
              <th>Target</th>
              <th>Mechanism</th>
              <th class="th-num">Amount</th>
              <th class="th-num">WHT Rate</th>
              <th class="th-num">WHT Amount</th>
              <th class="th-num">Net Amount</th>
              <th>Status</th>
              <th>Date</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for p <- @plans do %>
              <tr>
                <td class="td-name">{p.source_jurisdiction}</td>
                <td>{p.target_jurisdiction}</td>
                <td><span class={"tag #{mechanism_tag(p.mechanism)}"}>{humanize_mechanism(p.mechanism)}</span></td>
                <td class="td-num">${format_number(p.amount)}</td>
                <td class="td-num">{format_pct(p.withholding_tax_rate)}%</td>
                <td class="td-num num-negative">${format_number(p.withholding_tax_amount)}</td>
                <td class="td-num num-positive">${format_number(p.net_amount)}</td>
                <td><span class={"tag #{plan_status_tag(p.status)}"}>{p.status}</span></td>
                <td class="td-mono">{p.planned_date || "---"}</td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit" phx-value-id={p.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete" phx-value-id={p.id} class="btn btn-danger btn-sm" data-confirm="Delete this plan?">Del</button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @plans == [] do %>
          <div class="empty-state">
            <p>{if @selected_company_id == "", do: "Select a company to view plans.", else: "No repatriation plans found."}</p>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit Plan", else: "New Repatriation Plan"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"} phx-change="calculate_preview">
              <input type="hidden" name="plan[company_id]" value={@selected_company_id} />
              <div class="form-group">
                <label class="form-label">Source Jurisdiction *</label>
                <input type="text" name="plan[source_jurisdiction]" class="form-input"
                  value={if @editing_item, do: @editing_item.source_jurisdiction, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Target Jurisdiction *</label>
                <input type="text" name="plan[target_jurisdiction]" class="form-input"
                  value={if @editing_item, do: @editing_item.target_jurisdiction, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Amount *</label>
                <input type="number" name="plan[amount]" class="form-input" step="any"
                  value={if @editing_item, do: @editing_item.amount, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Currency</label>
                <input type="text" name="plan[currency]" class="form-input"
                  value={if @editing_item, do: @editing_item.currency, else: "USD"} />
              </div>
              <div class="form-group">
                <label class="form-label">Mechanism *</label>
                <select name="plan[mechanism]" class="form-select" required>
                  <option value="">Select mechanism</option>
                  <%= for m <- ~w(dividend loan_repayment management_fee royalty liquidation) do %>
                    <option value={m} selected={@editing_item && @editing_item.mechanism == m}>{humanize_mechanism(m)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Withholding Tax Rate (0-1)</label>
                <input type="number" name="plan[withholding_tax_rate]" class="form-input" step="0.001" min="0" max="1"
                  value={if @editing_item, do: @editing_item.withholding_tax_rate, else: "0"} />
              </div>

              <%= if @preview do %>
                <div class="panel" style="background: var(--surface-raised); padding: 1rem; margin: 1rem 0; border-radius: 6px;">
                  <h4 style="margin-bottom: 0.5rem;">Calculation Preview</h4>
                  <table>
                    <tr><td>Gross Amount</td><td class="td-num">${format_number(@preview.amount)}</td></tr>
                    <tr><td>Withholding Tax</td><td class="td-num num-negative">${format_number(@preview.withholding_tax_amount)}</td></tr>
                    <tr style="font-weight: 600;"><td>Net Amount</td><td class="td-num num-positive">${format_number(@preview.net_amount)}</td></tr>
                    <tr><td>Effective Rate</td><td class="td-num">{format_pct(@preview.effective_tax_rate)}%</td></tr>
                  </table>
                </div>
              <% end %>

              <div class="form-group">
                <label class="form-label">Planned Date</label>
                <input type="date" name="plan[planned_date]" class="form-input"
                  value={if @editing_item, do: @editing_item.planned_date, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Status</label>
                <select name="plan[status]" class="form-select">
                  <%= for s <- ~w(draft approved executed) do %>
                    <option value={s} selected={@editing_item && @editing_item.status == s}>{s}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="plan[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">
                  {if @show_form == :edit, do: "Update", else: "Create Plan"}
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
    case socket.assigns.selected_company_id do
      "" ->
        assign(socket, plans: [])

      id ->
        company_id = String.to_integer(id)
        plans = Tax.list_repatriation_plans(company_id)
        assign(socket, plans: plans)
    end
  end

  defp sum_field(plans, field) do
    Enum.reduce(plans, Decimal.new(0), fn p, acc ->
      Money.add(acc, Map.get(p, field) || Decimal.new(0))
    end)
  end

  defp mechanism_tag("dividend"), do: "tag-jade"
  defp mechanism_tag("loan_repayment"), do: "tag-sky"
  defp mechanism_tag("management_fee"), do: "tag-lemon"
  defp mechanism_tag("royalty"), do: "tag-coral"
  defp mechanism_tag("liquidation"), do: "tag-red"
  defp mechanism_tag(_), do: ""

  defp humanize_mechanism("loan_repayment"), do: "Loan Repayment"
  defp humanize_mechanism("management_fee"), do: "Management Fee"
  defp humanize_mechanism(m) when is_binary(m), do: String.capitalize(m)
  defp humanize_mechanism(_), do: ""

  defp plan_status_tag("draft"), do: "tag-lemon"
  defp plan_status_tag("approved"), do: "tag-jade"
  defp plan_status_tag("executed"), do: "tag-sky"
  defp plan_status_tag(_), do: ""

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
