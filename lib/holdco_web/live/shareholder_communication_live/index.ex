defmodule HoldcoWeb.ShareholderCommunicationLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Governance, Corporate}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Governance.subscribe()

    companies = Corporate.list_companies()
    communications = Governance.list_shareholder_communications()

    {:ok,
     assign(socket,
       page_title: "Shareholder Communications",
       companies: companies,
       communications: communications,
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
    comm = Governance.get_shareholder_communication!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: comm)}
  end

  def handle_event("filter_company", %{"company_id" => id}, socket) do
    company_id = if id == "", do: nil, else: String.to_integer(id)
    communications = Governance.list_shareholder_communications(company_id)
    {:noreply, assign(socket, selected_company_id: id, communications: communications)}
  end

  def handle_event("save", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("save", %{"shareholder_communication" => params}, socket) do
    case Governance.create_shareholder_communication(params) do
      {:ok, _} ->
        communications = Governance.list_shareholder_communications()
        {:noreply,
         socket
         |> assign(communications: communications, show_form: false, editing_item: nil)
         |> put_flash(:info, "Communication created")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create communication")}
    end
  end

  def handle_event("update", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("update", %{"shareholder_communication" => params}, socket) do
    comm = socket.assigns.editing_item

    case Governance.update_shareholder_communication(comm, params) do
      {:ok, _} ->
        communications = Governance.list_shareholder_communications()
        {:noreply,
         socket
         |> assign(communications: communications, show_form: false, editing_item: nil)
         |> put_flash(:info, "Communication updated")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update communication")}
    end
  end

  def handle_event("delete", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete", %{"id" => id}, socket) do
    comm = Governance.get_shareholder_communication!(String.to_integer(id))
    Governance.delete_shareholder_communication(comm)
    communications = Governance.list_shareholder_communications()
    {:noreply, assign(socket, communications: communications) |> put_flash(:info, "Communication deleted")}
  end

  @impl true
  def handle_info({event, _record}, socket)
      when event in [
             :shareholder_communications_created,
             :shareholder_communications_updated,
             :shareholder_communications_deleted
           ] do
    communications = Governance.list_shareholder_communications()
    {:noreply, assign(socket, communications: communications)}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  defp status_tag_class(status) do
    case status do
      "draft" -> "tag-ink"
      "approved" -> "tag-info"
      "sent" -> "tag-success"
      "acknowledged" -> "tag-warning"
      _ -> "tag-ink"
    end
  end

  defp ack_percentage(comm) do
    if comm.recipients_count > 0 do
      pct = Float.round(comm.acknowledged_count / comm.recipients_count * 100, 1)
      "#{pct}%"
    else
      "---"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Shareholder Communications</h1>
          <p class="deck">{length(@communications)} communications</p>
        </div>
        <%= if @can_write do %>
          <button class="btn btn-primary" phx-click="show_form">New Communication</button>
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
              <th>Type</th>
              <th>Audience</th>
              <th>Status</th>
              <th>Distribution</th>
              <th>Deadline</th>
              <th>Acknowledged</th>
              <th>Company</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for c <- @communications do %>
              <tr>
                <td class="td-name">{c.title}</td>
                <td><span class="tag tag-ink">{c.communication_type}</span></td>
                <td>{c.target_audience}</td>
                <td><span class={"tag #{status_tag_class(c.status)}"}>{c.status}</span></td>
                <td class="td-mono">{if c.distribution_date, do: Date.to_string(c.distribution_date), else: "---"}</td>
                <td class="td-mono">{if c.response_deadline, do: Date.to_string(c.response_deadline), else: "---"}</td>
                <td class="td-mono">{ack_percentage(c)}</td>
                <td>
                  <%= if c.company do %>
                    <.link navigate={~p"/companies/#{c.company.id}"} class="td-link">{c.company.name}</.link>
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit" phx-value-id={c.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete" phx-value-id={c.id} class="btn btn-danger btn-sm" data-confirm="Delete?">Del</button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @communications == [] do %>
          <div class="empty-state">
            <p>No shareholder communications yet.</p>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @show_form == :add do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header"><h3>New Communication</h3></div>
          <div class="dialog-body">
            <form phx-submit="save">
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="shareholder_communication[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Title *</label>
                <input type="text" name="shareholder_communication[title]" class="form-input" required />
              </div>
              <div class="form-group">
                <label class="form-label">Type *</label>
                <select name="shareholder_communication[communication_type]" class="form-select" required>
                  <option value="">Select type</option>
                  <%= for t <- ~w(notice circular annual_report interim_report proxy_statement dividend_notice agm_notice special_notice) do %>
                    <option value={t}>{String.replace(t, "_", " ") |> String.capitalize()}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Target Audience</label>
                <select name="shareholder_communication[target_audience]" class="form-select">
                  <%= for a <- ~w(all_shareholders preferred common institutional retail) do %>
                    <option value={a}>{String.replace(a, "_", " ") |> String.capitalize()}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Delivery Method</label>
                <select name="shareholder_communication[delivery_method]" class="form-select">
                  <%= for m <- ~w(email postal portal all) do %>
                    <option value={m}>{String.capitalize(m)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Content</label>
                <textarea name="shareholder_communication[content]" class="form-input" rows="4"></textarea>
              </div>
              <div class="form-group">
                <label class="form-label">Distribution Date</label>
                <input type="date" name="shareholder_communication[distribution_date]" class="form-input" />
              </div>
              <div class="form-group">
                <label class="form-label">Response Deadline</label>
                <input type="date" name="shareholder_communication[response_deadline]" class="form-input" />
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="shareholder_communication[notes]" class="form-input" rows="2"></textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Create</button>
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
          <div class="dialog-header"><h3>Edit Communication</h3></div>
          <div class="dialog-body">
            <form phx-submit="update">
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="shareholder_communication[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={c.id == @editing_item.company_id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Title *</label>
                <input type="text" name="shareholder_communication[title]" class="form-input" value={@editing_item.title} required />
              </div>
              <div class="form-group">
                <label class="form-label">Type *</label>
                <select name="shareholder_communication[communication_type]" class="form-select" required>
                  <%= for t <- ~w(notice circular annual_report interim_report proxy_statement dividend_notice agm_notice special_notice) do %>
                    <option value={t} selected={t == @editing_item.communication_type}>{String.replace(t, "_", " ") |> String.capitalize()}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Target Audience</label>
                <select name="shareholder_communication[target_audience]" class="form-select">
                  <%= for a <- ~w(all_shareholders preferred common institutional retail) do %>
                    <option value={a} selected={a == @editing_item.target_audience}>{String.replace(a, "_", " ") |> String.capitalize()}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Status</label>
                <select name="shareholder_communication[status]" class="form-select">
                  <%= for s <- ~w(draft approved sent acknowledged) do %>
                    <option value={s} selected={s == @editing_item.status}>{String.capitalize(s)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Delivery Method</label>
                <select name="shareholder_communication[delivery_method]" class="form-select">
                  <%= for m <- ~w(email postal portal all) do %>
                    <option value={m} selected={m == @editing_item.delivery_method}>{String.capitalize(m)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Content</label>
                <textarea name="shareholder_communication[content]" class="form-input" rows="4">{@editing_item.content}</textarea>
              </div>
              <div class="form-group">
                <label class="form-label">Distribution Date</label>
                <input type="date" name="shareholder_communication[distribution_date]" class="form-input" value={@editing_item.distribution_date} />
              </div>
              <div class="form-group">
                <label class="form-label">Response Deadline</label>
                <input type="date" name="shareholder_communication[response_deadline]" class="form-input" value={@editing_item.response_deadline} />
              </div>
              <div class="form-group">
                <label class="form-label">Recipients Count</label>
                <input type="number" name="shareholder_communication[recipients_count]" class="form-input" min="0" value={@editing_item.recipients_count} />
              </div>
              <div class="form-group">
                <label class="form-label">Acknowledged Count</label>
                <input type="number" name="shareholder_communication[acknowledged_count]" class="form-input" min="0" value={@editing_item.acknowledged_count} />
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="shareholder_communication[notes]" class="form-input" rows="2">{@editing_item.notes}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Update</button>
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
