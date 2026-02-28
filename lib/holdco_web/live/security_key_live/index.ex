defmodule HoldcoWeb.SecurityKeyLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.Platform

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Platform.subscribe("platform")

    user_id = socket.assigns.current_scope.user.id

    {:ok,
     socket
     |> assign(
       page_title: "Security Keys",
       user_id: user_id,
       security_keys: Platform.list_security_keys(user_id),
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

  # --- Permission Guards ---
  def handle_event("save", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("save", %{"security_key" => params}, socket) do
    params = Map.merge(params, %{
      "user_id" => socket.assigns.user_id,
      "credential_id" => params["credential_id"] || "cred_#{System.unique_integer([:positive])}",
      "public_key" => params["public_key"] || "pk_#{System.unique_integer([:positive])}"
    })

    case Platform.register_security_key(params) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Security key registered successfully")
         |> assign(show_form: false, editing_item: nil)
         |> reload_data()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to register security key.")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    key = Platform.get_security_key!(String.to_integer(id))
    {:ok, _} = Platform.delete_security_key(key)

    {:noreply,
     socket
     |> put_flash(:info, "Security key deleted")
     |> reload_data()}
  end

  @impl true
  def handle_info({event, _record}, socket) when event in [
    :security_keys_created, :security_keys_updated, :security_keys_deleted
  ] do
    {:noreply, reload_data(socket)}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  defp reload_data(socket) do
    assign(socket, security_keys: Platform.list_security_keys(socket.assigns.user_id))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-header">
      <h1>Security Keys (FIDO2)</h1>
      <button phx-click="show_form" class="btn btn-primary">+ Register Key</button>
    </div>

    <div class="table-container">
      <table class="data-table">
        <thead>
          <tr>
            <th>Name</th>
            <th>Credential ID</th>
            <th>Sign Count</th>
            <th>Registered</th>
            <th>Last Used</th>
            <th>Active</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          <%= for key <- @security_keys do %>
            <tr>
              <td><%= key.name %></td>
              <td><code><%= String.slice(key.credential_id || "", 0..15) %>...</code></td>
              <td><%= key.sign_count %></td>
              <td><%= format_datetime(key.registered_at) %></td>
              <td><%= format_datetime(key.last_used_at) %></td>
              <td><span class={"tag #{if key.is_active, do: "tag-jade", else: "tag-crimson"}"}><%= if key.is_active, do: "Active", else: "Inactive" %></span></td>
              <td>
                <button phx-click="delete" phx-value-id={key.id} data-confirm="Remove this security key?" class="btn btn-xs btn-danger">Delete</button>
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
            <h2>Register Security Key</h2>
            <button phx-click="close_form" class="btn-close">&times;</button>
          </div>
          <form phx-submit="save">
            <div class="form-group">
              <label class="form-label">Key Name *</label>
              <input type="text" name="security_key[name]" class="form-input" required
                placeholder="e.g. YubiKey 5 NFC" />
            </div>
            <div class="form-group">
              <label class="form-label">Notes</label>
              <textarea name="security_key[notes]" class="form-input" rows="2"></textarea>
            </div>
            <div class="form-actions">
              <button type="submit" class="btn btn-primary">Register Key</button>
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
end
