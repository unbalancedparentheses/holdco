defmodule HoldcoWeb.SsoConfigLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.Platform

  @provider_types ~w(saml oidc oauth2)

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Platform.subscribe("platform")

    {:ok,
     socket
     |> assign(
       page_title: "SSO Configuration",
       provider_types: @provider_types,
       sso_configs: Platform.list_sso_configs(),
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
    config = Platform.get_sso_config!(String.to_integer(id))
    {:noreply, assign(socket, show_form: true, editing_item: config)}
  end

  # --- Permission Guards ---
  def handle_event("save", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("toggle_active", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("save", %{"sso_config" => params}, socket) do
    result =
      case socket.assigns.editing_item do
        nil -> Platform.create_sso_config(params)
        config -> Platform.update_sso_config(config, params)
      end

    case result do
      {:ok, _} ->
        action = if socket.assigns.editing_item, do: "updated", else: "created"
        {:noreply,
         socket
         |> put_flash(:info, "SSO config #{action} successfully")
         |> assign(show_form: false, editing_item: nil)
         |> reload_data()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to save SSO config. Check required fields.")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    config = Platform.get_sso_config!(String.to_integer(id))
    {:ok, _} = Platform.delete_sso_config(config)

    {:noreply,
     socket
     |> put_flash(:info, "SSO config deleted")
     |> reload_data()}
  end

  def handle_event("toggle_active", %{"id" => id}, socket) do
    config = Platform.get_sso_config!(String.to_integer(id))
    {:ok, _} = Platform.update_sso_config(config, %{is_active: !config.is_active})

    {:noreply, reload_data(socket)}
  end

  def handle_event("test_connection", %{"id" => _id}, socket) do
    {:noreply, put_flash(socket, :info, "Connection test initiated (visual only)")}
  end

  @impl true
  def handle_info({event, _record}, socket) when event in [
    :sso_configs_created, :sso_configs_updated, :sso_configs_deleted
  ] do
    {:noreply, reload_data(socket)}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  defp reload_data(socket) do
    assign(socket, sso_configs: Platform.list_sso_configs())
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-header">
      <h1>SSO Configuration</h1>
      <button phx-click="show_form" class="btn btn-primary">+ Add SSO Config</button>
    </div>

    <div class="table-container">
      <table class="data-table">
        <thead>
          <tr>
            <th>Name</th>
            <th>Provider Type</th>
            <th>Entity ID</th>
            <th>SSO URL</th>
            <th>Active</th>
            <th>Last Synced</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          <%= for config <- @sso_configs do %>
            <tr>
              <td><%= config.name %></td>
              <td><span class={"tag #{provider_tag(config.provider_type)}"}><%= config.provider_type %></span></td>
              <td><%= config.entity_id || "-" %></td>
              <td><%= config.sso_url || "-" %></td>
              <td>
                <button phx-click="toggle_active" phx-value-id={config.id} class={"tag #{if config.is_active, do: "tag-jade", else: "tag-crimson"}"}>
                  <%= if config.is_active, do: "Active", else: "Inactive" %>
                </button>
              </td>
              <td><%= format_datetime(config.last_synced_at) %></td>
              <td>
                <button phx-click="test_connection" phx-value-id={config.id} class="btn btn-xs btn-secondary">Test</button>
                <button phx-click="edit" phx-value-id={config.id} class="btn btn-xs">Edit</button>
                <button phx-click="delete" phx-value-id={config.id} data-confirm="Delete this SSO config?" class="btn btn-xs btn-danger">Delete</button>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>

    <%= if @show_form do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click="noop">
          <div class="modal-header">
            <h2><%= if @editing_item, do: "Edit SSO Config", else: "New SSO Config" %></h2>
            <button phx-click="close_form" class="btn-close">&times;</button>
          </div>
          <form phx-submit="save">
            <div class="form-group">
              <label class="form-label">Name *</label>
              <input type="text" name="sso_config[name]" class="form-input" required
                value={if @editing_item, do: @editing_item.name, else: ""} />
            </div>
            <div class="form-group">
              <label class="form-label">Provider Type *</label>
              <select name="sso_config[provider_type]" class="form-select" required>
                <option value="">Select...</option>
                <%= for t <- @provider_types do %>
                  <option value={t} selected={@editing_item && @editing_item.provider_type == t}><%= t %></option>
                <% end %>
              </select>
            </div>
            <div class="form-group">
              <label class="form-label">Entity ID</label>
              <input type="text" name="sso_config[entity_id]" class="form-input"
                value={if @editing_item, do: @editing_item.entity_id, else: ""} />
            </div>
            <div class="form-group">
              <label class="form-label">SSO URL</label>
              <input type="text" name="sso_config[sso_url]" class="form-input"
                value={if @editing_item, do: @editing_item.sso_url, else: ""} />
            </div>
            <div class="form-group">
              <label class="form-label">SLO URL</label>
              <input type="text" name="sso_config[slo_url]" class="form-input"
                value={if @editing_item, do: @editing_item.slo_url, else: ""} />
            </div>
            <div class="form-group">
              <label class="form-label">Metadata URL</label>
              <input type="text" name="sso_config[metadata_url]" class="form-input"
                value={if @editing_item, do: @editing_item.metadata_url, else: ""} />
            </div>
            <div class="form-group">
              <label class="form-label">Client ID</label>
              <input type="text" name="sso_config[client_id]" class="form-input"
                value={if @editing_item, do: @editing_item.client_id, else: ""} />
            </div>
            <div class="form-group">
              <label class="form-label">Scopes</label>
              <input type="text" name="sso_config[scopes]" class="form-input"
                value={if @editing_item, do: @editing_item.scopes, else: ""} />
            </div>
            <div class="form-group">
              <label class="form-label">Default Role</label>
              <input type="text" name="sso_config[default_role]" class="form-input"
                value={if @editing_item, do: @editing_item.default_role, else: ""} />
            </div>
            <div class="form-group">
              <label class="form-label">Notes</label>
              <textarea name="sso_config[notes]" class="form-input" rows="2"><%= if @editing_item, do: @editing_item.notes, else: "" %></textarea>
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

  defp format_datetime(nil), do: "-"
  defp format_datetime(dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")

  defp provider_tag("saml"), do: "tag-ink"
  defp provider_tag("oidc"), do: "tag-jade"
  defp provider_tag("oauth2"), do: "tag-lemon"
  defp provider_tag(_), do: "tag-ink"
end
