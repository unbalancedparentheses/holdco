defmodule HoldcoWeb.RegulatoryChangesLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.Compliance
  alias Holdco.Compliance.RegulatoryChange

  @impl true
  def mount(_params, _session, socket) do
    changes = Compliance.list_regulatory_changes()

    jurisdictions =
      changes
      |> Enum.map(& &1.jurisdiction)
      |> Enum.uniq()
      |> Enum.sort()

    {:ok,
     assign(socket,
       page_title: "Regulatory Changes",
       changes: changes,
       all_changes: changes,
       jurisdictions: jurisdictions,
       filter_jurisdiction: nil,
       show_form: false,
       editing_item: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: :add, editing_item: nil)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false, editing_item: nil)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    change = Compliance.get_regulatory_change!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: change)}
  end

  def handle_event("filter_jurisdiction", %{"jurisdiction" => ""}, socket) do
    {:noreply, assign(socket, changes: socket.assigns.all_changes, filter_jurisdiction: nil)}
  end

  def handle_event("filter_jurisdiction", %{"jurisdiction" => j}, socket) do
    filtered = Enum.filter(socket.assigns.all_changes, &(&1.jurisdiction == j))
    {:noreply, assign(socket, changes: filtered, filter_jurisdiction: j)}
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

  def handle_event("save", %{"regulatory_change" => params}, socket) do
    case Compliance.create_regulatory_change(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Regulatory change created")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create regulatory change")}
    end
  end

  def handle_event("update", %{"regulatory_change" => params}, socket) do
    change = socket.assigns.editing_item

    case Compliance.update_regulatory_change(change, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Regulatory change updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update regulatory change")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    change = Compliance.get_regulatory_change!(String.to_integer(id))

    case Compliance.delete_regulatory_change(change) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Regulatory change deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete regulatory change")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Regulatory Changes</h1>
          <p class="deck">Monitor and track regulatory changes across jurisdictions</p>
        </div>
        <%= if @can_write do %>
          <button class="btn btn-primary" phx-click="show_form">Add Change</button>
        <% end %>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Changes</div>
        <div class="metric-value">{length(@all_changes)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">High/Critical Impact</div>
        <div class="metric-value">{Enum.count(@all_changes, &(&1.impact_assessment in ["high", "critical"]))}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Pending</div>
        <div class="metric-value">{Enum.count(@all_changes, &(&1.status in ["monitoring", "assessment"]))}</div>
      </div>
    </div>

    <div class="section">
      <div class="section-head" style="display: flex; justify-content: space-between; align-items: center;">
        <h2>All Regulatory Changes</h2>
        <form phx-change="filter_jurisdiction" style="display: flex; gap: 0.5rem;">
          <select name="jurisdiction" class="form-select" style="width: auto;">
            <option value="">All Jurisdictions</option>
            <%= for j <- @jurisdictions do %>
              <option value={j} selected={@filter_jurisdiction == j}>{j}</option>
            <% end %>
          </select>
        </form>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Title</th><th>Jurisdiction</th><th>Type</th><th>Impact</th>
              <th>Status</th><th>Effective Date</th><th></th>
            </tr>
          </thead>
          <tbody>
            <%= for c <- @changes do %>
              <tr>
                <td class="td-name">{c.title}</td>
                <td>{c.jurisdiction}</td>
                <td><span class="tag tag-sky">{humanize(c.change_type)}</span></td>
                <td><span class={"tag #{impact_tag(c.impact_assessment)}"}>{humanize(c.impact_assessment)}</span></td>
                <td><span class={"tag #{status_tag(c.status)}"}>{humanize(c.status)}</span></td>
                <td class="td-mono">{c.effective_date || "---"}</td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit" phx-value-id={c.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete" phx-value-id={c.id} class="btn btn-danger btn-sm" data-confirm="Delete this change?">Del</button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @changes == [] do %>
          <div class="empty-state">
            <p>No regulatory changes found.</p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_form">Add Your First Change</button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit Regulatory Change", else: "Add Regulatory Change"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Title *</label>
                <input type="text" name="regulatory_change[title]" class="form-input" value={if @editing_item, do: @editing_item.title, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Jurisdiction *</label>
                <input type="text" name="regulatory_change[jurisdiction]" class="form-input" value={if @editing_item, do: @editing_item.jurisdiction, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Regulatory Body</label>
                <input type="text" name="regulatory_change[regulatory_body]" class="form-input" value={if @editing_item, do: @editing_item.regulatory_body, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Change Type *</label>
                <select name="regulatory_change[change_type]" class="form-select" required>
                  <%= for t <- RegulatoryChange.change_types() do %>
                    <option value={t} selected={@editing_item && @editing_item.change_type == t}>{humanize(t)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Impact Assessment</label>
                <select name="regulatory_change[impact_assessment]" class="form-select">
                  <%= for i <- RegulatoryChange.impact_levels() do %>
                    <option value={i} selected={@editing_item && @editing_item.impact_assessment == i}>{humanize(i)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Status</label>
                <select name="regulatory_change[status]" class="form-select">
                  <%= for s <- RegulatoryChange.statuses() do %>
                    <option value={s} selected={@editing_item && @editing_item.status == s}>{humanize(s)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Effective Date</label>
                <input type="date" name="regulatory_change[effective_date]" class="form-input" value={if @editing_item, do: @editing_item.effective_date, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Description</label>
                <textarea name="regulatory_change[description]" class="form-input">{if @editing_item, do: @editing_item.description, else: ""}</textarea>
              </div>
              <div class="form-group">
                <label class="form-label">Source URL</label>
                <input type="url" name="regulatory_change[source_url]" class="form-input" value={if @editing_item, do: @editing_item.source_url, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="regulatory_change[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">{if @show_form == :edit, do: "Update", else: "Add"}</button>
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
    changes = Compliance.list_regulatory_changes()
    jurisdictions = changes |> Enum.map(& &1.jurisdiction) |> Enum.uniq() |> Enum.sort()
    assign(socket, changes: changes, all_changes: changes, jurisdictions: jurisdictions, filter_jurisdiction: nil)
  end

  defp humanize(str), do: str |> String.replace("_", " ") |> String.split(" ") |> Enum.map(&String.capitalize/1) |> Enum.join(" ")

  defp impact_tag("low"), do: "tag-jade"
  defp impact_tag("medium"), do: "tag-lemon"
  defp impact_tag("high"), do: "tag-orange"
  defp impact_tag("critical"), do: "tag-rose"
  defp impact_tag(_), do: ""

  defp status_tag("monitoring"), do: "tag-sky"
  defp status_tag("assessment"), do: "tag-lemon"
  defp status_tag("implementation"), do: "tag-orange"
  defp status_tag("completed"), do: "tag-jade"
  defp status_tag(_), do: ""
end
