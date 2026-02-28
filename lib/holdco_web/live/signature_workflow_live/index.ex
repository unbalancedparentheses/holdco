defmodule HoldcoWeb.SignatureWorkflowLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Documents, Corporate}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Documents.subscribe()

    companies = Corporate.list_companies()
    workflows = Documents.list_signature_workflows()
    documents = Documents.list_documents()

    {:ok,
     assign(socket,
       page_title: "Signature Workflows",
       companies: companies,
       workflows: workflows,
       documents: documents,
       selected_company_id: "",
       show_form: false,
       editing_item: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("show_form", _, socket),
    do: {:noreply, assign(socket, show_form: :add, editing_item: nil)}

  def handle_event("close_form", _, socket),
    do: {:noreply, assign(socket, show_form: false, editing_item: nil)}

  def handle_event("edit", %{"id" => id}, socket) do
    workflow = Documents.get_signature_workflow!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: workflow)}
  end

  def handle_event("filter_company", %{"company_id" => id}, socket) do
    company_id = if id == "", do: nil, else: String.to_integer(id)
    workflows = Documents.list_signature_workflows(company_id)
    {:noreply, assign(socket, selected_company_id: id, workflows: workflows)}
  end

  def handle_event("save", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("save", %{"signature_workflow" => params}, socket) do
    case Documents.create_signature_workflow(params) do
      {:ok, _} ->
        workflows = Documents.list_signature_workflows()
        {:noreply,
         socket
         |> assign(workflows: workflows, show_form: false, editing_item: nil)
         |> put_flash(:info, "Signature workflow created")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create signature workflow")}
    end
  end

  def handle_event("update", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("update", %{"signature_workflow" => params}, socket) do
    workflow = socket.assigns.editing_item

    case Documents.update_signature_workflow(workflow, params) do
      {:ok, _} ->
        workflows = Documents.list_signature_workflows()
        {:noreply,
         socket
         |> assign(workflows: workflows, show_form: false, editing_item: nil)
         |> put_flash(:info, "Signature workflow updated")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update signature workflow")}
    end
  end

  def handle_event("delete", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete", %{"id" => id}, socket) do
    workflow = Documents.get_signature_workflow!(String.to_integer(id))
    Documents.delete_signature_workflow(workflow)
    workflows = Documents.list_signature_workflows()
    {:noreply, assign(socket, workflows: workflows) |> put_flash(:info, "Workflow deleted")}
  end

  def handle_event("sign", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("sign", %{"id" => id, "email" => email}, socket) do
    case Documents.sign_document(String.to_integer(id), email) do
      {:ok, _} ->
        workflows = Documents.list_signature_workflows()
        {:noreply,
         socket
         |> assign(workflows: workflows)
         |> put_flash(:info, "Document signed by #{email}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to sign document")}
    end
  end

  def handle_event("send_reminder", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("send_reminder", %{"id" => id}, socket) do
    workflow = Documents.get_signature_workflow!(String.to_integer(id))
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    case Documents.update_signature_workflow(workflow, %{last_reminder_sent: now}) do
      {:ok, _} ->
        workflows = Documents.list_signature_workflows()
        {:noreply,
         socket
         |> assign(workflows: workflows)
         |> put_flash(:info, "Reminder sent")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to send reminder")}
    end
  end

  @impl true
  def handle_info({event, _record}, socket)
      when event in [
             :signature_workflows_created,
             :signature_workflows_updated,
             :signature_workflows_deleted
           ] do
    workflows = Documents.list_signature_workflows()
    {:noreply, assign(socket, workflows: workflows)}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  defp status_tag_class(status) do
    case status do
      "draft" -> "tag-ink"
      "pending_signatures" -> "tag-warning"
      "partially_signed" -> "tag-info"
      "completed" -> "tag-success"
      "expired" -> "tag-danger"
      "cancelled" -> "tag-danger"
      _ -> "tag-ink"
    end
  end

  defp signer_status_class(status) do
    case status do
      "signed" -> "color: var(--success);"
      "pending" -> "color: var(--warning);"
      _ -> ""
    end
  end

  defp signers_summary(workflow) do
    signed = Enum.count(workflow.signers, fn s -> s["status"] == "signed" end)
    total = length(workflow.signers)
    "#{signed}/#{total}"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Signature Workflows</h1>
          <p class="deck">{length(@workflows)} workflows</p>
        </div>
        <%= if @can_write do %>
          <button class="btn btn-primary" phx-click="show_form">New Workflow</button>
        <% end %>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div style="margin-bottom: 1rem;">
      <form phx-change="filter_company" style="display: flex; align-items: center; gap: 0.5rem;">
        <label class="form-label" style="margin: 0; font-size: 0.85rem;">Company</label>
        <select name="company_id" class="form-select" style="width: auto; padding: 0.3rem 0.5rem;">
          <option value="">All Companies</option>
          <%= for c <- @companies do %>
            <option value={c.id} selected={to_string(c.id) == @selected_company_id}>{c.name}</option>
          <% end %>
        </select>
      </form>
    </div>

    <div class="section">
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Title</th>
              <th>Document</th>
              <th>Status</th>
              <th>Signers</th>
              <th>Created By</th>
              <th>Expiry</th>
              <th>Company</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for w <- @workflows do %>
              <tr>
                <td class="td-name">{w.title}</td>
                <td>
                  <%= if w.document do %>
                    {w.document.name}
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td><span class={"tag #{status_tag_class(w.status)}"}>{w.status}</span></td>
                <td>
                  <span class="td-mono">{signers_summary(w)}</span>
                  <div style="margin-top: 0.25rem;">
                    <%= for signer <- w.signers do %>
                      <div style={"font-size: 0.8rem; #{signer_status_class(signer["status"])}"}>
                        {signer["name"]} ({signer["email"]}) - {signer["status"]}
                        <%= if signer["status"] != "signed" and w.status in ~w(pending_signatures partially_signed) and @can_write do %>
                          <button
                            phx-click="sign"
                            phx-value-id={w.id}
                            phx-value-email={signer["email"]}
                            class="btn btn-secondary btn-sm"
                            style="padding: 0.1rem 0.3rem; font-size: 0.75rem;"
                          >
                            Sign
                          </button>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                </td>
                <td>{w.created_by || "---"}</td>
                <td class="td-mono">{if w.expiry_date, do: Date.to_string(w.expiry_date), else: "---"}</td>
                <td>
                  <%= if w.company do %>
                    <.link navigate={~p"/companies/#{w.company.id}"} class="td-link">{w.company.name}</.link>
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem; flex-direction: column;">
                      <div style="display: flex; gap: 0.25rem;">
                        <button phx-click="edit" phx-value-id={w.id} class="btn btn-secondary btn-sm">Edit</button>
                        <button phx-click="delete" phx-value-id={w.id} class="btn btn-danger btn-sm" data-confirm="Delete?">Del</button>
                      </div>
                      <%= if w.status in ~w(pending_signatures partially_signed) do %>
                        <button phx-click="send_reminder" phx-value-id={w.id} class="btn btn-secondary btn-sm">Send Reminder</button>
                      <% end %>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @workflows == [] do %>
          <div class="empty-state">
            <p>No signature workflows yet.</p>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @show_form == :add do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header"><h3>New Signature Workflow</h3></div>
          <div class="dialog-body">
            <form phx-submit="save">
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="signature_workflow[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Title *</label>
                <input type="text" name="signature_workflow[title]" class="form-input" required />
              </div>
              <div class="form-group">
                <label class="form-label">Document (optional)</label>
                <select name="signature_workflow[document_id]" class="form-select">
                  <option value="">None</option>
                  <%= for d <- @documents do %>
                    <option value={d.id}>{d.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Created By</label>
                <input type="text" name="signature_workflow[created_by]" class="form-input" />
              </div>
              <div class="form-group">
                <label class="form-label">Status</label>
                <select name="signature_workflow[status]" class="form-select">
                  <%= for s <- ~w(draft pending_signatures) do %>
                    <option value={s}>{String.replace(s, "_", " ") |> String.capitalize()}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Expiry Date</label>
                <input type="date" name="signature_workflow[expiry_date]" class="form-input" />
              </div>
              <div class="form-group">
                <label class="form-label">Reminder Frequency</label>
                <select name="signature_workflow[reminder_frequency]" class="form-select">
                  <%= for f <- ~w(none daily weekly) do %>
                    <option value={f}>{String.capitalize(f)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="signature_workflow[notes]" class="form-input" rows="2"></textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Create Workflow</button>
                <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>

    <%= if @show_form == :edit and @editing_item do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header"><h3>Edit Signature Workflow</h3></div>
          <div class="dialog-body">
            <form phx-submit="update">
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="signature_workflow[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={c.id == @editing_item.company_id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Title *</label>
                <input type="text" name="signature_workflow[title]" class="form-input" value={@editing_item.title} required />
              </div>
              <div class="form-group">
                <label class="form-label">Document (optional)</label>
                <select name="signature_workflow[document_id]" class="form-select">
                  <option value="">None</option>
                  <%= for d <- @documents do %>
                    <option value={d.id} selected={d.id == @editing_item.document_id}>{d.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Created By</label>
                <input type="text" name="signature_workflow[created_by]" class="form-input" value={@editing_item.created_by} />
              </div>
              <div class="form-group">
                <label class="form-label">Status</label>
                <select name="signature_workflow[status]" class="form-select">
                  <%= for s <- ~w(draft pending_signatures partially_signed completed expired cancelled) do %>
                    <option value={s} selected={s == @editing_item.status}>{String.replace(s, "_", " ") |> String.capitalize()}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Expiry Date</label>
                <input type="date" name="signature_workflow[expiry_date]" class="form-input" value={@editing_item.expiry_date} />
              </div>
              <div class="form-group">
                <label class="form-label">Reminder Frequency</label>
                <select name="signature_workflow[reminder_frequency]" class="form-select">
                  <%= for f <- ~w(none daily weekly) do %>
                    <option value={f} selected={f == @editing_item.reminder_frequency}>{String.capitalize(f)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="signature_workflow[notes]" class="form-input" rows="2">{@editing_item.notes}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Update Workflow</button>
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
