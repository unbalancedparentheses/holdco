defmodule HoldcoWeb.SettingsLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Platform, Accounts}

  @tabs ~w(settings categories webhooks backups users)

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Platform.subscribe("platform")

    {:ok,
     assign(socket,
       page_title: "Settings",
       tabs: @tabs,
       settings: Platform.list_settings(),
       categories: Platform.list_categories(),
       webhooks: Platform.list_webhooks(),
       backups: Platform.list_backup_configs(),
       users: Accounts.list_users(),
       active_tab: "settings",
       show_form: false
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("switch_tab", %{"tab" => tab}, socket) when tab in @tabs do
    {:noreply, assign(socket, active_tab: tab, show_form: false)}
  end

  def handle_event("show_form", _, socket), do: {:noreply, assign(socket, show_form: true)}
  def handle_event("close_form", _, socket), do: {:noreply, assign(socket, show_form: false)}

  # --- Permission Guards (admin-only) ---
  def handle_event("save_setting", _params, %{assigns: %{can_admin: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "Admin access required")}

  def handle_event("delete_setting", _params, %{assigns: %{can_admin: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "Admin access required")}

  def handle_event("save_category", _params, %{assigns: %{can_admin: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "Admin access required")}

  def handle_event("delete_category", _params, %{assigns: %{can_admin: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "Admin access required")}

  def handle_event("save_webhook", _params, %{assigns: %{can_admin: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "Admin access required")}

  def handle_event("delete_webhook", _params, %{assigns: %{can_admin: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "Admin access required")}

  def handle_event("save_backup", _params, %{assigns: %{can_admin: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "Admin access required")}

  def handle_event("delete_backup", _params, %{assigns: %{can_admin: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "Admin access required")}

  def handle_event("update_role", _params, %{assigns: %{can_admin: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "Admin access required")}

  # --- Settings ---
  def handle_event("save_setting", %{"setting" => %{"key" => key, "value" => value}}, socket) do
    case Platform.upsert_setting(key, value) do
      {:ok, _} ->
        {:noreply,
         reload(socket) |> put_flash(:info, "Setting saved") |> assign(show_form: false)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to save setting")}
    end
  end

  def handle_event("delete_setting", %{"id" => id}, socket) do
    Platform.delete_setting(String.to_integer(id))
    {:noreply, reload(socket) |> put_flash(:info, "Setting deleted")}
  end

  # --- Categories ---
  def handle_event("save_category", %{"category" => params}, socket) do
    case Platform.create_category(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket) |> put_flash(:info, "Category added") |> assign(show_form: false)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add category")}
    end
  end

  def handle_event("delete_category", %{"id" => id}, socket) do
    cat = Platform.get_category!(String.to_integer(id))
    Platform.delete_category(cat)
    {:noreply, reload(socket) |> put_flash(:info, "Category deleted")}
  end

  # --- Webhooks ---
  def handle_event("save_webhook", %{"webhook" => params}, socket) do
    case Platform.create_webhook(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket) |> put_flash(:info, "Webhook added") |> assign(show_form: false)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add webhook")}
    end
  end

  def handle_event("delete_webhook", %{"id" => id}, socket) do
    wh = Platform.get_webhook!(String.to_integer(id))
    Platform.delete_webhook(wh)
    {:noreply, reload(socket) |> put_flash(:info, "Webhook deleted")}
  end

  # --- Backup Configs ---
  def handle_event("save_backup", %{"backup_config" => params}, socket) do
    case Platform.create_backup_config(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket) |> put_flash(:info, "Backup config added") |> assign(show_form: false)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add backup config")}
    end
  end

  def handle_event("delete_backup", %{"id" => id}, socket) do
    bc = Platform.get_backup_config!(String.to_integer(id))
    Platform.delete_backup_config(bc)
    {:noreply, reload(socket) |> put_flash(:info, "Backup config deleted")}
  end

  # --- User Role Update ---
  def handle_event("update_role", %{"user_id" => user_id, "role" => role}, socket) do
    user = Accounts.get_user!(String.to_integer(user_id))

    case Accounts.set_user_role(user, role) do
      {:ok, _} ->
        {:noreply,
         assign(socket, users: Accounts.list_users())
         |> put_flash(:info, "Role updated for #{user.email}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update role")}
    end
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, reload(socket)}

  defp reload(socket) do
    assign(socket,
      settings: Platform.list_settings(),
      categories: Platform.list_categories(),
      webhooks: Platform.list_webhooks(),
      backups: Platform.list_backup_configs(),
      users: Accounts.list_users()
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <h1>Settings</h1>
      <p class="deck">
        Application settings, categories, API keys, webhooks, and backup configuration
      </p>
      <hr class="page-title-rule" />
    </div>

    <div class="tabs">
      <button
        :for={tab <- @tabs}
        class={"tab #{if @active_tab == tab, do: "tab-active"}"}
        phx-click="switch_tab"
        phx-value-tab={tab}
      >
        {tab_label(tab)}
      </button>
    </div>

    <div class="tab-body">
      {render_tab(assigns)}
    </div>
    """
  end

  defp tab_label("settings"), do: "Settings"
  defp tab_label("categories"), do: "Categories"
  defp tab_label("webhooks"), do: "Webhooks"
  defp tab_label("backups"), do: "Backups"
  defp tab_label("users"), do: "Users"

  defp render_tab(%{active_tab: "settings"} = assigns) do
    ~H"""
    <div class="section">
      <div class="section-head">
        <h2>Application Settings</h2>
        <%= if @can_admin do %>
          <button class="btn btn-sm btn-primary" phx-click="show_form">Add Setting</button>
        <% end %>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Key</th>
              <th>Value</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for s <- @settings do %>
              <tr>
                <td class="td-mono">{s.key}</td>
                <td>{s.value}</td>
                <td>
                  <%= if @can_admin do %>
                    <button
                      phx-click="delete_setting"
                      phx-value-id={s.id}
                      class="btn btn-danger btn-sm"
                      data-confirm="Delete?"
                    >
                      Del
                    </button>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @settings == [] do %>
          <div class="empty-state">No settings configured yet. Add key-value pairs to configure the application.</div>
        <% end %>
      </div>
    </div>
    <%= if @show_form do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click="noop">
          <div class="modal-header">
            <h3>Add/Update Setting</h3>
          </div>
          <div class="modal-body">
            <form phx-submit="save_setting">
              <div class="form-group">
                <label class="form-label">Key *</label>
                <input type="text" name="setting[key]" class="form-input" required />
              </div>
              <div class="form-group">
                <label class="form-label">Value *</label>
                <input type="text" name="setting[value]" class="form-input" required />
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Save</button><button
                  type="button"
                  phx-click="close_form"
                  class="btn btn-secondary"
                >Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp render_tab(%{active_tab: "categories"} = assigns) do
    ~H"""
    <div class="section">
      <div class="section-head">
        <h2>Categories</h2>
        <%= if @can_admin do %>
          <button class="btn btn-sm btn-primary" phx-click="show_form">Add Category</button>
        <% end %>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>Color</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for c <- @categories do %>
              <tr>
                <td class="td-name">{c.name}</td>
                <td>
                  <span style={"display:inline-block;width:1rem;height:1rem;background:#{c.color};border-radius:2px;vertical-align:middle"}>
                  </span> {c.color}
                </td>
                <td>
                  <%= if @can_admin do %>
                    <button
                      phx-click="delete_category"
                      phx-value-id={c.id}
                      class="btn btn-danger btn-sm"
                      data-confirm="Delete?"
                    >
                      Del
                    </button>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @categories == [] do %>
          <div class="empty-state">No categories yet. Categories help organize your companies by type.</div>
        <% end %>
      </div>
    </div>
    <%= if @show_form do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click="noop">
          <div class="modal-header">
            <h3>Add Category</h3>
          </div>
          <div class="modal-body">
            <form phx-submit="save_category">
              <div class="form-group">
                <label class="form-label">Name *</label>
                <input type="text" name="category[name]" class="form-input" required />
              </div>
              <div class="form-group">
                <label class="form-label">Color</label>
                <input type="color" name="category[color]" class="form-input" value="#e0e0e0" />
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Add</button><button
                  type="button"
                  phx-click="close_form"
                  class="btn btn-secondary"
                >Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp render_tab(%{active_tab: "webhooks"} = assigns) do
    ~H"""
    <div class="section">
      <div class="section-head">
        <h2>Webhooks</h2>
        <%= if @can_admin do %>
          <button class="btn btn-sm btn-primary" phx-click="show_form">Add Webhook</button>
        <% end %>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>URL</th>
              <th>Events</th>
              <th>Active</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for w <- @webhooks do %>
              <tr>
                <td class="td-mono">{w.url}</td>
                <td>{w.events}</td>
                <td>{if w.is_active, do: "Yes", else: "No"}</td>
                <td>
                  <%= if @can_admin do %>
                    <button
                      phx-click="delete_webhook"
                      phx-value-id={w.id}
                      class="btn btn-danger btn-sm"
                      data-confirm="Delete?"
                    >
                      Del
                    </button>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @webhooks == [] do %>
          <div class="empty-state">No webhooks configured yet. Webhooks notify external services when actions occur.</div>
        <% end %>
      </div>
    </div>
    <%= if @show_form do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click="noop">
          <div class="modal-header">
            <h3>Add Webhook</h3>
          </div>
          <div class="modal-body">
            <form phx-submit="save_webhook">
              <div class="form-group">
                <label class="form-label">URL *</label>
                <input type="url" name="webhook[url]" class="form-input" required />
              </div>
              <div class="form-group">
                <label class="form-label">Events (JSON array)</label>
                <input type="text" name="webhook[events]" class="form-input" value="[]" />
              </div>
              <div class="form-group">
                <label class="form-label">Secret</label>
                <input type="text" name="webhook[secret]" class="form-input" />
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label><textarea
                  name="webhook[notes]"
                  class="form-input"
                ></textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Add</button><button
                  type="button"
                  phx-click="close_form"
                  class="btn btn-secondary"
                >Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp render_tab(%{active_tab: "backups"} = assigns) do
    ~H"""
    <div class="section">
      <div class="section-head">
        <h2>Backup Configurations</h2>
        <%= if @can_admin do %>
          <button class="btn btn-sm btn-primary" phx-click="show_form">Add Config</button>
        <% end %>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>Destination</th>
              <th>Schedule</th>
              <th>Retention</th>
              <th>Active</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for bc <- @backups do %>
              <tr>
                <td class="td-name">{bc.name}</td>
                <td class="td-mono">{bc.destination_type}: {bc.destination_path}</td>
                <td>{bc.schedule}</td>
                <td>{bc.retention_days} days</td>
                <td>{if bc.is_active, do: "Yes", else: "No"}</td>
                <td>
                  <%= if @can_admin do %>
                    <button
                      phx-click="delete_backup"
                      phx-value-id={bc.id}
                      class="btn btn-danger btn-sm"
                      data-confirm="Delete?"
                    >
                      Del
                    </button>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @backups == [] do %>
          <div class="empty-state">No backup configurations yet. Configure automated backups to protect your data.</div>
        <% end %>
      </div>
    </div>
    <%= if @show_form do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click="noop">
          <div class="modal-header">
            <h3>Add Backup Config</h3>
          </div>
          <div class="modal-body">
            <form phx-submit="save_backup">
              <div class="form-group">
                <label class="form-label">Name *</label>
                <input type="text" name="backup_config[name]" class="form-input" required />
              </div>
              <div class="form-group">
                <label class="form-label">Destination Type</label><select
                  name="backup_config[destination_type]"
                  class="form-select"
                ><option value="local">Local</option><option value="s3">S3</option><option value="gcs">GCS</option></select>
              </div>
              <div class="form-group">
                <label class="form-label">Destination Path *</label>
                <input type="text" name="backup_config[destination_path]" class="form-input" required />
              </div>
              <div class="form-group">
                <label class="form-label">Schedule</label><select
                  name="backup_config[schedule]"
                  class="form-select"
                ><option value="daily">Daily</option><option value="weekly">Weekly</option><option value="monthly">Monthly</option></select>
              </div>
              <div class="form-group">
                <label class="form-label">Retention Days</label>
                <input
                  type="number"
                  name="backup_config[retention_days]"
                  class="form-input"
                  value="30"
                />
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Add</button><button
                  type="button"
                  phx-click="close_form"
                  class="btn btn-secondary"
                >Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp render_tab(%{active_tab: "users"} = assigns) do
    ~H"""
    <div class="section">
      <div class="section-head">
        <h2>Users</h2>
        <span class="count">{length(@users)} users</span>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Email</th>
              <th>Role</th>
              <th>Joined</th>
            </tr>
          </thead>
          <tbody>
            <%= for u <- @users do %>
              <tr>
                <td class="td-name">{u.email}</td>
                <td>
                  <%= if @can_admin do %>
                    <form phx-change="update_role" style="display: inline;">
                      <input type="hidden" name="user_id" value={u.id} />
                      <select name="role" class="form-select" style="width: auto; padding: 0.2rem 0.4rem; font-size: 0.85rem;">
                        <option value="admin" selected={u.role == "admin"}>admin</option>
                        <option value="editor" selected={u.role == "editor"}>editor</option>
                        <option value="viewer" selected={u.role == "viewer"}>viewer</option>
                      </select>
                    </form>
                  <% else %>
                    <span class="tag tag-ink">{u.role}</span>
                  <% end %>
                </td>
                <td class="td-mono">
                  {if u.inserted_at, do: Calendar.strftime(u.inserted_at, "%Y-%m-%d")}
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @users == [] do %>
          <div class="empty-state">No users yet.</div>
        <% end %>
      </div>
    </div>
    """
  end
end
