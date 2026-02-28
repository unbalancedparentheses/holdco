defmodule HoldcoWeb.FamilyGovernanceLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.Governance
  alias Holdco.Governance.{FamilyCharter, FamilyMember}

  @impl true
  def mount(_params, _session, socket) do
    charters = Governance.list_family_charters()

    {:ok,
     assign(socket,
       page_title: "Family Governance",
       charters: charters,
       selected_charter: nil,
       members: [],
       members_by_gen: %{},
       voting_members: [],
       show_form: false,
       show_member_form: false,
       editing_item: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: :add, editing_item: nil)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false, show_member_form: false, editing_item: nil)}
  end

  def handle_event("edit_charter", %{"id" => id}, socket) do
    charter = Governance.get_family_charter!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: charter)}
  end

  def handle_event("view_charter", %{"id" => id}, socket) do
    charter_id = String.to_integer(id)
    charter = Governance.get_family_charter!(charter_id)
    members = Governance.list_family_members(charter_id)
    members_by_gen = Governance.members_by_generation(charter_id)
    voting = Governance.voting_members(charter_id)

    {:noreply,
     assign(socket,
       selected_charter: charter,
       members: members,
       members_by_gen: members_by_gen,
       voting_members: voting
     )}
  end

  def handle_event("back_to_list", _, socket) do
    {:noreply, assign(socket, selected_charter: nil, members: [], members_by_gen: %{}, voting_members: [])}
  end

  def handle_event("show_member_form", _, socket) do
    {:noreply, assign(socket, show_member_form: :add, editing_item: nil)}
  end

  def handle_event("edit_member", %{"id" => id}, socket) do
    member = Governance.get_family_member!(String.to_integer(id))
    {:noreply, assign(socket, show_member_form: :edit, editing_item: member)}
  end

  def handle_event("save", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("update", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("delete_member", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("save_member", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("update_member", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("save", %{"family_charter" => params}, socket) do
    case Governance.create_family_charter(params) do
      {:ok, _} ->
        {:noreply,
         reload_charters(socket)
         |> put_flash(:info, "Family charter created")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create family charter")}
    end
  end

  def handle_event("update", %{"family_charter" => params}, socket) do
    charter = socket.assigns.editing_item

    case Governance.update_family_charter(charter, params) do
      {:ok, _} ->
        {:noreply,
         reload_charters(socket)
         |> put_flash(:info, "Family charter updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update family charter")}
    end
  end

  def handle_event("save_member", %{"family_member" => params}, socket) do
    params = Map.put(params, "family_charter_id", socket.assigns.selected_charter.id)

    case Governance.create_family_member(params) do
      {:ok, _} ->
        {:noreply,
         reload_members(socket)
         |> put_flash(:info, "Family member added")
         |> assign(show_member_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add family member")}
    end
  end

  def handle_event("update_member", %{"family_member" => params}, socket) do
    member = socket.assigns.editing_item

    case Governance.update_family_member(member, params) do
      {:ok, _} ->
        {:noreply,
         reload_members(socket)
         |> put_flash(:info, "Family member updated")
         |> assign(show_member_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update family member")}
    end
  end

  def handle_event("delete_member", %{"id" => id}, socket) do
    member = Governance.get_family_member!(String.to_integer(id))

    case Governance.delete_family_member(member) do
      {:ok, _} ->
        {:noreply,
         reload_members(socket)
         |> put_flash(:info, "Family member removed")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to remove family member")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Family Governance</h1>
          <p class="deck">Family charters, members, and governance structures</p>
        </div>
        <%= if @can_write && !@selected_charter do %>
          <button class="btn btn-primary" phx-click="show_form">Add Charter</button>
        <% end %>
      </div>
      <hr class="page-title-rule" />
    </div>

    <%= if @selected_charter do %>
      <div style="margin-bottom: 1rem;">
        <button class="btn btn-secondary" phx-click="back_to_list">Back to Charters</button>
      </div>

      <div class="metrics-strip">
        <div class="metric-cell">
          <div class="metric-label">Charter</div>
          <div class="metric-value">{@selected_charter.family_name} v{@selected_charter.version}</div>
        </div>
        <div class="metric-cell">
          <div class="metric-label">Status</div>
          <div class="metric-value"><span class={"tag #{charter_status_tag(@selected_charter.status)}"}>{humanize(@selected_charter.status)}</span></div>
        </div>
        <div class="metric-cell">
          <div class="metric-label">Members</div>
          <div class="metric-value">{length(@members)}</div>
        </div>
        <div class="metric-cell">
          <div class="metric-label">Voting Members</div>
          <div class="metric-value">{length(@voting_members)}</div>
        </div>
      </div>

      <%= if @selected_charter.mission_statement do %>
        <div class="section">
          <div class="section-head"><h2>Mission Statement</h2></div>
          <div class="panel" style="padding: 1rem;">
            <p>{@selected_charter.mission_statement}</p>
          </div>
        </div>
      <% end %>

      <%= if @selected_charter.values != [] do %>
        <div class="section">
          <div class="section-head"><h2>Values</h2></div>
          <div class="panel" style="padding: 1rem;">
            <div style="display: flex; flex-wrap: wrap; gap: 0.5rem;">
              <%= for v <- @selected_charter.values do %>
                <span class="tag tag-sky">{v}</span>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>

      <div class="section">
        <div class="section-head">
          <h2>Family Members by Generation</h2>
          <%= if @can_write do %>
            <button class="btn btn-primary btn-sm" phx-click="show_member_form">Add Member</button>
          <% end %>
        </div>
        <div class="panel">
          <%= for {gen, gen_members} <- Enum.sort(@members_by_gen) do %>
            <h3 style="padding: 0.5rem 1rem; background: var(--bg-alt, #f5f5f5); margin: 0;">Generation {gen || "Unknown"}</h3>
            <table>
              <thead>
                <tr><th>Name</th><th>Relationship</th><th>Role</th><th>Voting</th><th>Board Eligible</th><th>Employment</th><th></th></tr>
              </thead>
              <tbody>
                <%= for m <- gen_members do %>
                  <tr>
                    <td class="td-name">{m.full_name}</td>
                    <td>{m.relationship}</td>
                    <td><span class="tag tag-sky">{humanize(m.role_in_family_office)}</span></td>
                    <td>{if m.voting_rights, do: "Yes", else: "No"}</td>
                    <td>{if m.board_eligible, do: "Yes", else: "No"}</td>
                    <td>{humanize(m.employment_status)}</td>
                    <td>
                      <%= if @can_write do %>
                        <div style="display: flex; gap: 0.25rem;">
                          <button phx-click="edit_member" phx-value-id={m.id} class="btn btn-secondary btn-sm">Edit</button>
                          <button phx-click="delete_member" phx-value-id={m.id} class="btn btn-danger btn-sm" data-confirm="Remove this member?">Del</button>
                        </div>
                      <% end %>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          <% end %>
          <%= if @members == [] do %>
            <div class="empty-state">
              <p>No family members added yet.</p>
              <%= if @can_write do %>
                <button class="btn btn-primary" phx-click="show_member_form">Add First Member</button>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>

      <%= if @show_member_form do %>
        <div class="dialog-overlay" phx-click="close_form">
          <div class="dialog-panel" phx-click="noop">
            <div class="dialog-header">
              <h3>{if @show_member_form == :edit, do: "Edit Family Member", else: "Add Family Member"}</h3>
            </div>
            <div class="dialog-body">
              <form phx-submit={if @show_member_form == :edit, do: "update_member", else: "save_member"}>
                <div class="form-group">
                  <label class="form-label">Full Name *</label>
                  <input type="text" name="family_member[full_name]" class="form-input" value={if @editing_item, do: @editing_item.full_name, else: ""} required />
                </div>
                <div class="form-group">
                  <label class="form-label">Relationship *</label>
                  <input type="text" name="family_member[relationship]" class="form-input" value={if @editing_item, do: @editing_item.relationship, else: ""} required />
                </div>
                <div class="form-group">
                  <label class="form-label">Generation</label>
                  <input type="number" name="family_member[generation]" class="form-input" value={if @editing_item, do: @editing_item.generation, else: ""} />
                </div>
                <div class="form-group">
                  <label class="form-label">Date of Birth</label>
                  <input type="date" name="family_member[date_of_birth]" class="form-input" value={if @editing_item, do: @editing_item.date_of_birth, else: ""} />
                </div>
                <div class="form-group">
                  <label class="form-label">Role</label>
                  <select name="family_member[role_in_family_office]" class="form-select">
                    <%= for r <- FamilyMember.roles() do %>
                      <option value={r} selected={@editing_item && @editing_item.role_in_family_office == r}>{humanize(r)}</option>
                    <% end %>
                  </select>
                </div>
                <div class="form-group">
                  <label class="form-label">Voting Rights</label>
                  <select name="family_member[voting_rights]" class="form-select">
                    <option value="false" selected={!@editing_item || !@editing_item.voting_rights}>No</option>
                    <option value="true" selected={@editing_item && @editing_item.voting_rights}>Yes</option>
                  </select>
                </div>
                <div class="form-group">
                  <label class="form-label">Board Eligible</label>
                  <select name="family_member[board_eligible]" class="form-select">
                    <option value="false" selected={!@editing_item || !@editing_item.board_eligible}>No</option>
                    <option value="true" selected={@editing_item && @editing_item.board_eligible}>Yes</option>
                  </select>
                </div>
                <div class="form-group">
                  <label class="form-label">Employment Status</label>
                  <select name="family_member[employment_status]" class="form-select">
                    <%= for s <- FamilyMember.employment_statuses() do %>
                      <option value={s} selected={@editing_item && @editing_item.employment_status == s}>{humanize(s)}</option>
                    <% end %>
                  </select>
                </div>
                <div class="form-group">
                  <label class="form-label">Branch</label>
                  <input type="text" name="family_member[branch]" class="form-input" value={if @editing_item, do: @editing_item.branch, else: ""} />
                </div>
                <div class="form-group">
                  <label class="form-label">Contact Email</label>
                  <input type="email" name="family_member[contact_email]" class="form-input" value={if @editing_item, do: @editing_item.contact_email, else: ""} />
                </div>
                <div class="form-group">
                  <label class="form-label">Notes</label>
                  <textarea name="family_member[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
                </div>
                <div class="form-actions">
                  <button type="submit" class="btn btn-primary">{if @show_member_form == :edit, do: "Update", else: "Add Member"}</button>
                  <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
                </div>
              </form>
            </div>
          </div>
        </div>
      <% end %>
    <% else %>
      <div class="metrics-strip">
        <div class="metric-cell">
          <div class="metric-label">Total Charters</div>
          <div class="metric-value">{length(@charters)}</div>
        </div>
        <div class="metric-cell">
          <div class="metric-label">Active</div>
          <div class="metric-value">{Enum.count(@charters, &(&1.status == "active"))}</div>
        </div>
        <div class="metric-cell">
          <div class="metric-label">Under Review</div>
          <div class="metric-value">{Enum.count(@charters, &(&1.status == "under_review"))}</div>
        </div>
      </div>

      <div class="section">
        <div class="section-head"><h2>Family Charters</h2></div>
        <div class="panel">
          <table>
            <thead>
              <tr><th>Family Name</th><th>Version</th><th>Status</th><th>Next Review</th><th></th></tr>
            </thead>
            <tbody>
              <%= for c <- @charters do %>
                <tr>
                  <td class="td-name">
                    <a href="#" phx-click="view_charter" phx-value-id={c.id} style="text-decoration: underline;">{c.family_name}</a>
                  </td>
                  <td>{c.version}</td>
                  <td><span class={"tag #{charter_status_tag(c.status)}"}>{humanize(c.status)}</span></td>
                  <td class="td-mono">{c.next_review_date || "---"}</td>
                  <td>
                    <%= if @can_write do %>
                      <button phx-click="edit_charter" phx-value-id={c.id} class="btn btn-secondary btn-sm">Edit</button>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
          <%= if @charters == [] do %>
            <div class="empty-state">
              <p>No family charters found.</p>
              <%= if @can_write do %>
                <button class="btn btn-primary" phx-click="show_form">Create Your First Charter</button>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    <% end %>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit Family Charter", else: "Create Family Charter"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Family Name *</label>
                <input type="text" name="family_charter[family_name]" class="form-input" value={if @editing_item, do: @editing_item.family_name, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Version *</label>
                <input type="text" name="family_charter[version]" class="form-input" value={if @editing_item, do: @editing_item.version, else: "1.0"} required />
              </div>
              <div class="form-group">
                <label class="form-label">Status</label>
                <select name="family_charter[status]" class="form-select">
                  <%= for s <- FamilyCharter.statuses() do %>
                    <option value={s} selected={@editing_item && @editing_item.status == s}>{humanize(s)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Mission Statement</label>
                <textarea name="family_charter[mission_statement]" class="form-input" rows="3">{if @editing_item, do: @editing_item.mission_statement, else: ""}</textarea>
              </div>
              <div class="form-group">
                <label class="form-label">Meeting Schedule</label>
                <input type="text" name="family_charter[meeting_schedule]" class="form-input" value={if @editing_item, do: @editing_item.meeting_schedule, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Next Review Date</label>
                <input type="date" name="family_charter[next_review_date]" class="form-input" value={if @editing_item, do: @editing_item.next_review_date, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="family_charter[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">{if @show_form == :edit, do: "Update", else: "Create Charter"}</button>
                <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp reload_charters(socket) do
    assign(socket, charters: Governance.list_family_charters())
  end

  defp reload_members(socket) do
    charter_id = socket.assigns.selected_charter.id
    members = Governance.list_family_members(charter_id)
    members_by_gen = Governance.members_by_generation(charter_id)
    voting = Governance.voting_members(charter_id)
    assign(socket, members: members, members_by_gen: members_by_gen, voting_members: voting)
  end

  defp humanize(str), do: str |> String.replace("_", " ") |> String.split(" ") |> Enum.map(&String.capitalize/1) |> Enum.join(" ")

  defp charter_status_tag("draft"), do: "tag-lemon"
  defp charter_status_tag("active"), do: "tag-jade"
  defp charter_status_tag("under_review"), do: "tag-sky"
  defp charter_status_tag("archived"), do: ""
  defp charter_status_tag(_), do: ""
end
