defmodule HoldcoWeb.WebhookEndpointLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.Platform

  @available_events ~w(create update delete activate deactivate install uninstall)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Webhook Endpoints",
       endpoints: Platform.list_webhook_endpoints(),
       show_form: false,
       editing_item: nil,
       show_deliveries: nil,
       deliveries: [],
       available_events: @available_events
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: :add, editing_item: nil)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false, editing_item: nil, show_deliveries: nil)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    endpoint = Platform.get_webhook_endpoint!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: endpoint)}
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

  def handle_event("save", %{"webhook_endpoint" => params}, socket) do
    params = normalize_events(params)

    case Platform.create_webhook_endpoint(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Endpoint created")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create endpoint")}
    end
  end

  def handle_event("update", %{"webhook_endpoint" => params}, socket) do
    endpoint = socket.assigns.editing_item
    params = normalize_events(params)

    case Platform.update_webhook_endpoint(endpoint, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Endpoint updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update endpoint")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    endpoint = Platform.get_webhook_endpoint!(String.to_integer(id))

    case Platform.delete_webhook_endpoint(endpoint) do
      {:ok, _} -> {:noreply, reload(socket) |> put_flash(:info, "Endpoint deleted")}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Failed to delete endpoint")}
    end
  end

  def handle_event("test_endpoint", %{"id" => id}, socket) do
    endpoint = Platform.get_webhook_endpoint!(String.to_integer(id))
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Platform.create_webhook_delivery(%{
      endpoint_id: endpoint.id,
      event_type: "test",
      payload: %{"test" => true, "timestamp" => DateTime.to_iso8601(now)},
      status: "delivered",
      attempts: 1,
      delivered_at: now
    })

    Platform.update_webhook_endpoint(endpoint, %{last_triggered_at: now, last_response_code: 200})
    {:noreply, reload(socket) |> put_flash(:info, "Test delivery sent")}
  end

  def handle_event("retry", %{"id" => id}, socket) do
    delivery = Holdco.Repo.get!(Holdco.Platform.WebhookDelivery, String.to_integer(id))
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Platform.update_webhook_delivery(delivery, %{
      status: "delivered",
      attempts: delivery.attempts + 1,
      delivered_at: now
    })

    {:noreply,
     socket
     |> put_flash(:info, "Delivery retried")
     |> assign(deliveries: Platform.list_webhook_deliveries(socket.assigns.show_deliveries))}
  end

  def handle_event("show_deliveries", %{"id" => id}, socket) do
    endpoint_id = String.to_integer(id)
    deliveries = Platform.list_webhook_deliveries(endpoint_id)
    {:noreply, assign(socket, show_deliveries: endpoint_id, deliveries: deliveries)}
  end

  defp normalize_events(params) do
    events = Map.get(params, "events", [])
    events = if is_list(events), do: events, else: []
    Map.put(params, "events", events)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Webhook Endpoints</h1>
          <p class="deck">Manage outgoing webhook endpoints and delivery logs</p>
        </div>
        <%= if @can_write do %>
          <button class="btn btn-primary" phx-click="show_form">Add Endpoint</button>
        <% end %>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Endpoints</div>
        <div class="metric-value">{length(@endpoints)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Active</div>
        <div class="metric-value">{Enum.count(@endpoints, & &1.is_active)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Failed (3+)</div>
        <div class="metric-value">{Enum.count(@endpoints, &(&1.failure_count >= 3))}</div>
      </div>
    </div>

    <div class="section">
      <div class="section-head"><h2>All Endpoints</h2></div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Name</th><th>URL</th><th>Events</th><th>Active</th>
              <th>Failures</th><th>Last Triggered</th><th>Last Code</th><th></th>
            </tr>
          </thead>
          <tbody>
            <%= for e <- @endpoints do %>
              <tr>
                <td class="td-name">{e.name}</td>
                <td class="td-mono" style="font-size: 0.8rem;">{e.url}</td>
                <td>{if e.events == [], do: "All", else: Enum.join(e.events, ", ")}</td>
                <td>{if e.is_active, do: "Yes", else: "No"}</td>
                <td class="td-num">{e.failure_count}</td>
                <td class="td-mono">{if e.last_triggered_at, do: Calendar.strftime(e.last_triggered_at, "%Y-%m-%d %H:%M"), else: "Never"}</td>
                <td class="td-num">{e.last_response_code || "---"}</td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="test_endpoint" phx-value-id={e.id} class="btn btn-primary btn-sm">Test</button>
                      <button phx-click="show_deliveries" phx-value-id={e.id} class="btn btn-secondary btn-sm">Log</button>
                      <button phx-click="edit" phx-value-id={e.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete" phx-value-id={e.id} class="btn btn-danger btn-sm" data-confirm="Delete endpoint?">Del</button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @endpoints == [] do %>
          <div class="empty-state">
            <p>No webhook endpoints configured.</p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_form">Add Your First Endpoint</button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @show_deliveries do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop" style="max-width: 800px;">
          <div class="dialog-header"><h3>Delivery Log</h3></div>
          <div class="dialog-body">
            <table>
              <thead>
                <tr><th>Event</th><th>Status</th><th>Attempts</th><th>Code</th><th>Delivered</th><th></th></tr>
              </thead>
              <tbody>
                <%= for d <- @deliveries do %>
                  <tr>
                    <td>{d.event_type}</td>
                    <td><span class={"tag #{delivery_tag(d.status)}"}>{humanize(d.status)}</span></td>
                    <td class="td-num">{d.attempts}</td>
                    <td class="td-num">{d.response_code || "---"}</td>
                    <td class="td-mono">{if d.delivered_at, do: Calendar.strftime(d.delivered_at, "%Y-%m-%d %H:%M"), else: "---"}</td>
                    <td>
                      <%= if d.status in ["failed", "retrying"] and @can_write do %>
                        <button phx-click="retry" phx-value-id={d.id} class="btn btn-primary btn-sm">Retry</button>
                      <% end %>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
            <%= if @deliveries == [] do %>
              <p style="color: var(--muted); text-align: center; padding: 1rem;">No deliveries yet.</p>
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
            <h3>{if @show_form == :edit, do: "Edit Endpoint", else: "Add Endpoint"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Name *</label>
                <input type="text" name="webhook_endpoint[name]" class="form-input" value={if @editing_item, do: @editing_item.name, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">URL *</label>
                <input type="text" name="webhook_endpoint[url]" class="form-input" value={if @editing_item, do: @editing_item.url, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Description</label>
                <textarea name="webhook_endpoint[description]" class="form-input">{if @editing_item, do: @editing_item.description, else: ""}</textarea>
              </div>
              <div class="form-group">
                <label class="form-label">Secret Key</label>
                <input type="text" name="webhook_endpoint[secret_key]" class="form-input" value={if @editing_item, do: @editing_item.secret_key, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Max Retries</label>
                <input type="number" name="webhook_endpoint[max_retries]" class="form-input" value={if @editing_item, do: @editing_item.max_retries, else: "3"} />
              </div>
              <div class="form-group">
                <label class="form-label">Events (select which events to subscribe to)</label>
                <div style="display: flex; flex-wrap: wrap; gap: 0.75rem;">
                  <%= for event <- @available_events do %>
                    <label style="display: flex; align-items: center; gap: 0.25rem;">
                      <input type="checkbox" name="webhook_endpoint[events][]" value={event}
                        checked={@editing_item && event in (@editing_item.events || [])} />
                      {humanize(event)}
                    </label>
                  <% end %>
                </div>
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="webhook_endpoint[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">{if @show_form == :edit, do: "Update Endpoint", else: "Add Endpoint"}</button>
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
    assign(socket, endpoints: Platform.list_webhook_endpoints())
  end

  defp humanize(str), do: str |> String.replace("_", " ") |> String.split(" ") |> Enum.map(&String.capitalize/1) |> Enum.join(" ")

  defp delivery_tag("pending"), do: "tag-lemon"
  defp delivery_tag("delivered"), do: "tag-jade"
  defp delivery_tag("failed"), do: "tag-rose"
  defp delivery_tag("retrying"), do: "tag-sky"
  defp delivery_tag(_), do: ""
end
