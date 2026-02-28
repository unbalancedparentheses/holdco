defmodule HoldcoWeb.EmissionsLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Compliance, Corporate}
  alias Holdco.Compliance.EmissionsRecord

  @impl true
  def mount(_params, _session, socket) do
    companies = Corporate.list_companies()
    records = Compliance.list_emissions_records()

    {:ok,
     assign(socket,
       page_title: "Carbon & Emissions Tracking",
       companies: companies,
       records: records,
       show_form: false,
       editing_item: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: :add, editing_item: nil)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false, editing_item: nil)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    record = Compliance.get_emissions_record!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: record)}
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

  def handle_event("save", %{"emissions_record" => params}, socket) do
    case Compliance.create_emissions_record(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Emissions record created")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create emissions record")}
    end
  end

  def handle_event("update", %{"emissions_record" => params}, socket) do
    record = socket.assigns.editing_item

    case Compliance.update_emissions_record(record, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Emissions record updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update emissions record")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    record = Compliance.get_emissions_record!(String.to_integer(id))

    case Compliance.delete_emissions_record(record) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Emissions record deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete emissions record")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Carbon & Emissions Tracking</h1>
          <p class="deck">Track Scope 1, 2, 3 emissions across the portfolio</p>
        </div>
        <%= if @can_write do %>
          <button class="btn btn-primary" phx-click="show_form">Add Record</button>
        <% end %>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Records</div>
        <div class="metric-value">{length(@records)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Scope 1</div>
        <div class="metric-value">{Enum.count(@records, &(&1.scope == "scope_1"))}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Scope 2</div>
        <div class="metric-value">{Enum.count(@records, &(&1.scope == "scope_2"))}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Scope 3</div>
        <div class="metric-value">{Enum.count(@records, &(&1.scope == "scope_3"))}</div>
      </div>
    </div>

    <div class="section">
      <div class="section-head"><h2>All Emissions Records</h2></div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Company</th><th>Year</th><th>Scope</th><th>Category</th>
              <th>CO2e</th><th>Unit</th><th>Verification</th><th></th>
            </tr>
          </thead>
          <tbody>
            <%= for r <- @records do %>
              <tr>
                <td>{if r.company, do: r.company.name, else: "---"}</td>
                <td class="td-mono">{r.reporting_year}</td>
                <td><span class="tag tag-sky">{humanize(r.scope)}</span></td>
                <td>{humanize(r.category)}</td>
                <td class="td-num">{if r.co2_equivalent, do: Decimal.to_string(r.co2_equivalent), else: "---"}</td>
                <td>{humanize(r.unit)}</td>
                <td><span class={"tag #{verification_tag(r.verification_status)}"}>{humanize(r.verification_status)}</span></td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit" phx-value-id={r.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete" phx-value-id={r.id} class="btn btn-danger btn-sm" data-confirm="Delete this record?">Del</button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @records == [] do %>
          <div class="empty-state">
            <p>No emissions records found.</p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_form">Add Your First Record</button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit Emissions Record", else: "Add Emissions Record"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="emissions_record[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={@editing_item && @editing_item.company_id == c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Reporting Year *</label>
                <input type="number" name="emissions_record[reporting_year]" class="form-input" value={if @editing_item, do: @editing_item.reporting_year, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Scope *</label>
                <select name="emissions_record[scope]" class="form-select" required>
                  <%= for s <- EmissionsRecord.scopes() do %>
                    <option value={s} selected={@editing_item && @editing_item.scope == s}>{humanize(s)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Category *</label>
                <select name="emissions_record[category]" class="form-select" required>
                  <%= for c <- EmissionsRecord.categories() do %>
                    <option value={c} selected={@editing_item && @editing_item.category == c}>{humanize(c)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Source Description</label>
                <input type="text" name="emissions_record[source_description]" class="form-input" value={if @editing_item, do: @editing_item.source_description, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Quantity</label>
                <input type="number" name="emissions_record[quantity]" class="form-input" step="0.01" value={if @editing_item && @editing_item.quantity, do: Decimal.to_string(@editing_item.quantity), else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Unit</label>
                <select name="emissions_record[unit]" class="form-select">
                  <%= for u <- EmissionsRecord.units() do %>
                    <option value={u} selected={@editing_item && @editing_item.unit == u}>{humanize(u)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">CO2 Equivalent</label>
                <input type="number" name="emissions_record[co2_equivalent]" class="form-input" step="0.01" value={if @editing_item && @editing_item.co2_equivalent, do: Decimal.to_string(@editing_item.co2_equivalent), else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Verification Status</label>
                <select name="emissions_record[verification_status]" class="form-select">
                  <%= for v <- EmissionsRecord.verification_statuses() do %>
                    <option value={v} selected={@editing_item && @editing_item.verification_status == v}>{humanize(v)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="emissions_record[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">{if @show_form == :edit, do: "Update Record", else: "Add Record"}</button>
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
    assign(socket, records: Compliance.list_emissions_records())
  end

  defp humanize(str), do: str |> String.replace("_", " ") |> String.split(" ") |> Enum.map(&String.capitalize/1) |> Enum.join(" ")

  defp verification_tag("unverified"), do: "tag-lemon"
  defp verification_tag("self_assessed"), do: "tag-sky"
  defp verification_tag("third_party_verified"), do: "tag-jade"
  defp verification_tag(_), do: ""
end
