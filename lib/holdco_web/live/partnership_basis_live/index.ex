defmodule HoldcoWeb.PartnershipBasisLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Fund, Corporate, Money}

  @impl true
  def mount(_params, _session, socket) do
    companies = Corporate.list_companies()
    bases = Fund.list_partnership_bases()

    {:ok,
     assign(socket,
       page_title: "Partnership Basis Tracking",
       companies: companies,
       bases: bases,
       selected_company_id: "",
       selected_partner: nil,
       history: [],
       chart_data: [],
       show_form: false,
       editing_item: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("filter_company", %{"company_id" => id}, socket) do
    company_id = if id == "", do: nil, else: String.to_integer(id)
    bases = Fund.list_partnership_bases(company_id)

    {:noreply,
     assign(socket,
       selected_company_id: id,
       bases: bases,
       selected_partner: nil,
       history: [],
       chart_data: []
     )}
  end

  def handle_event("view_history", %{"company-id" => company_id, "partner" => partner_name}, socket) do
    cid = String.to_integer(company_id)
    history = Fund.basis_history(cid, partner_name)

    chart_data =
      Enum.map(history, fn pb ->
        %{
          tax_year: pb.tax_year,
          beginning_basis: Money.to_float(pb.beginning_basis),
          ending_basis: Money.to_float(pb.ending_basis),
          calculated_ending: Money.to_float(Fund.calculate_ending_basis(pb))
        }
      end)

    {:noreply,
     assign(socket,
       selected_partner: partner_name,
       history: history,
       chart_data: chart_data
     )}
  end

  def handle_event("close_history", _, socket) do
    {:noreply, assign(socket, selected_partner: nil, history: [], chart_data: [])}
  end

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: :add, editing_item: nil)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false, editing_item: nil)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    basis = Fund.get_partnership_basis!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: basis)}
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

  def handle_event("save", %{"partnership_basis" => params}, socket) do
    case Fund.create_partnership_basis(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Partnership basis record added")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add partnership basis")}
    end
  end

  def handle_event("update", %{"partnership_basis" => params}, socket) do
    basis = socket.assigns.editing_item

    case Fund.update_partnership_basis(basis, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Partnership basis updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update partnership basis")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    basis = Fund.get_partnership_basis!(String.to_integer(id))

    case Fund.delete_partnership_basis(basis) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Partnership basis record deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete partnership basis")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Partnership Basis Tracking</h1>
          <p class="deck">Track partner tax basis, at-risk amounts, and passive activity limitations</p>
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
            <button class="btn btn-primary" phx-click="show_form">Add Basis Record</button>
          <% end %>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Records</div>
        <div class="metric-value">{length(@bases)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Unique Partners</div>
        <div class="metric-value">{@bases |> Enum.map(& &1.partner_name) |> Enum.uniq() |> length()}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Tax Years</div>
        <div class="metric-value">{@bases |> Enum.map(& &1.tax_year) |> Enum.uniq() |> length()}</div>
      </div>
    </div>

    <div class="section">
      <div class="section-head"><h2>Partnership Basis Records</h2></div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Partner</th>
              <th>Company</th>
              <th>Tax Year</th>
              <th class="th-num">Beginning Basis</th>
              <th class="th-num">Contributions</th>
              <th class="th-num">Income</th>
              <th class="th-num">Losses</th>
              <th class="th-num">Distributions</th>
              <th class="th-num">Ending Basis</th>
              <th class="th-num">Calculated</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for pb <- @bases do %>
              <tr>
                <td>
                  <button
                    phx-click="view_history"
                    phx-value-company-id={pb.company_id}
                    phx-value-partner={pb.partner_name}
                    class="td-link td-name"
                    style="background: none; border: none; cursor: pointer; padding: 0; font: inherit; text-align: left;"
                  >
                    {pb.partner_name}
                  </button>
                </td>
                <td>
                  <%= if pb.company do %>
                    <.link navigate={~p"/companies/#{pb.company.id}"} class="td-link">{pb.company.name}</.link>
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td class="td-mono">{pb.tax_year}</td>
                <td class="td-num">${format_number(pb.beginning_basis)}</td>
                <td class="td-num">${format_number(pb.capital_contributions)}</td>
                <td class="td-num">${format_number(pb.share_of_income)}</td>
                <td class="td-num num-negative">${format_number(pb.share_of_losses)}</td>
                <td class="td-num num-negative">${format_number(pb.distributions_received)}</td>
                <td class="td-num">${format_number(pb.ending_basis)}</td>
                <td class="td-num">
                  <span class={"#{if basis_matches?(pb), do: "num-positive", else: "num-negative"}"}>
                    ${format_number(Fund.calculate_ending_basis(pb))}
                  </span>
                </td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit" phx-value-id={pb.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete" phx-value-id={pb.id} class="btn btn-danger btn-sm" data-confirm="Delete this record?">Del</button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @bases == [] do %>
          <div class="empty-state">
            <p>No partnership basis records found.</p>
            <p style="color: var(--muted); font-size: 0.9rem;">
              Track each partner's tax basis including contributions, income allocations, distributions, and Section 754 adjustments.
            </p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_form">Add Your First Record</button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @selected_partner do %>
      <div class="section">
        <div class="section-head" style="display: flex; justify-content: space-between; align-items: center;">
          <h2>Basis History: {@selected_partner}</h2>
          <button phx-click="close_history" class="btn btn-secondary btn-sm">Close</button>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Tax Year</th>
                <th class="th-num">Beginning</th>
                <th class="th-num">+ Contributions</th>
                <th class="th-num">+ Income</th>
                <th class="th-num">- Losses</th>
                <th class="th-num">- Distributions</th>
                <th class="th-num">+/- Special</th>
                <th class="th-num">+/- Sec 754</th>
                <th class="th-num">Ending</th>
                <th class="th-num">At-Risk</th>
                <th class="th-num">Passive</th>
              </tr>
            </thead>
            <tbody>
              <%= for pb <- @history do %>
                <tr>
                  <td class="td-mono">{pb.tax_year}</td>
                  <td class="td-num">${format_number(pb.beginning_basis)}</td>
                  <td class="td-num">${format_number(pb.capital_contributions)}</td>
                  <td class="td-num">${format_number(pb.share_of_income)}</td>
                  <td class="td-num num-negative">${format_number(pb.share_of_losses)}</td>
                  <td class="td-num num-negative">${format_number(pb.distributions_received)}</td>
                  <td class="td-num">${format_number(pb.special_allocations)}</td>
                  <td class="td-num">${format_number(pb.section_754_adjustments)}</td>
                  <td class="td-num">${format_number(pb.ending_basis)}</td>
                  <td class="td-num">${format_number(pb.at_risk_amount)}</td>
                  <td class="td-num">${format_number(pb.passive_activity_amount)}</td>
                </tr>
              <% end %>
            </tbody>
          </table>
          <%= if @history == [] do %>
            <div class="empty-state">No history found for this partner.</div>
          <% end %>
        </div>

        <%= if @chart_data != [] do %>
          <div style="margin-top: 1rem;">
            <h3>Chart Data (JSON)</h3>
            <pre style="background: var(--bg-secondary); padding: 1rem; border-radius: 0.5rem; overflow-x: auto; font-size: 0.85rem;">
              {Jason.encode!(@chart_data, pretty: true)}
            </pre>
          </div>
        <% end %>
      </div>
    <% end %>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit Basis Record", else: "Add Basis Record"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="partnership_basis[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={@editing_item && @editing_item.company_id == c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Partner Name *</label>
                <input type="text" name="partnership_basis[partner_name]" class="form-input"
                  value={if @editing_item, do: @editing_item.partner_name, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Tax Year *</label>
                <input type="number" name="partnership_basis[tax_year]" class="form-input"
                  value={if @editing_item, do: @editing_item.tax_year, else: Date.utc_today().year} required />
              </div>
              <div class="form-group">
                <label class="form-label">Beginning Basis</label>
                <input type="number" name="partnership_basis[beginning_basis]" class="form-input" step="any"
                  value={if @editing_item, do: @editing_item.beginning_basis, else: "0"} />
              </div>
              <div class="form-group">
                <label class="form-label">Capital Contributions</label>
                <input type="number" name="partnership_basis[capital_contributions]" class="form-input" step="any"
                  value={if @editing_item, do: @editing_item.capital_contributions, else: "0"} />
              </div>
              <div class="form-group">
                <label class="form-label">Share of Income</label>
                <input type="number" name="partnership_basis[share_of_income]" class="form-input" step="any"
                  value={if @editing_item, do: @editing_item.share_of_income, else: "0"} />
              </div>
              <div class="form-group">
                <label class="form-label">Share of Losses</label>
                <input type="number" name="partnership_basis[share_of_losses]" class="form-input" step="any"
                  value={if @editing_item, do: @editing_item.share_of_losses, else: "0"} />
              </div>
              <div class="form-group">
                <label class="form-label">Distributions Received</label>
                <input type="number" name="partnership_basis[distributions_received]" class="form-input" step="any"
                  value={if @editing_item, do: @editing_item.distributions_received, else: "0"} />
              </div>
              <div class="form-group">
                <label class="form-label">Special Allocations</label>
                <input type="number" name="partnership_basis[special_allocations]" class="form-input" step="any"
                  value={if @editing_item, do: @editing_item.special_allocations, else: "0"} />
              </div>
              <div class="form-group">
                <label class="form-label">Section 754 Adjustments</label>
                <input type="number" name="partnership_basis[section_754_adjustments]" class="form-input" step="any"
                  value={if @editing_item, do: @editing_item.section_754_adjustments, else: "0"} />
              </div>
              <div class="form-group">
                <label class="form-label">Ending Basis</label>
                <input type="number" name="partnership_basis[ending_basis]" class="form-input" step="any"
                  value={if @editing_item, do: @editing_item.ending_basis, else: "0"} />
              </div>
              <div class="form-group">
                <label class="form-label">At-Risk Amount</label>
                <input type="number" name="partnership_basis[at_risk_amount]" class="form-input" step="any"
                  value={if @editing_item, do: @editing_item.at_risk_amount, else: "0"} />
              </div>
              <div class="form-group">
                <label class="form-label">Passive Activity Amount</label>
                <input type="number" name="partnership_basis[passive_activity_amount]" class="form-input" step="any"
                  value={if @editing_item, do: @editing_item.passive_activity_amount, else: "0"} />
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="partnership_basis[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">
                  {if @show_form == :edit, do: "Update Record", else: "Add Record"}
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

    bases = Fund.list_partnership_bases(company_id)
    assign(socket, bases: bases)
  end

  defp basis_matches?(pb) do
    calculated = Fund.calculate_ending_basis(pb)
    recorded = Money.to_decimal(pb.ending_basis)
    Decimal.equal?(Decimal.round(calculated, 2), Decimal.round(recorded, 2))
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
        formatted_int =
          int_part |> String.reverse() |> String.replace(~r/(\d{3})(?=\d)/, "\\1,") |> String.reverse()

        "#{formatted_int}.#{dec_part}"

      [int_part] ->
        int_part |> String.reverse() |> String.replace(~r/(\d{3})(?=\d)/, "\\1,") |> String.reverse()
    end
  end
end
