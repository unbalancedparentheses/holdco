defmodule HoldcoWeb.LeiLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.Corporate
  alias Holdco.Corporate.LeiRecord

  @impl true
  def mount(_params, _session, socket) do
    companies = Corporate.list_companies()
    records = Corporate.list_lei_records()
    due_for_renewal = Corporate.lei_due_for_renewal()

    {:ok,
     assign(socket,
       page_title: "LEI Records",
       companies: companies,
       records: records,
       due_for_renewal: due_for_renewal,
       selected_company_id: "",
       show_form: false,
       editing_item: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("filter_company", %{"company_id" => id}, socket) do
    company_id = if id == "", do: nil, else: String.to_integer(id)
    records = Corporate.list_lei_records(company_id)

    {:noreply, assign(socket, selected_company_id: id, records: records)}
  end

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: :add, editing_item: nil)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false, editing_item: nil)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    record = Corporate.get_lei_record!(String.to_integer(id))
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

  def handle_event("save", %{"lei_record" => params}, socket) do
    case Corporate.create_lei_record(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "LEI record added")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add LEI record")}
    end
  end

  def handle_event("update", %{"lei_record" => params}, socket) do
    record = socket.assigns.editing_item

    case Corporate.update_lei_record(record, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "LEI record updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update LEI record")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    record = Corporate.get_lei_record!(String.to_integer(id))

    case Corporate.delete_lei_record(record) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "LEI record deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete LEI record")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>LEI Records</h1>
          <p class="deck">Legal Entity Identifier tracking and renewal management</p>
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
            <button class="btn btn-primary" phx-click="show_form">Add LEI Record</button>
          <% end %>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Records</div>
        <div class="metric-value">{length(@records)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Due for Renewal (30d)</div>
        <div class="metric-value num-negative">{length(@due_for_renewal)}</div>
      </div>
    </div>

    <%= if @due_for_renewal != [] do %>
      <div class="section">
        <div class="section-head"><h2>Renewal Alerts (Next 30 Days)</h2></div>
        <div class="panel">
          <table>
            <thead>
              <tr><th>LEI Code</th><th>Legal Name</th><th>Company</th><th>Next Renewal</th><th>Status</th></tr>
            </thead>
            <tbody>
              <%= for r <- @due_for_renewal do %>
                <tr>
                  <td class="td-mono">{r.lei_code}</td>
                  <td>{r.legal_name || "---"}</td>
                  <td>{if r.company, do: r.company.name, else: "---"}</td>
                  <td class="td-mono">{r.next_renewal_date}</td>
                  <td><span class={"tag #{reg_status_tag(r.registration_status)}"}>{humanize(r.registration_status)}</span></td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    <% end %>

    <div class="section">
      <div class="section-head"><h2>All LEI Records</h2></div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>LEI Code</th><th>Legal Name</th><th>Company</th><th>Registration Status</th>
              <th>Entity Status</th><th>Managing LOU</th><th>Next Renewal</th><th></th>
            </tr>
          </thead>
          <tbody>
            <%= for r <- @records do %>
              <tr>
                <td class="td-mono">{r.lei_code}</td>
                <td>{r.legal_name || "---"}</td>
                <td>{if r.company, do: r.company.name, else: "---"}</td>
                <td><span class={"tag #{reg_status_tag(r.registration_status)}"}>{humanize(r.registration_status)}</span></td>
                <td><span class={"tag #{entity_status_tag(r.entity_status)}"}>{humanize(r.entity_status)}</span></td>
                <td>{r.managing_lou || "---"}</td>
                <td class="td-mono">{r.next_renewal_date || "---"}</td>
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
            <p>No LEI records found.</p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_form">Add Your First LEI Record</button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit LEI Record", else: "Add LEI Record"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="lei_record[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={@editing_item && @editing_item.company_id == c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">LEI Code * (20 characters)</label>
                <input type="text" name="lei_record[lei_code]" class="form-input" maxlength="20" value={if @editing_item, do: @editing_item.lei_code, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Registration Status</label>
                <select name="lei_record[registration_status]" class="form-select">
                  <%= for s <- LeiRecord.registration_statuses() do %>
                    <option value={s} selected={@editing_item && @editing_item.registration_status == s}>{humanize(s)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Entity Status</label>
                <select name="lei_record[entity_status]" class="form-select">
                  <%= for s <- LeiRecord.entity_statuses() do %>
                    <option value={s} selected={@editing_item && @editing_item.entity_status == s}>{humanize(s)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Legal Name</label>
                <input type="text" name="lei_record[legal_name]" class="form-input" value={if @editing_item, do: @editing_item.legal_name, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Jurisdiction</label>
                <input type="text" name="lei_record[jurisdiction]" class="form-input" value={if @editing_item, do: @editing_item.jurisdiction, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Managing LOU</label>
                <input type="text" name="lei_record[managing_lou]" class="form-input" value={if @editing_item, do: @editing_item.managing_lou, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Registration Authority</label>
                <input type="text" name="lei_record[registration_authority]" class="form-input" value={if @editing_item, do: @editing_item.registration_authority, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Initial Registration Date</label>
                <input type="date" name="lei_record[initial_registration_date]" class="form-input" value={if @editing_item, do: @editing_item.initial_registration_date, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Last Renewal Date</label>
                <input type="date" name="lei_record[last_renewal_date]" class="form-input" value={if @editing_item, do: @editing_item.last_renewal_date, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Next Renewal Date</label>
                <input type="date" name="lei_record[next_renewal_date]" class="form-input" value={if @editing_item, do: @editing_item.next_renewal_date, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="lei_record[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
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
    company_id = case socket.assigns.selected_company_id do
      "" -> nil
      id -> String.to_integer(id)
    end

    records = Corporate.list_lei_records(company_id)
    due_for_renewal = Corporate.lei_due_for_renewal()
    assign(socket, records: records, due_for_renewal: due_for_renewal)
  end

  defp humanize(str), do: str |> String.replace("_", " ") |> String.split(" ") |> Enum.map(&String.capitalize/1) |> Enum.join(" ")

  defp reg_status_tag("issued"), do: "tag-jade"
  defp reg_status_tag("pending"), do: "tag-lemon"
  defp reg_status_tag("lapsed"), do: "tag-rose"
  defp reg_status_tag("retired"), do: "tag-rose"
  defp reg_status_tag(_), do: ""

  defp entity_status_tag("active"), do: "tag-jade"
  defp entity_status_tag("inactive"), do: "tag-rose"
  defp entity_status_tag(_), do: ""
end
