defmodule HoldcoWeb.PluginLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.Platform
  alias Holdco.Platform.{Plugin, PluginHook}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Plugins",
       plugins: Platform.list_plugins(),
       show_form: false,
       editing_item: nil,
       show_hooks: nil,
       hooks: [],
       show_hook_form: false
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: :add, editing_item: nil)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false, editing_item: nil, show_hooks: nil, show_hook_form: false)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    plugin = Platform.get_plugin!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: plugin)}
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

  def handle_event("save", %{"plugin" => params}, socket) do
    case Platform.install_plugin(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Plugin installed")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to install plugin")}
    end
  end

  def handle_event("update", %{"plugin" => params}, socket) do
    plugin = socket.assigns.editing_item

    case Platform.update_plugin(plugin, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Plugin updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update plugin")}
    end
  end

  def handle_event("activate", %{"id" => id}, socket) do
    plugin = Platform.get_plugin!(String.to_integer(id))

    case Platform.activate_plugin(plugin) do
      {:ok, _} -> {:noreply, reload(socket) |> put_flash(:info, "Plugin activated")}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Failed to activate plugin")}
    end
  end

  def handle_event("deactivate", %{"id" => id}, socket) do
    plugin = Platform.get_plugin!(String.to_integer(id))

    case Platform.deactivate_plugin(plugin) do
      {:ok, _} -> {:noreply, reload(socket) |> put_flash(:info, "Plugin deactivated")}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Failed to deactivate plugin")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    plugin = Platform.get_plugin!(String.to_integer(id))

    case Platform.uninstall_plugin(plugin) do
      {:ok, _} -> {:noreply, reload(socket) |> put_flash(:info, "Plugin uninstalled")}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Failed to uninstall plugin")}
    end
  end

  def handle_event("show_hooks", %{"id" => id}, socket) do
    plugin_id = String.to_integer(id)
    hooks = Platform.list_plugin_hooks(plugin_id)
    {:noreply, assign(socket, show_hooks: plugin_id, hooks: hooks, show_hook_form: false)}
  end

  def handle_event("show_hook_form", _, socket) do
    {:noreply, assign(socket, show_hook_form: true)}
  end

  def handle_event("save_hook", %{"plugin_hook" => params}, socket) do
    params = Map.put(params, "plugin_id", socket.assigns.show_hooks)

    case Platform.create_plugin_hook(params) do
      {:ok, _} ->
        hooks = Platform.list_plugin_hooks(socket.assigns.show_hooks)
        {:noreply, assign(socket, hooks: hooks, show_hook_form: false) |> put_flash(:info, "Hook created")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create hook")}
    end
  end

  def handle_event("delete_hook", %{"id" => id}, socket) do
    hook = Holdco.Repo.get!(PluginHook, String.to_integer(id))

    case Platform.delete_plugin_hook(hook) do
      {:ok, _} ->
        hooks = Platform.list_plugin_hooks(socket.assigns.show_hooks)
        {:noreply, assign(socket, hooks: hooks) |> put_flash(:info, "Hook deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete hook")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Plugin Marketplace</h1>
          <p class="deck">Manage extensions, integrations, and automation plugins</p>
        </div>
        <%= if @can_write do %>
          <button class="btn btn-primary" phx-click="show_form">Install Plugin</button>
        <% end %>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Plugins</div>
        <div class="metric-value">{length(@plugins)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Active</div>
        <div class="metric-value">{Enum.count(@plugins, &(&1.status == "active"))}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Disabled</div>
        <div class="metric-value">{Enum.count(@plugins, &(&1.status == "disabled"))}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Errors</div>
        <div class="metric-value">{Enum.count(@plugins, &(&1.status == "error"))}</div>
      </div>
    </div>

    <div class="section">
      <div class="section-head"><h2>All Plugins</h2></div>
      <div class="panel">
        <div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 1rem;">
          <%= for p <- @plugins do %>
            <div class="panel" style="padding: 1rem;">
              <div style="display: flex; justify-content: space-between; align-items: center;">
                <h3 style="margin: 0;">{p.name}</h3>
                <span class={"tag #{status_tag(p.status)}"}>{humanize(p.status)}</span>
              </div>
              <p style="color: var(--muted); font-size: 0.875rem; margin: 0.5rem 0;">{p.description || "No description"}</p>
              <div style="font-size: 0.8rem; color: var(--muted);">
                <span class="tag tag-sky">{humanize(p.plugin_type)}</span>
                <span>v{p.version || "1.0"}</span>
                <span> by {p.author || "Unknown"}</span>
              </div>
              <%= if @can_write do %>
                <div style="display: flex; gap: 0.25rem; margin-top: 0.75rem; flex-wrap: wrap;">
                  <%= if p.status != "active" do %>
                    <button phx-click="activate" phx-value-id={p.id} class="btn btn-primary btn-sm">Activate</button>
                  <% end %>
                  <%= if p.status == "active" do %>
                    <button phx-click="deactivate" phx-value-id={p.id} class="btn btn-secondary btn-sm">Deactivate</button>
                  <% end %>
                  <button phx-click="edit" phx-value-id={p.id} class="btn btn-secondary btn-sm">Config</button>
                  <button phx-click="show_hooks" phx-value-id={p.id} class="btn btn-secondary btn-sm">Hooks</button>
                  <button phx-click="delete" phx-value-id={p.id} class="btn btn-danger btn-sm" data-confirm="Uninstall this plugin?">Uninstall</button>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
        <%= if @plugins == [] do %>
          <div class="empty-state">
            <p>No plugins installed.</p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_form">Install Your First Plugin</button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @show_hooks do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header"><h3>Plugin Hooks</h3></div>
          <div class="dialog-body">
            <table>
              <thead>
                <tr><th>Hook Point</th><th>Entity</th><th>Handler</th><th>Priority</th><th>Active</th><th></th></tr>
              </thead>
              <tbody>
                <%= for h <- @hooks do %>
                  <tr>
                    <td>{h.hook_point}</td>
                    <td>{h.entity_type || "---"}</td>
                    <td class="td-mono">{h.handler_function}</td>
                    <td class="td-num">{h.priority}</td>
                    <td>{if h.is_active, do: "Yes", else: "No"}</td>
                    <td>
                      <%= if @can_write do %>
                        <button phx-click="delete_hook" phx-value-id={h.id} class="btn btn-danger btn-sm" data-confirm="Delete?">Del</button>
                      <% end %>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
            <%= if @can_write and not @show_hook_form do %>
              <button class="btn btn-primary btn-sm" phx-click="show_hook_form" style="margin-top: 0.5rem;">Add Hook</button>
            <% end %>
            <%= if @show_hook_form do %>
              <form phx-submit="save_hook" style="margin-top: 1rem;">
                <div class="form-group">
                  <label class="form-label">Hook Point *</label>
                  <select name="plugin_hook[hook_point]" class="form-select" required>
                    <%= for hp <- ~w(before_save after_save before_delete after_delete on_event scheduled) do %>
                      <option value={hp}>{humanize(hp)}</option>
                    <% end %>
                  </select>
                </div>
                <div class="form-group">
                  <label class="form-label">Entity Type</label>
                  <input type="text" name="plugin_hook[entity_type]" class="form-input" />
                </div>
                <div class="form-group">
                  <label class="form-label">Handler Function *</label>
                  <input type="text" name="plugin_hook[handler_function]" class="form-input" required />
                </div>
                <div class="form-group">
                  <label class="form-label">Priority</label>
                  <input type="number" name="plugin_hook[priority]" class="form-input" value="50" />
                </div>
                <button type="submit" class="btn btn-primary btn-sm">Save Hook</button>
              </form>
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
            <h3>{if @show_form == :edit, do: "Edit Plugin Config", else: "Install Plugin"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Name *</label>
                <input type="text" name="plugin[name]" class="form-input" value={if @editing_item, do: @editing_item.name, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Slug *</label>
                <input type="text" name="plugin[slug]" class="form-input" value={if @editing_item, do: @editing_item.slug, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Type *</label>
                <select name="plugin[plugin_type]" class="form-select" required>
                  <%= for t <- Plugin.plugin_types() do %>
                    <option value={t} selected={@editing_item && @editing_item.plugin_type == t}>{humanize(t)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Version</label>
                <input type="text" name="plugin[version]" class="form-input" value={if @editing_item, do: @editing_item.version, else: "1.0.0"} />
              </div>
              <div class="form-group">
                <label class="form-label">Author</label>
                <input type="text" name="plugin[author]" class="form-input" value={if @editing_item, do: @editing_item.author, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Entry Module</label>
                <input type="text" name="plugin[entry_module]" class="form-input" value={if @editing_item, do: @editing_item.entry_module, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Description</label>
                <textarea name="plugin[description]" class="form-input">{if @editing_item, do: @editing_item.description, else: ""}</textarea>
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="plugin[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">{if @show_form == :edit, do: "Update Plugin", else: "Install Plugin"}</button>
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
    assign(socket, plugins: Platform.list_plugins())
  end

  defp humanize(str), do: str |> String.replace("_", " ") |> String.split(" ") |> Enum.map(&String.capitalize/1) |> Enum.join(" ")

  defp status_tag("installed"), do: "tag-sky"
  defp status_tag("active"), do: "tag-jade"
  defp status_tag("disabled"), do: "tag-lemon"
  defp status_tag("error"), do: "tag-rose"
  defp status_tag(_), do: ""
end
