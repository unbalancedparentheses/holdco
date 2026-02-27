defmodule HoldcoWeb.LeaseLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Finance, Corporate}

  @impl true
  def mount(_params, _session, socket) do
    companies = Corporate.list_companies()
    leases = Finance.list_leases()
    metrics = compute_metrics(leases)

    {:ok,
     assign(socket,
       page_title: "Lease Accounting",
       companies: companies,
       leases: leases,
       metrics: metrics,
       selected_company_id: "",
       selected_lease: nil,
       schedule: [],
       show_form: false,
       editing_item: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("filter_company", %{"company_id" => id}, socket) do
    company_id = if id == "", do: nil, else: String.to_integer(id)
    leases = Finance.list_leases(company_id)
    metrics = compute_metrics(leases)

    {:noreply,
     assign(socket,
       selected_company_id: id,
       leases: leases,
       metrics: metrics,
       selected_lease: nil,
       schedule: []
     )}
  end

  def handle_event("select_lease", %{"id" => id}, socket) do
    lease = Finance.get_lease!(String.to_integer(id))
    schedule = amortization_schedule(lease)

    {:noreply, assign(socket, selected_lease: lease, schedule: schedule)}
  end

  def handle_event("close_schedule", _, socket) do
    {:noreply, assign(socket, selected_lease: nil, schedule: [])}
  end

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: :add, editing_item: nil)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false, editing_item: nil)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    lease = Finance.get_lease!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: lease)}
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

  def handle_event("save", %{"lease" => params}, socket) do
    case Finance.create_lease(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Lease added")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add lease")}
    end
  end

  def handle_event("update", %{"lease" => params}, socket) do
    lease = socket.assigns.editing_item

    case Finance.update_lease(lease, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Lease updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update lease")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    lease = Finance.get_lease!(String.to_integer(id))

    case Finance.delete_lease(lease) do
      {:ok, _} ->
        selected =
          if socket.assigns.selected_lease && socket.assigns.selected_lease.id == lease.id,
            do: nil,
            else: socket.assigns.selected_lease

        {:noreply,
         reload(socket)
         |> put_flash(:info, "Lease deleted")
         |> assign(
           selected_lease: selected,
           schedule: if(selected, do: socket.assigns.schedule, else: [])
         )}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete lease")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Lease Accounting</h1>
          <p class="deck">IFRS 16 / ASC 842 lease tracking with ROU assets and liability calculations</p>
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
            <button class="btn btn-primary" phx-click="show_form">Add Lease</button>
          <% end %>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total ROU Assets</div>
        <div class="metric-value">${format_number(@metrics.total_rou_assets)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Total Lease Liabilities</div>
        <div class="metric-value num-negative">${format_number(@metrics.total_lease_liabilities)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Monthly Payment Obligation</div>
        <div class="metric-value">${format_number(@metrics.total_monthly_payment)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Active Leases</div>
        <div class="metric-value">{length(@leases)}</div>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Leases</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Lessor</th>
              <th>Asset Description</th>
              <th>Company</th>
              <th>Type</th>
              <th class="th-num">Monthly Payment</th>
              <th>Currency</th>
              <th class="td-mono">Start</th>
              <th class="td-mono">End</th>
              <th class="th-num">Discount Rate</th>
              <th class="th-num">PV (Liability)</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for lease <- @leases do %>
              <% pv = present_value(lease) %>
              <tr>
                <td>
                  <button
                    phx-click="select_lease"
                    phx-value-id={lease.id}
                    class="td-link td-name"
                    style="background: none; border: none; cursor: pointer; padding: 0; font: inherit; text-align: left;"
                  >
                    {lease.lessor}
                  </button>
                </td>
                <td>{lease.asset_description || "---"}</td>
                <td>
                  <%= if lease.company do %>
                    <.link navigate={~p"/companies/#{lease.company.id}"} class="td-link">{lease.company.name}</.link>
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td>
                  <span class={"tag #{lease_type_tag(lease.lease_type)}"}>{humanize_lease_type(lease.lease_type)}</span>
                </td>
                <td class="td-num">{format_number(lease.monthly_payment || 0.0)}</td>
                <td>{lease.currency || "USD"}</td>
                <td class="td-mono">{lease.start_date || "---"}</td>
                <td class="td-mono">{lease.end_date || "---"}</td>
                <td class="td-num">{format_rate(lease.discount_rate)}%</td>
                <td class="td-num num-negative">{format_number(pv)}</td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button
                        phx-click="edit"
                        phx-value-id={lease.id}
                        class="btn btn-secondary btn-sm"
                      >
                        Edit
                      </button>
                      <button
                        phx-click="delete"
                        phx-value-id={lease.id}
                        class="btn btn-danger btn-sm"
                        data-confirm="Delete this lease?"
                      >
                        Del
                      </button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @leases == [] do %>
          <div class="empty-state">
            <p>No leases found.</p>
            <p style="color: var(--muted); font-size: 0.9rem;">
              Track operating and finance leases under IFRS 16 / ASC 842 with right-of-use asset and liability calculations.
            </p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_form">Add Your First Lease</button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Lease Portfolio Breakdown</h2>
      </div>
      <div class="panel" style="padding: 1rem;">
        <div
          id="lease-pv-chart"
          phx-hook="ChartHook"
          data-chart-type="bar"
          data-chart-data={Jason.encode!(lease_chart_data(@leases))}
          style="height: 300px;"
        >
          <canvas></canvas>
        </div>
      </div>
    </div>

    <%= if @selected_lease do %>
      <div class="section">
        <div class="section-head" style="display: flex; justify-content: space-between; align-items: center;">
          <h2>Amortization Schedule: {@selected_lease.lessor}</h2>
          <button phx-click="close_schedule" class="btn btn-secondary btn-sm">Close</button>
        </div>
        <div class="panel" style="padding: 1rem; margin-bottom: 1rem;">
          <div class="grid-2">
            <div>
              <div style="font-size: 0.85rem; color: #888; margin-bottom: 0.25rem;">Asset</div>
              <div style="font-weight: 600;">{@selected_lease.asset_description || @selected_lease.lessor}</div>
            </div>
            <div>
              <div style="font-size: 0.85rem; color: #888; margin-bottom: 0.25rem;">Lease Type</div>
              <div><span class={"tag #{lease_type_tag(@selected_lease.lease_type)}"}>{humanize_lease_type(@selected_lease.lease_type)}</span></div>
            </div>
            <div>
              <div style="font-size: 0.85rem; color: #888; margin-bottom: 0.25rem;">ROU Asset (at inception)</div>
              <div style="font-weight: 600;">${format_number(rou_asset_at_inception(@selected_lease))}</div>
            </div>
            <div>
              <div style="font-size: 0.85rem; color: #888; margin-bottom: 0.25rem;">Remaining Lease Liability</div>
              <div style="font-weight: 600; color: #cc0000;">${format_number(present_value(@selected_lease))}</div>
            </div>
          </div>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Month</th>
                <th class="th-num">Opening Balance</th>
                <th class="th-num">Payment</th>
                <th class="th-num">Interest</th>
                <th class="th-num">Principal</th>
                <th class="th-num">Closing Balance</th>
              </tr>
            </thead>
            <tbody>
              <%= for row <- @schedule do %>
                <tr>
                  <td class="td-mono">{row.month}</td>
                  <td class="td-num">{format_number(row.opening_balance)}</td>
                  <td class="td-num">{format_number(row.payment)}</td>
                  <td class="td-num">{format_number(row.interest)}</td>
                  <td class="td-num">{format_number(row.principal)}</td>
                  <td class="td-num">{format_number(row.closing_balance)}</td>
                </tr>
              <% end %>
            </tbody>
          </table>
          <%= if @schedule == [] do %>
            <div class="empty-state">No amortization schedule available. Ensure start date, end date, payment, and discount rate are set.</div>
          <% end %>
        </div>
      </div>
    <% end %>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit Lease", else: "Add Lease"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Lessor *</label>
                <input
                  type="text"
                  name="lease[lessor]"
                  class="form-input"
                  value={if @editing_item, do: @editing_item.lessor, else: ""}
                  required
                />
              </div>
              <div class="form-group">
                <label class="form-label">Asset Description</label>
                <input
                  type="text"
                  name="lease[asset_description]"
                  class="form-input"
                  value={if @editing_item, do: @editing_item.asset_description, else: ""}
                />
              </div>
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="lease[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option
                      value={c.id}
                      selected={@editing_item && @editing_item.company_id == c.id}
                    >
                      {c.name}
                    </option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Lease Type</label>
                <select name="lease[lease_type]" class="form-select">
                  <option
                    value="operating"
                    selected={!@editing_item || @editing_item.lease_type == "operating"}
                  >
                    Operating
                  </option>
                  <option
                    value="finance"
                    selected={@editing_item && @editing_item.lease_type == "finance"}
                  >
                    Finance
                  </option>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Start Date</label>
                <input
                  type="date"
                  name="lease[start_date]"
                  class="form-input"
                  value={if @editing_item, do: @editing_item.start_date, else: ""}
                />
              </div>
              <div class="form-group">
                <label class="form-label">End Date</label>
                <input
                  type="date"
                  name="lease[end_date]"
                  class="form-input"
                  value={if @editing_item, do: @editing_item.end_date, else: ""}
                />
              </div>
              <div class="form-group">
                <label class="form-label">Monthly Payment</label>
                <input
                  type="number"
                  name="lease[monthly_payment]"
                  class="form-input"
                  step="any"
                  value={if @editing_item, do: @editing_item.monthly_payment, else: "0"}
                />
              </div>
              <div class="form-group">
                <label class="form-label">Discount Rate (annual %)</label>
                <input
                  type="number"
                  name="lease[discount_rate]"
                  class="form-input"
                  step="any"
                  value={if @editing_item, do: @editing_item.discount_rate, else: "5.0"}
                />
              </div>
              <div class="form-group">
                <label class="form-label">Currency</label>
                <select name="lease[currency]" class="form-select">
                  <%= for cur <- ~w(USD EUR GBP CHF JPY AUD CAD) do %>
                    <option
                      value={cur}
                      selected={
                        (@editing_item && @editing_item.currency == cur) ||
                          (!@editing_item && cur == "USD")
                      }
                    >
                      {cur}
                    </option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea
                  name="lease[notes]"
                  class="form-input"
                >{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">
                  {if @show_form == :edit, do: "Update Lease", else: "Add Lease"}
                </button>
                <button type="button" phx-click="close_form" class="btn btn-secondary">
                  Cancel
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  # -- Data reload --

  defp reload(socket) do
    company_id =
      case socket.assigns.selected_company_id do
        "" -> nil
        id -> String.to_integer(id)
      end

    leases = Finance.list_leases(company_id)
    metrics = compute_metrics(leases)
    assign(socket, leases: leases, metrics: metrics)
  end

  # -- Metrics --

  defp compute_metrics(leases) do
    total_rou =
      Enum.reduce(leases, 0.0, fn lease, acc -> acc + rou_asset_at_inception(lease) end)

    total_liability =
      Enum.reduce(leases, 0.0, fn lease, acc -> acc + present_value(lease) end)

    total_monthly =
      Enum.reduce(leases, 0.0, fn lease, acc -> acc + (lease.monthly_payment || 0.0) end)

    %{
      total_rou_assets: total_rou,
      total_lease_liabilities: total_liability,
      total_monthly_payment: total_monthly
    }
  end

  # -- PV & Amortization Calculations --

  # Present Value of lease payments:
  # PV = payment * (1 - (1 + r)^(-n)) / r
  # where r is monthly discount rate, n is remaining months.
  defp present_value(lease) do
    payment = lease.monthly_payment || 0.0
    n = remaining_months(lease)
    r = monthly_rate(lease)

    calculate_pv(payment, r, n)
  end

  defp rou_asset_at_inception(lease) do
    payment = lease.monthly_payment || 0.0
    n = total_months(lease)
    r = monthly_rate(lease)

    calculate_pv(payment, r, n)
  end

  defp calculate_pv(_payment, _r, n) when n <= 0, do: 0.0

  defp calculate_pv(payment, r, n) when r <= 0.0 do
    # If discount rate is zero, PV is simply payment * n
    payment * n
  end

  defp calculate_pv(payment, r, n) do
    # PV = payment * (1 - (1 + r)^(-n)) / r
    payment * (1.0 - :math.pow(1.0 + r, -n)) / r
  end

  defp monthly_rate(lease) do
    annual_rate = (lease.discount_rate || 5.0) / 100.0
    annual_rate / 12.0
  end

  defp total_months(lease) do
    case {parse_date(lease.start_date), parse_date(lease.end_date)} do
      {nil, _} -> 0
      {_, nil} -> 0
      {start_date, end_date} -> max(months_between(start_date, end_date), 0)
    end
  end

  defp remaining_months(lease) do
    today = Date.utc_today()

    case {parse_date(lease.start_date), parse_date(lease.end_date)} do
      {nil, _} -> 0
      {_, nil} -> 0
      {_start_date, end_date} -> max(months_between(today, end_date), 0)
    end
  end

  defp months_between(from, to) do
    days = Date.diff(to, from)
    # Approximate months from days
    round(days / 30.44)
  end

  defp amortization_schedule(lease) do
    payment = lease.monthly_payment || 0.0
    n = remaining_months(lease)
    r = monthly_rate(lease)
    pv = present_value(lease)

    if n <= 0 or payment <= 0 or pv <= 0 do
      []
    else
      build_schedule(1, n, pv, payment, r, [])
    end
  end

  defp build_schedule(month, total_months, opening, _payment, _r, acc)
       when month > total_months or opening <= 0.01 do
    Enum.reverse(acc)
  end

  defp build_schedule(month, total_months, opening, payment, r, acc) do
    interest = Float.round(opening * r, 2)
    # On the last month, adjust payment to close out the balance
    effective_payment = if month == total_months, do: opening + interest, else: payment
    principal = Float.round(effective_payment - interest, 2)
    closing = Float.round(max(opening - principal, 0.0), 2)

    row = %{
      month: month,
      opening_balance: Float.round(opening, 2),
      payment: Float.round(effective_payment, 2),
      interest: interest,
      principal: principal,
      closing_balance: closing
    }

    build_schedule(month + 1, total_months, closing, payment, r, [row | acc])
  end

  # -- Chart data --

  defp lease_chart_data(leases) do
    data =
      leases
      |> Enum.map(fn lease ->
        %{
          label: lease.lessor || "Unknown",
          rou: rou_asset_at_inception(lease),
          liability: present_value(lease)
        }
      end)
      |> Enum.sort_by(& &1.liability, :desc)
      |> Enum.take(20)

    %{
      labels: Enum.map(data, & &1.label),
      datasets: [
        %{
          label: "ROU Asset (inception)",
          data: Enum.map(data, & &1.rou),
          backgroundColor: "#4a8c87"
        },
        %{
          label: "Lease Liability (remaining)",
          data: Enum.map(data, & &1.liability),
          backgroundColor: "#b0605e"
        }
      ]
    }
  end

  # -- Helpers --

  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil

  defp parse_date(date_str) do
    case Date.from_iso8601(date_str) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp lease_type_tag("finance"), do: "tag-lemon"
  defp lease_type_tag(_), do: "tag-jade"

  defp humanize_lease_type("operating"), do: "Operating"
  defp humanize_lease_type("finance"), do: "Finance"
  defp humanize_lease_type(other), do: other || "Operating"

  defp format_rate(nil), do: "0.00"
  defp format_rate(r), do: :erlang.float_to_binary(r * 1.0, decimals: 2)

  defp format_number(n) when is_float(n),
    do: :erlang.float_to_binary(n, decimals: 2) |> add_commas()

  defp format_number(n) when is_integer(n), do: Integer.to_string(n) |> add_commas()
  defp format_number(_), do: "0.00"

  defp add_commas(str) do
    case String.split(str, ".") do
      [int_part, dec_part] ->
        formatted_int =
          int_part
          |> String.reverse()
          |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
          |> String.reverse()

        "#{formatted_int}.#{dec_part}"

      [int_part] ->
        int_part
        |> String.reverse()
        |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
        |> String.reverse()
    end
  end
end
