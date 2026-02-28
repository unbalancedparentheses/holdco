defmodule HoldcoWeb.NotificationSettingsLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.Notifications
  alias Holdco.Notifications.Dispatcher

  @event_types ~w(alert task approval report system)
  @providers Holdco.Notifications.NotificationChannel.valid_providers()

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id
    if connected?(socket), do: Notifications.subscribe(user_id)

    {:ok,
     assign(socket,
       page_title: "Notification Settings",
       channels: Notifications.list_channels(user_id),
       deliveries: Notifications.list_recent_deliveries(user_id, 20),
       stats: Notifications.delivery_stats(user_id),
       event_types: @event_types,
       providers: @providers,
       show_form: false,
       editing_channel: nil,
       selected_provider: nil,
       test_result: nil,
       active_tab: "channels"
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("switch_tab", %{"tab" => tab}, socket) when tab in ~w(channels deliveries) do
    {:noreply, assign(socket, active_tab: tab)}
  end

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: true, editing_channel: nil, selected_provider: nil, test_result: nil)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false, editing_channel: nil, selected_provider: nil, test_result: nil)}
  end

  def handle_event("select_provider", %{"provider" => provider}, socket) do
    {:noreply, assign(socket, selected_provider: provider)}
  end

  def handle_event("edit_channel", %{"id" => id}, socket) do
    channel = Notifications.get_channel!(String.to_integer(id))
    {:noreply, assign(socket, show_form: true, editing_channel: channel, selected_provider: channel.provider)}
  end

  # Permission guards
  def handle_event("save_channel", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "Write access required")}

  def handle_event("delete_channel", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "Write access required")}

  def handle_event("toggle_channel", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "Write access required")}

  def handle_event("test_channel", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "Write access required")}

  def handle_event("save_channel", %{"channel" => params} = full_params, socket) do
    user_id = socket.assigns.current_user.id

    # Collect event type checkboxes
    selected_events = Map.get(full_params, "event_types", [])
    selected_events = if is_list(selected_events), do: selected_events, else: [selected_events]

    # Build config based on provider
    config = build_config(params)

    channel_attrs = %{
      user_id: user_id,
      provider: params["provider"],
      config: config,
      event_types: selected_events,
      notes: params["notes"] || ""
    }

    result =
      case socket.assigns.editing_channel do
        nil -> Notifications.create_channel(channel_attrs)
        channel -> Notifications.update_channel(channel, channel_attrs)
      end

    case result do
      {:ok, _channel} ->
        action = if socket.assigns.editing_channel, do: "updated", else: "created"

        {:noreply,
         socket
         |> reload_data()
         |> put_flash(:info, "Channel #{action} successfully")
         |> assign(show_form: false, editing_channel: nil, selected_provider: nil)}

      {:error, changeset} ->
        errors = format_changeset_errors(changeset)
        {:noreply, put_flash(socket, :error, "Failed to save channel: #{errors}")}
    end
  end

  def handle_event("delete_channel", %{"id" => id}, socket) do
    channel = Notifications.get_channel!(String.to_integer(id))
    {:ok, _} = Notifications.delete_channel(channel)

    {:noreply,
     socket
     |> reload_data()
     |> put_flash(:info, "Channel deleted")}
  end

  def handle_event("toggle_channel", %{"id" => id}, socket) do
    channel = Notifications.get_channel!(String.to_integer(id))
    {:ok, _} = Notifications.update_channel(channel, %{is_active: !channel.is_active})

    {:noreply, reload_data(socket)}
  end

  def handle_event("test_channel", %{"id" => id}, socket) do
    channel = Notifications.get_channel!(String.to_integer(id))

    # Create a test notification
    {:ok, test_notif} =
      Notifications.create_notification(%{
        user_id: socket.assigns.current_user.id,
        title: "Test Notification",
        body: "This is a test notification from Holdco to verify your #{channel.provider} channel is working.",
        type: "info"
      })

    provider_mod = Dispatcher.get_provider(channel.provider)

    result =
      if provider_mod do
        case provider_mod.send_notification(channel, test_notif) do
          {:ok, _} -> :ok
          {:error, msg} -> {:error, msg}
        end
      else
        {:error, "No provider module for #{channel.provider}"}
      end

    case result do
      :ok ->
        {:noreply, put_flash(socket, :info, "Test notification sent successfully to #{channel.provider}!")}

      {:error, msg} ->
        {:noreply, put_flash(socket, :error, "Test failed: #{msg}")}
    end
  end

  @impl true
  def handle_info({:new_notification, _notif}, socket) do
    {:noreply, reload_data(socket)}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  defp reload_data(socket) do
    user_id = socket.assigns.current_user.id

    assign(socket,
      channels: Notifications.list_channels(user_id),
      deliveries: Notifications.list_recent_deliveries(user_id, 20),
      stats: Notifications.delivery_stats(user_id)
    )
  end

  defp build_config(params) do
    config = %{}

    config =
      if params["webhook_url"] && params["webhook_url"] != "",
        do: Map.put(config, "webhook_url", params["webhook_url"]),
        else: config

    config =
      if params["bot_token"] && params["bot_token"] != "",
        do: Map.put(config, "bot_token", params["bot_token"]),
        else: config

    config =
      if params["chat_id"] && params["chat_id"] != "",
        do: Map.put(config, "chat_id", params["chat_id"]),
        else: config

    config =
      if params["email"] && params["email"] != "",
        do: Map.put(config, "email", params["email"]),
        else: config

    config
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map(fn {k, v} -> "#{k} #{Enum.join(v, ", ")}" end)
    |> Enum.join("; ")
  end

  defp provider_label("slack"), do: "Slack"
  defp provider_label("telegram"), do: "Telegram"
  defp provider_label("email"), do: "Email"
  defp provider_label("in_app"), do: "In-App"
  defp provider_label(other), do: other

  defp status_color("sent"), do: "color: #2e7d32"
  defp status_color("failed"), do: "color: #c62828"
  defp status_color("pending"), do: "color: #e65100"
  defp status_color("skipped"), do: "color: #757575"
  defp status_color(_), do: ""

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <h1>Notification Settings</h1>
      <p class="deck">
        Configure notification channels to receive alerts via Slack, Telegram, Email, or In-App.
      </p>
      <hr class="page-title-rule" />
    </div>

    <%!-- Stats bar --%>
    <div style="display: flex; gap: 2rem; margin-bottom: 1.5rem;">
      <div>
        <strong>{@stats.total}</strong> total deliveries
      </div>
      <div style="color: #2e7d32;">
        <strong>{@stats.sent}</strong> sent
      </div>
      <div style="color: #c62828;">
        <strong>{@stats.failed}</strong> failed
      </div>
      <div>
        <strong>{length(@channels)}</strong> channels configured
      </div>
    </div>

    <div class="tabs">
      <button
        class={"tab #{if @active_tab == "channels", do: "tab-active"}"}
        phx-click="switch_tab"
        phx-value-tab="channels"
      >
        Channels
      </button>
      <button
        class={"tab #{if @active_tab == "deliveries", do: "tab-active"}"}
        phx-click="switch_tab"
        phx-value-tab="deliveries"
      >
        Delivery History
      </button>
    </div>

    <div class="tab-body">
      <%= if @active_tab == "channels" do %>
        {render_channels(assigns)}
      <% else %>
        {render_deliveries(assigns)}
      <% end %>
    </div>

    <%!-- Add/Edit Channel Dialog --%>
    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop" style="max-width: 500px;">
          <div class="dialog-header">
            <h3>{if @editing_channel, do: "Edit Channel", else: "Add Channel"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit="save_channel">
              <%!-- Provider selector --%>
              <div class="form-group">
                <label class="form-label">Provider *</label>
                <select
                  name="channel[provider]"
                  class="form-select"
                  phx-change="select_provider"
                  required
                >
                  <option value="">Select provider...</option>
                  <%= for p <- @providers do %>
                    <option value={p} selected={@selected_provider == p}>
                      {provider_label(p)}
                    </option>
                  <% end %>
                </select>
              </div>

              <%!-- Provider-specific config fields --%>
              <%= if @selected_provider == "slack" do %>
                <div class="form-group">
                  <label class="form-label">Webhook URL *</label>
                  <input
                    type="url"
                    name="channel[webhook_url]"
                    class="form-input"
                    placeholder="https://hooks.slack.com/services/..."
                    value={(@editing_channel && @editing_channel.config["webhook_url"]) || ""}
                    required
                  />
                </div>
              <% end %>
              <%= if @selected_provider == "telegram" do %>
                <div class="form-group">
                  <label class="form-label">Bot Token *</label>
                  <input
                    type="text"
                    name="channel[bot_token]"
                    class="form-input"
                    placeholder="123456:ABC-DEF..."
                    value={(@editing_channel && @editing_channel.config["bot_token"]) || ""}
                    required
                  />
                </div>
                <div class="form-group">
                  <label class="form-label">Chat ID *</label>
                  <input
                    type="text"
                    name="channel[chat_id]"
                    class="form-input"
                    placeholder="-1001234567890"
                    value={(@editing_channel && @editing_channel.config["chat_id"]) || ""}
                    required
                  />
                </div>
              <% end %>
              <%= if @selected_provider == "email" do %>
                <div class="form-group">
                  <label class="form-label">Email Address *</label>
                  <input
                    type="email"
                    name="channel[email]"
                    class="form-input"
                    placeholder="user@example.com"
                    value={(@editing_channel && @editing_channel.config["email"]) || ""}
                    required
                  />
                </div>
              <% end %>

              <%!-- Event type subscriptions --%>
              <div class="form-group">
                <label class="form-label">Event Subscriptions</label>
                <p style="font-size: 0.8rem; color: #666; margin-bottom: 0.5rem;">
                  Select which events trigger this channel. Leave all unchecked for all events.
                </p>
                <div style="display: flex; flex-direction: column; gap: 0.4rem;">
                  <%= for evt <- @event_types do %>
                    <label style="display: flex; align-items: center; gap: 0.5rem; font-size: 0.9rem;">
                      <input
                        type="checkbox"
                        name="event_types[]"
                        value={evt}
                        checked={@editing_channel && evt in (@editing_channel.event_types || [])}
                      />
                      <span><strong>{evt}</strong></span>
                    </label>
                  <% end %>
                </div>
              </div>

              <%!-- Notes --%>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="channel[notes]" class="form-input">{(@editing_channel && @editing_channel.notes) || ""}</textarea>
              </div>

              <div class="form-actions">
                <button type="submit" class="btn btn-primary">
                  {if @editing_channel, do: "Update", else: "Add Channel"}
                </button>
                <button type="button" phx-click="close_form" class="btn btn-secondary">
                  Cancel
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp render_channels(assigns) do
    ~H"""
    <div class="section">
      <div class="section-head">
        <h2>Notification Channels</h2>
        <%= if @can_write do %>
          <button class="btn btn-sm btn-primary" phx-click="show_form">Add Channel</button>
        <% end %>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Provider</th>
              <th>Status</th>
              <th>Events</th>
              <th>Notes</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for ch <- @channels do %>
              <tr>
                <td class="td-name">{provider_label(ch.provider)}</td>
                <td>
                  <%= if ch.is_active do %>
                    <span style="color: #2e7d32;">Active</span>
                  <% else %>
                    <span style="color: #757575;">Inactive</span>
                  <% end %>
                </td>
                <td>
                  <%= if ch.event_types == [] do %>
                    <span style="color: #666;">All events</span>
                  <% else %>
                    {Enum.join(ch.event_types, ", ")}
                  <% end %>
                </td>
                <td>{ch.notes || ""}</td>
                <td style="white-space: nowrap;">
                  <%= if @can_write do %>
                    <button
                      phx-click="test_channel"
                      phx-value-id={ch.id}
                      class="btn btn-sm btn-secondary"
                      title="Send test notification"
                    >
                      Test
                    </button>
                    <button
                      phx-click="toggle_channel"
                      phx-value-id={ch.id}
                      class="btn btn-sm btn-secondary"
                    >
                      {if ch.is_active, do: "Disable", else: "Enable"}
                    </button>
                    <button
                      phx-click="edit_channel"
                      phx-value-id={ch.id}
                      class="btn btn-sm btn-secondary"
                    >
                      Edit
                    </button>
                    <button
                      phx-click="delete_channel"
                      phx-value-id={ch.id}
                      class="btn btn-danger btn-sm"
                      data-confirm="Delete this channel?"
                    >
                      Del
                    </button>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @channels == [] do %>
          <div class="empty-state">
            No notification channels configured yet. Add a channel to receive notifications via Slack, Telegram, or Email.
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_deliveries(assigns) do
    ~H"""
    <div class="section">
      <div class="section-head">
        <h2>Recent Deliveries</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Provider</th>
              <th>Status</th>
              <th>Notification</th>
              <th>Sent At</th>
              <th>Attempts</th>
              <th>Error</th>
            </tr>
          </thead>
          <tbody>
            <%= for d <- @deliveries do %>
              <tr>
                <td>{provider_label(d.provider)}</td>
                <td style={status_color(d.status)}>
                  <strong>{d.status}</strong>
                </td>
                <td>{if d.notification, do: d.notification.title, else: "-"}</td>
                <td class="td-mono">
                  {if d.sent_at, do: Calendar.strftime(d.sent_at, "%Y-%m-%d %H:%M"), else: "-"}
                </td>
                <td>{d.attempts}</td>
                <td style="max-width: 200px; overflow: hidden; text-overflow: ellipsis;">
                  {d.error_message || "-"}
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @deliveries == [] do %>
          <div class="empty-state">No delivery history yet.</div>
        <% end %>
      </div>
    </div>
    """
  end
end
