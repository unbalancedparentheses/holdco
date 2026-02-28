defmodule HoldcoWeb.BoardMeetingLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Governance, Corporate}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Governance.subscribe()

    companies = Corporate.list_companies()
    meetings = Governance.list_board_meetings()

    {:ok,
     assign(socket,
       page_title: "Board Meetings",
       companies: companies,
       meetings: meetings,
       selected_company_id: "",
       view_mode: "list",
       calendar_month: Date.utc_today(),
       show_form: false,
       editing_item: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("show_form", _, socket),
    do: {:noreply, assign(socket, show_form: :add, editing_item: nil)}

  def handle_event("close_form", _, socket),
    do: {:noreply, assign(socket, show_form: false, editing_item: nil)}

  def handle_event("edit", %{"id" => id}, socket) do
    meeting = Governance.get_board_meeting!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: meeting)}
  end

  def handle_event("switch_view", %{"mode" => mode}, socket) when mode in ~w(list calendar) do
    {:noreply, assign(socket, view_mode: mode)}
  end

  def handle_event("prev_month", _, socket) do
    current = socket.assigns.calendar_month
    prev = Date.add(current, -Date.days_in_month(current))
    {:noreply, assign(socket, calendar_month: Date.beginning_of_month(prev))}
  end

  def handle_event("next_month", _, socket) do
    current = socket.assigns.calendar_month
    next = Date.add(current, Date.days_in_month(current))
    {:noreply, assign(socket, calendar_month: Date.beginning_of_month(next))}
  end

  def handle_event("filter_company", %{"company_id" => id}, socket) do
    company_id = if id == "", do: nil, else: String.to_integer(id)
    meetings = Governance.list_board_meetings(company_id)
    {:noreply, assign(socket, selected_company_id: id, meetings: meetings)}
  end

  def handle_event("save", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("save", %{"board_meeting" => params}, socket) do
    case Governance.create_board_meeting(params) do
      {:ok, _} ->
        meetings = Governance.list_board_meetings()
        {:noreply,
         socket
         |> assign(meetings: meetings, show_form: false, editing_item: nil)
         |> put_flash(:info, "Board meeting created")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create board meeting")}
    end
  end

  def handle_event("update", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("update", %{"board_meeting" => params}, socket) do
    meeting = socket.assigns.editing_item

    case Governance.update_board_meeting(meeting, params) do
      {:ok, _} ->
        meetings = Governance.list_board_meetings()
        {:noreply,
         socket
         |> assign(meetings: meetings, show_form: false, editing_item: nil)
         |> put_flash(:info, "Board meeting updated")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update board meeting")}
    end
  end

  def handle_event("delete", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete", %{"id" => id}, socket) do
    meeting = Governance.get_board_meeting!(String.to_integer(id))
    Governance.delete_board_meeting(meeting)
    meetings = Governance.list_board_meetings()
    {:noreply, assign(socket, meetings: meetings) |> put_flash(:info, "Board meeting deleted")}
  end

  @impl true
  def handle_info({event, _record}, socket)
      when event in [
             :board_meetings_created,
             :board_meetings_updated,
             :board_meetings_deleted
           ] do
    meetings = Governance.list_board_meetings()
    {:noreply, assign(socket, meetings: meetings)}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  defp status_tag_class(status) do
    case status do
      "scheduled" -> "tag-info"
      "in_progress" -> "tag-warning"
      "completed" -> "tag-success"
      "cancelled" -> "tag-danger"
      _ -> "tag-ink"
    end
  end

  defp meetings_for_date(meetings, date) do
    Enum.filter(meetings, fn m -> m.meeting_date == date end)
  end

  defp calendar_weeks(month) do
    first = Date.beginning_of_month(month)
    last = Date.end_of_month(month)
    start_day = Date.day_of_week(first)
    pad_before = if start_day == 7, do: 0, else: start_day
    first_cal = Date.add(first, -pad_before)

    days = Date.range(first_cal, Date.add(last, 6 - rem(Date.day_of_week(last), 7)))
    Enum.chunk_every(Enum.to_list(days), 7)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Board Meetings</h1>
          <p class="deck">{length(@meetings)} meetings</p>
        </div>
        <div style="display: flex; gap: 0.5rem;">
          <button class="btn btn-secondary" phx-click="switch_view" phx-value-mode={if @view_mode == "list", do: "calendar", else: "list"}>
            {if @view_mode == "list", do: "Calendar View", else: "List View"}
          </button>
          <%= if @can_write do %>
            <button class="btn btn-primary" phx-click="show_form">New Meeting</button>
          <% end %>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div style="margin-bottom: 1rem;">
      <form phx-change="filter_company" style="display: flex; align-items: center; gap: 0.5rem;">
        <label class="form-label" style="margin: 0; font-size: 0.85rem;">Company</label>
        <select name="company_id" class="form-select" style="width: auto; padding: 0.3rem 0.5rem;">
          <option value="">All Companies</option>
          <%= for c <- @companies do %>
            <option value={c.id} selected={to_string(c.id) == @selected_company_id}>{c.name}</option>
          <% end %>
        </select>
      </form>
    </div>

    <%= if @view_mode == "calendar" do %>
      <div class="section">
        <div class="panel">
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem;">
            <button class="btn btn-secondary btn-sm" phx-click="prev_month">&larr; Prev</button>
            <h3>{Calendar.strftime(@calendar_month, "%B %Y")}</h3>
            <button class="btn btn-secondary btn-sm" phx-click="next_month">Next &rarr;</button>
          </div>
          <table style="width: 100%; table-layout: fixed;">
            <thead>
              <tr>
                <th>Sun</th><th>Mon</th><th>Tue</th><th>Wed</th><th>Thu</th><th>Fri</th><th>Sat</th>
              </tr>
            </thead>
            <tbody>
              <%= for week <- calendar_weeks(@calendar_month) do %>
                <tr>
                  <%= for day <- week do %>
                    <td style={"padding: 0.5rem; min-height: 4rem; vertical-align: top; #{if day.month != @calendar_month.month, do: "opacity: 0.4;", else: ""}"}>
                      <div style="font-size: 0.8rem; font-weight: 600;">{day.day}</div>
                      <%= for m <- meetings_for_date(@meetings, day) do %>
                        <div style="font-size: 0.75rem; padding: 0.15rem 0.3rem; margin-top: 0.15rem; background: var(--accent-bg); border-radius: 3px;">
                          {m.title || m.meeting_type}
                        </div>
                      <% end %>
                    </td>
                  <% end %>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    <% else %>
      <div class="section">
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Title</th>
                <th>Type</th>
                <th>Date</th>
                <th>Time</th>
                <th>Location</th>
                <th>Status</th>
                <th>Company</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <%= for m <- @meetings do %>
                <tr>
                  <td class="td-name">{m.title || "---"}</td>
                  <td><span class="tag tag-ink">{m.meeting_type}</span></td>
                  <td class="td-mono">{if m.meeting_date, do: Date.to_string(m.meeting_date), else: m.scheduled_date}</td>
                  <td class="td-mono">
                    <%= if m.start_time do %>
                      {Calendar.strftime(m.start_time, "%H:%M")}
                      <%= if m.end_time do %> - {Calendar.strftime(m.end_time, "%H:%M")}<% end %>
                    <% else %>
                      ---
                    <% end %>
                  </td>
                  <td>
                    {if m.is_virtual, do: "Virtual", else: m.location || "---"}
                  </td>
                  <td><span class={"tag #{status_tag_class(m.status)}"}>{m.status}</span></td>
                  <td>
                    <%= if m.company do %>
                      <.link navigate={~p"/companies/#{m.company.id}"} class="td-link">{m.company.name}</.link>
                    <% else %>
                      ---
                    <% end %>
                  </td>
                  <td>
                    <%= if @can_write do %>
                      <div style="display: flex; gap: 0.25rem;">
                        <button phx-click="edit" phx-value-id={m.id} class="btn btn-secondary btn-sm">Edit</button>
                        <button phx-click="delete" phx-value-id={m.id} class="btn btn-danger btn-sm" data-confirm="Delete?">Del</button>
                      </div>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
          <%= if @meetings == [] do %>
            <div class="empty-state">
              <p>No board meetings yet.</p>
            </div>
          <% end %>
        </div>
      </div>
    <% end %>

    <%= if @show_form == :add do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header"><h3>New Board Meeting</h3></div>
          <div class="dialog-body">
            <form phx-submit="save">
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="board_meeting[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Title</label>
                <input type="text" name="board_meeting[title]" class="form-input" />
              </div>
              <div class="form-group">
                <label class="form-label">Meeting Type</label>
                <select name="board_meeting[meeting_type]" class="form-select">
                  <option value="regular">Regular</option>
                  <option value="special">Special</option>
                  <option value="annual">Annual</option>
                  <option value="emergency">Emergency</option>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Meeting Date</label>
                <input type="date" name="board_meeting[meeting_date]" class="form-input" />
              </div>
              <div class="form-group">
                <label class="form-label">Start Time</label>
                <input type="time" name="board_meeting[start_time]" class="form-input" />
              </div>
              <div class="form-group">
                <label class="form-label">End Time</label>
                <input type="time" name="board_meeting[end_time]" class="form-input" />
              </div>
              <div class="form-group">
                <label class="form-label">Location</label>
                <input type="text" name="board_meeting[location]" class="form-input" />
              </div>
              <div class="form-group">
                <label class="form-label">
                  <input type="hidden" name="board_meeting[is_virtual]" value="false" />
                  <input type="checkbox" name="board_meeting[is_virtual]" value="true" /> Virtual Meeting
                </label>
              </div>
              <div class="form-group">
                <label class="form-label">Virtual Link</label>
                <input type="text" name="board_meeting[virtual_link]" class="form-input" />
              </div>
              <div class="form-group">
                <label class="form-label">Quorum Required</label>
                <input type="number" name="board_meeting[quorum_required]" class="form-input" min="0" />
              </div>
              <div class="form-group">
                <label class="form-label">Agenda</label>
                <textarea name="board_meeting[agenda]" class="form-input" rows="4"></textarea>
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="board_meeting[notes]" class="form-input" rows="2"></textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Create Meeting</button>
                <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>

    <%= if @show_form == :edit and @editing_item do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header"><h3>Edit Board Meeting</h3></div>
          <div class="dialog-body">
            <form phx-submit="update">
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="board_meeting[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={c.id == @editing_item.company_id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Title</label>
                <input type="text" name="board_meeting[title]" class="form-input" value={@editing_item.title} />
              </div>
              <div class="form-group">
                <label class="form-label">Meeting Type</label>
                <select name="board_meeting[meeting_type]" class="form-select">
                  <%= for t <- ~w(regular special annual emergency) do %>
                    <option value={t} selected={t == @editing_item.meeting_type}>{t}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Meeting Date</label>
                <input type="date" name="board_meeting[meeting_date]" class="form-input" value={@editing_item.meeting_date} />
              </div>
              <div class="form-group">
                <label class="form-label">Start Time</label>
                <input type="time" name="board_meeting[start_time]" class="form-input" value={@editing_item.start_time} />
              </div>
              <div class="form-group">
                <label class="form-label">End Time</label>
                <input type="time" name="board_meeting[end_time]" class="form-input" value={@editing_item.end_time} />
              </div>
              <div class="form-group">
                <label class="form-label">Location</label>
                <input type="text" name="board_meeting[location]" class="form-input" value={@editing_item.location} />
              </div>
              <div class="form-group">
                <label class="form-label">
                  <input type="hidden" name="board_meeting[is_virtual]" value="false" />
                  <input type="checkbox" name="board_meeting[is_virtual]" value="true" checked={@editing_item.is_virtual} /> Virtual Meeting
                </label>
              </div>
              <div class="form-group">
                <label class="form-label">Virtual Link</label>
                <input type="text" name="board_meeting[virtual_link]" class="form-input" value={@editing_item.virtual_link} />
              </div>
              <div class="form-group">
                <label class="form-label">Status</label>
                <select name="board_meeting[status]" class="form-select">
                  <%= for s <- ~w(scheduled in_progress completed cancelled) do %>
                    <option value={s} selected={s == @editing_item.status}>{s}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Quorum Required</label>
                <input type="number" name="board_meeting[quorum_required]" class="form-input" min="0" value={@editing_item.quorum_required} />
              </div>
              <div class="form-group">
                <label class="form-label">Attendees Count</label>
                <input type="number" name="board_meeting[attendees_count]" class="form-input" min="0" value={@editing_item.attendees_count} />
              </div>
              <div class="form-group">
                <label class="form-label">Agenda</label>
                <textarea name="board_meeting[agenda]" class="form-input" rows="4">{@editing_item.agenda}</textarea>
              </div>
              <div class="form-group">
                <label class="form-label">Minutes</label>
                <textarea name="board_meeting[minutes]" class="form-input" rows="4">{@editing_item.minutes}</textarea>
              </div>
              <div class="form-group">
                <label class="form-label">Resolutions</label>
                <textarea name="board_meeting[resolutions]" class="form-input" rows="3">{@editing_item.resolutions}</textarea>
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="board_meeting[notes]" class="form-input" rows="2">{@editing_item.notes}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Update Meeting</button>
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
