defmodule HoldcoWeb.QuickActionsLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.Platform

  @impl true
  def mount(_params, _session, socket) do
    actions = Platform.list_quick_actions()

    {:ok,
     assign(socket,
       page_title: "Quick Actions",
       actions: actions,
       search_query: "",
       filtered_actions: actions,
       show_form: false,
       editing_item: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("search", %{"query" => query}, socket) do
    filtered =
      if query == "" do
        socket.assigns.actions
      else
        Platform.search_quick_actions(query)
      end

    {:noreply, assign(socket, search_query: query, filtered_actions: filtered)}
  end

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: :add, editing_item: nil)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false, editing_item: nil)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    action = Platform.get_quick_action!(String.to_integer(id))
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

  def handle_event("save", %{"quick_action" => params}, socket) do
    params = normalize_keywords(params)

    case Platform.create_quick_action(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Quick action created")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create quick action")}
    end
  end

  def handle_event("update", %{"quick_action" => params}, socket) do
    action = socket.assigns.editing_item
    params = normalize_keywords(params)

    case Platform.update_quick_action(action, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Quick action updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update quick action")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    action = Platform.get_quick_action!(String.to_integer(id))

    case Platform.delete_quick_action(action) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Quick action deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete quick action")}
    end
  end

  def handle_event("seed_defaults", _, socket) do
    Platform.seed_default_actions()

    {:noreply,
     reload(socket)
     |> put_flash(:info, "Default actions seeded")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Quick Actions</h1>
          <p class="deck">Command palette for power users - search pages, entities, and actions</p>
        </div>
        <div style="display: flex; gap: 0.5rem;">
          <%= if @can_write do %>
            <button class="btn btn-secondary" phx-click="seed_defaults">Seed Defaults</button>
            <button class="btn btn-primary" phx-click="show_form">Add Action</button>
          <% end %>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="section">
      <div class="section-head"><h2>Search</h2></div>
      <div class="panel" style="padding: 1rem;">
        <form phx-change="search">
          <input type="text" name="query" class="form-input" placeholder="Search actions..." value={@search_query} phx-debounce="200" style="width: 100%; font-size: 1.1rem;" />
        </form>
      </div>
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Actions</div>
        <div class="metric-value">{length(@actions)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Showing</div>
        <div class="metric-value">{length(@filtered_actions)}</div>
      </div>
    </div>

    <%= for {category, group_actions} <- group_by_category(@filtered_actions) do %>
      <div class="section">
        <div class="section-head"><h2>{humanize(category)}</h2></div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Name</th><th>Description</th><th>Type</th><th>Path</th><th>Keywords</th><th></th>
              </tr>
            </thead>
            <tbody>
              <%= for a <- group_actions do %>
                <tr>
                  <td class="td-name">{a.name}</td>
                  <td>{a.description || "---"}</td>
                  <td><span class={"tag #{type_tag(a.action_type)}"}>{humanize(a.action_type)}</span></td>
                  <td class="td-mono"><a href={a.target_path}>{a.target_path}</a></td>
                  <td>{Enum.join(a.search_keywords || [], ", ")}</td>
                  <td>
                    <%= if @can_write do %>
                      <div style="display: flex; gap: 0.25rem;">
                        <button phx-click="edit" phx-value-id={a.id} class="btn btn-secondary btn-sm">Edit</button>
                        <button phx-click="delete" phx-value-id={a.id} class="btn btn-danger btn-sm" data-confirm="Delete this action?">Del</button>
                      </div>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    <% end %>

    <%= if @filtered_actions == [] do %>
      <div class="section">
        <div class="panel">
          <div class="empty-state">
            <p>No quick actions found.</p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="seed_defaults">Seed Default Actions</button>
            <% end %>
          </div>
        </div>
      </div>
    <% end %>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit Quick Action", else: "Add Quick Action"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Name *</label>
                <input type="text" name="quick_action[name]" class="form-input" value={if @editing_item, do: @editing_item.name, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Description</label>
                <input type="text" name="quick_action[description]" class="form-input" value={if @editing_item, do: @editing_item.description, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Action Type *</label>
                <select name="quick_action[action_type]" class="form-select" required>
                  <%= for t <- ~w(navigate create search export) do %>
                    <option value={t} selected={@editing_item && @editing_item.action_type == t}>{humanize(t)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Target Path *</label>
                <input type="text" name="quick_action[target_path]" class="form-input" value={if @editing_item, do: @editing_item.target_path, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Category</label>
                <select name="quick_action[category]" class="form-select">
                  <option value="">Select category</option>
                  <%= for c <- ~w(portfolio fund corporate accounting tax risk reports settings) do %>
                    <option value={c} selected={@editing_item && @editing_item.category == c}>{humanize(c)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Keywords (comma-separated)</label>
                <input type="text" name="quick_action[search_keywords]" class="form-input" value={if @editing_item, do: Enum.join(@editing_item.search_keywords || [], ", "), else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Sort Order</label>
                <input type="number" name="quick_action[sort_order]" class="form-input" value={if @editing_item, do: @editing_item.sort_order, else: "0"} />
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">{if @show_form == :edit, do: "Update", else: "Add Action"}</button>
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
    actions = Platform.list_quick_actions()
    filtered =
      if socket.assigns.search_query == "" do
        actions
      else
        Platform.search_quick_actions(socket.assigns.search_query)
      end

    assign(socket, actions: actions, filtered_actions: filtered)
  end

  defp normalize_keywords(%{"search_keywords" => kw} = params) when is_binary(kw) do
    keywords = kw |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
    Map.put(params, "search_keywords", keywords)
  end

  defp normalize_keywords(params), do: params

  defp group_by_category(actions) do
    actions
    |> Enum.group_by(& &1.category || "other")
    |> Enum.sort_by(fn {cat, _} -> cat end)
  end

  defp humanize(str) when is_binary(str), do: str |> String.replace("_", " ") |> String.split(" ") |> Enum.map(&String.capitalize/1) |> Enum.join(" ")
  defp humanize(nil), do: "---"

  defp type_tag("navigate"), do: "tag-sky"
  defp type_tag("create"), do: "tag-jade"
  defp type_tag("search"), do: "tag-lemon"
  defp type_tag("export"), do: ""
  defp type_tag(_), do: ""
end
