defmodule HoldcoWeb.NotificationChannelsLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.Notifications
  alias Holdco.Notifications.NotificationChannel

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_scope.user.id
    channels = Notifications.list_notification_channels(user_id)

    {:ok,
     assign(socket,
       page_title: "Notification Channels",
       channels: channels,
       show_form: false,
       editing_item: nil,
       show_logs: nil,
       logs: []
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
    channel = Notifications.get_notification_channel!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: channel)}
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

  def handle_event("save", %{"notification_channel" => params}, socket) do
    user_id = socket.assigns.current_scope.user.id
    params = Map.put(params, "user_id", user_id)

    case Notifications.create_notification_channel(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Channel created")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create channel")}
    end
  end

  def handle_event("update", %{"notification_channel" => params}, socket) do
    channel = socket.assigns.editing_item

    case Notifications.update_notification_channel(channel, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Channel updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update channel")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    channel = Notifications.get_notification_channel!(String.to_integer(id))

    case Notifications.delete_notification_channel(channel) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Channel deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete channel")}
    end
  end

  def handle_event("test_send", %{"id" => id}, socket) do
    channel = Notifications.get_notification_channel!(String.to_integer(id))
    provider_mod = Holdco.Notifications.Dispatcher.get_provider(channel.provider)

    if provider_mod do
      case provider_mod.send_notification(channel, %{title: "Test", body: "Test notification from Holdco"}) do
        {:ok, _} ->
          {:noreply, put_flash(socket, :info, "Test notification sent successfully")}

        {:error, msg} ->
          {:noreply, put_flash(socket, :error, "Test failed: #{msg}")}
      end
    else
      {:noreply, put_flash(socket, :error, "Unknown provider")}
    end
  end

  def handle_event("show_logs", %{"id" => id}, socket) do
    channel_id = String.to_integer(id)
    logs = Notifications.list_notification_logs(channel_id)
    {:noreply, assign(socket, show_logs: channel_id, logs: logs)}
  end

  def handle_event("close_logs", _, socket) do
    {:noreply, assign(socket, show_logs: nil, logs: [])}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Notification Channels</h1>
          <p class="deck">Manage notification providers and delivery channels</p>
        </div>
        <%= if @can_write do %>
          <button class="btn btn-primary" phx-click="show_form">Add Channel</button>
        <% end %>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Channels</div>
        <div class="metric-value">{length(@channels)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Active</div>
        <div class="metric-value">{Enum.count(@channels, & &1.is_active)}</div>
      </div>
    </div>

    <div class="section">
      <div class="section-head"><h2>All Channels</h2></div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Name</th><th>Provider</th><th>Active</th><th>Failures</th><th>Last Sent</th><th></th>
            </tr>
          </thead>
          <tbody>
            <%= for c <- @channels do %>
              <tr>
                <td class="td-name">{c.name || "---"}</td>
                <td><span class="tag tag-sky">{c.provider}</span></td>
                <td>{if c.is_active, do: "Yes", else: "No"}</td>
                <td class="td-num">{c.failure_count || 0}</td>
                <td class="td-mono">{if c.last_sent_at, do: Calendar.strftime(c.last_sent_at, "%Y-%m-%d %H:%M"), else: "---"}</td>
                <td>
                  <div style="display: flex; gap: 0.25rem;">
                    <button phx-click="show_logs" phx-value-id={c.id} class="btn btn-secondary btn-sm">Logs</button>
                    <button phx-click="test_send" phx-value-id={c.id} class="btn btn-secondary btn-sm">Test</button>
                    <%= if @can_write do %>
                      <button phx-click="edit" phx-value-id={c.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete" phx-value-id={c.id} class="btn btn-danger btn-sm" data-confirm="Delete this channel?">Del</button>
                    <% end %>
                  </div>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @channels == [] do %>
          <div class="empty-state">
            <p>No notification channels configured.</p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_form">Add Your First Channel</button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @show_logs do %>
      <div class="dialog-overlay" phx-click="close_logs">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header"><h3>Notification Logs</h3></div>
          <div class="dialog-body">
            <table>
              <thead><tr><th>Event</th><th>Status</th><th>Message</th><th>Error</th><th>Sent At</th></tr></thead>
              <tbody>
                <%= for log <- @logs do %>
                  <tr>
                    <td>{log.event_type}</td>
                    <td><span class={"tag #{log_status_tag(log.status)}"}>{log.status}</span></td>
                    <td>{String.slice(log.message, 0..50)}</td>
                    <td>{log.error_message || "---"}</td>
                    <td class="td-mono">{if log.sent_at, do: Calendar.strftime(log.sent_at, "%Y-%m-%d %H:%M"), else: "---"}</td>
                  </tr>
                <% end %>
              </tbody>
            </table>
            <%= if @logs == [] do %>
              <p>No logs found for this channel.</p>
            <% end %>
            <div class="form-actions">
              <button phx-click="close_logs" class="btn btn-secondary">Close</button>
            </div>
          </div>
        </div>
      </div>
    <% end %>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit Channel", else: "Add Channel"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Name</label>
                <input type="text" name="notification_channel[name]" class="form-input" value={if @editing_item, do: @editing_item.name, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Provider *</label>
                <select name="notification_channel[provider]" class="form-select" required>
                  <option value="">Select provider</option>
                  <%= for p <- NotificationChannel.valid_providers() do %>
                    <option value={p} selected={@editing_item && @editing_item.provider == p}>{p}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Active</label>
                <select name="notification_channel[is_active]" class="form-select">
                  <option value="true" selected={!@editing_item || @editing_item.is_active}>Active</option>
                  <option value="false" selected={@editing_item && !@editing_item.is_active}>Inactive</option>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="notification_channel[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">{if @show_form == :edit, do: "Update", else: "Add"}</button>
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
    user_id = socket.assigns.current_scope.user.id
    assign(socket, channels: Notifications.list_notification_channels(user_id))
  end

  defp log_status_tag("sent"), do: "tag-jade"
  defp log_status_tag("failed"), do: "tag-rose"
  defp log_status_tag("pending"), do: "tag-lemon"
  defp log_status_tag(_), do: ""
end
