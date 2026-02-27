defmodule HoldcoWeb.CalendarLive.Index do
  use HoldcoWeb, :live_view

  import Ecto.Query

  alias Holdco.Repo
  alias Holdco.Money

  @event_types ~w(all tax meeting liability insurance filing)

  @impl true
  def mount(_params, _session, socket) do
    deadlines =
      Repo.all(from td in Holdco.Compliance.TaxDeadline, preload: :company)

    meetings =
      Repo.all(from bm in Holdco.Governance.BoardMeeting, preload: :company)

    liabilities =
      Repo.all(from l in Holdco.Finance.Liability, preload: :company)

    insurance =
      Repo.all(from ip in Holdco.Compliance.InsurancePolicy, preload: :company)

    filings =
      Repo.all(from rf in Holdco.Compliance.RegulatoryFiling, preload: :company)

    today = Date.utc_today()
    month = Date.beginning_of_month(today)
    events = build_events(deadlines, meetings, liabilities, insurance, filings)

    {:ok,
     assign(socket,
       page_title: "Calendar",
       all_events: events,
       events: events,
       current_month: month,
       filter_type: "all"
     )}
  end

  @impl true
  def handle_event("prev_month", _, socket) do
    new_month = Date.add(socket.assigns.current_month, -1) |> Date.beginning_of_month()

    {:noreply,
     assign(socket,
       current_month: new_month,
       events: filter_events(socket.assigns.all_events, socket.assigns.filter_type)
     )}
  end

  def handle_event("next_month", _, socket) do
    days = Date.days_in_month(socket.assigns.current_month)
    new_month = Date.add(socket.assigns.current_month, days) |> Date.beginning_of_month()

    {:noreply,
     assign(socket,
       current_month: new_month,
       events: filter_events(socket.assigns.all_events, socket.assigns.filter_type)
     )}
  end

  def handle_event("filter_type", %{"type" => type}, socket) do
    {:noreply,
     assign(socket,
       filter_type: type,
       events: filter_events(socket.assigns.all_events, type)
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Calendar</h1>
          <p class="deck">
            Unified view of compliance deadlines, governance meetings, finance liabilities,
            insurance renewals, and regulatory filings
          </p>
        </div>
        <form phx-change="filter_type" style="display: flex; align-items: center; gap: 0.5rem;">
          <label class="form-label" style="margin: 0; font-size: 0.85rem;">Event Type</label>
          <select name="type" class="form-select" style="width: auto; padding: 0.3rem 0.5rem;">
            <%= for t <- event_types() do %>
              <option value={t} selected={t == @filter_type}>{type_label(t)}</option>
            <% end %>
          </select>
        </form>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Events</div>
        <div class="metric-value">{length(@all_events)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">This Month</div>
        <div class="metric-value">{count_month_events(@events, @current_month)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">
          <span class="tag tag-crimson">Tax</span>
        </div>
        <div class="metric-value">{count_type(@all_events, "tax")}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">
          <span class="tag tag-jade">Meetings</span>
        </div>
        <div class="metric-value">{count_type(@all_events, "meeting")}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">
          <span class="tag tag-lemon">Liabilities</span>
        </div>
        <div class="metric-value">{count_type(@all_events, "liability")}</div>
      </div>
    </div>

    <div class="section">
      <div class="section-head" style="display: flex; justify-content: space-between; align-items: center;">
        <h2>{format_month(@current_month)}</h2>
        <div style="display: flex; gap: 0.5rem;">
          <button class="btn btn-secondary" phx-click="prev_month">&larr; Prev</button>
          <button class="btn btn-secondary" phx-click="next_month">Next &rarr;</button>
        </div>
      </div>
      <div class="panel">
        <% month_events = events_for_month(@events, @current_month) %>
        <% grouped = group_by_week(month_events, @current_month) %>
        <%= if grouped == %{} do %>
          <div class="empty-state">No events this month.</div>
        <% else %>
          <%= for {week_num, week_events} <- Enum.sort(grouped) do %>
            <div style="margin-bottom: 1.5rem;">
              <div style="font-size: 0.8rem; color: #888; font-weight: 600; text-transform: uppercase; letter-spacing: 0.05em; padding: 0.5rem 1rem; border-bottom: 1px solid #eee;">
                Week {week_num}
              </div>
              <table>
                <thead>
                  <tr>
                    <th style="width: 100px;">Date</th>
                    <th style="width: 100px;">Type</th>
                    <th>Description</th>
                    <th>Company</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for event <- week_events do %>
                    <tr>
                      <td class="td-mono">{event.date}</td>
                      <td>
                        <span class={"tag #{event_tag(event.type)}"}>{event.type}</span>
                      </td>
                      <td class="td-name">{event.description}</td>
                      <td>
                        <%= if event.company_id do %>
                          <.link navigate={~p"/companies/#{event.company_id}"} class="td-link">
                            {event.company_name}
                          </.link>
                        <% else %>
                          ---
                        <% end %>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          <% end %>
        <% end %>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>All Upcoming Events</h2>
      </div>
      <div class="panel">
        <% upcoming = upcoming_events(@events) %>
        <%= if upcoming == [] do %>
          <div class="empty-state">No upcoming events found.</div>
        <% else %>
          <table>
            <thead>
              <tr>
                <th>Date</th>
                <th>Type</th>
                <th>Description</th>
                <th>Company</th>
              </tr>
            </thead>
            <tbody>
              <%= for event <- Enum.take(upcoming, 50) do %>
                <tr>
                  <td class="td-mono">{event.date}</td>
                  <td>
                    <span class={"tag #{event_tag(event.type)}"}>{event.type}</span>
                  </td>
                  <td class="td-name">{event.description}</td>
                  <td>
                    <%= if event.company_id do %>
                      <.link navigate={~p"/companies/#{event.company_id}"} class="td-link">
                        {event.company_name}
                      </.link>
                    <% else %>
                      ---
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        <% end %>
      </div>
    </div>
    """
  end

  # -- Helpers --

  defp event_types, do: @event_types

  defp type_label("all"), do: "All Events"
  defp type_label("tax"), do: "Tax Deadlines"
  defp type_label("meeting"), do: "Board Meetings"
  defp type_label("liability"), do: "Liabilities"
  defp type_label("insurance"), do: "Insurance"
  defp type_label("filing"), do: "Filings"

  defp event_tag("tax"), do: "tag-crimson"
  defp event_tag("meeting"), do: "tag-jade"
  defp event_tag("liability"), do: "tag-lemon"
  defp event_tag("insurance"), do: "tag-ink"
  defp event_tag("filing"), do: "tag-ink"
  defp event_tag(_), do: "tag-ink"

  defp build_events(deadlines, meetings, liabilities, insurance, filings) do
    tax_events =
      Enum.map(deadlines, fn td ->
        %{
          date: td.due_date,
          type: "tax",
          description: "#{td.jurisdiction} - #{td.description}",
          company_id: td.company_id,
          company_name: if(td.company, do: td.company.name, else: nil)
        }
      end)

    meeting_events =
      Enum.map(meetings, fn bm ->
        %{
          date: bm.scheduled_date,
          type: "meeting",
          description: "#{bm.meeting_type} board meeting",
          company_id: bm.company_id,
          company_name: if(bm.company, do: bm.company.name, else: nil)
        }
      end)

    liability_events =
      liabilities
      |> Enum.filter(&(&1.maturity_date != nil and &1.maturity_date != ""))
      |> Enum.map(fn l ->
        %{
          date: l.maturity_date,
          type: "liability",
          description: "#{l.liability_type} - #{l.creditor} (#{format_amount(l.principal, l.currency)})",
          company_id: l.company_id,
          company_name: if(l.company, do: l.company.name, else: nil)
        }
      end)

    insurance_events =
      insurance
      |> Enum.filter(&(&1.expiry_date != nil and &1.expiry_date != ""))
      |> Enum.map(fn ip ->
        %{
          date: ip.expiry_date,
          type: "insurance",
          description: "#{ip.policy_type} renewal - #{ip.provider}",
          company_id: ip.company_id,
          company_name: if(ip.company, do: ip.company.name, else: nil)
        }
      end)

    filing_events =
      Enum.map(filings, fn rf ->
        %{
          date: rf.due_date,
          type: "filing",
          description: "#{rf.jurisdiction} - #{rf.filing_type}",
          company_id: rf.company_id,
          company_name: if(rf.company, do: rf.company.name, else: nil)
        }
      end)

    (tax_events ++ meeting_events ++ liability_events ++ insurance_events ++ filing_events)
    |> Enum.filter(&(&1.date != nil and &1.date != ""))
    |> Enum.sort_by(& &1.date)
  end

  defp filter_events(events, "all"), do: events
  defp filter_events(events, type), do: Enum.filter(events, &(&1.type == type))

  defp events_for_month(events, month) do
    month_str = Calendar.strftime(month, "%Y-%m")

    Enum.filter(events, fn event ->
      String.starts_with?(event.date || "", month_str)
    end)
  end

  defp group_by_week(events, month) do
    Enum.group_by(events, fn event ->
      case Date.from_iso8601(event.date) do
        {:ok, date} ->
          day_of_month = date.day
          first_day_weekday = Date.day_of_week(month)
          div(day_of_month + first_day_weekday - 2, 7) + 1

        _ ->
          1
      end
    end)
  end

  defp upcoming_events(events) do
    today = Date.utc_today() |> Date.to_iso8601()
    Enum.filter(events, fn e -> (e.date || "") >= today end)
  end

  defp count_month_events(events, month) do
    events_for_month(events, month) |> length()
  end

  defp count_type(events, type) do
    Enum.count(events, &(&1.type == type))
  end

  defp format_month(date) do
    Calendar.strftime(date, "%B %Y")
  end

  defp format_amount(nil, _), do: "N/A"

  defp format_amount(amount, currency) do
    formatted =
      Money.abs(amount)
      |> Money.round(0)
      |> Decimal.to_string()
      |> String.reverse()
      |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
      |> String.reverse()

    "#{currency} #{formatted}"
  end
end
