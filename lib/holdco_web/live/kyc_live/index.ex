defmodule HoldcoWeb.KycLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Compliance, Corporate}
  alias Holdco.Compliance.KycRecord

  @impl true
  def mount(_params, _session, socket) do
    companies = Corporate.list_companies()
    records = Compliance.list_kyc_records()
    summary = Compliance.kyc_summary()
    review_queue = Compliance.kyc_due_for_review()

    {:ok,
     assign(socket,
       page_title: "KYC/AML",
       companies: companies,
       records: records,
       summary: summary,
       review_queue: review_queue,
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
    record = Compliance.get_kyc_record!(String.to_integer(id))
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

  def handle_event("save", %{"kyc_record" => params}, socket) do
    case Compliance.create_kyc_record(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "KYC record created")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create KYC record")}
    end
  end

  def handle_event("update", %{"kyc_record" => params}, socket) do
    record = socket.assigns.editing_item

    case Compliance.update_kyc_record(record, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "KYC record updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update KYC record")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    record = Compliance.get_kyc_record!(String.to_integer(id))

    case Compliance.delete_kyc_record(record) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "KYC record deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete KYC record")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>KYC/AML Compliance</h1>
          <p class="deck">Know Your Customer records and verification workflow</p>
        </div>
        <%= if @can_write do %>
          <button class="btn btn-primary" phx-click="show_form">Add KYC Record</button>
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
        <div class="metric-label">Due for Review</div>
        <div class="metric-value num-negative">{length(@review_queue)}</div>
      </div>
      <%= for s <- @summary.by_status do %>
        <div class="metric-cell">
          <div class="metric-label">{humanize_status(s.status)}</div>
          <div class="metric-value">{s.count}</div>
        </div>
      <% end %>
    </div>

    <%= if @summary.by_risk != [] do %>
      <div class="section">
        <div class="section-head"><h2>Risk Dashboard</h2></div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Risk Level</th>
                <th class="th-num">Count</th>
              </tr>
            </thead>
            <tbody>
              <%= for r <- @summary.by_risk do %>
                <tr>
                  <td><span class={"tag #{risk_tag(r.risk_level)}"}>{humanize_risk(r.risk_level)}</span></td>
                  <td class="td-num">{r.count}</td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    <% end %>

    <%= if @review_queue != [] do %>
      <div class="section">
        <div class="section-head"><h2>Review Queue</h2></div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Entity</th>
                <th>Company</th>
                <th>Type</th>
                <th>Risk</th>
                <th>Status</th>
                <th>Next Review</th>
              </tr>
            </thead>
            <tbody>
              <%= for r <- @review_queue do %>
                <tr>
                  <td class="td-name">{r.entity_name}</td>
                  <td>{if r.company, do: r.company.name, else: "---"}</td>
                  <td><span class="tag tag-sky">{humanize_entity_type(r.entity_type)}</span></td>
                  <td><span class={"tag #{risk_tag(r.risk_level)}"}>{humanize_risk(r.risk_level)}</span></td>
                  <td><span class={"tag #{status_tag(r.verification_status)}"}>{humanize_status(r.verification_status)}</span></td>
                  <td class="td-mono">{r.next_review_date}</td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    <% end %>

    <div class="section">
      <div class="section-head"><h2>All KYC Records</h2></div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Entity Name</th>
              <th>Company</th>
              <th>Type</th>
              <th>Risk</th>
              <th>Status</th>
              <th>PEP</th>
              <th>Sanctions</th>
              <th>Next Review</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for r <- @records do %>
              <tr>
                <td class="td-name">{r.entity_name}</td>
                <td>{if r.company, do: r.company.name, else: "---"}</td>
                <td><span class="tag tag-sky">{humanize_entity_type(r.entity_type)}</span></td>
                <td><span class={"tag #{risk_tag(r.risk_level)}"}>{humanize_risk(r.risk_level)}</span></td>
                <td><span class={"tag #{status_tag(r.verification_status)}"}>{humanize_status(r.verification_status)}</span></td>
                <td>{if r.pep_status, do: "Yes", else: "No"}</td>
                <td>{if r.sanctions_checked, do: "Checked", else: "Pending"}</td>
                <td class="td-mono">{r.next_review_date || "---"}</td>
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
            <p>No KYC records found.</p>
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
            <h3>{if @show_form == :edit, do: "Edit KYC Record", else: "Add KYC Record"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Entity Name *</label>
                <input type="text" name="kyc_record[entity_name]" class="form-input"
                  value={if @editing_item, do: @editing_item.entity_name, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="kyc_record[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={@editing_item && @editing_item.company_id == c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Entity Type</label>
                <select name="kyc_record[entity_type]" class="form-select">
                  <%= for t <- KycRecord.entity_types() do %>
                    <option value={t} selected={@editing_item && @editing_item.entity_type == t}>{humanize_entity_type(t)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Risk Level</label>
                <select name="kyc_record[risk_level]" class="form-select">
                  <%= for r <- KycRecord.risk_levels() do %>
                    <option value={r} selected={@editing_item && @editing_item.risk_level == r}>{humanize_risk(r)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Verification Status</label>
                <select name="kyc_record[verification_status]" class="form-select">
                  <%= for s <- KycRecord.verification_statuses() do %>
                    <option value={s} selected={@editing_item && @editing_item.verification_status == s}>{humanize_status(s)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">ID Type</label>
                <select name="kyc_record[id_type]" class="form-select">
                  <option value="">None</option>
                  <%= for t <- KycRecord.id_types() do %>
                    <option value={t} selected={@editing_item && @editing_item.id_type == t}>{humanize_id_type(t)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">ID Number</label>
                <input type="text" name="kyc_record[id_number]" class="form-input"
                  value={if @editing_item, do: @editing_item.id_number, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">ID Expiry Date</label>
                <input type="date" name="kyc_record[id_expiry_date]" class="form-input"
                  value={if @editing_item, do: @editing_item.id_expiry_date, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Country of Residence</label>
                <input type="text" name="kyc_record[country_of_residence]" class="form-input"
                  value={if @editing_item, do: @editing_item.country_of_residence, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Nationality</label>
                <input type="text" name="kyc_record[nationality]" class="form-input"
                  value={if @editing_item, do: @editing_item.nationality, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">PEP Status</label>
                <select name="kyc_record[pep_status]" class="form-select">
                  <option value="false" selected={@editing_item && !@editing_item.pep_status}>No</option>
                  <option value="true" selected={@editing_item && @editing_item.pep_status}>Yes</option>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Next Review Date</label>
                <input type="date" name="kyc_record[next_review_date]" class="form-input"
                  value={if @editing_item, do: @editing_item.next_review_date, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Reviewer Notes</label>
                <textarea name="kyc_record[reviewer_notes]" class="form-input">{if @editing_item, do: @editing_item.reviewer_notes, else: ""}</textarea>
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
    records = Compliance.list_kyc_records()
    summary = Compliance.kyc_summary()
    review_queue = Compliance.kyc_due_for_review()
    assign(socket, records: records, summary: summary, review_queue: review_queue)
  end

  defp humanize_entity_type("individual"), do: "Individual"
  defp humanize_entity_type("corporate"), do: "Corporate"
  defp humanize_entity_type("trust"), do: "Trust"
  defp humanize_entity_type("fund"), do: "Fund"
  defp humanize_entity_type(other), do: other || "Individual"

  defp humanize_risk("low"), do: "Low"
  defp humanize_risk("medium"), do: "Medium"
  defp humanize_risk("high"), do: "High"
  defp humanize_risk("pep"), do: "PEP"
  defp humanize_risk(other), do: other || "Low"

  defp risk_tag("low"), do: "tag-jade"
  defp risk_tag("medium"), do: "tag-lemon"
  defp risk_tag("high"), do: "tag-rose"
  defp risk_tag("pep"), do: "tag-rose"
  defp risk_tag(_), do: "tag-jade"

  defp humanize_status("not_started"), do: "Not Started"
  defp humanize_status("documents_requested"), do: "Docs Requested"
  defp humanize_status("under_review"), do: "Under Review"
  defp humanize_status("verified"), do: "Verified"
  defp humanize_status("rejected"), do: "Rejected"
  defp humanize_status("expired"), do: "Expired"
  defp humanize_status(other), do: other || "Not Started"

  defp status_tag("verified"), do: "tag-jade"
  defp status_tag("under_review"), do: "tag-sky"
  defp status_tag("documents_requested"), do: "tag-lemon"
  defp status_tag("rejected"), do: "tag-rose"
  defp status_tag("expired"), do: "tag-rose"
  defp status_tag(_), do: "tag-lemon"

  defp humanize_id_type("passport"), do: "Passport"
  defp humanize_id_type("national_id"), do: "National ID"
  defp humanize_id_type("drivers_license"), do: "Driver's License"
  defp humanize_id_type("corporate_registration"), do: "Corporate Registration"
  defp humanize_id_type(other), do: other || ""
end
