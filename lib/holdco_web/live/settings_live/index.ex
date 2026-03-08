defmodule HoldcoWeb.SettingsLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Platform, Accounts, AI, Config, Notifications, Analytics, Corporate}
  alias Holdco.Notifications.Dispatcher
  alias Holdco.Analytics.ScheduledReport

  @tabs ~w(settings services categories webhooks backups users ai notifications reports)
  @notification_event_types ~w(alert task approval report system)
  @notification_providers Holdco.Notifications.NotificationChannel.valid_providers()

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Platform.subscribe("platform")
    user_id = socket.assigns.current_scope.user.id
    if connected?(socket), do: Notifications.subscribe(user_id)

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
       show_form: false,
       ai_provider: Platform.get_setting_value("llm_provider", ""),
       ai_api_key: Platform.get_setting_value("llm_api_key", ""),
       ai_model: Platform.get_setting_value("llm_model", ""),
       ai_test_result: nil,
       channels: Notifications.list_channels(user_id),
       deliveries: Notifications.list_recent_deliveries(user_id, 20),
       notification_stats: Notifications.delivery_stats(user_id),
       editing_channel: nil,
       selected_provider: nil,
       notification_event_types: @notification_event_types,
       notification_providers: @notification_providers,
       scheduled_reports: Analytics.list_scheduled_reports(),
       report_companies: Corporate.list_companies(),
       editing_report: nil
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
  def handle_event("save_webhook", %{"webhook" => params} = full_params, socket) do
    # Encode selected event checkboxes as JSON array
    selected_events = Map.get(full_params, "webhook_events", [])
    selected_events = if is_list(selected_events), do: selected_events, else: [selected_events]
    events_json = Jason.encode!(selected_events)
    params = Map.put(params, "events", events_json)

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

  # --- AI Settings ---
  def handle_event("save_ai", _params, %{assigns: %{can_admin: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "Admin access required")}

  def handle_event("save_ai", %{"ai" => params}, socket) do
    results =
      for {key, setting_key} <- [
            {"provider", "llm_provider"},
            {"api_key", "llm_api_key"},
            {"model", "llm_model"}
          ],
          value = Map.get(params, key, ""),
          value != "" do
        Platform.upsert_setting(setting_key, value)
      end

    if Enum.all?(results, &match?({:ok, _}, &1)) do
      {:noreply,
       socket
       |> assign(
         ai_provider: Map.get(params, "provider", ""),
         ai_api_key: Map.get(params, "api_key", ""),
         ai_model: Map.get(params, "model", ""),
         ai_test_result: nil
       )
       |> put_flash(:info, "AI settings saved")}
    else
      {:noreply, put_flash(socket, :error, "Failed to save AI settings")}
    end
  end

  def handle_event("test_ai", _params, %{assigns: %{can_admin: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "Admin access required")}

  def handle_event("test_ai", _params, socket) do
    case AI.test_connection() do
      {:ok, _response} ->
        {:noreply, assign(socket, ai_test_result: :ok)}

      {:error, reason} ->
        {:noreply, assign(socket, ai_test_result: {:error, reason})}
    end
  end

  # --- Services ---
  def handle_event("save_services", _params, %{assigns: %{can_admin: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "Admin access required")}

  def handle_event("save_services", %{"services" => params}, socket) do
    keys = [
      "email_provider", "postmark_api_key", "resend_api_key",
      "smtp_relay", "smtp_port", "smtp_username", "smtp_password",
      "mail_from_name", "mail_from_address",
      "xero_client_id", "xero_client_secret", "xero_redirect_uri",
      "quickbooks_client_id", "quickbooks_client_secret", "quickbooks_redirect_uri",
      "quickbooks_environment",
      "s3_bucket", "s3_endpoint", "s3_region", "s3_access_key_id", "s3_secret_access_key"
    ]

    for key <- keys, value = Map.get(params, key, ""), value != "" do
      Platform.upsert_setting(key, value)
    end

    # Sync mailer config immediately so emails start working
    Config.sync_mailer!()

    {:noreply, put_flash(socket, :info, "Service settings saved")}
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

  # --- Notification Channels ---
  def handle_event("save_channel", _params, %{assigns: %{can_admin: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "Admin access required")}

  def handle_event("delete_channel", _params, %{assigns: %{can_admin: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "Admin access required")}

  def handle_event("toggle_channel", _params, %{assigns: %{can_admin: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "Admin access required")}

  def handle_event("test_channel", _params, %{assigns: %{can_admin: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "Admin access required")}

  def handle_event("select_provider", %{"provider" => provider}, socket) do
    {:noreply, assign(socket, selected_provider: provider)}
  end

  def handle_event("edit_channel", %{"id" => id}, socket) do
    channel = Notifications.get_channel!(String.to_integer(id))
    {:noreply, assign(socket, show_form: true, editing_channel: channel, selected_provider: channel.provider)}
  end

  def handle_event("save_channel", %{"channel" => params} = full_params, socket) do
    user_id = socket.assigns.current_scope.user.id
    selected_events = Map.get(full_params, "event_types", [])
    selected_events = if is_list(selected_events), do: selected_events, else: [selected_events]

    channel_attrs = %{
      user_id: user_id,
      provider: params["provider"],
      config: build_channel_config(params),
      event_types: selected_events,
      notes: params["notes"] || ""
    }

    result =
      case socket.assigns.editing_channel do
        nil -> Notifications.create_channel(channel_attrs)
        channel -> Notifications.update_channel(channel, channel_attrs)
      end

    case result do
      {:ok, _} ->
        action = if socket.assigns.editing_channel, do: "updated", else: "created"

        {:noreply,
         reload(socket)
         |> put_flash(:info, "Channel #{action}")
         |> assign(show_form: false, editing_channel: nil, selected_provider: nil)}

      {:error, changeset} ->
        errors = format_changeset_errors(changeset)
        {:noreply, put_flash(socket, :error, "Failed: #{errors}")}
    end
  end

  def handle_event("delete_channel", %{"id" => id}, socket) do
    channel = Notifications.get_channel!(String.to_integer(id))
    {:ok, _} = Notifications.delete_channel(channel)
    {:noreply, reload(socket) |> put_flash(:info, "Channel deleted")}
  end

  def handle_event("toggle_channel", %{"id" => id}, socket) do
    channel = Notifications.get_channel!(String.to_integer(id))
    {:ok, _} = Notifications.update_channel(channel, %{is_active: !channel.is_active})
    {:noreply, reload(socket)}
  end

  def handle_event("test_channel", %{"id" => id}, socket) do
    channel = Notifications.get_channel!(String.to_integer(id))

    {:ok, test_notif} =
      Notifications.create_notification(%{
        user_id: socket.assigns.current_scope.user.id,
        title: "Test Notification",
        body: "Test from Holdco to verify your #{channel.provider} channel.",
        type: "info"
      })

    provider_mod = Dispatcher.get_provider(channel.provider)

    case provider_mod && provider_mod.send_notification(channel, test_notif) do
      {:ok, _} ->
        {:noreply, put_flash(socket, :info, "Test sent to #{channel.provider}!")}

      {:error, msg} ->
        {:noreply, put_flash(socket, :error, "Test failed: #{msg}")}

      nil ->
        {:noreply, put_flash(socket, :error, "No provider for #{channel.provider}")}
    end
  end

  # --- Scheduled Reports ---
  def handle_event("save_report", _params, %{assigns: %{can_admin: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "Admin access required")}

  def handle_event("delete_report", _params, %{assigns: %{can_admin: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "Admin access required")}

  def handle_event("toggle_report", _params, %{assigns: %{can_admin: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "Admin access required")}

  def handle_event("send_now", _params, %{assigns: %{can_admin: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "Admin access required")}

  def handle_event("edit_report", %{"id" => id}, socket) do
    report = Analytics.get_scheduled_report!(String.to_integer(id))
    {:noreply, assign(socket, show_form: true, editing_report: report)}
  end

  def handle_event("save_report", %{"report" => params}, socket) do
    result =
      case socket.assigns.editing_report do
        nil -> Analytics.create_scheduled_report(params)
        report -> Analytics.update_scheduled_report(report, params)
      end

    case result do
      {:ok, _} ->
        action = if socket.assigns.editing_report, do: "updated", else: "created"

        {:noreply,
         reload(socket)
         |> put_flash(:info, "Report #{action}")
         |> assign(show_form: false, editing_report: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to save report")}
    end
  end

  def handle_event("delete_report", %{"id" => id}, socket) do
    report = Analytics.get_scheduled_report!(String.to_integer(id))
    {:ok, _} = Analytics.delete_scheduled_report(report)
    {:noreply, reload(socket) |> put_flash(:info, "Report deleted")}
  end

  def handle_event("toggle_report", %{"id" => id}, socket) do
    report = Analytics.get_scheduled_report!(String.to_integer(id))
    {:ok, _} = Analytics.update_scheduled_report(report, %{is_active: !report.is_active})
    status = if report.is_active, do: "paused", else: "activated"
    {:noreply, reload(socket) |> put_flash(:info, "Report #{status}")}
  end

  def handle_event("send_now", %{"id" => id}, socket) do
    report = Analytics.get_scheduled_report!(String.to_integer(id))

    case Oban.insert(Holdco.Workers.ScheduledReportWorker.new(%{"report_id" => report.id})) do
      {:ok, _} ->
        {:noreply, put_flash(socket, :info, "Report '#{report.name}' queued")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to queue report")}
    end
  end

  @impl true
  def handle_info({:new_notification, _}, socket), do: {:noreply, reload(socket)}
  def handle_info(_, socket), do: {:noreply, reload(socket)}

  defp reload(socket) do
    user_id = socket.assigns.current_scope.user.id

    assign(socket,
      settings: Platform.list_settings(),
      categories: Platform.list_categories(),
      webhooks: Platform.list_webhooks(),
      backups: Platform.list_backup_configs(),
      users: Accounts.list_users(),
      channels: Notifications.list_channels(user_id),
      deliveries: Notifications.list_recent_deliveries(user_id, 20),
      notification_stats: Notifications.delivery_stats(user_id),
      scheduled_reports: Analytics.list_scheduled_reports()
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

  defp format_webhook_events(nil), do: "All events"
  defp format_webhook_events(""), do: "All events"
  defp format_webhook_events("[]"), do: "All events"

  defp format_webhook_events(events_json) when is_binary(events_json) do
    case Jason.decode(events_json) do
      {:ok, []} -> "All events"
      {:ok, events} when is_list(events) -> Enum.join(events, ", ")
      _ -> "All events"
    end
  end

  defp format_webhook_events(_), do: "All events"

  defp tab_label("settings"), do: "Settings"
  defp tab_label("services"), do: "Services"
  defp tab_label("categories"), do: "Categories"
  defp tab_label("webhooks"), do: "Webhooks"
  defp tab_label("backups"), do: "Backups"
  defp tab_label("users"), do: "Users"
  defp tab_label("ai"), do: "AI"
  defp tab_label("notifications"), do: "Notifications"
  defp tab_label("reports"), do: "Reports"

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
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>Add/Update Setting</h3>
          </div>
          <div class="dialog-body">
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

  defp render_tab(%{active_tab: "services"} = assigns) do
    ~H"""
    <div class="section">
      <div class="section-head">
        <h2>Service Credentials</h2>
      </div>
      <div class="panel" style="padding: 1.5rem;">
        <form phx-submit="save_services">
          <h3 style="margin-top: 0;">Email</h3>
          <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 0.75rem;">
            <div class="form-group">
              <label class="form-label">Provider</label>
              <select name="services[email_provider]" class="form-select">
                <option value="">Not configured</option>
                <option value="postmark" selected={sv("email_provider") == "postmark"}>Postmark (Recommended)</option>
                <option value="resend" selected={sv("email_provider") == "resend"}>Resend</option>
                <option value="smtp" selected={sv("email_provider") == "smtp"}>SMTP</option>
              </select>
            </div>
            <div class="form-group">
              <label class="form-label">Postmark Server Token</label>
              <input type="password" name="services[postmark_api_key]" class="form-input"
                value={sv("postmark_api_key")} placeholder="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" autocomplete="off" />
            </div>
            <div class="form-group">
              <label class="form-label">Resend API Key</label>
              <input type="password" name="services[resend_api_key]" class="form-input"
                value={sv("resend_api_key")} placeholder="re_..." autocomplete="off" />
            </div>
            <div class="form-group">
            </div>
            <div class="form-group">
              <label class="form-label">From Name</label>
              <input type="text" name="services[mail_from_name]" class="form-input"
                value={sv("mail_from_name")} placeholder="Holdco" />
            </div>
            <div class="form-group">
              <label class="form-label">From Address</label>
              <input type="email" name="services[mail_from_address]" class="form-input"
                value={sv("mail_from_address")} placeholder="reports@yourdomain.com" />
            </div>
          </div>
          <p style="font-size: 0.8rem; color: #666; margin-bottom: 1rem;">
            Only fill in the API key for your chosen provider. SMTP fields are for advanced use (Gmail, etc).
          </p>

          <h3>Xero</h3>
          <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 0.75rem;">
            <div class="form-group">
              <label class="form-label">Client ID</label>
              <input type="text" name="services[xero_client_id]" class="form-input"
                value={sv("xero_client_id")} />
            </div>
            <div class="form-group">
              <label class="form-label">Client Secret</label>
              <input type="password" name="services[xero_client_secret]" class="form-input"
                value={sv("xero_client_secret")} autocomplete="off" />
            </div>
            <div class="form-group" style="grid-column: span 2;">
              <label class="form-label">Redirect URI</label>
              <input type="url" name="services[xero_redirect_uri]" class="form-input"
                value={sv("xero_redirect_uri")} placeholder="http://localhost:4000/auth/xero/callback" />
            </div>
          </div>

          <h3>QuickBooks</h3>
          <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 0.75rem;">
            <div class="form-group">
              <label class="form-label">Client ID</label>
              <input type="text" name="services[quickbooks_client_id]" class="form-input"
                value={sv("quickbooks_client_id")} />
            </div>
            <div class="form-group">
              <label class="form-label">Client Secret</label>
              <input type="password" name="services[quickbooks_client_secret]" class="form-input"
                value={sv("quickbooks_client_secret")} autocomplete="off" />
            </div>
            <div class="form-group">
              <label class="form-label">Redirect URI</label>
              <input type="url" name="services[quickbooks_redirect_uri]" class="form-input"
                value={sv("quickbooks_redirect_uri")} placeholder="http://localhost:4000/auth/quickbooks/callback" />
            </div>
            <div class="form-group">
              <label class="form-label">Environment</label>
              <select name="services[quickbooks_environment]" class="form-select">
                <option value="sandbox" selected={sv("quickbooks_environment") != "production"}>Sandbox</option>
                <option value="production" selected={sv("quickbooks_environment") == "production"}>Production</option>
              </select>
            </div>
          </div>

          <h3>S3 / R2 Backup Storage</h3>
          <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 0.75rem;">
            <div class="form-group">
              <label class="form-label">Bucket</label>
              <input type="text" name="services[s3_bucket]" class="form-input"
                value={sv("s3_bucket")} />
            </div>
            <div class="form-group">
              <label class="form-label">Endpoint</label>
              <input type="text" name="services[s3_endpoint]" class="form-input"
                value={sv("s3_endpoint")} placeholder="s3.amazonaws.com" />
            </div>
            <div class="form-group">
              <label class="form-label">Region</label>
              <input type="text" name="services[s3_region]" class="form-input"
                value={sv("s3_region")} placeholder="us-east-1" />
            </div>
            <div class="form-group">
              <label class="form-label">Access Key ID</label>
              <input type="text" name="services[s3_access_key_id]" class="form-input"
                value={sv("s3_access_key_id")} />
            </div>
            <div class="form-group" style="grid-column: span 2;">
              <label class="form-label">Secret Access Key</label>
              <input type="password" name="services[s3_secret_access_key]" class="form-input"
                value={sv("s3_secret_access_key")} autocomplete="off" />
            </div>
          </div>

          <%= if @can_admin do %>
            <div class="form-actions" style="margin-top: 1rem;">
              <button type="submit" class="btn btn-primary">Save All</button>
            </div>
          <% end %>
        </form>
        <p style="font-size: 0.8rem; color: #666; margin-top: 1rem;">
          Only fill in the services you use. Leave fields blank to skip.
        </p>
      </div>
    </div>
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
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>Add Category</h3>
          </div>
          <div class="dialog-body">
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
                <td>{format_webhook_events(w.events)}</td>
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
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>Add Webhook</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit="save_webhook">
              <div class="form-group">
                <label class="form-label">URL *</label>
                <input type="url" name="webhook[url]" class="form-input" required />
              </div>
              <div class="form-group">
                <label class="form-label">Subscribe to</label>
                <p style="font-size: 0.8rem; color: #666; margin-bottom: 0.5rem;">
                  Select which events trigger this webhook. Leave all unchecked for all events.
                </p>
                <div style="display: flex; flex-direction: column; gap: 0.4rem;">
                  <label style="display: flex; align-items: center; gap: 0.5rem; font-size: 0.9rem;">
                    <input type="checkbox" name="webhook_events[]" value="create" />
                    <span><strong>create</strong> -- New records created</span>
                  </label>
                  <label style="display: flex; align-items: center; gap: 0.5rem; font-size: 0.9rem;">
                    <input type="checkbox" name="webhook_events[]" value="update" />
                    <span><strong>update</strong> -- Records updated</span>
                  </label>
                  <label style="display: flex; align-items: center; gap: 0.5rem; font-size: 0.9rem;">
                    <input type="checkbox" name="webhook_events[]" value="delete" />
                    <span><strong>delete</strong> -- Records deleted</span>
                  </label>
                </div>
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
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>Add Backup Config</h3>
          </div>
          <div class="dialog-body">
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

  defp render_tab(%{active_tab: "ai"} = assigns) do
    ~H"""
    <div class="section">
      <div class="section-head">
        <h2>AI / LLM Configuration</h2>
      </div>
      <div class="panel" style="padding: 1.5rem;">
        <form phx-submit="save_ai">
          <div class="form-group">
            <label class="form-label">Provider *</label>
            <select name="ai[provider]" class="form-select">
              <option value="">Select provider...</option>
              <option value="anthropic" selected={@ai_provider == "anthropic"}>Anthropic (Claude)</option>
              <option value="openai" selected={@ai_provider == "openai"}>OpenAI (GPT)</option>
            </select>
          </div>
          <div class="form-group">
            <label class="form-label">API Key *</label>
            <input
              type="password"
              name="ai[api_key]"
              class="form-input"
              value={@ai_api_key}
              placeholder="sk-..."
              autocomplete="off"
            />
          </div>
          <div class="form-group">
            <label class="form-label">Model</label>
            <input
              type="text"
              name="ai[model]"
              class="form-input"
              value={@ai_model}
              placeholder="claude-sonnet-4-20250514 or gpt-4o"
            />
            <p style="font-size: 0.8rem; color: #666; margin-top: 0.25rem;">
              Leave blank for default. Anthropic: claude-sonnet-4-20250514, OpenAI: gpt-4o
            </p>
          </div>
          <div class="form-actions" style="gap: 0.5rem;">
            <%= if @can_admin do %>
              <button type="submit" class="btn btn-primary">Save</button>
              <button type="button" class="btn btn-secondary" phx-click="test_ai">
                Test Connection
              </button>
            <% end %>
          </div>
        </form>

        <%= case @ai_test_result do %>
          <% :ok -> %>
            <div style="margin-top: 1rem; padding: 0.75rem; background: #e8f5e9; border-radius: 4px; color: #2e7d32;">
              Connection successful! The AI provider is responding correctly.
            </div>
          <% {:error, reason} -> %>
            <div style="margin-top: 1rem; padding: 0.75rem; background: #ffebee; border-radius: 4px; color: #c62828;">
              Connection failed: {reason}
            </div>
          <% _ -> %>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_tab(%{active_tab: "notifications"} = assigns) do
    ~H"""
    <%!-- Stats bar --%>
    <div style="display: flex; gap: 2rem; margin-bottom: 1.5rem;">
      <div><strong>{@notification_stats.total}</strong> total deliveries</div>
      <div style="color: #2e7d32;"><strong>{@notification_stats.sent}</strong> sent</div>
      <div style="color: #c62828;"><strong>{@notification_stats.failed}</strong> failed</div>
      <div><strong>{length(@channels)}</strong> channels</div>
    </div>

    <%!-- Channels --%>
    <div class="section">
      <div class="section-head">
        <h2>Notification Channels</h2>
        <%= if @can_admin do %>
          <button class="btn btn-sm btn-primary" phx-click="show_form">Add Channel</button>
        <% end %>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr><th>Provider</th><th>Status</th><th>Events</th><th>Notes</th><th></th></tr>
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
                  {if ch.event_types == [], do: "All events", else: Enum.join(ch.event_types, ", ")}
                </td>
                <td>{ch.notes || ""}</td>
                <td style="white-space: nowrap;">
                  <%= if @can_admin do %>
                    <button phx-click="test_channel" phx-value-id={ch.id} class="btn btn-sm btn-secondary" title="Send test">Test</button>
                    <button phx-click="toggle_channel" phx-value-id={ch.id} class="btn btn-sm btn-secondary">
                      {if ch.is_active, do: "Disable", else: "Enable"}
                    </button>
                    <button phx-click="edit_channel" phx-value-id={ch.id} class="btn btn-sm btn-secondary">Edit</button>
                    <button phx-click="delete_channel" phx-value-id={ch.id} class="btn btn-danger btn-sm" data-confirm="Delete?">Del</button>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @channels == [] do %>
          <div class="empty-state">No channels configured. Add a channel to receive notifications via Slack, Telegram, or Email.</div>
        <% end %>
      </div>
    </div>

    <%!-- Recent Deliveries --%>
    <div class="section" style="margin-top: 1.5rem;">
      <div class="section-head">
        <h2>Recent Deliveries</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr><th>Provider</th><th>Status</th><th>Notification</th><th>Sent At</th><th>Attempts</th><th>Error</th></tr>
          </thead>
          <tbody>
            <%= for d <- @deliveries do %>
              <tr>
                <td>{provider_label(d.provider)}</td>
                <td style={notif_status_color(d.status)}><strong>{d.status}</strong></td>
                <td>{if d.notification, do: d.notification.title, else: "-"}</td>
                <td class="td-mono">{if d.sent_at, do: Calendar.strftime(d.sent_at, "%Y-%m-%d %H:%M"), else: "-"}</td>
                <td>{d.attempts}</td>
                <td style="max-width: 200px; overflow: hidden; text-overflow: ellipsis;">{d.error_message || "-"}</td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @deliveries == [] do %>
          <div class="empty-state">No delivery history yet.</div>
        <% end %>
      </div>
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
              <div class="form-group">
                <label class="form-label">Provider *</label>
                <select name="channel[provider]" class="form-select" phx-change="select_provider" required>
                  <option value="">Select provider...</option>
                  <%= for p <- @notification_providers do %>
                    <option value={p} selected={@selected_provider == p}>{provider_label(p)}</option>
                  <% end %>
                </select>
              </div>
              <%= if @selected_provider == "slack" do %>
                <div class="form-group">
                  <label class="form-label">Webhook URL *</label>
                  <input type="url" name="channel[webhook_url]" class="form-input"
                    placeholder="https://hooks.slack.com/services/..."
                    value={(@editing_channel && @editing_channel.config["webhook_url"]) || ""} required />
                </div>
              <% end %>
              <%= if @selected_provider == "telegram" do %>
                <div class="form-group">
                  <label class="form-label">Bot Token *</label>
                  <input type="text" name="channel[bot_token]" class="form-input"
                    placeholder="123456:ABC-DEF..."
                    value={(@editing_channel && @editing_channel.config["bot_token"]) || ""} required />
                </div>
                <div class="form-group">
                  <label class="form-label">Chat ID *</label>
                  <input type="text" name="channel[chat_id]" class="form-input"
                    placeholder="-1001234567890"
                    value={(@editing_channel && @editing_channel.config["chat_id"]) || ""} required />
                </div>
              <% end %>
              <%= if @selected_provider == "email" do %>
                <div class="form-group">
                  <label class="form-label">Email Address *</label>
                  <input type="email" name="channel[email]" class="form-input"
                    placeholder="user@example.com"
                    value={(@editing_channel && @editing_channel.config["email"]) || ""} required />
                </div>
              <% end %>
              <div class="form-group">
                <label class="form-label">Event Subscriptions</label>
                <p style="font-size: 0.8rem; color: #666; margin-bottom: 0.5rem;">
                  Select which events trigger this channel. Leave all unchecked for all events.
                </p>
                <div style="display: flex; flex-direction: column; gap: 0.4rem;">
                  <%= for evt <- @notification_event_types do %>
                    <label style="display: flex; align-items: center; gap: 0.5rem; font-size: 0.9rem;">
                      <input type="checkbox" name="event_types[]" value={evt}
                        checked={@editing_channel && evt in (@editing_channel.event_types || [])} />
                      <span><strong>{evt}</strong></span>
                    </label>
                  <% end %>
                </div>
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="channel[notes]" class="form-input">{(@editing_channel && @editing_channel.notes) || ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">{if @editing_channel, do: "Update", else: "Add Channel"}</button>
                <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp render_tab(%{active_tab: "reports"} = assigns) do
    ~H"""
    <div class="section">
      <div class="section-head">
        <h2>Scheduled Reports</h2>
        <span class="count">{length(@scheduled_reports)} configured</span>
        <%= if @can_admin do %>
          <button class="btn btn-sm btn-primary" phx-click="show_form">New Report</button>
        <% end %>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr><th>Name</th><th>Type</th><th>Frequency</th><th>Recipients</th><th>Format</th><th>Next Run</th><th>Active</th><th></th></tr>
          </thead>
          <tbody>
            <%= for r <- @scheduled_reports do %>
              <tr>
                <td class="td-name">{r.name}</td>
                <td><span class="tag tag-ink">{report_type_label(r.report_type)}</span></td>
                <td>{r.frequency}</td>
                <td class="td-mono" style="max-width: 200px; overflow: hidden; text-overflow: ellipsis;">{r.recipients}</td>
                <td>{r.format}</td>
                <td class="td-mono">{r.next_run_date || "Not set"}</td>
                <td>
                  <%= if @can_admin do %>
                    <button phx-click="toggle_report" phx-value-id={r.id}
                      class={"tag #{if r.is_active, do: "tag-jade", else: "tag-crimson"}"} style="cursor: pointer; border: none;">
                      {if r.is_active, do: "Active", else: "Paused"}
                    </button>
                  <% else %>
                    <span class={"tag #{if r.is_active, do: "tag-jade", else: "tag-crimson"}"}>{if r.is_active, do: "Active", else: "Paused"}</span>
                  <% end %>
                </td>
                <td style="white-space: nowrap;">
                  <%= if @can_admin do %>
                    <button phx-click="send_now" phx-value-id={r.id} class="btn btn-sm btn-secondary">Send Now</button>
                    <button phx-click="edit_report" phx-value-id={r.id} class="btn btn-sm btn-secondary">Edit</button>
                    <button phx-click="delete_report" phx-value-id={r.id} class="btn btn-danger btn-sm" data-confirm="Delete?">Del</button>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @scheduled_reports == [] do %>
          <div class="empty-state">No scheduled reports configured yet. Create one to automate report delivery.</div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @editing_report, do: "Edit Report", else: "New Scheduled Report"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit="save_report">
              <div class="form-group">
                <label class="form-label">Name *</label>
                <input type="text" name="report[name]" class="form-input"
                  value={if @editing_report, do: @editing_report.name} required />
              </div>
              <div class="form-group">
                <label class="form-label">Report Type *</label>
                <select name="report[report_type]" class="form-select" required>
                  <option value="">Select type...</option>
                  <%= for rt <- ScheduledReport.report_types() do %>
                    <option value={rt} selected={@editing_report && @editing_report.report_type == rt}>
                      {report_type_label(rt)}
                    </option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Frequency *</label>
                <select name="report[frequency]" class="form-select" required>
                  <%= for f <- ScheduledReport.frequencies() do %>
                    <option value={f} selected={@editing_report && @editing_report.frequency == f}>
                      {String.capitalize(f)}
                    </option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Recipients * (comma-separated)</label>
                <input type="text" name="report[recipients]" class="form-input"
                  value={if @editing_report, do: @editing_report.recipients}
                  placeholder="alice@example.com, bob@example.com" required />
              </div>
              <div class="form-group">
                <label class="form-label">Format</label>
                <select name="report[format]" class="form-select">
                  <%= for f <- ScheduledReport.formats() do %>
                    <option value={f} selected={@editing_report && @editing_report.format == f}>{String.upcase(f)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Company (optional)</label>
                <select name="report[company_id]" class="form-select">
                  <option value="">All companies</option>
                  <%= for c <- @report_companies do %>
                    <option value={c.id} selected={@editing_report && @editing_report.company_id == c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Next Run Date</label>
                <input type="date" name="report[next_run_date]" class="form-input"
                  value={if @editing_report, do: @editing_report.next_run_date, else: Date.to_iso8601(Date.utc_today())} />
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="report[notes]" class="form-input">{if @editing_report, do: @editing_report.notes}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">{if @editing_report, do: "Update", else: "Create"}</button>
                <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp sv(key), do: Platform.get_setting_value(key, "")

  defp build_channel_config(params) do
    for {key, val} <- [
          {"webhook_url", params["webhook_url"]},
          {"bot_token", params["bot_token"]},
          {"chat_id", params["chat_id"]},
          {"email", params["email"]}
        ],
        val && val != "",
        into: %{},
        do: {key, val}
  end

  defp provider_label("slack"), do: "Slack"
  defp provider_label("telegram"), do: "Telegram"
  defp provider_label("email"), do: "Email"
  defp provider_label("in_app"), do: "In-App"
  defp provider_label(other), do: other

  defp notif_status_color("sent"), do: "color: #2e7d32"
  defp notif_status_color("failed"), do: "color: #c62828"
  defp notif_status_color("pending"), do: "color: #e65100"
  defp notif_status_color(_), do: ""

  defp report_type_label("portfolio_summary"), do: "Portfolio Summary"
  defp report_type_label("financial_report"), do: "Financial Report"
  defp report_type_label("compliance_report"), do: "Compliance Report"
  defp report_type_label("board_pack"), do: "Board Pack"
  defp report_type_label(other), do: other

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map(fn {k, v} -> "#{k} #{Enum.join(v, ", ")}" end)
    |> Enum.join("; ")
  end
end
