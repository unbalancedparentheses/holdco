defmodule HoldcoWeb.EntityLifecycleLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Corporate, Corporate.EntityLifecycle}

  @impl true
  def mount(_params, _session, socket) do
    companies = Corporate.list_companies()

    {:ok,
     assign(socket,
       page_title: "Entity Lifecycle",
       companies: companies,
       selected_company_id: "",
       events: [],
       timeline: [],
       show_form: false,
       editing_item: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("filter_company", %{"company_id" => id}, socket) do
    {events, timeline, selected} =
      if id == "" do
        {[], [], ""}
      else
        cid = String.to_integer(id)
        {Corporate.list_entity_lifecycles(cid), Corporate.entity_timeline(cid), id}
      end

    {:noreply,
     assign(socket,
       selected_company_id: selected,
       events: events,
       timeline: timeline,
       show_form: false,
       editing_item: nil
     )}
  end

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: :add, editing_item: nil)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false, editing_item: nil)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    event = Corporate.get_entity_lifecycle!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: event)}
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

  def handle_event("save", %{"entity_lifecycle" => params}, socket) do
    case Corporate.create_entity_lifecycle(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Lifecycle event added")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add lifecycle event")}
    end
  end

  def handle_event("update", %{"entity_lifecycle" => params}, socket) do
    event = socket.assigns.editing_item

    case Corporate.update_entity_lifecycle(event, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Lifecycle event updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update lifecycle event")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    event = Corporate.get_entity_lifecycle!(String.to_integer(id))

    case Corporate.delete_entity_lifecycle(event) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Lifecycle event deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete lifecycle event")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Entity Lifecycle</h1>
          <p class="deck">Track corporate events from incorporation to dissolution</p>
        </div>
        <div style="display: flex; gap: 0.5rem; align-items: center;">
          <form phx-change="filter_company" style="display: flex; align-items: center; gap: 0.5rem;">
            <label class="form-label" style="margin: 0; font-size: 0.85rem;">Company</label>
            <select name="company_id" class="form-select" style="width: auto; padding: 0.3rem 0.5rem;">
              <option value="">Select Company</option>
              <%= for c <- @companies do %>
                <option value={c.id} selected={to_string(c.id) == @selected_company_id}>{c.name}</option>
              <% end %>
            </select>
          </form>
          <%= if @can_write && @selected_company_id != "" do %>
            <button class="btn btn-primary" phx-click="show_form">Add Event</button>
          <% end %>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <%= if @selected_company_id != "" do %>
      <div class="section">
        <div class="section-head">
          <h2>Timeline</h2>
        </div>
        <div class="panel">
          <%= if @timeline == [] do %>
            <p style="padding: 1rem; color: var(--text-muted);">No lifecycle events recorded yet.</p>
          <% else %>
            <div style="padding: 1rem;">
              <%= for event <- @timeline do %>
                <div style="display: flex; gap: 1rem; margin-bottom: 1rem; padding-bottom: 1rem; border-bottom: 1px solid var(--border);">
                  <div style="min-width: 100px; font-size: 0.85rem; color: var(--text-muted);">{event.event_date}</div>
                  <div>
                    <span class={"tag #{status_tag(event.status)}"}>{event.status}</span>
                    <strong style="margin-left: 0.5rem;">{humanize_event_type(event.event_type)}</strong>
                    <%= if event.jurisdiction do %>
                      <span style="margin-left: 0.5rem; color: var(--text-muted);">({event.jurisdiction})</span>
                    <% end %>
                    <%= if event.description do %>
                      <p style="margin: 0.25rem 0 0; font-size: 0.9rem;">{event.description}</p>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>

      <div class="section">
        <div class="section-head">
          <h2>All Events</h2>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Event Type</th>
                <th>Event Date</th>
                <th>Effective Date</th>
                <th>Jurisdiction</th>
                <th>Filing Ref</th>
                <th>Status</th>
                <th>Description</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <%= for event <- @events do %>
                <tr>
                  <td>{humanize_event_type(event.event_type)}</td>
                  <td>{event.event_date}</td>
                  <td>{event.effective_date || "-"}</td>
                  <td>{event.jurisdiction || "-"}</td>
                  <td>{event.filing_reference || "-"}</td>
                  <td><span class={"tag #{status_tag(event.status)}"}>{event.status}</span></td>
                  <td>{event.description || "-"}</td>
                  <td style="text-align: right;">
                    <%= if @can_write do %>
                      <button phx-click="edit" phx-value-id={event.id} class="btn btn-sm">Edit</button>
                      <button phx-click="delete" phx-value-id={event.id} class="btn btn-sm btn-danger" data-confirm="Delete this event?">Delete</button>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    <% else %>
      <div class="section">
        <div class="panel" style="padding: 2rem; text-align: center; color: var(--text-muted);">
          Select a company to view its lifecycle events.
        </div>
      </div>
    <% end %>

    <%= if @show_form do %>
      <div class="modal-backdrop" phx-click="close_form">
        <div class="modal" phx-click="noop">
          <div class="modal-header">
            <h3>{if @show_form == :edit, do: "Edit Event", else: "Add Event"}</h3>
          </div>
          <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
            <div class="form-group">
              <label class="form-label">Company</label>
              <select name="entity_lifecycle[company_id]" class="form-select" required>
                <option value="">Select company</option>
                <%= for c <- @companies do %>
                  <option value={c.id} selected={(@editing_item && @editing_item.company_id == c.id) || to_string(c.id) == @selected_company_id}>{c.name}</option>
                <% end %>
              </select>
            </div>
            <div class="form-group">
              <label class="form-label">Event Type</label>
              <select name="entity_lifecycle[event_type]" class="form-select" required>
                <%= for t <- EntityLifecycle.event_types() do %>
                  <option value={t} selected={@editing_item && @editing_item.event_type == t}>{humanize_event_type(t)}</option>
                <% end %>
              </select>
            </div>
            <div class="form-group">
              <label class="form-label">Event Date</label>
              <input type="date" name="entity_lifecycle[event_date]" class="form-input" required value={if @editing_item, do: @editing_item.event_date, else: ""} />
            </div>
            <div class="form-group">
              <label class="form-label">Effective Date</label>
              <input type="date" name="entity_lifecycle[effective_date]" class="form-input" value={if @editing_item, do: @editing_item.effective_date, else: ""} />
            </div>
            <div class="form-group">
              <label class="form-label">Jurisdiction</label>
              <input type="text" name="entity_lifecycle[jurisdiction]" class="form-input" value={if @editing_item, do: @editing_item.jurisdiction, else: ""} />
            </div>
            <div class="form-group">
              <label class="form-label">Filing Reference</label>
              <input type="text" name="entity_lifecycle[filing_reference]" class="form-input" value={if @editing_item, do: @editing_item.filing_reference, else: ""} />
            </div>
            <div class="form-group">
              <label class="form-label">Status</label>
              <select name="entity_lifecycle[status]" class="form-select">
                <%= for s <- EntityLifecycle.statuses() do %>
                  <option value={s} selected={@editing_item && @editing_item.status == s}>{String.capitalize(s)}</option>
                <% end %>
              </select>
            </div>
            <div class="form-group">
              <label class="form-label">Description</label>
              <textarea name="entity_lifecycle[description]" class="form-input">{if @editing_item, do: @editing_item.description, else: ""}</textarea>
            </div>
            <div class="form-group">
              <label class="form-label">Notes</label>
              <textarea name="entity_lifecycle[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
            </div>
            <div class="form-actions">
              <button type="submit" class="btn btn-primary">{if @show_form == :edit, do: "Update Event", else: "Add Event"}</button>
              <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
            </div>
          </form>
        </div>
      </div>
    <% end %>
    """
  end

  defp reload(socket) do
    case socket.assigns.selected_company_id do
      "" ->
        assign(socket, events: [], timeline: [])

      id ->
        cid = String.to_integer(id)
        assign(socket,
          events: Corporate.list_entity_lifecycles(cid),
          timeline: Corporate.entity_timeline(cid)
        )
    end
  end

  defp humanize_event_type(type) do
    type
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp status_tag("completed"), do: "tag-jade"
  defp status_tag("pending"), do: "tag-lemon"
  defp status_tag("rejected"), do: "tag-rose"
  defp status_tag(_), do: ""
end
