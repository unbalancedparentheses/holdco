defmodule HoldcoWeb.InsuranceClaimLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.Compliance
  alias Holdco.Compliance.InsuranceClaim

  @impl true
  def mount(_params, _session, socket) do
    companies = Holdco.Corporate.list_companies()
    claims = Compliance.list_insurance_claims()
    summary = Compliance.claims_summary()
    open = Compliance.open_claims()

    {:ok,
     assign(socket,
       page_title: "Insurance Claims",
       companies: companies,
       claims: claims,
       summary: summary,
       open_claims: open,
       selected_company_id: "",
       show_form: false,
       editing_item: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("filter_company", %{"company_id" => id}, socket) do
    company_id = if id == "", do: nil, else: String.to_integer(id)
    claims = Compliance.list_insurance_claims(company_id)
    summary = Compliance.claims_summary(company_id)
    open = Compliance.open_claims(company_id)
    {:noreply, assign(socket, selected_company_id: id, claims: claims, summary: summary, open_claims: open)}
  end

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: :add, editing_item: nil)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false, editing_item: nil)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    claim = Compliance.get_insurance_claim!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: claim)}
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

  def handle_event("save", %{"insurance_claim" => params}, socket) do
    case Compliance.create_insurance_claim(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Insurance claim added")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add insurance claim")}
    end
  end

  def handle_event("update", %{"insurance_claim" => params}, socket) do
    claim = socket.assigns.editing_item

    case Compliance.update_insurance_claim(claim, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Insurance claim updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update insurance claim")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    claim = Compliance.get_insurance_claim!(String.to_integer(id))

    case Compliance.delete_insurance_claim(claim) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Insurance claim deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete insurance claim")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Insurance Claims</h1>
          <p class="deck">Track and manage insurance claims</p>
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
            <button class="btn btn-primary" phx-click="show_form">Add Claim</button>
          <% end %>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Claims</div>
        <div class="metric-value">{length(@claims)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Open Claims</div>
        <div class="metric-value num-negative">{length(@open_claims)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Total Claimed</div>
        <div class="metric-value">${format_number(@summary.total_claimed)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Total Settled</div>
        <div class="metric-value">${format_number(@summary.total_settled)}</div>
      </div>
    </div>

    <div class="section">
      <div class="section-head"><h2>All Claims</h2></div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Claim #</th><th>Company</th><th>Type</th><th>Status</th>
              <th>Incident</th><th>Filed</th><th class="th-num">Claimed</th><th class="th-num">Settled</th><th></th>
            </tr>
          </thead>
          <tbody>
            <%= for ic <- @claims do %>
              <tr>
                <td class="td-name">{ic.claim_number}</td>
                <td>{if ic.company, do: ic.company.name, else: "---"}</td>
                <td><span class="tag tag-sky">{humanize(ic.claim_type)}</span></td>
                <td><span class={"tag #{claim_status_tag(ic.status)}"}>{humanize(ic.status)}</span></td>
                <td class="td-mono">{ic.incident_date || "---"}</td>
                <td class="td-mono">{ic.filing_date || "---"}</td>
                <td class="td-num">{format_number(ic.claimed_amount)}</td>
                <td class="td-num">{format_number(ic.settled_amount)}</td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit" phx-value-id={ic.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete" phx-value-id={ic.id} class="btn btn-danger btn-sm" data-confirm="Delete this claim?">Del</button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @claims == [] do %>
          <div class="empty-state">
            <p>No insurance claims found.</p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_form">Add Your First Claim</button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit Claim", else: "Add Claim"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="insurance_claim[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={@editing_item && @editing_item.company_id == c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Claim Number *</label>
                <input type="text" name="insurance_claim[claim_number]" class="form-input" value={if @editing_item, do: @editing_item.claim_number, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Claim Type *</label>
                <select name="insurance_claim[claim_type]" class="form-select" required>
                  <%= for t <- InsuranceClaim.claim_types() do %>
                    <option value={t} selected={@editing_item && @editing_item.claim_type == t}>{humanize(t)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Status</label>
                <select name="insurance_claim[status]" class="form-select">
                  <%= for s <- InsuranceClaim.statuses() do %>
                    <option value={s} selected={@editing_item && @editing_item.status == s}>{humanize(s)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Incident Date</label>
                <input type="date" name="insurance_claim[incident_date]" class="form-input" value={if @editing_item, do: @editing_item.incident_date, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Filing Date</label>
                <input type="date" name="insurance_claim[filing_date]" class="form-input" value={if @editing_item, do: @editing_item.filing_date, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Claimed Amount</label>
                <input type="number" name="insurance_claim[claimed_amount]" class="form-input" step="any" value={if @editing_item, do: @editing_item.claimed_amount, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Settled Amount</label>
                <input type="number" name="insurance_claim[settled_amount]" class="form-input" step="any" value={if @editing_item, do: @editing_item.settled_amount, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Deductible</label>
                <input type="number" name="insurance_claim[deductible]" class="form-input" step="any" value={if @editing_item, do: @editing_item.deductible, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Adjuster Name</label>
                <input type="text" name="insurance_claim[adjuster_name]" class="form-input" value={if @editing_item, do: @editing_item.adjuster_name, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Adjuster Contact</label>
                <input type="text" name="insurance_claim[adjuster_contact]" class="form-input" value={if @editing_item, do: @editing_item.adjuster_contact, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Settlement Date</label>
                <input type="date" name="insurance_claim[settlement_date]" class="form-input" value={if @editing_item, do: @editing_item.settlement_date, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Description</label>
                <textarea name="insurance_claim[description]" class="form-input">{if @editing_item, do: @editing_item.description, else: ""}</textarea>
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="insurance_claim[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">{if @show_form == :edit, do: "Update", else: "Add Claim"}</button>
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

    claims = Compliance.list_insurance_claims(company_id)
    summary = Compliance.claims_summary(company_id)
    open = Compliance.open_claims(company_id)
    assign(socket, claims: claims, summary: summary, open_claims: open)
  end

  defp humanize(str), do: str |> String.replace("_", " ") |> String.split(" ") |> Enum.map(&String.capitalize/1) |> Enum.join(" ")

  defp claim_status_tag("filed"), do: "tag-lemon"
  defp claim_status_tag("under_review"), do: "tag-lemon"
  defp claim_status_tag("approved"), do: "tag-jade"
  defp claim_status_tag("denied"), do: "tag-rose"
  defp claim_status_tag("settled"), do: "tag-sky"
  defp claim_status_tag("closed"), do: ""
  defp claim_status_tag(_), do: ""

  defp format_number(%Decimal{} = n), do: n |> Decimal.round(2) |> Decimal.to_string()
  defp format_number(n) when is_number(n), do: to_string(n)
  defp format_number(_), do: "---"
end
