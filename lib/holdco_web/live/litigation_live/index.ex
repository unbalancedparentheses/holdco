defmodule HoldcoWeb.LitigationLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.Compliance
  alias Holdco.Compliance.Litigation

  @impl true
  def mount(_params, _session, socket) do
    companies = Holdco.Corporate.list_companies()
    litigations = Compliance.list_litigations()
    active = Compliance.active_litigation()
    exposure = Compliance.litigation_exposure()

    {:ok,
     assign(socket,
       page_title: "Litigation & Disputes",
       companies: companies,
       litigations: litigations,
       active_litigation: active,
       exposure: exposure,
       selected_company_id: "",
       show_form: false,
       editing_item: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("filter_company", %{"company_id" => id}, socket) do
    company_id = if id == "", do: nil, else: String.to_integer(id)
    litigations = Compliance.list_litigations(company_id)
    active = Compliance.active_litigation(company_id)
    exposure = Compliance.litigation_exposure(company_id)
    {:noreply, assign(socket, selected_company_id: id, litigations: litigations, active_litigation: active, exposure: exposure)}
  end

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: :add, editing_item: nil)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false, editing_item: nil)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    lit = Compliance.get_litigation!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: lit)}
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

  def handle_event("save", %{"litigation" => params}, socket) do
    case Compliance.create_litigation(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Litigation case added")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add litigation case")}
    end
  end

  def handle_event("update", %{"litigation" => params}, socket) do
    lit = socket.assigns.editing_item

    case Compliance.update_litigation(lit, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Litigation case updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update litigation case")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    lit = Compliance.get_litigation!(String.to_integer(id))

    case Compliance.delete_litigation(lit) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Litigation case deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete litigation case")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Litigation & Disputes</h1>
          <p class="deck">Track legal cases, disputes, and exposure</p>
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
            <button class="btn btn-primary" phx-click="show_form">Add Case</button>
          <% end %>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Cases</div>
        <div class="metric-value">{length(@litigations)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Active Cases</div>
        <div class="metric-value num-negative">{length(@active_litigation)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Total Exposure</div>
        <div class="metric-value num-negative">${format_number(@exposure)}</div>
      </div>
    </div>

    <div class="section">
      <div class="section-head"><h2>All Cases</h2></div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Case Name</th><th>Case #</th><th>Company</th><th>Type</th><th>Role</th>
              <th>Status</th><th class="th-num">Exposure</th><th>Next Hearing</th><th></th>
            </tr>
          </thead>
          <tbody>
            <%= for l <- @litigations do %>
              <tr>
                <td class="td-name">{l.case_name}</td>
                <td class="td-mono">{l.case_number || "---"}</td>
                <td>{if l.company, do: l.company.name, else: "---"}</td>
                <td><span class="tag tag-sky">{humanize(l.case_type)}</span></td>
                <td>{humanize(l.party_role)}</td>
                <td><span class={"tag #{lit_status_tag(l.status)}"}>{humanize(l.status)}</span></td>
                <td class="td-num">{if l.estimated_exposure, do: "#{l.currency} #{format_number(l.estimated_exposure)}", else: "---"}</td>
                <td class="td-mono">{l.next_hearing_date || "---"}</td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit" phx-value-id={l.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete" phx-value-id={l.id} class="btn btn-danger btn-sm" data-confirm="Delete this case?">Del</button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @litigations == [] do %>
          <div class="empty-state">
            <p>No litigation cases found.</p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_form">Add Your First Case</button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit Case", else: "Add Case"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="litigation[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={@editing_item && @editing_item.company_id == c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Case Name *</label>
                <input type="text" name="litigation[case_name]" class="form-input" value={if @editing_item, do: @editing_item.case_name, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Case Number</label>
                <input type="text" name="litigation[case_number]" class="form-input" value={if @editing_item, do: @editing_item.case_number, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Court/Tribunal</label>
                <input type="text" name="litigation[court_or_tribunal]" class="form-input" value={if @editing_item, do: @editing_item.court_or_tribunal, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Jurisdiction</label>
                <input type="text" name="litigation[jurisdiction]" class="form-input" value={if @editing_item, do: @editing_item.jurisdiction, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Case Type *</label>
                <select name="litigation[case_type]" class="form-select" required>
                  <%= for t <- Litigation.case_types() do %>
                    <option value={t} selected={@editing_item && @editing_item.case_type == t}>{humanize(t)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Party Role *</label>
                <select name="litigation[party_role]" class="form-select" required>
                  <%= for r <- Litigation.party_roles() do %>
                    <option value={r} selected={@editing_item && @editing_item.party_role == r}>{humanize(r)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Opposing Party</label>
                <input type="text" name="litigation[opposing_party]" class="form-input" value={if @editing_item, do: @editing_item.opposing_party, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Filing Date</label>
                <input type="date" name="litigation[filing_date]" class="form-input" value={if @editing_item, do: @editing_item.filing_date, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Status</label>
                <select name="litigation[status]" class="form-select">
                  <%= for s <- Litigation.statuses() do %>
                    <option value={s} selected={@editing_item && @editing_item.status == s}>{humanize(s)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Estimated Exposure</label>
                <input type="number" name="litigation[estimated_exposure]" class="form-input" step="any" value={if @editing_item, do: @editing_item.estimated_exposure, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Actual Outcome Amount</label>
                <input type="number" name="litigation[actual_outcome_amount]" class="form-input" step="any" value={if @editing_item, do: @editing_item.actual_outcome_amount, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Currency</label>
                <input type="text" name="litigation[currency]" class="form-input" value={if @editing_item, do: @editing_item.currency, else: "USD"} />
              </div>
              <div class="form-group">
                <label class="form-label">Lead Counsel</label>
                <input type="text" name="litigation[lead_counsel]" class="form-input" value={if @editing_item, do: @editing_item.lead_counsel, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Next Hearing Date</label>
                <input type="date" name="litigation[next_hearing_date]" class="form-input" value={if @editing_item, do: @editing_item.next_hearing_date, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="litigation[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">{if @show_form == :edit, do: "Update", else: "Add Case"}</button>
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

    litigations = Compliance.list_litigations(company_id)
    active = Compliance.active_litigation(company_id)
    exposure = Compliance.litigation_exposure(company_id)
    assign(socket, litigations: litigations, active_litigation: active, exposure: exposure)
  end

  defp humanize(str), do: str |> String.replace("_", " ") |> String.split(" ") |> Enum.map(&String.capitalize/1) |> Enum.join(" ")

  defp lit_status_tag("active"), do: "tag-rose"
  defp lit_status_tag("discovery"), do: "tag-lemon"
  defp lit_status_tag("trial"), do: "tag-rose"
  defp lit_status_tag("appeal"), do: "tag-lemon"
  defp lit_status_tag("settled"), do: "tag-jade"
  defp lit_status_tag("dismissed"), do: "tag-jade"
  defp lit_status_tag("closed"), do: ""
  defp lit_status_tag("pre_filing"), do: "tag-lemon"
  defp lit_status_tag(_), do: ""

  defp format_number(%Decimal{} = n), do: n |> Decimal.round(2) |> Decimal.to_string()
  defp format_number(n) when is_number(n), do: to_string(n)
  defp format_number(_), do: "---"
end
