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
       edit_project: nil
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
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
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
                    </div>
                  <% end %>
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
    """
  end
end
