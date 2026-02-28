defmodule HoldcoWeb.CorporateActionLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Corporate, Corporate.CorporateAction}

  @statuses CorporateAction.statuses()

  @impl true
  def mount(_params, _session, socket) do
    companies = Corporate.list_companies()

    {:ok,
     assign(socket,
       page_title: "Corporate Actions",
       companies: companies,
       selected_company_id: "",
       actions: [],
       pending: [],
       show_form: false,
       editing_item: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("filter_company", %{"company_id" => id}, socket) do
    if id == "" do
      {:noreply,
       assign(socket,
         selected_company_id: "",
         actions: [],
         pending: [],
         show_form: false,
         editing_item: nil
       )}
    else
      cid = String.to_integer(id)

      {:noreply,
       assign(socket,
         selected_company_id: id,
         actions: Corporate.list_corporate_actions(cid),
         pending: Corporate.pending_actions(cid),
         show_form: false,
         editing_item: nil
       )}
    end
  end

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: :add, editing_item: nil)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false, editing_item: nil)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    action = Corporate.get_corporate_action!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: action)}
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

  def handle_event("advance_status", %{"id" => id}, socket) do
    action = Corporate.get_corporate_action!(String.to_integer(id))
    next = next_status(action.status)

    case Corporate.update_corporate_action(action, %{status: next}) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Status advanced to #{next}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to advance status")}
    end
  end

  def handle_event("save", %{"corporate_action" => params}, socket) do
    case Corporate.create_corporate_action(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Corporate action added")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add corporate action")}
    end
  end

  def handle_event("update", %{"corporate_action" => params}, socket) do
    action = socket.assigns.editing_item

    case Corporate.update_corporate_action(action, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Corporate action updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update corporate action")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    action = Corporate.get_corporate_action!(String.to_integer(id))

    case Corporate.delete_corporate_action(action) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Corporate action deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete corporate action")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Corporate Actions</h1>
          <p class="deck">Track splits, mergers, spin-offs, and other corporate actions</p>
        </div>
        <div style="display: flex; gap: 0.5rem; align-items: center;">
          <form phx-change="filter_company" style="display: flex; align-items: center; gap: 0.5rem;">
            <label class="form-label" style="margin: 0; font-size: 0.85rem;">Company</label>
            <select name="company_id" class="form-select" style="width: auto; padding: 0.3rem 0.5rem;">
              <option value="">Select Company</option>
              <%= for c <- @companies do %>
                <option value={c.id} selected={to_string(c.id) == @selected_company_id}>{c.name}</option>
              <% end %>
            </select>
          </form>
          <%= if @can_write && @selected_company_id != "" do %>
            <button class="btn btn-primary" phx-click="show_form">Add Action</button>
          <% end %>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <%= if @selected_company_id != "" do %>
      <%= if @pending != [] do %>
        <div class="section">
          <div class="section-head">
            <h2>Status Pipeline</h2>
          </div>
          <div class="panel" style="padding: 1rem;">
            <div style="display: flex; gap: 1rem; flex-wrap: wrap;">
              <%= for status <- statuses() do %>
                <div style="flex: 1; min-width: 180px;">
                  <h4 style="margin-bottom: 0.5rem;"><span class={"tag #{action_status_tag(status)}"}>{humanize_status(status)}</span></h4>
                  <%= for action <- Enum.filter(@actions, &(&1.status == status)) do %>
                    <div style="padding: 0.5rem; margin-bottom: 0.5rem; border: 1px solid var(--border); border-radius: 4px;">
                      <strong>{humanize_action_type(action.action_type)}</strong>
                      <div style="font-size: 0.85rem; color: var(--text-muted);">{action.description || "No description"}</div>
                      <%= if @can_write && action.status not in ["completed", "cancelled"] do %>
                        <button phx-click="advance_status" phx-value-id={action.id} class="btn btn-sm" style="margin-top: 0.25rem;">Advance</button>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>

      <div class="section">
        <div class="section-head">
          <h2>All Corporate Actions</h2>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Type</th>
                <th>Description</th>
                <th>Announcement</th>
                <th>Record Date</th>
                <th>Effective</th>
                <th>Completion</th>
                <th>Ratio</th>
                <th class="th-num">Price/Share</th>
                <th class="th-num">Total Value</th>
                <th>Status</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <%= for action <- @actions do %>
                <tr>
                  <td>{humanize_action_type(action.action_type)}</td>
                  <td>{action.description || "-"}</td>
                  <td>{action.announcement_date || "-"}</td>
                  <td>{action.record_date || "-"}</td>
                  <td>{action.effective_date || "-"}</td>
                  <td>{action.completion_date || "-"}</td>
                  <td>{format_ratio(action)}</td>
                  <td class="td-num">{if action.price_per_share, do: Decimal.to_string(action.price_per_share), else: "-"}</td>
                  <td class="td-num">{if action.total_value, do: Decimal.to_string(action.total_value), else: "-"}</td>
                  <td><span class={"tag #{action_status_tag(action.status)}"}>{humanize_status(action.status)}</span></td>
                  <td style="text-align: right;">
                    <%= if @can_write do %>
                      <button phx-click="edit" phx-value-id={action.id} class="btn btn-sm">Edit</button>
                      <button phx-click="delete" phx-value-id={action.id} class="btn btn-sm btn-danger" data-confirm="Delete this action?">Delete</button>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
          <%= if @actions == [] do %>
            <p style="padding: 1rem; color: var(--text-muted);">No corporate actions recorded.</p>
          <% end %>
        </div>
      </div>
    <% else %>
      <div class="section">
        <div class="panel" style="padding: 2rem; text-align: center; color: var(--text-muted);">
          Select a company to view its corporate actions.
        </div>
      </div>
    <% end %>

    <%= if @show_form do %>
      <div class="modal-backdrop" phx-click="close_form">
        <div class="modal" phx-click="noop">
          <div class="modal-header">
            <h3>{if @show_form == :edit, do: "Edit Action", else: "Add Action"}</h3>
          </div>
          <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
            <div class="form-group">
              <label class="form-label">Company</label>
              <select name="corporate_action[company_id]" class="form-select" required>
                <option value="">Select company</option>
                <%= for c <- @companies do %>
                  <option value={c.id} selected={(@editing_item && @editing_item.company_id == c.id) || to_string(c.id) == @selected_company_id}>{c.name}</option>
                <% end %>
              </select>
            </div>
            <div class="form-group">
              <label class="form-label">Action Type</label>
              <select name="corporate_action[action_type]" class="form-select" required>
                <%= for t <- CorporateAction.action_types() do %>
                  <option value={t} selected={@editing_item && @editing_item.action_type == t}>{humanize_action_type(t)}</option>
                <% end %>
              </select>
            </div>
            <div class="form-group">
              <label class="form-label">Announcement Date</label>
              <input type="date" name="corporate_action[announcement_date]" class="form-input" value={if @editing_item, do: @editing_item.announcement_date, else: ""} />
            </div>
            <div class="form-group">
              <label class="form-label">Record Date</label>
              <input type="date" name="corporate_action[record_date]" class="form-input" value={if @editing_item, do: @editing_item.record_date, else: ""} />
            </div>
            <div class="form-group">
              <label class="form-label">Effective Date</label>
              <input type="date" name="corporate_action[effective_date]" class="form-input" value={if @editing_item, do: @editing_item.effective_date, else: ""} />
            </div>
            <div class="form-group">
              <label class="form-label">Completion Date</label>
              <input type="date" name="corporate_action[completion_date]" class="form-input" value={if @editing_item, do: @editing_item.completion_date, else: ""} />
            </div>
            <div class="form-group">
              <label class="form-label">Ratio (Numerator : Denominator)</label>
              <div style="display: flex; gap: 0.5rem;">
                <input type="number" name="corporate_action[ratio_numerator]" class="form-input" placeholder="e.g. 2" value={if @editing_item, do: @editing_item.ratio_numerator, else: ""} />
                <span style="align-self: center;">:</span>
                <input type="number" name="corporate_action[ratio_denominator]" class="form-input" placeholder="e.g. 1" value={if @editing_item, do: @editing_item.ratio_denominator, else: ""} />
              </div>
            </div>
            <div class="form-group">
              <label class="form-label">Price per Share</label>
              <input type="number" name="corporate_action[price_per_share]" class="form-input" step="any" value={if @editing_item && @editing_item.price_per_share, do: Decimal.to_string(@editing_item.price_per_share), else: ""} />
            </div>
            <div class="form-group">
              <label class="form-label">Total Value</label>
              <input type="number" name="corporate_action[total_value]" class="form-input" step="any" value={if @editing_item && @editing_item.total_value, do: Decimal.to_string(@editing_item.total_value), else: ""} />
            </div>
            <div class="form-group">
              <label class="form-label">Currency</label>
              <input type="text" name="corporate_action[currency]" class="form-input" value={if @editing_item, do: @editing_item.currency, else: "USD"} />
            </div>
            <div class="form-group">
              <label class="form-label">Status</label>
              <select name="corporate_action[status]" class="form-select">
                <%= for s <- CorporateAction.statuses() do %>
                  <option value={s} selected={@editing_item && @editing_item.status == s}>{humanize_status(s)}</option>
                <% end %>
              </select>
            </div>
            <div class="form-group">
              <label class="form-label">Description</label>
              <textarea name="corporate_action[description]" class="form-input">{if @editing_item, do: @editing_item.description, else: ""}</textarea>
            </div>
            <div class="form-group">
              <label class="form-label">Notes</label>
              <textarea name="corporate_action[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
            </div>
            <div class="form-actions">
              <button type="submit" class="btn btn-primary">{if @show_form == :edit, do: "Update Action", else: "Add Action"}</button>
              <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
            </div>
          </form>
        </div>
      </div>
    <% end %>
    """
  end

  defp reload(socket) do
    case socket.assigns.selected_company_id do
      "" ->
        assign(socket, actions: [], pending: [])

      id ->
        cid = String.to_integer(id)
        assign(socket,
          actions: Corporate.list_corporate_actions(cid),
          pending: Corporate.pending_actions(cid)
        )
    end
  end

  defp statuses, do: @statuses

  defp next_status("announced"), do: "approved"
  defp next_status("approved"), do: "in_progress"
  defp next_status("in_progress"), do: "completed"
  defp next_status(other), do: other

  defp humanize_action_type(type) do
    type
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp humanize_status(status) do
    status
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp format_ratio(%{ratio_numerator: n, ratio_denominator: d}) when is_integer(n) and is_integer(d) do
    "#{n}:#{d}"
  end

  defp format_ratio(_), do: "-"

  defp action_status_tag("announced"), do: "tag-lemon"
  defp action_status_tag("approved"), do: "tag-sky"
  defp action_status_tag("in_progress"), do: "tag-lemon"
  defp action_status_tag("completed"), do: "tag-jade"
  defp action_status_tag("cancelled"), do: "tag-rose"
  defp action_status_tag(_), do: ""
end
