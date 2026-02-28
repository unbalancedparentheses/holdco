defmodule HoldcoWeb.SegmentLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Finance, Corporate, Money}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Finance.subscribe()

    segments = Finance.list_segments()
    companies = Corporate.list_companies()

    {:ok,
     assign(socket,
       page_title: "Segment Reporting",
       segments: segments,
       companies: companies,
       selected_company_id: "",
       show_form: false,
       editing_item: nil,
       selected_segment: nil,
       trial_balance: [],
       segment_revenue: 0.0,
       segment_expenses: 0.0,
       segment_income: 0.0
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("show_form", _, socket),
    do: {:noreply, assign(socket, show_form: :add, editing_item: nil)}

  def handle_event("close_form", _, socket),
    do: {:noreply, assign(socket, show_form: false, editing_item: nil)}

  def handle_event("filter_company", %{"company_id" => id}, socket) do
    company_id = if id == "", do: nil, else: String.to_integer(id)
    segments = Finance.list_segments(company_id)
    {:noreply, assign(socket, selected_company_id: id, segments: segments)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    segment = Finance.get_segment!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: segment)}
  end

  def handle_event("select_segment", %{"id" => id}, socket) do
    segment_id = String.to_integer(id)
    segment = Finance.get_segment!(segment_id)
    tb = Finance.trial_balance_by_segment(segment_id)

    {revenue, expenses, income} = compute_segment_totals(tb)

    {:noreply,
     assign(socket,
       selected_segment: segment,
       trial_balance: tb,
       segment_revenue: revenue,
       segment_expenses: expenses,
       segment_income: income
     )}
  end

  def handle_event("deselect_segment", _, socket) do
    {:noreply,
     assign(socket,
       selected_segment: nil,
       trial_balance: [],
       segment_revenue: 0.0,
       segment_expenses: 0.0,
       segment_income: 0.0
     )}
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

  def handle_event("save", %{"segment" => params}, socket) do
    case Finance.create_segment(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Segment created")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create segment")}
    end
  end

  def handle_event("update", %{"segment" => params}, socket) do
    segment = socket.assigns.editing_item

    case Finance.update_segment(segment, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Segment updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update segment")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    segment = Finance.get_segment!(String.to_integer(id))
    Finance.delete_segment(segment)

    selected_segment =
      if socket.assigns.selected_segment && socket.assigns.selected_segment.id == segment.id,
        do: nil,
        else: socket.assigns.selected_segment

    {:noreply,
     reload(socket)
     |> put_flash(:info, "Segment deleted")
     |> assign(
       selected_segment: selected_segment,
       trial_balance: if(selected_segment, do: socket.assigns.trial_balance, else: []),
       segment_revenue: if(selected_segment, do: socket.assigns.segment_revenue, else: 0.0),
       segment_expenses: if(selected_segment, do: socket.assigns.segment_expenses, else: 0.0),
       segment_income: if(selected_segment, do: socket.assigns.segment_income, else: 0.0)
     )}
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, reload(socket)}

  defp reload(socket) do
    company_id =
      case socket.assigns.selected_company_id do
        "" -> nil
        id -> String.to_integer(id)
      end

    assign(socket, segments: Finance.list_segments(company_id))
  end

  defp compute_segment_totals(trial_balance) do
    revenue =
      trial_balance
      |> Enum.filter(&(&1.account_type in ["revenue", "income"]))
      |> Enum.reduce(Decimal.new(0), &Money.add(Money.sub(&1.total_credit, &1.total_debit), &2))

    expenses =
      trial_balance
      |> Enum.filter(&(&1.account_type == "expense"))
      |> Enum.reduce(Decimal.new(0), &Money.add(Money.sub(&1.total_debit, &1.total_credit), &2))

    income = Money.sub(revenue, expenses)
    {revenue, expenses, income}
  end

  defp revenue_accounts(trial_balance) do
    Enum.filter(trial_balance, &(&1.account_type in ["revenue", "income"]))
  end

  defp expense_accounts(trial_balance) do
    Enum.filter(trial_balance, &(&1.account_type == "expense"))
  end

  defp segment_comparison_chart(segments) do
    segment_data =
      Enum.map(segments, fn s ->
        tb = Finance.trial_balance_by_segment(s.id)
        {rev, exp, inc} = compute_segment_totals(tb)
        %{name: s.name, revenue: rev, expenses: exp, income: inc}
      end)

    %{
      labels: Enum.map(segment_data, & &1.name),
      datasets: [
        %{label: "Revenue", data: Enum.map(segment_data, & &1.revenue), backgroundColor: "#00994d"},
        %{label: "Expenses", data: Enum.map(segment_data, & &1.expenses), backgroundColor: "#cc0000"},
        %{label: "Net Income", data: Enum.map(segment_data, & &1.income), backgroundColor: "#4a8c87"}
      ]
    }
  end

  defp format_number(n) when is_float(n),
    do: :erlang.float_to_binary(n, decimals: 2) |> add_commas()

  defp format_number(n) when is_integer(n), do: Integer.to_string(n) |> add_commas()
  defp format_number(_), do: "0"

  defp add_commas(str) do
    str |> String.reverse() |> String.replace(~r/(\d{3})(?=\d)/, "\\1,") |> String.reverse()
  end

  defp segment_type_tag("business"), do: "tag-jade"
  defp segment_type_tag("geographic"), do: "tag-lemon"
  defp segment_type_tag("product"), do: "tag-ink"
  defp segment_type_tag(_), do: "tag-ink"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Segment Reporting</h1>
          <p class="deck">Revenue, expenses, and income broken down by business segment</p>
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
            <button class="btn btn-primary" phx-click="show_form">Add Segment</button>
          <% end %>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Segments</div>
        <div class="metric-value">{length(@segments)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Business</div>
        <div class="metric-value">{Enum.count(@segments, &(&1.segment_type == "business"))}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Geographic</div>
        <div class="metric-value">{Enum.count(@segments, &(&1.segment_type == "geographic"))}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Product</div>
        <div class="metric-value">{Enum.count(@segments, &(&1.segment_type == "product"))}</div>
      </div>
    </div>

    <%= if length(@segments) > 1 do %>
      <div class="section">
        <div class="section-head">
          <h2>Segment Comparison</h2>
        </div>
        <div class="panel" style="padding: 1rem;">
          <div
            id="segment-comparison-chart"
            phx-hook="ChartHook"
            data-chart-type="bar"
            data-chart-data={Jason.encode!(segment_comparison_chart(@segments))}
            data-chart-options={
              Jason.encode!(%{
                plugins: %{legend: %{display: true}},
                scales: %{y: %{beginAtZero: true}}
              })
            }
            style="height: 300px;"
          >
            <canvas></canvas>
          </div>
        </div>
      </div>
    <% end %>

    <div class="section">
      <div class="section-head">
        <h2>Segments</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>Type</th>
              <th>Description</th>
              <th>Company</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for s <- @segments do %>
              <tr>
                <td>
                  <a href="#" phx-click="select_segment" phx-value-id={s.id} class="td-link td-name">
                    {s.name}
                  </a>
                </td>
                <td><span class={"tag #{segment_type_tag(s.segment_type)}"}>{s.segment_type}</span></td>
                <td>{s.description || ""}</td>
                <td>
                  <%= if s.company do %>
                    <.link navigate={~p"/companies/#{s.company.id}"} class="td-link">{s.company.name}</.link>
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit" phx-value-id={s.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete" phx-value-id={s.id} class="btn btn-danger btn-sm" data-confirm="Delete this segment?">Del</button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @segments == [] do %>
          <div class="empty-state">
            <p>No segments defined yet.</p>
            <p style="color: var(--muted); font-size: 0.9rem;">
              Create segments to break down your financials by business line, geography, or product category.
            </p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_form">Add Your First Segment</button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%!-- Segment Detail / Trial Balance --%>
    <%= if @selected_segment do %>
      <div class="section">
        <div class="section-head" style="display: flex; justify-content: space-between; align-items: center;">
          <h2>{@selected_segment.name} -- Trial Balance</h2>
          <a href="#" phx-click="deselect_segment" class="btn btn-secondary btn-sm">Close</a>
        </div>

        <div class="metrics-strip">
          <div class="metric-cell">
            <div class="metric-label">Revenue</div>
            <div class="metric-value num-positive">{format_number(@segment_revenue)}</div>
          </div>
          <div class="metric-cell">
            <div class="metric-label">Expenses</div>
            <div class="metric-value num-negative">{format_number(@segment_expenses)}</div>
          </div>
          <div class="metric-cell">
            <div class="metric-label">Net Income</div>
            <div class={"metric-value #{if @segment_income >= 0, do: "num-positive", else: "num-negative"}"}>
              {format_number(@segment_income)}
            </div>
          </div>
        </div>

        <div class="grid-2">
          <div class="panel">
            <h3 style="padding: 0.75rem 1rem 0; margin: 0; font-size: 0.95rem;">Revenue Accounts</h3>
            <table>
              <thead>
                <tr>
                  <th>Code</th>
                  <th>Name</th>
                  <th class="th-num">Debit</th>
                  <th class="th-num">Credit</th>
                  <th class="th-num">Balance</th>
                </tr>
              </thead>
              <tbody>
                <%= for a <- revenue_accounts(@trial_balance) do %>
                  <tr>
                    <td class="td-mono">{a.code}</td>
                    <td class="td-name">{a.name}</td>
                    <td class="td-num">{format_number(a.total_debit)}</td>
                    <td class="td-num">{format_number(a.total_credit)}</td>
                    <td class="td-num num-positive">{format_number(Money.sub(a.total_credit, a.total_debit))}</td>
                  </tr>
                <% end %>
              </tbody>
              <tfoot>
                <tr style="font-weight: bold;">
                  <td colspan="4">Total Revenue</td>
                  <td class="td-num num-positive">{format_number(@segment_revenue)}</td>
                </tr>
              </tfoot>
            </table>
            <%= if revenue_accounts(@trial_balance) == [] do %>
              <div class="empty-state">No revenue accounts in this segment.</div>
            <% end %>
          </div>

          <div class="panel">
            <h3 style="padding: 0.75rem 1rem 0; margin: 0; font-size: 0.95rem;">Expense Accounts</h3>
            <table>
              <thead>
                <tr>
                  <th>Code</th>
                  <th>Name</th>
                  <th class="th-num">Debit</th>
                  <th class="th-num">Credit</th>
                  <th class="th-num">Balance</th>
                </tr>
              </thead>
              <tbody>
                <%= for a <- expense_accounts(@trial_balance) do %>
                  <tr>
                    <td class="td-mono">{a.code}</td>
                    <td class="td-name">{a.name}</td>
                    <td class="td-num">{format_number(a.total_debit)}</td>
                    <td class="td-num">{format_number(a.total_credit)}</td>
                    <td class="td-num num-negative">{format_number(Money.sub(a.total_debit, a.total_credit))}</td>
                  </tr>
                <% end %>
              </tbody>
              <tfoot>
                <tr style="font-weight: bold;">
                  <td colspan="4">Total Expenses</td>
                  <td class="td-num num-negative">{format_number(@segment_expenses)}</td>
                </tr>
              </tfoot>
            </table>
            <%= if expense_accounts(@trial_balance) == [] do %>
              <div class="empty-state">No expense accounts in this segment.</div>
            <% end %>
          </div>
        </div>
      </div>
    <% end %>

    <%!-- Add/Edit Segment Modal --%>
    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit Segment", else: "Add Segment"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Name *</label>
                <input
                  type="text"
                  name="segment[name]"
                  class="form-input"
                  value={if @editing_item, do: @editing_item.name, else: ""}
                  required
                />
              </div>
              <div class="form-group">
                <label class="form-label">Segment Type *</label>
                <select name="segment[segment_type]" class="form-select" required>
                  <option value="">Select type</option>
                  <%= for t <- ~w(business geographic product) do %>
                    <option value={t} selected={@editing_item && @editing_item.segment_type == t}>{t}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Description</label>
                <textarea
                  name="segment[description]"
                  class="form-input"
                >{if @editing_item, do: @editing_item.description, else: ""}</textarea>
              </div>
              <div class="form-group">
                <label class="form-label">Company</label>
                <select name="segment[company_id]" class="form-select">
                  <option value="">-- No company (global) --</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={@editing_item && @editing_item.company_id == c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">
                  {if @show_form == :edit, do: "Update Segment", else: "Add Segment"}
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
