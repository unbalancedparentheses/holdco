defmodule HoldcoWeb.ProjectLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Collaboration, Corporate}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket),
      do: Phoenix.PubSub.subscribe(Holdco.PubSub, "projects")

    projects = Collaboration.list_projects()
    contacts = Collaboration.list_contacts()
    companies = Corporate.list_companies()

    {:ok,
     assign(socket,
       page_title: "Projects",
       all_projects: projects,
       projects: projects,
       contacts: contacts,
       companies: companies,
       filter_status: nil,
       show_form: nil,
       edit_project: nil,
       selected_project: nil,
       milestones: nil,
       show_milestones: false,
       show_milestone_form: false,
       edit_milestone: nil
     )}
  end

  @impl true
  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("show_form", _, socket),
    do: {:noreply, assign(socket, show_form: "project", edit_project: nil)}

  def handle_event("close_form", _, socket),
    do: {:noreply, assign(socket, show_form: nil, edit_project: nil)}

  def handle_event("filter_status", %{"status" => status}, socket) do
    status = if status == "", do: nil, else: status
    projects = filter_projects(socket.assigns.all_projects, status)
    {:noreply, assign(socket, filter_status: status, projects: projects)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    project = Collaboration.get_project!(String.to_integer(id))
    {:noreply, assign(socket, show_form: "project", edit_project: project)}
  end

  # --- Permission Guards ---
  def handle_event("save", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("update", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("save", %{"project" => params}, socket) do
    case Collaboration.create_project(params) do
      {:ok, _} ->
        {:noreply,
         socket
         |> reload()
         |> assign(show_form: nil, edit_project: nil)
         |> put_flash(:info, "Project created")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create project")}
    end
  end

  def handle_event("update", %{"project" => params}, socket) do
    project = socket.assigns.edit_project

    case Collaboration.update_project(project, params) do
      {:ok, _} ->
        {:noreply,
         socket
         |> reload()
         |> assign(show_form: nil, edit_project: nil)
         |> put_flash(:info, "Project updated")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update project")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    project = Collaboration.get_project!(String.to_integer(id))
    Collaboration.delete_project(project)
    {:noreply, reload(socket) |> put_flash(:info, "Project deleted")}
  end

  # --- Milestone Events ---

  def handle_event("view_milestones", %{"id" => id}, socket) do
    project = Collaboration.get_project!(String.to_integer(id))
    milestones = Collaboration.list_milestones(project.id)

    {:noreply,
     assign(socket,
       selected_project: project,
       milestones: milestones,
       show_milestones: true,
       show_milestone_form: false,
       edit_milestone: nil
     )}
  end

  def handle_event("close_milestones", _, socket) do
    {:noreply,
     assign(socket,
       selected_project: nil,
       milestones: nil,
       show_milestones: false,
       show_milestone_form: false,
       edit_milestone: nil
     )}
  end

  def handle_event("add_milestone", _, socket) do
    {:noreply, assign(socket, show_milestone_form: true, edit_milestone: nil)}
  end

  def handle_event("close_milestone_form", _, socket) do
    {:noreply, assign(socket, show_milestone_form: false, edit_milestone: nil)}
  end

  def handle_event("edit_milestone", %{"id" => id}, socket) do
    milestone = Collaboration.get_milestone!(String.to_integer(id))
    {:noreply, assign(socket, show_milestone_form: true, edit_milestone: milestone)}
  end

  def handle_event("save_milestone", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("update_milestone", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete_milestone", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("toggle_milestone_status", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("save_milestone", %{"milestone" => params}, socket) do
    project = socket.assigns.selected_project
    params = Map.put(params, "project_id", project.id)

    case Collaboration.create_milestone(params) do
      {:ok, _} ->
        milestones = Collaboration.list_milestones(project.id)

        {:noreply,
         socket
         |> assign(milestones: milestones, show_milestone_form: false, edit_milestone: nil)
         |> put_flash(:info, "Milestone created")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create milestone")}
    end
  end

  def handle_event("update_milestone", %{"milestone" => params}, socket) do
    milestone = socket.assigns.edit_milestone
    project = socket.assigns.selected_project

    case Collaboration.update_milestone(milestone, params) do
      {:ok, _} ->
        milestones = Collaboration.list_milestones(project.id)

        {:noreply,
         socket
         |> assign(milestones: milestones, show_milestone_form: false, edit_milestone: nil)
         |> put_flash(:info, "Milestone updated")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update milestone")}
    end
  end

  def handle_event("toggle_milestone_status", %{"id" => id}, socket) do
    milestone = Collaboration.get_milestone!(String.to_integer(id))
    project = socket.assigns.selected_project

    next_status =
      case milestone.status do
        "pending" -> "in_progress"
        "in_progress" -> "completed"
        "completed" -> "pending"
        other -> other
      end

    case Collaboration.update_milestone(milestone, %{status: next_status}) do
      {:ok, _} ->
        milestones = Collaboration.list_milestones(project.id)
        {:noreply, assign(socket, milestones: milestones)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update milestone status")}
    end
  end

  def handle_event("delete_milestone", %{"id" => id}, socket) do
    milestone = Collaboration.get_milestone!(String.to_integer(id))
    project = socket.assigns.selected_project
    Collaboration.delete_milestone(milestone)
    milestones = Collaboration.list_milestones(project.id)
    {:noreply, assign(socket, milestones: milestones) |> put_flash(:info, "Milestone deleted")}
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, reload(socket)}

  defp reload(socket) do
    projects = Collaboration.list_projects()
    filtered = filter_projects(projects, socket.assigns.filter_status)

    assign(socket,
      all_projects: projects,
      projects: filtered,
      contacts: Collaboration.list_contacts(),
      companies: Corporate.list_companies()
    )
  end

  defp filter_projects(projects, nil), do: projects
  defp filter_projects(projects, ""), do: projects

  defp filter_projects(projects, status),
    do: Enum.filter(projects, &(&1.status == status))

  defp status_tag("planned"), do: "tag-lemon"
  defp status_tag("active"), do: "tag-jade"
  defp status_tag("on_hold"), do: "tag-amber"
  defp status_tag("completed"), do: "tag-sage"
  defp status_tag("cancelled"), do: "tag-crimson"
  defp status_tag(_), do: "tag-ink"

  defp humanize(nil), do: ""
  defp humanize(str), do: str |> String.replace("_", " ") |> String.capitalize()

  defp milestone_status_tag("completed"), do: "tag tag-jade"
  defp milestone_status_tag("in_progress"), do: "tag tag-lemon"
  defp milestone_status_tag("pending"), do: "tag tag-ink"
  defp milestone_status_tag("cancelled"), do: "tag tag-crimson"
  defp milestone_status_tag(_), do: "tag tag-ink"

  defp milestone_progress(milestones) when is_list(milestones) do
    total = length(milestones)
    if total == 0, do: 0, else: round(Enum.count(milestones, &(&1.status == "completed")) / total * 100)
  end

  defp milestone_progress(_), do: 0

  defp format_budget(nil), do: "---"

  defp format_budget(%Decimal{} = d) do
    d |> Decimal.to_float() |> format_budget_float()
  end

  defp format_budget(n) when is_float(n), do: format_budget_float(n)
  defp format_budget(n) when is_integer(n), do: format_budget_float(n / 1)
  defp format_budget(_), do: "---"

  defp format_budget_float(n) do
    :erlang.float_to_binary(n, decimals: 0) |> add_commas()
  end

  defp add_commas(str) do
    str |> String.reverse() |> String.replace(~r/(\d{3})(?=\d)/, "\\1,") |> String.reverse()
  end

  defp total_budget(projects) do
    projects
    |> Enum.reduce(Decimal.new(0), fn p, acc ->
      case p.budget do
        nil -> acc
        %Decimal{} = d -> Decimal.add(acc, d)
        _ -> acc
      end
    end)
    |> format_budget()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Projects</h1>
          <p class="deck">Track active and planned initiatives across the group</p>
        </div>
        <%= if @can_write do %>
          <button class="btn btn-primary" phx-click="show_form">Add Project</button>
        <% end %>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div style="display: flex; gap: 0.5rem; margin-bottom: 1rem; flex-wrap: wrap;">
      <button
        class={"btn btn-sm #{if @filter_status == nil, do: "btn-primary", else: "btn-secondary"}"}
        phx-click="filter_status"
        phx-value-status=""
      >
        All
      </button>
      <%= for status <- ~w(planned active on_hold completed cancelled) do %>
        <button
          class={"btn btn-sm #{if @filter_status == status, do: "btn-primary", else: "btn-secondary"}"}
          phx-click="filter_status"
          phx-value-status={status}
        >
          {humanize(status)}
        </button>
      <% end %>
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total</div>
        <div class="metric-value">{length(@all_projects)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Active</div>
        <div class="metric-value">{Enum.count(@all_projects, &(&1.status == "active"))}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Planned</div>
        <div class="metric-value">{Enum.count(@all_projects, &(&1.status == "planned"))}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Total Budget</div>
        <div class="metric-value">{total_budget(@all_projects)}</div>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Projects</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>Status</th>
              <th>Type</th>
              <th>Responsible</th>
              <th>Start Date</th>
              <th>Target Date</th>
              <th>Budget</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for project <- @projects do %>
              <tr>
                <td class="td-name">{project.name}</td>
                <td><span class={"tag #{status_tag(project.status)}"}>{humanize(project.status)}</span></td>
                <td>{humanize(project.project_type)}</td>
                <td>
                  <%= if project.contact do %>
                    {project.contact.name}
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td class="td-mono">{project.start_date}</td>
                <td class="td-mono">{project.target_date}</td>
                <td class="td-num">
                  <%= if project.budget do %>
                    {format_budget(project.budget)} {project.currency}
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td>
                  <div style="display: flex; gap: 0.25rem;">
                    <button
                      phx-click="view_milestones"
                      phx-value-id={project.id}
                      class="btn btn-secondary btn-sm"
                    >
                      Milestones
                    </button>
                    <%= if @can_write do %>
                      <button
                        phx-click="edit"
                        phx-value-id={project.id}
                        class="btn btn-secondary btn-sm"
                      >
                        Edit
                      </button>
                      <button
                        phx-click="delete"
                        phx-value-id={project.id}
                        class="btn btn-danger btn-sm"
                        data-confirm="Delete this project?"
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
        <%= if @projects == [] do %>
          <div class="empty-state">
            <p>No projects found.</p>
            <p style="color: var(--muted); font-size: 0.9rem;">
              Create projects to track M&A due diligence, restructurings, migrations, fundraises, and other initiatives.
            </p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_form">Add Your First Project</button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @edit_project, do: "Edit Project", else: "Add Project"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @edit_project, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Name *</label>
                <input
                  type="text"
                  name="project[name]"
                  class="form-input"
                  value={if @edit_project, do: @edit_project.name, else: ""}
                  required
                />
              </div>
              <div class="form-group">
                <label class="form-label">Status</label>
                <select name="project[status]" class="form-select">
                  <%= for s <- ~w(planned active on_hold completed cancelled) do %>
                    <option
                      value={s}
                      selected={@edit_project && @edit_project.status == s}
                    >
                      {humanize(s)}
                    </option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Project Type</label>
                <select name="project[project_type]" class="form-select">
                  <option value="">Select type</option>
                  <%= for t <- ~w(ma_due_diligence entity_restructuring system_migration fundraise compliance_project other) do %>
                    <option
                      value={t}
                      selected={@edit_project && @edit_project.project_type == t}
                    >
                      {humanize(t)}
                    </option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Description</label>
                <textarea
                  name="project[description]"
                  class="form-input"
                  rows="3"
                >{if @edit_project, do: @edit_project.description, else: ""}</textarea>
              </div>
              <div class="form-group">
                <label class="form-label">Start Date</label>
                <input
                  type="date"
                  name="project[start_date]"
                  class="form-input"
                  value={if @edit_project, do: @edit_project.start_date, else: ""}
                />
              </div>
              <div class="form-group">
                <label class="form-label">Target Date</label>
                <input
                  type="date"
                  name="project[target_date]"
                  class="form-input"
                  value={if @edit_project, do: @edit_project.target_date, else: ""}
                />
              </div>
              <div class="form-group">
                <label class="form-label">Budget</label>
                <input
                  type="number"
                  name="project[budget]"
                  class="form-input"
                  step="0.01"
                  value={if @edit_project, do: @edit_project.budget, else: ""}
                />
              </div>
              <div class="form-group">
                <label class="form-label">Currency</label>
                <input
                  type="text"
                  name="project[currency]"
                  class="form-input"
                  value={if @edit_project, do: @edit_project.currency, else: "USD"}
                  placeholder="USD"
                />
              </div>
              <div class="form-group">
                <label class="form-label">Responsible Contact</label>
                <select name="project[contact_id]" class="form-select">
                  <option value="">Select contact</option>
                  <%= for c <- @contacts do %>
                    <option
                      value={c.id}
                      selected={@edit_project && @edit_project.contact_id == c.id}
                    >
                      {c.name}
                    </option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea
                  name="project[notes]"
                  class="form-input"
                  rows="3"
                >{if @edit_project, do: @edit_project.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">
                  {if @edit_project, do: "Update Project", else: "Add Project"}
                </button>
                <button type="button" phx-click="close_form" class="btn btn-secondary">
                  Cancel
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>

    <%= if @show_milestones && @selected_project do %>
      <div class="dialog-overlay" phx-click="close_milestones">
        <div class="dialog-panel" style="max-width: 700px;" phx-click="noop">
          <div class="dialog-header">
            <h3>
              {@selected_project.name} &mdash; Milestones
              <span style="font-weight: normal; font-size: 0.9rem; color: var(--muted);">
                ({length(@milestones || [])})
              </span>
            </h3>
          </div>
          <div class="dialog-body">
            <%!-- Progress bar --%>
            <div style="margin-bottom: 1rem;">
              <div style="display: flex; justify-content: space-between; font-size: 0.85rem; margin-bottom: 0.25rem;">
                <span>Progress</span>
                <span>{milestone_progress(@milestones)}%</span>
              </div>
              <div style="background: var(--border); border-radius: 4px; height: 8px; overflow: hidden;">
                <div style={"background: var(--jade); height: 100%; width: #{milestone_progress(@milestones)}%; transition: width 0.3s;"}></div>
              </div>
              <div style="font-size: 0.8rem; color: var(--muted); margin-top: 0.25rem;">
                {Enum.count(@milestones || [], &(&1.status == "completed"))} of {length(@milestones || [])} completed
              </div>
            </div>

            <%!-- Milestone list --%>
            <%= if @milestones && @milestones != [] do %>
              <div style="display: flex; flex-direction: column; gap: 0.5rem;">
                <%= for milestone <- @milestones do %>
                  <div style="display: flex; align-items: center; gap: 0.75rem; padding: 0.5rem; border: 1px solid var(--border); border-radius: 6px;">
                    <div style="flex: 1;">
                      <div style="display: flex; align-items: center; gap: 0.5rem;">
                        <span style={"font-weight: 500; #{if milestone.status == "completed", do: "text-decoration: line-through; color: var(--muted);", else: ""}"}>{milestone.name}</span>
                        <span class={milestone_status_tag(milestone.status)}>{humanize(milestone.status)}</span>
                      </div>
                      <div style="font-size: 0.8rem; color: var(--muted); margin-top: 0.25rem;">
                        <%= if milestone.due_date && milestone.due_date != "" do %>
                          Due: {milestone.due_date}
                        <% end %>
                        <%= if milestone.notes && milestone.notes != "" do %>
                          <span style="margin-left: 0.5rem;">{milestone.notes}</span>
                        <% end %>
                      </div>
                    </div>
                    <%= if @can_write do %>
                      <div style="display: flex; gap: 0.25rem; flex-shrink: 0;">
                        <button
                          phx-click="toggle_milestone_status"
                          phx-value-id={milestone.id}
                          class="btn btn-secondary btn-sm"
                          title="Cycle status"
                        >
                          <%= case milestone.status do %>
                            <% "pending" -> %>
                              Start
                            <% "in_progress" -> %>
                              Done
                            <% "completed" -> %>
                              Reset
                            <% _ -> %>
                              Cycle
                          <% end %>
                        </button>
                        <button
                          phx-click="edit_milestone"
                          phx-value-id={milestone.id}
                          class="btn btn-secondary btn-sm"
                        >
                          Edit
                        </button>
                        <button
                          phx-click="delete_milestone"
                          phx-value-id={milestone.id}
                          class="btn btn-danger btn-sm"
                          data-confirm="Delete this milestone?"
                        >
                          Del
                        </button>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            <% else %>
              <div class="empty-state">
                <p>No milestones yet.</p>
                <p style="color: var(--muted); font-size: 0.9rem;">
                  Add milestones to track key deliverables and deadlines for this project.
                </p>
              </div>
            <% end %>

            <%!-- Add/Edit milestone form --%>
            <%= if @show_milestone_form && @can_write do %>
              <div style="margin-top: 1rem; padding: 1rem; border: 1px solid var(--border); border-radius: 6px; background: var(--surface);">
                <h4 style="margin-bottom: 0.75rem;">{if @edit_milestone, do: "Edit Milestone", else: "Add Milestone"}</h4>
                <form phx-submit={if @edit_milestone, do: "update_milestone", else: "save_milestone"}>
                  <div class="form-group">
                    <label class="form-label">Name *</label>
                    <input
                      type="text"
                      name="milestone[name]"
                      class="form-input"
                      value={if @edit_milestone, do: @edit_milestone.name, else: ""}
                      required
                    />
                  </div>
                  <div class="form-group">
                    <label class="form-label">Due Date</label>
                    <input
                      type="date"
                      name="milestone[due_date]"
                      class="form-input"
                      value={if @edit_milestone, do: @edit_milestone.due_date, else: ""}
                    />
                  </div>
                  <div class="form-group">
                    <label class="form-label">Status</label>
                    <select name="milestone[status]" class="form-select">
                      <%= for s <- ~w(pending in_progress completed cancelled) do %>
                        <option
                          value={s}
                          selected={@edit_milestone && @edit_milestone.status == s}
                        >
                          {humanize(s)}
                        </option>
                      <% end %>
                    </select>
                  </div>
                  <div class="form-group">
                    <label class="form-label">Notes</label>
                    <textarea
                      name="milestone[notes]"
                      class="form-input"
                      rows="2"
                    >{if @edit_milestone, do: @edit_milestone.notes, else: ""}</textarea>
                  </div>
                  <div class="form-actions">
                    <button type="submit" class="btn btn-primary">
                      {if @edit_milestone, do: "Update Milestone", else: "Add Milestone"}
                    </button>
                    <button type="button" phx-click="close_milestone_form" class="btn btn-secondary">
                      Cancel
                    </button>
                  </div>
                </form>
              </div>
            <% end %>

            <%= if @can_write && !@show_milestone_form do %>
              <div style="margin-top: 1rem;">
                <button class="btn btn-primary btn-sm" phx-click="add_milestone">Add Milestone</button>
              </div>
            <% end %>

            <div style="margin-top: 1rem; text-align: right;">
              <button class="btn btn-secondary" phx-click="close_milestones">Close</button>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    """
  end
end
