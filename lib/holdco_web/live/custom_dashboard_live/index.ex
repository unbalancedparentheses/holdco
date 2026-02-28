defmodule HoldcoWeb.CustomDashboardLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.Analytics

  @themes ~w(light dark auto)
  @widget_types ~w(chart table metric list)

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Analytics.subscribe()

    user_id = socket.assigns.current_scope.user.id

    {:ok,
     socket
     |> assign(
       page_title: "Custom Dashboards",
       user_id: user_id,
       themes: @themes,
       widget_types: @widget_types,
       dashboards: Analytics.list_custom_dashboards(user_id),
       shared_dashboards: Analytics.shared_dashboards(),
       show_form: false,
       editing_item: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("show_form", _, socket),
    do: {:noreply, assign(socket, show_form: true, editing_item: nil)}

  def handle_event("close_form", _, socket),
    do: {:noreply, assign(socket, show_form: false, editing_item: nil)}

  def handle_event("edit", %{"id" => id}, socket) do
    dashboard = Analytics.get_custom_dashboard!(String.to_integer(id))
    {:noreply, assign(socket, show_form: true, editing_item: dashboard)}
  end

  # --- Permission Guards ---
  def handle_event("save", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("save", %{"dashboard" => params}, socket) do
    params = Map.put(params, "user_id", socket.assigns.user_id)

    result =
      case socket.assigns.editing_item do
        nil -> Analytics.create_custom_dashboard(params)
        dashboard -> Analytics.update_custom_dashboard(dashboard, params)
      end

    case result do
      {:ok, _} ->
        action = if socket.assigns.editing_item, do: "updated", else: "created"
        {:noreply,
         socket
         |> put_flash(:info, "Dashboard #{action} successfully")
         |> assign(show_form: false, editing_item: nil)
         |> reload_data()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to save dashboard. Check required fields.")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    dashboard = Analytics.get_custom_dashboard!(String.to_integer(id))
    {:ok, _} = Analytics.delete_custom_dashboard(dashboard)

    {:noreply,
     socket
     |> put_flash(:info, "Dashboard deleted")
     |> reload_data()}
  end

  def handle_event("set_default", %{"id" => id}, socket) do
    dashboard = Analytics.get_custom_dashboard!(String.to_integer(id))
    {:ok, _} = Analytics.update_custom_dashboard(dashboard, %{is_default: true})

    {:noreply, reload_data(socket)}
  end

  @impl true
  def handle_info({event, _record}, socket) when event in [
    :custom_dashboards_created, :custom_dashboards_updated, :custom_dashboards_deleted
  ] do
    {:noreply, reload_data(socket)}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  defp reload_data(socket) do
    assign(socket,
      dashboards: Analytics.list_custom_dashboards(socket.assigns.user_id),
      shared_dashboards: Analytics.shared_dashboards()
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-header">
      <h1>Custom Dashboards</h1>
      <button phx-click="show_form" class="btn btn-primary">+ New Dashboard</button>
    </div>

    <h2 class="section-title">My Dashboards</h2>
    <div class="dashboard-grid" style="display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 1rem; margin-bottom: 2rem;">
      <%= for dash <- @dashboards do %>
        <div class="card" style="padding: 1rem; border: 1px solid #ddd; border-radius: 8px;">
          <div style="display: flex; justify-content: space-between; align-items: center;">
            <h3><%= dash.name %></h3>
            <span class={"tag #{theme_tag(dash.theme)}"}><%= dash.theme %></span>
          </div>
          <p style="color: #666; font-size: 0.875rem;"><%= dash.description || "No description" %></p>
          <div style="margin-top: 0.5rem; font-size: 0.75rem; color: #999;">
            <span><%= length(dash.widgets || []) %> widgets</span>
            <span> &middot; Refresh: <%= dash.refresh_interval_seconds %>s</span>
            <%= if dash.is_default do %><span class="tag tag-jade">Default</span><% end %>
            <%= if dash.is_shared do %><span class="tag tag-ink">Shared</span><% end %>
          </div>
          <div style="margin-top: 0.75rem; display: flex; gap: 0.5rem;">
            <button phx-click="edit" phx-value-id={dash.id} class="btn btn-xs">Edit</button>
            <button phx-click="set_default" phx-value-id={dash.id} class="btn btn-xs btn-secondary">Set Default</button>
            <button phx-click="delete" phx-value-id={dash.id} data-confirm="Delete this dashboard?" class="btn btn-xs btn-danger">Delete</button>
          </div>
        </div>
      <% end %>
    </div>

    <%= if @shared_dashboards != [] do %>
      <h2 class="section-title">Shared Dashboards</h2>
      <div class="table-container">
        <table class="data-table">
          <thead>
            <tr>
              <th>Name</th>
              <th>Description</th>
              <th>Theme</th>
              <th>Widgets</th>
            </tr>
          </thead>
          <tbody>
            <%= for dash <- @shared_dashboards do %>
              <tr>
                <td><%= dash.name %></td>
                <td><%= dash.description || "-" %></td>
                <td><span class={"tag #{theme_tag(dash.theme)}"}><%= dash.theme %></span></td>
                <td><%= length(dash.widgets || []) %></td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    <% end %>

    <%= if @show_form do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click="noop">
          <div class="modal-header">
            <h2><%= if @editing_item, do: "Edit Dashboard", else: "New Dashboard" %></h2>
            <button phx-click="close_form" class="btn-close">&times;</button>
          </div>
          <form phx-submit="save">
            <div class="form-group">
              <label class="form-label">Name *</label>
              <input type="text" name="dashboard[name]" class="form-input" required
                value={if @editing_item, do: @editing_item.name, else: ""} />
            </div>
            <div class="form-group">
              <label class="form-label">Description</label>
              <textarea name="dashboard[description]" class="form-input" rows="2"><%= if @editing_item, do: @editing_item.description, else: "" %></textarea>
            </div>
            <div class="form-group">
              <label class="form-label">Theme</label>
              <select name="dashboard[theme]" class="form-select">
                <%= for t <- @themes do %>
                  <option value={t} selected={@editing_item && @editing_item.theme == t}><%= t %></option>
                <% end %>
              </select>
            </div>
            <div class="form-group">
              <label class="form-label">Refresh Interval (seconds)</label>
              <input type="number" name="dashboard[refresh_interval_seconds]" class="form-input" min="1"
                value={if @editing_item, do: @editing_item.refresh_interval_seconds, else: "300"} />
            </div>
            <div class="form-group">
              <label class="form-label">
                <input type="checkbox" name="dashboard[is_shared]" value="true"
                  checked={@editing_item && @editing_item.is_shared} />
                Share with team
              </label>
            </div>
            <div class="form-group">
              <label class="form-label">Notes</label>
              <textarea name="dashboard[notes]" class="form-input" rows="2"><%= if @editing_item, do: @editing_item.notes, else: "" %></textarea>
            </div>
            <div class="form-actions">
              <button type="submit" class="btn btn-primary">
                <%= if @editing_item, do: "Update", else: "Create" %>
              </button>
              <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
            </div>
          </form>
        </div>
      </div>
    <% end %>
    """
  end

  defp theme_tag("light"), do: "tag-lemon"
  defp theme_tag("dark"), do: "tag-ink"
  defp theme_tag("auto"), do: "tag-jade"
  defp theme_tag(_), do: "tag-ink"
end
