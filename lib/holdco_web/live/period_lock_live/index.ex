defmodule HoldcoWeb.PeriodLockLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Finance, Corporate}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Finance.subscribe()

    companies = Corporate.list_companies()
    locks = Finance.list_period_locks()

    {:ok,
     assign(socket,
       page_title: "Period Locks",
       companies: companies,
       locks: locks,
       selected_company_id: "",
       show_form: false,
       show_unlock_form: false,
       unlock_target_id: nil,
       unlock_reason: ""
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("filter_company", %{"company_id" => id}, socket) do
    company_id = if id == "", do: nil, else: String.to_integer(id)
    locks = Finance.list_period_locks(company_id)
    {:noreply, assign(socket, selected_company_id: id, locks: locks)}
  end

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: true)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false)}
  end

  def handle_event("lock_period", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("lock_period", %{"lock" => params}, socket) do
    user_id = socket.assigns.current_scope.user.id

    case Finance.lock_period(
           params["company_id"],
           params["period_start"],
           params["period_end"],
           params["period_type"],
           user_id
         ) do
      {:ok, _lock} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Period locked successfully")
         |> assign(show_form: false)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to lock period")}
    end
  end

  def handle_event("show_unlock", %{"id" => id}, socket) do
    {:noreply,
     assign(socket,
       show_unlock_form: true,
       unlock_target_id: String.to_integer(id),
       unlock_reason: ""
     )}
  end

  def handle_event("close_unlock", _, socket) do
    {:noreply, assign(socket, show_unlock_form: false, unlock_target_id: nil, unlock_reason: "")}
  end

  def handle_event("unlock_period", _params, %{assigns: %{can_admin: false}} = socket) do
    {:noreply, put_flash(socket, :error, "Only administrators can unlock periods")}
  end

  def handle_event("unlock_period", %{"reason" => reason}, socket) do
    user_id = socket.assigns.current_scope.user.id

    case Finance.unlock_period(socket.assigns.unlock_target_id, user_id, reason) do
      {:ok, _lock} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Period unlocked")
         |> assign(show_unlock_form: false, unlock_target_id: nil, unlock_reason: "")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to unlock period")}
    end
  end

  def handle_event("delete", _params, %{assigns: %{can_admin: false}} = socket) do
    {:noreply, put_flash(socket, :error, "Only administrators can delete period locks")}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    lock = Finance.get_period_lock!(String.to_integer(id))

    case Finance.delete_period_lock(lock) do
      {:ok, _} ->
        {:noreply, reload(socket) |> put_flash(:info, "Period lock deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete period lock")}
    end
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, reload(socket)}

  defp reload(socket) do
    company_id =
      case socket.assigns.selected_company_id do
        "" -> nil
        id -> String.to_integer(id)
      end

    assign(socket, locks: Finance.list_period_locks(company_id))
  end

  defp status_tag("locked"), do: "tag-ruby"
  defp status_tag("unlocked"), do: "tag-jade"
  defp status_tag(_), do: "tag-ink"

  defp period_type_label("month"), do: "Month"
  defp period_type_label("quarter"), do: "Quarter"
  defp period_type_label("year"), do: "Year"
  defp period_type_label(other), do: other || "Unknown"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Period Locks</h1>
          <p class="deck">Lock accounting periods to prevent modifications to closed periods</p>
        </div>
        <div style="display: flex; gap: 0.5rem; align-items: center;">
          <form phx-change="filter_company" style="display: flex; align-items: center; gap: 0.5rem;">
            <label class="form-label" style="margin: 0; font-size: 0.85rem;">Company</label>
            <select name="company_id" class="form-select" style="width: auto; padding: 0.3rem 0.5rem;">
              <option value="">All Companies</option>
              <%= for c <- @companies do %>
                <option value={c.id} selected={to_string(c.id) == @selected_company_id}>{c.name}</option>
              <% end %>
            </select>
          </form>
          <%= if @can_write do %>
            <button class="btn btn-primary" phx-click="show_form">Lock Period</button>
          <% end %>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Locks</div>
        <div class="metric-value">{length(@locks)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Active Locks</div>
        <div class="metric-value">{Enum.count(@locks, &(&1.status == "locked"))}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Unlocked</div>
        <div class="metric-value">{Enum.count(@locks, &(&1.status == "unlocked"))}</div>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>All Period Locks</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Company</th>
              <th>Period Type</th>
              <th class="td-mono">Start</th>
              <th class="td-mono">End</th>
              <th>Status</th>
              <th>Locked At</th>
              <th>Notes</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for lock <- @locks do %>
              <tr>
                <td>
                  <%= if lock.company do %>
                    <.link navigate={~p"/companies/#{lock.company.id}"} class="td-link">{lock.company.name}</.link>
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td>{period_type_label(lock.period_type)}</td>
                <td class="td-mono">{lock.period_start}</td>
                <td class="td-mono">{lock.period_end}</td>
                <td>
                  <span class={"tag #{status_tag(lock.status)}"}>{lock.status}</span>
                </td>
                <td class="td-mono" style="font-size: 0.85rem;">
                  {if lock.locked_at, do: Calendar.strftime(lock.locked_at, "%Y-%m-%d %H:%M"), else: "---"}
                </td>
                <td style="font-size: 0.85rem;">
                  {lock.notes || ""}
                  <%= if lock.unlock_reason do %>
                    <span style="color: var(--color-muted);">(Unlock: {lock.unlock_reason})</span>
                  <% end %>
                </td>
                <td>
                  <div style="display: flex; gap: 0.25rem;">
                    <%= if lock.status == "locked" && @can_admin do %>
                      <button
                        phx-click="show_unlock"
                        phx-value-id={lock.id}
                        class="btn btn-secondary btn-sm"
                      >
                        Unlock
                      </button>
                    <% end %>
                    <%= if @can_admin do %>
                      <button
                        phx-click="delete"
                        phx-value-id={lock.id}
                        class="btn btn-danger btn-sm"
                        data-confirm="Delete this period lock?"
                      >
                        Del
                      </button>
                    <% end %>
                  </div>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @locks == [] do %>
          <div class="empty-state">
            <p>No period locks defined.</p>
            <p style="color: var(--muted); font-size: 0.9rem;">
              Lock accounting periods to prevent modifications to finalized months, quarters, or years.
            </p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_form">Lock Your First Period</button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>Lock Period</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit="lock_period">
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="lock[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Period Type *</label>
                <select name="lock[period_type]" class="form-select" required>
                  <option value="month">Month</option>
                  <option value="quarter">Quarter</option>
                  <option value="year">Year</option>
                </select>
              </div>
              <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 0.75rem;">
                <div class="form-group">
                  <label class="form-label">Period Start *</label>
                  <input type="date" name="lock[period_start]" class="form-input" required />
                </div>
                <div class="form-group">
                  <label class="form-label">Period End *</label>
                  <input type="date" name="lock[period_end]" class="form-input" required />
                </div>
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="lock[notes]" class="form-input"></textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Lock Period</button>
                <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>

    <%= if @show_unlock_form do %>
      <div class="dialog-overlay" phx-click="close_unlock">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>Unlock Period</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit="unlock_period">
              <div class="form-group">
                <label class="form-label">Reason for unlocking *</label>
                <textarea name="reason" class="form-input" required placeholder="Enter the reason for unlocking this period..."></textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Unlock Period</button>
                <button type="button" phx-click="close_unlock" class="btn btn-secondary">Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end
end
