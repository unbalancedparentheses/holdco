defmodule HoldcoWeb.NotificationsLive do
  use HoldcoWeb, :live_view

  alias Holdco.Notifications

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_scope.user.id
    if connected?(socket), do: Phoenix.PubSub.subscribe(Holdco.PubSub, "notifications:#{user_id}")

    notifications = Notifications.list_notifications(user_id)
    unread = Notifications.unread_count(user_id)

    {:ok,
     assign(socket,
       page_title: "Notifications",
       notifications: notifications,
       unread_count: unread
     )}
  end

  @impl true
  def handle_event("mark_read", %{"id" => id}, socket) do
    Notifications.mark_read(String.to_integer(id))
    {:noreply, reload(socket)}
  end

  def handle_event("mark_all_read", _, socket) do
    Notifications.mark_all_read(socket.assigns.current_scope.user.id)
    {:noreply, reload(socket)}
  end

  @impl true
  def handle_info({:new_notification, _notif}, socket) do
    {:noreply, reload(socket)}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  defp reload(socket) do
    user_id = socket.assigns.current_scope.user.id
    notifications = Notifications.list_notifications(user_id)
    unread = Notifications.unread_count(user_id)
    assign(socket, notifications: notifications, unread_count: unread)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Notifications</h1>
          <p class="deck">{@unread_count} unread</p>
        </div>
        <%= if @unread_count > 0 do %>
          <button class="btn btn-secondary" phx-click="mark_all_read">Mark All Read</button>
        <% end %>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="section">
      <div class="panel">
        <%= if @notifications == [] do %>
          <div class="empty-state">No notifications yet.</div>
        <% else %>
          <table>
            <thead>
              <tr>
                <th></th>
                <th>Title</th>
                <th>Message</th>
                <th>Time</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <%= for notif <- @notifications do %>
                <tr style={if is_nil(notif.read_at), do: "font-weight: 500; background: #fdf6e3;"}>
                  <td>
                    <span class={"tag #{type_tag(notif.type)}"}>{notif.type}</span>
                  </td>
                  <td class="td-name">
                    <%= if notif.action_url do %>
                      <.link navigate={notif.action_url}>{notif.title}</.link>
                    <% else %>
                      {notif.title}
                    <% end %>
                  </td>
                  <td>{notif.body}</td>
                  <td class="td-mono">{format_time(notif.inserted_at)}</td>
                  <td>
                    <%= if is_nil(notif.read_at) do %>
                      <button
                        phx-click="mark_read"
                        phx-value-id={notif.id}
                        class="btn btn-secondary btn-sm"
                      >
                        Mark Read
                      </button>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        <% end %>
      </div>
    </div>
    """
  end

  defp type_tag("warning"), do: "tag-lemon"
  defp type_tag("error"), do: "tag-crimson"
  defp type_tag("success"), do: "tag-jade"
  defp type_tag(_), do: "tag-ink"

  defp format_time(nil), do: ""
  defp format_time(dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")
end
