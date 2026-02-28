defmodule HoldcoWeb.TasksLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Collaboration, Corporate, Accounts}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Collaboration.subscribe_tasks()

    tasks = Collaboration.list_tasks()
    companies = Corporate.list_companies()
    users = Accounts.list_users()

    {:ok,
     assign(socket,
       page_title: "Tasks",
       tasks: tasks,
       companies: companies,
       users: users,
       filter_status: "",
       filter_priority: "",
       filter_assignee_id: "",
       filter_company_id: "",
       sort_by: "due_date",
       show_form: false,
       editing_item: nil
     )}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("show_form", _, socket),
    do: {:noreply, assign(socket, show_form: true, editing_item: nil)}

  def handle_event("close_form", _, socket),
    do: {:noreply, assign(socket, show_form: false, editing_item: nil)}

  def handle_event("edit", %{"id" => id}, socket) do
    task = Collaboration.get_task!(String.to_integer(id))
    {:noreply, assign(socket, show_form: true, editing_item: task)}
  end

  def handle_event("filter", params, socket) do
    filters = %{
      status: params["status"] || "",
      priority: params["priority"] || "",
      assignee_id: params["assignee_id"] || "",
      company_id: params["company_id"] || ""
    }

    tasks = Collaboration.list_tasks(filters)
    sort_by = socket.assigns.sort_by
    tasks = sort_tasks(tasks, sort_by)

    {:noreply,
     assign(socket,
       tasks: tasks,
       filter_status: filters.status,
       filter_priority: filters.priority,
       filter_assignee_id: filters.assignee_id,
       filter_company_id: filters.company_id
     )}
  end

  def handle_event("sort", %{"field" => field}, socket) do
    tasks = sort_tasks(socket.assigns.tasks, field)
    {:noreply, assign(socket, tasks: tasks, sort_by: field)}
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

  def handle_event("mark_complete", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("save", %{"task" => params}, socket) do
    params = clean_params(params)

    case Collaboration.create_task(params) do
      {:ok, _task} ->
        {:noreply,
         socket
         |> reload_tasks()
         |> assign(show_form: false, editing_item: nil)
         |> put_flash(:info, "Task created")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create task")}
    end
  end

  def handle_event("update", %{"task" => params}, socket) do
    task = socket.assigns.editing_item
    params = clean_params(params)

    case Collaboration.update_task(task, params) do
      {:ok, _task} ->
        {:noreply,
         socket
         |> reload_tasks()
         |> assign(show_form: false, editing_item: nil)
         |> put_flash(:info, "Task updated")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update task")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    task = Collaboration.get_task!(String.to_integer(id))
    Collaboration.delete_task(task)

    {:noreply,
     socket
     |> reload_tasks()
     |> put_flash(:info, "Task deleted")}
  end

  def handle_event("mark_complete", %{"id" => id}, socket) do
    task = Collaboration.get_task!(String.to_integer(id))
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    case Collaboration.update_task(task, %{status: "completed", completed_at: now}) do
      {:ok, _task} ->
        {:noreply,
         socket
         |> reload_tasks()
         |> put_flash(:info, "Task completed")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to complete task")}
    end
  end

  @impl true
  def handle_info(_, socket) do
    {:noreply, reload_tasks(socket)}
  end

  defp reload_tasks(socket) do
    filters = %{
      status: socket.assigns.filter_status,
      priority: socket.assigns.filter_priority,
      assignee_id: socket.assigns.filter_assignee_id,
      company_id: socket.assigns.filter_company_id
    }

    tasks = Collaboration.list_tasks(filters)
    tasks = sort_tasks(tasks, socket.assigns.sort_by)
    assign(socket, tasks: tasks)
  end

  defp sort_tasks(tasks, "due_date") do
    Enum.sort_by(tasks, fn t -> t.due_date || "9999-99-99" end, :asc)
  end

  defp sort_tasks(tasks, "priority") do
    priority_order = %{"urgent" => 0, "high" => 1, "medium" => 2, "low" => 3}
    Enum.sort_by(tasks, fn t -> Map.get(priority_order, t.priority, 4) end, :asc)
  end

  defp sort_tasks(tasks, _), do: tasks

  defp clean_params(params) do
    params
    |> Enum.reject(fn {_k, v} -> v == "" end)
    |> Map.new()
  end

  defp priority_class("urgent"), do: "tag-crimson"
  defp priority_class("high"), do: "tag-lemon"
  defp priority_class("medium"), do: "tag-teal"
  defp priority_class("low"), do: "tag-ink"
  defp priority_class(_), do: "tag-ink"

  defp status_class("open"), do: "tag-teal"
  defp status_class("in_progress"), do: "tag-lemon"
  defp status_class("completed"), do: "tag-jade"
  defp status_class("cancelled"), do: "tag-ink"
  defp status_class(_), do: "tag-ink"

  defp overdue?(task) do
    task.status in ["open", "in_progress"] and
      task.due_date != nil and
      task.due_date != "" and
      task.due_date < Date.utc_today() |> Date.to_string()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Tasks</h1>
          <p class="deck">Track and manage work items across the holding structure</p>
        </div>
        <%= if @can_write do %>
          <button class="btn btn-primary" phx-click="show_form">New Task</button>
        <% end %>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Tasks</div>
        <div class="metric-value">{length(@tasks)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Open</div>
        <div class="metric-value">{Enum.count(@tasks, &(&1.status == "open"))}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">In Progress</div>
        <div class="metric-value">{Enum.count(@tasks, &(&1.status == "in_progress"))}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Overdue</div>
        <div class="metric-value">{Enum.count(@tasks, &overdue?/1)}</div>
      </div>
    </div>

    <div style="margin-bottom: 1rem;">
      <form phx-change="filter" style="display: flex; align-items: center; gap: 0.5rem; flex-wrap: wrap;">
        <select name="status" class="form-select" style="width: auto; padding: 0.3rem 0.5rem;">
          <option value="">All Statuses</option>
          <option value="open" selected={@filter_status == "open"}>Open</option>
          <option value="in_progress" selected={@filter_status == "in_progress"}>In Progress</option>
          <option value="completed" selected={@filter_status == "completed"}>Completed</option>
          <option value="cancelled" selected={@filter_status == "cancelled"}>Cancelled</option>
        </select>
        <select name="priority" class="form-select" style="width: auto; padding: 0.3rem 0.5rem;">
          <option value="">All Priorities</option>
          <option value="low" selected={@filter_priority == "low"}>Low</option>
          <option value="medium" selected={@filter_priority == "medium"}>Medium</option>
          <option value="high" selected={@filter_priority == "high"}>High</option>
          <option value="urgent" selected={@filter_priority == "urgent"}>Urgent</option>
        </select>
        <select name="assignee_id" class="form-select" style="width: auto; padding: 0.3rem 0.5rem;">
          <option value="">All Assignees</option>
          <%= for u <- @users do %>
            <option value={u.id} selected={to_string(u.id) == @filter_assignee_id}>{u.email}</option>
          <% end %>
        </select>
        <select name="company_id" class="form-select" style="width: auto; padding: 0.3rem 0.5rem;">
          <option value="">All Companies</option>
          <%= for c <- @companies do %>
            <option value={c.id} selected={to_string(c.id) == @filter_company_id}>{c.name}</option>
          <% end %>
        </select>
      </form>
    </div>

    <div style="margin-bottom: 0.5rem; display: flex; gap: 0.5rem;">
      <button phx-click="sort" phx-value-field="due_date" class={"btn btn-sm #{if @sort_by == "due_date", do: "btn-primary", else: "btn-secondary"}"}>
        Sort by Due Date
      </button>
      <button phx-click="sort" phx-value-field="priority" class={"btn btn-sm #{if @sort_by == "priority", do: "btn-primary", else: "btn-secondary"}"}>
        Sort by Priority
      </button>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>All Tasks</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Title</th>
              <th>Status</th>
              <th>Priority</th>
              <th>Assignee</th>
              <th>Company</th>
              <th>Due Date</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for task <- @tasks do %>
              <tr style={if overdue?(task), do: "background: #fff3f3;", else: ""}>
                <td class="td-name">
                  {task.title}
                  <%= if task.description do %>
                    <div style="color: var(--color-muted); font-size: 0.85rem; margin-top: 0.15rem;">
                      {String.slice(task.description, 0, 80)}<%= if String.length(task.description || "") > 80, do: "..." %>
                    </div>
                  <% end %>
                </td>
                <td>
                  <span class={"tag #{status_class(task.status)}"}>{task.status |> String.replace("_", " ")}</span>
                </td>
                <td>
                  <span class={"tag #{priority_class(task.priority)}"}>{task.priority}</span>
                </td>
                <td>{if task.assignee, do: task.assignee.email, else: "---"}</td>
                <td>{if task.company, do: task.company.name, else: "---"}</td>
                <td class="td-mono">
                  {task.due_date || "---"}
                  <%= if overdue?(task) do %>
                    <span style="color: #c00; font-size: 0.8rem; margin-left: 0.25rem;">OVERDUE</span>
                  <% end %>
                </td>
                <td>
                  <div style="display: flex; gap: 0.25rem;">
                    <%= if @can_write and task.status in ["open", "in_progress"] do %>
                      <button
                        phx-click="mark_complete"
                        phx-value-id={task.id}
                        class="btn btn-secondary btn-sm"
                      >
                        Complete
                      </button>
                    <% end %>
                    <%= if @can_write do %>
                      <button
                        phx-click="edit"
                        phx-value-id={task.id}
                        class="btn btn-secondary btn-sm"
                      >
                        Edit
                      </button>
                      <button
                        phx-click="delete"
                        phx-value-id={task.id}
                        class="btn btn-danger btn-sm"
                        data-confirm="Delete this task?"
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
        <%= if @tasks == [] do %>
          <div class="empty-state">
            <p>No tasks found.</p>
            <p style="color: var(--muted); font-size: 0.9rem;">
              Create tasks to track work items, follow-ups from meetings, and deadlines.
            </p>
            <%= if @can_write do %>
              <div style="margin-top: 0.75rem;">
                <button class="btn btn-primary btn-sm" phx-click="show_form">
                  Create your first task
                </button>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop" style="max-width: 600px;">
          <div class="dialog-header">
            <h3>{if @editing_item, do: "Edit Task", else: "New Task"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @editing_item, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Title *</label>
                <input
                  type="text"
                  name="task[title]"
                  class="form-input"
                  value={if @editing_item, do: @editing_item.title, else: ""}
                  required
                />
              </div>
              <div class="form-group">
                <label class="form-label">Description</label>
                <textarea
                  name="task[description]"
                  class="form-input"
                  rows="3"
                >{if @editing_item, do: @editing_item.description, else: ""}</textarea>
              </div>
              <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 0.75rem;">
                <div class="form-group">
                  <label class="form-label">Status</label>
                  <select name="task[status]" class="form-select">
                    <%= for s <- ~w(open in_progress completed cancelled) do %>
                      <option value={s} selected={@editing_item && @editing_item.status == s}>
                        {s |> String.replace("_", " ") |> String.capitalize()}
                      </option>
                    <% end %>
                  </select>
                </div>
                <div class="form-group">
                  <label class="form-label">Priority</label>
                  <select name="task[priority]" class="form-select">
                    <%= for p <- ~w(low medium high urgent) do %>
                      <option value={p} selected={@editing_item && @editing_item.priority == p}>
                        {p |> String.capitalize()}
                      </option>
                    <% end %>
                  </select>
                </div>
              </div>
              <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 0.75rem;">
                <div class="form-group">
                  <label class="form-label">Due Date</label>
                  <input
                    type="date"
                    name="task[due_date]"
                    class="form-input"
                    value={if @editing_item, do: @editing_item.due_date, else: ""}
                  />
                </div>
                <div class="form-group">
                  <label class="form-label">Created From</label>
                  <select name="task[created_from]" class="form-select">
                    <option value="">Select source...</option>
                    <%= for src <- ~w(meeting deadline audit manual) do %>
                      <option value={src} selected={@editing_item && @editing_item.created_from == src}>
                        {src |> String.capitalize()}
                      </option>
                    <% end %>
                  </select>
                </div>
              </div>
              <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 0.75rem;">
                <div class="form-group">
                  <label class="form-label">Assignee</label>
                  <select name="task[assignee_id]" class="form-select">
                    <option value="">Unassigned</option>
                    <%= for u <- @users do %>
                      <option value={u.id} selected={@editing_item && @editing_item.assignee_id == u.id}>
                        {u.email}
                      </option>
                    <% end %>
                  </select>
                </div>
                <div class="form-group">
                  <label class="form-label">Company</label>
                  <select name="task[company_id]" class="form-select">
                    <option value="">No company</option>
                    <%= for c <- @companies do %>
                      <option value={c.id} selected={@editing_item && @editing_item.company_id == c.id}>
                        {c.name}
                      </option>
                    <% end %>
                  </select>
                </div>
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea
                  name="task[notes]"
                  class="form-input"
                  rows="2"
                >{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">
                  {if @editing_item, do: "Update Task", else: "Create Task"}
                </button>
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
