defmodule HoldcoWeb.CollaborationLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.Platform

  @impl true
  def mount(_params, _session, socket) do
    sessions = Platform.list_all_active_sessions()

    {:ok,
     assign(socket,
       page_title: "Collaboration",
       sessions: sessions,
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

  def handle_event("save", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("end_session_action", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("save", %{"collaboration_session" => params}, socket) do
    user_id = socket.assigns.current_scope.user.id
    params = Map.put(params, "user_id", user_id)

    case Platform.create_session(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Session started")
         |> assign(show_form: false)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create session")}
    end
  end

  def handle_event("end_session_action", %{"id" => id}, socket) do
    session = Platform.get_collaboration_session!(String.to_integer(id))

    case Platform.end_session(session) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Session ended")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to end session")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Collaboration</h1>
          <p class="deck">Real-time presence and collaboration tracking</p>
        </div>
        <%= if @can_write do %>
          <button class="btn btn-primary" phx-click="show_form">Start Session</button>
        <% end %>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Active Sessions</div>
        <div class="metric-value">{length(@sessions)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Active Users</div>
        <div class="metric-value">{@sessions |> Enum.map(& &1.user_id) |> Enum.uniq() |> length()}</div>
      </div>
    </div>

    <div class="section">
      <div class="section-head"><h2>Active Sessions</h2></div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>User</th><th>Entity Type</th><th>Entity ID</th>
              <th>Started</th><th>Last Active</th><th></th>
            </tr>
          </thead>
          <tbody>
            <%= for s <- @sessions do %>
              <tr>
                <td class="td-name">{if s.user, do: s.user.email, else: "---"}</td>
                <td><span class="tag tag-sky">{s.entity_type}</span></td>
                <td class="td-num">{s.entity_id}</td>
                <td class="td-mono">{Calendar.strftime(s.started_at, "%Y-%m-%d %H:%M")}</td>
                <td class="td-mono">{Calendar.strftime(s.last_active_at, "%Y-%m-%d %H:%M")}</td>
                <td>
                  <%= if @can_write do %>
                    <button phx-click="end_session_action" phx-value-id={s.id} class="btn btn-danger btn-sm" data-confirm="End this session?">End</button>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @sessions == [] do %>
          <div class="empty-state">
            <p>No active collaboration sessions.</p>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header"><h3>Start Collaboration Session</h3></div>
          <div class="dialog-body">
            <form phx-submit="save">
              <div class="form-group">
                <label class="form-label">Entity Type *</label>
                <input type="text" name="collaboration_session[entity_type]" class="form-input" placeholder="e.g. company, document, holding" required />
              </div>
              <div class="form-group">
                <label class="form-label">Entity ID *</label>
                <input type="number" name="collaboration_session[entity_id]" class="form-input" required />
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Start Session</button>
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
    assign(socket, sessions: Platform.list_all_active_sessions())
  end
end
