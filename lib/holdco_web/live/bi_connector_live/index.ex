defmodule HoldcoWeb.BiConnectorLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.Analytics
  alias Holdco.Analytics.BiConnector

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "BI Connectors",
       connectors: Analytics.list_bi_connectors(),
       show_form: false,
       editing_item: nil,
       show_logs: nil,
       export_logs: []
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: :add, editing_item: nil)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false, editing_item: nil, show_logs: nil)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    connector = Analytics.get_bi_connector!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: connector)}
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

  def handle_event("save", %{"bi_connector" => params}, socket) do
    case Analytics.create_bi_connector(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Connector created")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create connector")}
    end
  end

  def handle_event("update", %{"bi_connector" => params}, socket) do
    connector = socket.assigns.editing_item

    case Analytics.update_bi_connector(connector, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Connector updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update connector")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    connector = Analytics.get_bi_connector!(String.to_integer(id))

    case Analytics.delete_bi_connector(connector) do
      {:ok, _} -> {:noreply, reload(socket) |> put_flash(:info, "Connector deleted")}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Failed to delete connector")}
    end
  end

  def handle_event("sync", %{"id" => id}, socket) do
    connector = Analytics.get_bi_connector!(String.to_integer(id))
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Analytics.create_bi_export_log(%{
      connector_id: connector.id,
      started_at: now,
      completed_at: now,
      rows_exported: 0,
      tables_exported: connector.tables_included || [],
      status: "success"
    })

    Analytics.update_bi_connector(connector, %{
      last_sync_at: now,
      sync_status: "completed"
    })

    {:noreply, reload(socket) |> put_flash(:info, "Sync triggered")}
  end

  def handle_event("show_logs", %{"id" => id}, socket) do
    connector_id = String.to_integer(id)
    logs = Analytics.list_bi_export_logs(connector_id)
    {:noreply, assign(socket, show_logs: connector_id, export_logs: logs)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>BI Connectors</h1>
          <p class="deck">Connect to Power BI, Tableau, Looker, Metabase and more</p>
        </div>
        <%= if @can_write do %>
          <button class="btn btn-primary" phx-click="show_form">Add Connector</button>
        <% end %>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Connectors</div>
        <div class="metric-value">{length(@connectors)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Active</div>
        <div class="metric-value">{Enum.count(@connectors, & &1.is_active)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Syncing</div>
        <div class="metric-value">{Enum.count(@connectors, &(&1.sync_status == "syncing"))}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Errors</div>
        <div class="metric-value">{Enum.count(@connectors, &(&1.sync_status == "error"))}</div>
      </div>
    </div>

    <div class="section">
      <div class="section-head"><h2>All Connectors</h2></div>
      <div class="panel">
        <div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)); gap: 1rem;">
          <%= for c <- @connectors do %>
            <div class="panel" style="padding: 1rem;">
              <div style="display: flex; justify-content: space-between; align-items: center;">
                <h3 style="margin: 0;">{c.name}</h3>
                <span class={"tag #{sync_tag(c.sync_status)}"}>{humanize(c.sync_status)}</span>
              </div>
              <div style="font-size: 0.8rem; color: var(--muted); margin: 0.5rem 0;">
                <span class="tag tag-sky">{humanize(c.connector_type)}</span>
                <span>Refresh: {humanize(c.refresh_frequency)}</span>
              </div>
              <div style="font-size: 0.8rem; color: var(--muted);">
                Last sync: {if c.last_sync_at, do: Calendar.strftime(c.last_sync_at, "%Y-%m-%d %H:%M"), else: "Never"}
              </div>
              <%= if @can_write do %>
                <div style="display: flex; gap: 0.25rem; margin-top: 0.75rem; flex-wrap: wrap;">
                  <button phx-click="sync" phx-value-id={c.id} class="btn btn-primary btn-sm">Sync Now</button>
                  <button phx-click="show_logs" phx-value-id={c.id} class="btn btn-secondary btn-sm">History</button>
                  <button phx-click="edit" phx-value-id={c.id} class="btn btn-secondary btn-sm">Edit</button>
                  <button phx-click="delete" phx-value-id={c.id} class="btn btn-danger btn-sm" data-confirm="Delete connector?">Del</button>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
        <%= if @connectors == [] do %>
          <div class="empty-state">
            <p>No BI connectors configured.</p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_form">Add Your First Connector</button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @show_logs do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header"><h3>Export History</h3></div>
          <div class="dialog-body">
            <table>
              <thead>
                <tr><th>Started</th><th>Completed</th><th>Rows</th><th>Status</th><th>Size</th></tr>
              </thead>
              <tbody>
                <%= for l <- @export_logs do %>
                  <tr>
                    <td class="td-mono">{if l.started_at, do: Calendar.strftime(l.started_at, "%Y-%m-%d %H:%M"), else: "---"}</td>
                    <td class="td-mono">{if l.completed_at, do: Calendar.strftime(l.completed_at, "%Y-%m-%d %H:%M"), else: "---"}</td>
                    <td class="td-num">{l.rows_exported || 0}</td>
                    <td><span class={"tag #{export_status_tag(l.status)}"}>{humanize(l.status)}</span></td>
                    <td class="td-num">{if l.file_size_bytes, do: "#{div(l.file_size_bytes, 1024)} KB", else: "---"}</td>
                  </tr>
                <% end %>
              </tbody>
            </table>
            <%= if @export_logs == [] do %>
              <p style="color: var(--muted); text-align: center; padding: 1rem;">No export history.</p>
            <% end %>
            <div class="form-actions" style="margin-top: 1rem;">
              <button type="button" phx-click="close_form" class="btn btn-secondary">Close</button>
            </div>
          </div>
        </div>
      </div>
    <% end %>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit Connector", else: "Add Connector"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Name *</label>
                <input type="text" name="bi_connector[name]" class="form-input" value={if @editing_item, do: @editing_item.name, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Connector Type *</label>
                <select name="bi_connector[connector_type]" class="form-select" required>
                  <%= for t <- BiConnector.connector_types() do %>
                    <option value={t} selected={@editing_item && @editing_item.connector_type == t}>{humanize(t)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Dataset Name</label>
                <input type="text" name="bi_connector[dataset_name]" class="form-input" value={if @editing_item, do: @editing_item.dataset_name, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Refresh Frequency</label>
                <select name="bi_connector[refresh_frequency]" class="form-select">
                  <%= for f <- BiConnector.refresh_frequencies() do %>
                    <option value={f} selected={@editing_item && @editing_item.refresh_frequency == f}>{humanize(f)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Format</label>
                <select name="bi_connector[format]" class="form-select">
                  <%= for f <- ~w(json csv parquet) do %>
                    <option value={f} selected={@editing_item && @editing_item.format == f}>{String.upcase(f)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Row Limit</label>
                <input type="number" name="bi_connector[row_limit]" class="form-input" value={if @editing_item, do: @editing_item.row_limit, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="bi_connector[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">{if @show_form == :edit, do: "Update Connector", else: "Add Connector"}</button>
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
    assign(socket, connectors: Analytics.list_bi_connectors())
  end

  defp humanize(str), do: str |> String.replace("_", " ") |> String.split(" ") |> Enum.map(&String.capitalize/1) |> Enum.join(" ")

  defp sync_tag("idle"), do: ""
  defp sync_tag("syncing"), do: "tag-sky"
  defp sync_tag("completed"), do: "tag-jade"
  defp sync_tag("error"), do: "tag-rose"
  defp sync_tag(_), do: ""

  defp export_status_tag("success"), do: "tag-jade"
  defp export_status_tag("partial"), do: "tag-lemon"
  defp export_status_tag("failed"), do: "tag-rose"
  defp export_status_tag(_), do: ""
end
