defmodule HoldcoWeb.WhiteLabelLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.Platform

  @impl true
  def mount(_params, _session, socket) do
    config = Platform.get_white_label_config()

    {:ok,
     assign(socket,
       page_title: "White Label",
       config: config,
       show_form: false
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: true)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false)}
  end

  def handle_event("save", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("save", %{"white_label_config" => params}, socket) do
    case socket.assigns.config do
      nil ->
        case Platform.create_white_label_config(params) do
          {:ok, config} ->
            {:noreply,
             assign(socket, config: config, show_form: false)
             |> put_flash(:info, "White label config created")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to create config")}
        end

      config ->
        case Platform.update_white_label_config(config, params) do
          {:ok, config} ->
            {:noreply,
             assign(socket, config: config, show_form: false)
             |> put_flash(:info, "White label config updated")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to update config")}
        end
    end
  end

  def handle_event("reset", _, socket) do
    case Platform.reset_white_label_config() do
      {:ok, _} ->
        {:noreply, assign(socket, config: nil) |> put_flash(:info, "Config reset to defaults")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to reset config")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>White Label Configuration</h1>
          <p class="deck">Customize branding, colors, and appearance for your tenant</p>
        </div>
        <%= if @can_write do %>
          <div style="display: flex; gap: 0.5rem;">
            <button class="btn btn-primary" phx-click="show_form">{if @config, do: "Edit Theme", else: "Create Theme"}</button>
            <%= if @config do %>
              <button class="btn btn-danger" phx-click="reset" data-confirm="Reset all white-label config to defaults?">Reset</button>
            <% end %>
          </div>
        <% end %>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="section">
      <div class="section-head"><h2>Current Theme</h2></div>
      <div class="panel">
        <%= if @config do %>
          <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 2rem; padding: 1rem;">
            <div>
              <h3>Branding</h3>
              <table>
                <tr><td style="font-weight: 600;">Tenant Name</td><td>{@config.tenant_name}</td></tr>
                <tr><td style="font-weight: 600;">Logo URL</td><td>{@config.logo_url || "---"}</td></tr>
                <tr><td style="font-weight: 600;">Favicon URL</td><td>{@config.favicon_url || "---"}</td></tr>
                <tr><td style="font-weight: 600;">Font Family</td><td>{@config.font_family || "Default"}</td></tr>
                <tr><td style="font-weight: 600;">Custom Domain</td><td>{@config.custom_domain || "---"}</td></tr>
                <tr><td style="font-weight: 600;">Active</td><td>{if @config.is_active, do: "Yes", else: "No"}</td></tr>
              </table>
            </div>
            <div>
              <h3>Colors</h3>
              <div style="display: flex; gap: 1rem; margin-bottom: 1rem;">
                <%= if @config.primary_color do %>
                  <div style="text-align: center;">
                    <div style={"width: 60px; height: 60px; border-radius: 8px; background: #{@config.primary_color}; border: 1px solid #ccc;"}></div>
                    <small>Primary</small>
                  </div>
                <% end %>
                <%= if @config.secondary_color do %>
                  <div style="text-align: center;">
                    <div style={"width: 60px; height: 60px; border-radius: 8px; background: #{@config.secondary_color}; border: 1px solid #ccc;"}></div>
                    <small>Secondary</small>
                  </div>
                <% end %>
                <%= if @config.accent_color do %>
                  <div style="text-align: center;">
                    <div style={"width: 60px; height: 60px; border-radius: 8px; background: #{@config.accent_color}; border: 1px solid #ccc;"}></div>
                    <small>Accent</small>
                  </div>
                <% end %>
              </div>
              <h3>Login Page</h3>
              <table>
                <tr><td style="font-weight: 600;">Title</td><td>{@config.login_page_title || "---"}</td></tr>
                <tr><td style="font-weight: 600;">Subtitle</td><td>{@config.login_page_subtitle || "---"}</td></tr>
                <tr><td style="font-weight: 600;">Footer</td><td>{@config.footer_text || "---"}</td></tr>
                <tr><td style="font-weight: 600;">Powered By</td><td>{if @config.powered_by_visible, do: "Visible", else: "Hidden"}</td></tr>
              </table>
            </div>
          </div>
          <%= if @config.custom_css do %>
            <div style="padding: 1rem;">
              <h3>Custom CSS</h3>
              <pre style="background: var(--bg-secondary); padding: 1rem; border-radius: 6px; overflow-x: auto; font-size: 0.85rem;">{@config.custom_css}</pre>
            </div>
          <% end %>
        <% else %>
          <div class="empty-state">
            <p>No white-label configuration set. Using default theme.</p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_form">Create Theme</button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop" style="max-width: 700px;">
          <div class="dialog-header">
            <h3>{if @config, do: "Edit Theme", else: "Create Theme"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit="save">
              <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem;">
                <div class="form-group">
                  <label class="form-label">Tenant Name *</label>
                  <input type="text" name="white_label_config[tenant_name]" class="form-input" value={if @config, do: @config.tenant_name, else: ""} required />
                </div>
                <div class="form-group">
                  <label class="form-label">Custom Domain</label>
                  <input type="text" name="white_label_config[custom_domain]" class="form-input" value={if @config, do: @config.custom_domain, else: ""} />
                </div>
                <div class="form-group">
                  <label class="form-label">Logo URL</label>
                  <input type="text" name="white_label_config[logo_url]" class="form-input" value={if @config, do: @config.logo_url, else: ""} />
                </div>
                <div class="form-group">
                  <label class="form-label">Favicon URL</label>
                  <input type="text" name="white_label_config[favicon_url]" class="form-input" value={if @config, do: @config.favicon_url, else: ""} />
                </div>
                <div class="form-group">
                  <label class="form-label">Primary Color</label>
                  <input type="text" name="white_label_config[primary_color]" class="form-input" placeholder="#3B82F6" value={if @config, do: @config.primary_color, else: ""} />
                </div>
                <div class="form-group">
                  <label class="form-label">Secondary Color</label>
                  <input type="text" name="white_label_config[secondary_color]" class="form-input" placeholder="#10B981" value={if @config, do: @config.secondary_color, else: ""} />
                </div>
                <div class="form-group">
                  <label class="form-label">Accent Color</label>
                  <input type="text" name="white_label_config[accent_color]" class="form-input" placeholder="#F59E0B" value={if @config, do: @config.accent_color, else: ""} />
                </div>
                <div class="form-group">
                  <label class="form-label">Font Family</label>
                  <input type="text" name="white_label_config[font_family]" class="form-input" value={if @config, do: @config.font_family, else: ""} />
                </div>
                <div class="form-group">
                  <label class="form-label">Login Page Title</label>
                  <input type="text" name="white_label_config[login_page_title]" class="form-input" value={if @config, do: @config.login_page_title, else: ""} />
                </div>
                <div class="form-group">
                  <label class="form-label">Login Page Subtitle</label>
                  <input type="text" name="white_label_config[login_page_subtitle]" class="form-input" value={if @config, do: @config.login_page_subtitle, else: ""} />
                </div>
                <div class="form-group">
                  <label class="form-label">Footer Text</label>
                  <input type="text" name="white_label_config[footer_text]" class="form-input" value={if @config, do: @config.footer_text, else: ""} />
                </div>
                <div class="form-group">
                  <label class="form-label">Support Email</label>
                  <input type="email" name="white_label_config[support_email]" class="form-input" value={if @config, do: @config.support_email, else: ""} />
                </div>
                <div class="form-group">
                  <label class="form-label">Support URL</label>
                  <input type="text" name="white_label_config[support_url]" class="form-input" value={if @config, do: @config.support_url, else: ""} />
                </div>
              </div>
              <div class="form-group" style="margin-top: 1rem;">
                <label class="form-label">Custom CSS</label>
                <textarea name="white_label_config[custom_css]" class="form-input" rows="6" style="font-family: monospace;">{if @config, do: @config.custom_css, else: ""}</textarea>
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="white_label_config[notes]" class="form-input">{if @config, do: @config.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">{if @config, do: "Update Theme", else: "Create Theme"}</button>
                <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end
end
