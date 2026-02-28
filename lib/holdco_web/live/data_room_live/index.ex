defmodule HoldcoWeb.DataRoomLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Documents, Corporate}
  alias Holdco.Documents.DataRoom

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Documents.subscribe()
    companies = Corporate.list_companies()
    rooms = Documents.list_data_rooms()

    {:ok,
     assign(socket,
       page_title: "Virtual Data Room",
       companies: companies,
       rooms: rooms,
       show_form: false,
       editing_item: nil,
       viewing_room: nil,
       room_documents: []
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
    room = Documents.get_data_room!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: room)}
  end

  def handle_event("view_room", %{"id" => id}, socket) do
    room = Documents.get_data_room!(String.to_integer(id))
    docs = Documents.list_room_documents(room.id)
    {:noreply, assign(socket, viewing_room: room, room_documents: docs)}
  end

  def handle_event("close_room", _, socket) do
    {:noreply, assign(socket, viewing_room: nil, room_documents: [])}
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

  def handle_event("save", %{"data_room" => params}, socket) do
    case Documents.create_data_room(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Data room created")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create data room")}
    end
  end

  def handle_event("update", %{"data_room" => params}, socket) do
    room = socket.assigns.editing_item

    case Documents.update_data_room(room, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Data room updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update data room")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    room = Documents.get_data_room!(String.to_integer(id))

    case Documents.delete_data_room(room) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Data room deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete data room")}
    end
  end

  @impl true
  def handle_info({event, _record}, socket)
      when event in [:data_rooms_created, :data_rooms_updated, :data_rooms_deleted] do
    {:noreply, reload(socket)}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Virtual Data Room</h1>
          <p class="deck">Secure document sharing and due diligence rooms</p>
        </div>
        <%= if @can_write do %>
          <button class="btn btn-primary" phx-click="show_form">Create Room</button>
        <% end %>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Rooms</div>
        <div class="metric-value">{length(@rooms)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Active</div>
        <div class="metric-value">{Enum.count(@rooms, &(&1.status == "active"))}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Confidential</div>
        <div class="metric-value">{Enum.count(@rooms, &(&1.access_level == "confidential"))}</div>
      </div>
    </div>

    <%= if @viewing_room do %>
      <div class="section">
        <div class="section-head" style="display: flex; justify-content: space-between; align-items: center;">
          <h2>{@viewing_room.name}</h2>
          <button class="btn btn-secondary btn-sm" phx-click="close_room">Back to List</button>
        </div>
        <div class="panel" style="padding: 1rem;">
          <p><strong>Access:</strong> <span class={"tag #{access_tag(@viewing_room.access_level)}"}>{humanize(@viewing_room.access_level)}</span></p>
          <p><strong>Status:</strong> <span class={"tag #{status_tag(@viewing_room.status)}"}>{humanize(@viewing_room.status)}</span></p>
          <%= if @viewing_room.description do %><p>{@viewing_room.description}</p><% end %>
          <h3 style="margin-top: 1rem;">Documents</h3>
          <%= if @room_documents == [] do %>
            <p>No documents in this room yet.</p>
          <% else %>
            <table>
              <thead><tr><th>Section</th><th>Document</th><th>Order</th></tr></thead>
              <tbody>
                <%= for rd <- @room_documents do %>
                  <tr>
                    <td>{rd.section_name || "---"}</td>
                    <td>{if rd.document, do: rd.document.name, else: "---"}</td>
                    <td>{rd.sort_order}</td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          <% end %>
        </div>
      </div>
    <% else %>
      <div class="section">
        <div class="section-head"><h2>All Data Rooms</h2></div>
        <div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 1rem; padding: 1rem;">
          <%= for room <- @rooms do %>
            <div class="panel" style="padding: 1rem; cursor: pointer;" phx-click="view_room" phx-value-id={room.id}>
              <h3>{room.name}</h3>
              <p style="color: var(--text-secondary); font-size: 0.875rem;">{room.description || "No description"}</p>
              <div style="display: flex; gap: 0.5rem; margin-top: 0.5rem;">
                <span class={"tag #{access_tag(room.access_level)}"}>{humanize(room.access_level)}</span>
                <span class={"tag #{status_tag(room.status)}"}>{humanize(room.status)}</span>
              </div>
              <div style="display: flex; justify-content: space-between; margin-top: 0.75rem; font-size: 0.8rem; color: var(--text-secondary);">
                <span>Visitors: {room.visitor_count}</span>
                <span>{if room.watermark_enabled, do: "Watermarked", else: ""}</span>
              </div>
              <%= if @can_write do %>
                <div style="display: flex; gap: 0.25rem; margin-top: 0.75rem;">
                  <button phx-click="edit" phx-value-id={room.id} class="btn btn-secondary btn-sm">Edit</button>
                  <button phx-click="delete" phx-value-id={room.id} class="btn btn-danger btn-sm" data-confirm="Delete this room?">Del</button>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
        <%= if @rooms == [] do %>
          <div class="empty-state">
            <p>No data rooms found.</p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_form">Create Your First Room</button>
            <% end %>
          </div>
        <% end %>
      </div>
    <% end %>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit Data Room", else: "Create Data Room"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="data_room[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={@editing_item && @editing_item.company_id == c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Name *</label>
                <input type="text" name="data_room[name]" class="form-input" value={if @editing_item, do: @editing_item.name, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Description</label>
                <textarea name="data_room[description]" class="form-input">{if @editing_item, do: @editing_item.description, else: ""}</textarea>
              </div>
              <div class="form-group">
                <label class="form-label">Access Level</label>
                <select name="data_room[access_level]" class="form-select">
                  <%= for al <- DataRoom.access_levels() do %>
                    <option value={al} selected={@editing_item && @editing_item.access_level == al}>{humanize(al)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Status</label>
                <select name="data_room[status]" class="form-select">
                  <%= for s <- DataRoom.statuses() do %>
                    <option value={s} selected={@editing_item && @editing_item.status == s}>{humanize(s)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Watermark Enabled</label>
                <select name="data_room[watermark_enabled]" class="form-select">
                  <option value="true" selected={!@editing_item || @editing_item.watermark_enabled}>Yes</option>
                  <option value="false" selected={@editing_item && !@editing_item.watermark_enabled}>No</option>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Download Allowed</label>
                <select name="data_room[download_allowed]" class="form-select">
                  <option value="true" selected={!@editing_item || @editing_item.download_allowed}>Yes</option>
                  <option value="false" selected={@editing_item && !@editing_item.download_allowed}>No</option>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="data_room[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">{if @show_form == :edit, do: "Update Room", else: "Create Room"}</button>
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
    assign(socket, rooms: Documents.list_data_rooms())
  end

  defp humanize(str), do: str |> String.replace("_", " ") |> String.split(" ") |> Enum.map(&String.capitalize/1) |> Enum.join(" ")

  defp status_tag("active"), do: "tag-jade"
  defp status_tag("archived"), do: "tag-lemon"
  defp status_tag("expired"), do: "tag-rose"
  defp status_tag(_), do: ""

  defp access_tag("public"), do: "tag-jade"
  defp access_tag("restricted"), do: "tag-lemon"
  defp access_tag("confidential"), do: "tag-rose"
  defp access_tag(_), do: ""
end
