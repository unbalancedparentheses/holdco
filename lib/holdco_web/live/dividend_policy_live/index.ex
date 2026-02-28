defmodule HoldcoWeb.DividendPolicyLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Fund, Corporate, Money}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Fund.subscribe()

    policies = Fund.list_dividend_policies()
    companies = Corporate.list_companies()

    {:ok,
     assign(socket,
       page_title: "Dividend Policies",
       policies: policies,
       companies: companies,
       selected_company_id: "",
       show_form: false,
       editing_item: nil,
       calculation_result: nil,
       calculating_policy: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("show_form", _, socket),
    do: {:noreply, assign(socket, show_form: :add, editing_item: nil)}

  def handle_event("close_form", _, socket),
    do: {:noreply, assign(socket, show_form: false, editing_item: nil, calculation_result: nil, calculating_policy: nil)}

  def handle_event("filter_company", %{"company_id" => id}, socket) do
    company_id = if id == "", do: nil, else: String.to_integer(id)
    policies = Fund.list_dividend_policies(company_id)
    {:noreply, assign(socket, selected_company_id: id, policies: policies)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    policy = Fund.get_dividend_policy!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: policy)}
  end

  def handle_event("calculate_dividend", %{"id" => id}, socket) do
    policy = Fund.get_dividend_policy!(String.to_integer(id))
    result = Fund.calculate_dividend(policy, policy.company_id)
    {:noreply, assign(socket, calculation_result: result, calculating_policy: policy)}
  end

  def handle_event("close_calculation", _, socket) do
    {:noreply, assign(socket, calculation_result: nil, calculating_policy: nil)}
  end

  def handle_event("advance_date", %{"id" => id}, socket) do
    policy = Fund.get_dividend_policy!(String.to_integer(id))

    case Fund.advance_dividend_date(policy) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Dividend date advanced")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to advance date")}
    end
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

  def handle_event("save", %{"policy" => params}, socket) do
    case Fund.create_dividend_policy(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Dividend policy created")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create policy")}
    end
  end

  def handle_event("update", %{"policy" => params}, socket) do
    policy = socket.assigns.editing_item

    case Fund.update_dividend_policy(policy, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Dividend policy updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update policy")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    policy = Fund.get_dividend_policy!(String.to_integer(id))
    Fund.delete_dividend_policy(policy)

    {:noreply,
     reload(socket)
     |> put_flash(:info, "Dividend policy deleted")}
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, reload(socket)}

  defp reload(socket) do
    company_id =
      case socket.assigns.selected_company_id do
        "" -> nil
        id -> String.to_integer(id)
      end

    assign(socket, policies: Fund.list_dividend_policies(company_id))
  end

  defp format_decimal(nil), do: "---"
  defp format_decimal(val), do: Money.format(val, 2)

  defp policy_type_label("fixed_amount"), do: "Fixed Amount"
  defp policy_type_label("payout_ratio"), do: "Payout Ratio"
  defp policy_type_label("stable_growth"), do: "Stable Growth"
  defp policy_type_label("residual"), do: "Residual"
  defp policy_type_label(other), do: other

  defp frequency_label("monthly"), do: "Monthly"
  defp frequency_label("quarterly"), do: "Quarterly"
  defp frequency_label("semi_annual"), do: "Semi-Annual"
  defp frequency_label("annual"), do: "Annual"
  defp frequency_label(other), do: other

  defp policy_type_tag("fixed_amount"), do: "tag-jade"
  defp policy_type_tag("payout_ratio"), do: "tag-lemon"
  defp policy_type_tag("stable_growth"), do: "tag-ink"
  defp policy_type_tag("residual"), do: "tag-coral"
  defp policy_type_tag(_), do: "tag-ink"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Dividend Policies</h1>
          <p class="deck">Configure and manage dividend distribution policies for your companies</p>
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
            <button class="btn btn-primary" phx-click="show_form">Add Policy</button>
          <% end %>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Policies</div>
        <div class="metric-value">{length(@policies)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Active</div>
        <div class="metric-value">{Enum.count(@policies, & &1.is_active)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Fixed Amount</div>
        <div class="metric-value">{Enum.count(@policies, &(&1.policy_type == "fixed_amount"))}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Payout Ratio</div>
        <div class="metric-value">{Enum.count(@policies, &(&1.policy_type == "payout_ratio"))}</div>
      </div>
    </div>

    <%!-- Calculation Result --%>
    <%= if @calculation_result do %>
      <div class="section">
        <div class="section-head" style="display: flex; justify-content: space-between; align-items: center;">
          <h2>Dividend Recommendation -- {@calculating_policy.name}</h2>
          <button phx-click="close_calculation" class="btn btn-secondary btn-sm">Close</button>
        </div>
        <div class="metrics-strip">
          <div class="metric-cell">
            <div class="metric-label">Recommended Amount</div>
            <div class="metric-value num-positive">{format_decimal(@calculation_result.recommended_amount)}</div>
          </div>
          <div class="metric-cell">
            <div class="metric-label">Payout Ratio</div>
            <div class="metric-value">{format_decimal(@calculation_result.payout_ratio)}%</div>
          </div>
          <div class="metric-cell">
            <div class="metric-label">Retained Earnings</div>
            <div class="metric-value">{format_decimal(@calculation_result.retained_earnings)}</div>
          </div>
        </div>
      </div>
    <% end %>

    <div class="section">
      <div class="section-head">
        <h2>Policies</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>Company</th>
              <th>Type</th>
              <th>Frequency</th>
              <th>Active</th>
              <th>Next Dividend</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for p <- @policies do %>
              <tr>
                <td class="td-name">{p.name}</td>
                <td>
                  <%= if p.company do %>
                    <.link navigate={~p"/companies/#{p.company.id}"} class="td-link">{p.company.name}</.link>
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td><span class={"tag #{policy_type_tag(p.policy_type)}"}>{policy_type_label(p.policy_type)}</span></td>
                <td>{frequency_label(p.frequency)}</td>
                <td>
                  <%= if p.is_active do %>
                    <span class="tag tag-jade">Active</span>
                  <% else %>
                    <span class="tag tag-ink">Inactive</span>
                  <% end %>
                </td>
                <td>{if p.next_dividend_date, do: Date.to_string(p.next_dividend_date), else: "---"}</td>
                <td>
                  <div style="display: flex; gap: 0.25rem;">
                    <button phx-click="calculate_dividend" phx-value-id={p.id} class="btn btn-secondary btn-sm">Calculate</button>
                    <%= if @can_write do %>
                      <button phx-click="advance_date" phx-value-id={p.id} class="btn btn-secondary btn-sm">Advance Date</button>
                      <button phx-click="edit" phx-value-id={p.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete" phx-value-id={p.id} class="btn btn-danger btn-sm" data-confirm="Delete this policy?">Del</button>
                    <% end %>
                  </div>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @policies == [] do %>
          <div class="empty-state">
            <p>No dividend policies defined yet.</p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_form">Add Your First Policy</button>
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
            <h3>{if @show_form == :edit, do: "Edit Dividend Policy", else: "Add Dividend Policy"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Name *</label>
                <input type="text" name="policy[name]" class="form-input" value={if @editing_item, do: @editing_item.name, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="policy[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={@editing_item && @editing_item.company_id == c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Policy Type *</label>
                <select name="policy[policy_type]" class="form-select" required>
                  <option value="">Select type</option>
                  <%= for t <- ~w(fixed_amount payout_ratio stable_growth residual) do %>
                    <option value={t} selected={@editing_item && @editing_item.policy_type == t}>{policy_type_label(t)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Frequency</label>
                <select name="policy[frequency]" class="form-select">
                  <%= for f <- ~w(monthly quarterly semi_annual annual) do %>
                    <option value={f} selected={@editing_item && @editing_item.frequency == f}>{frequency_label(f)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Target Payout Ratio (%)</label>
                <input type="number" step="0.01" name="policy[target_payout_ratio]" class="form-input" value={if @editing_item, do: @editing_item.target_payout_ratio, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Fixed Amount</label>
                <input type="number" step="0.01" name="policy[fixed_amount]" class="form-input" value={if @editing_item, do: @editing_item.fixed_amount, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Growth Rate (%)</label>
                <input type="number" step="0.01" name="policy[growth_rate]" class="form-input" value={if @editing_item, do: @editing_item.growth_rate, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Max Payout Ratio (%)</label>
                <input type="number" step="0.01" name="policy[max_payout_ratio]" class="form-input" value={if @editing_item, do: @editing_item.max_payout_ratio, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Min Retained Earnings</label>
                <input type="number" step="0.01" name="policy[min_retained_earnings]" class="form-input" value={if @editing_item, do: @editing_item.min_retained_earnings, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="policy[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">
                  {if @show_form == :edit, do: "Update Policy", else: "Add Policy"}
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
