defmodule HoldcoWeb.GovernanceLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Governance, Corporate}

  @tabs ~w(meetings cap_table resolutions deals equity_plans joint_ventures powers_of_attorney)

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Governance.subscribe()

    companies = Corporate.list_companies()
    meetings = Governance.list_board_meetings()
    cap_table = Governance.list_cap_table_entries()
    resolutions = Governance.list_shareholder_resolutions()
    deals = Governance.list_deals()
    equity_plans = Governance.list_equity_incentive_plans()
    joint_ventures = Governance.list_joint_ventures()
    powers = Governance.list_powers_of_attorney()

    {:ok,
     assign(socket,
       page_title: "Governance",
       tabs: @tabs,
       companies: companies,
       meetings: meetings,
       cap_table: cap_table,
       resolutions: resolutions,
       deals: deals,
       equity_plans: equity_plans,
       joint_ventures: joint_ventures,
       powers: powers,
       active_tab: "meetings",
       show_form: false,
       editing_item: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("switch_tab", %{"tab" => tab}, socket) when tab in @tabs do
    {:noreply, assign(socket, active_tab: tab, show_form: false, editing_item: nil)}
  end

  def handle_event("show_form", _, socket),
    do: {:noreply, assign(socket, show_form: :add, editing_item: nil)}

  def handle_event("close_form", _, socket),
    do: {:noreply, assign(socket, show_form: false, editing_item: nil)}

  # --- Permission Guards ---
  def handle_event("save_meeting", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete_meeting", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("update_meeting", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("save_cap_table", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete_cap_table", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("update_cap_table", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("save_resolution", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete_resolution", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("update_resolution", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("save_deal", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete_deal", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("update_deal", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("save_equity_plan", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete_equity_plan", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("update_equity_plan", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("save_jv", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete_jv", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("update_jv", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("save_poa", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("delete_poa", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  def handle_event("update_poa", _params, %{assigns: %{can_write: false}} = socket),
    do: {:noreply, put_flash(socket, :error, "You don't have permission to do that")}

  # --- Meetings ---
  def handle_event("save_meeting", %{"board_meeting" => params}, socket) do
    case Governance.create_board_meeting(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket) |> put_flash(:info, "Meeting added") |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add meeting")}
    end
  end

  def handle_event("edit_meeting", %{"id" => id}, socket) do
    item = Governance.get_board_meeting!(id)
    {:noreply, assign(socket, show_form: :edit, editing_item: item)}
  end

  def handle_event("update_meeting", %{"board_meeting" => params}, socket) do
    item = socket.assigns.editing_item

    case Governance.update_board_meeting(item, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket) |> put_flash(:info, "Meeting updated") |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update meeting")}
    end
  end

  def handle_event("delete_meeting", %{"id" => id}, socket) do
    bm = Governance.get_board_meeting!(id)
    Governance.delete_board_meeting(bm)
    {:noreply, reload(socket) |> put_flash(:info, "Meeting deleted")}
  end

  # --- Cap Table ---
  def handle_event("save_cap_table", %{"cap_table_entry" => params}, socket) do
    case Governance.create_cap_table_entry(params) do
      {:ok, _} ->
        {:noreply, reload(socket) |> put_flash(:info, "Entry added") |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add entry")}
    end
  end

  def handle_event("edit_cap_table", %{"id" => id}, socket) do
    item = Governance.get_cap_table_entry!(id)
    {:noreply, assign(socket, show_form: :edit, editing_item: item)}
  end

  def handle_event("update_cap_table", %{"cap_table_entry" => params}, socket) do
    item = socket.assigns.editing_item

    case Governance.update_cap_table_entry(item, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket) |> put_flash(:info, "Entry updated") |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update entry")}
    end
  end

  def handle_event("delete_cap_table", %{"id" => id}, socket) do
    ct = Governance.get_cap_table_entry!(id)
    Governance.delete_cap_table_entry(ct)
    {:noreply, reload(socket) |> put_flash(:info, "Entry deleted")}
  end

  # --- Resolutions ---
  def handle_event("save_resolution", %{"resolution" => params}, socket) do
    case Governance.create_shareholder_resolution(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket) |> put_flash(:info, "Resolution added") |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add resolution")}
    end
  end

  def handle_event("edit_resolution", %{"id" => id}, socket) do
    item = Governance.get_shareholder_resolution!(id)
    {:noreply, assign(socket, show_form: :edit, editing_item: item)}
  end

  def handle_event("update_resolution", %{"resolution" => params}, socket) do
    item = socket.assigns.editing_item

    case Governance.update_shareholder_resolution(item, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket) |> put_flash(:info, "Resolution updated") |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update resolution")}
    end
  end

  def handle_event("delete_resolution", %{"id" => id}, socket) do
    sr = Governance.get_shareholder_resolution!(id)
    Governance.delete_shareholder_resolution(sr)
    {:noreply, reload(socket) |> put_flash(:info, "Resolution deleted")}
  end

  # --- Deals ---
  def handle_event("save_deal", %{"deal" => params}, socket) do
    case Governance.create_deal(params) do
      {:ok, _} ->
        {:noreply, reload(socket) |> put_flash(:info, "Deal added") |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add deal")}
    end
  end

  def handle_event("edit_deal", %{"id" => id}, socket) do
    item = Governance.get_deal!(id)
    {:noreply, assign(socket, show_form: :edit, editing_item: item)}
  end

  def handle_event("update_deal", %{"deal" => params}, socket) do
    item = socket.assigns.editing_item

    case Governance.update_deal(item, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket) |> put_flash(:info, "Deal updated") |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update deal")}
    end
  end

  def handle_event("delete_deal", %{"id" => id}, socket) do
    d = Governance.get_deal!(id)
    Governance.delete_deal(d)
    {:noreply, reload(socket) |> put_flash(:info, "Deal deleted")}
  end

  # --- Equity Plans ---
  def handle_event("save_equity_plan", %{"equity_plan" => params}, socket) do
    case Governance.create_equity_incentive_plan(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket) |> put_flash(:info, "Equity plan added") |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add equity plan")}
    end
  end

  def handle_event("edit_equity_plan", %{"id" => id}, socket) do
    item = Governance.get_equity_incentive_plan!(id)
    {:noreply, assign(socket, show_form: :edit, editing_item: item)}
  end

  def handle_event("update_equity_plan", %{"equity_plan" => params}, socket) do
    item = socket.assigns.editing_item

    case Governance.update_equity_incentive_plan(item, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket) |> put_flash(:info, "Equity plan updated") |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update equity plan")}
    end
  end

  def handle_event("delete_equity_plan", %{"id" => id}, socket) do
    ep = Governance.get_equity_incentive_plan!(id)
    Governance.delete_equity_incentive_plan(ep)
    {:noreply, reload(socket) |> put_flash(:info, "Equity plan deleted")}
  end

  # --- Joint Ventures ---
  def handle_event("save_jv", %{"joint_venture" => params}, socket) do
    case Governance.create_joint_venture(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket) |> put_flash(:info, "Joint venture added") |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add joint venture")}
    end
  end

  def handle_event("edit_jv", %{"id" => id}, socket) do
    item = Governance.get_joint_venture!(id)
    {:noreply, assign(socket, show_form: :edit, editing_item: item)}
  end

  def handle_event("update_jv", %{"joint_venture" => params}, socket) do
    item = socket.assigns.editing_item

    case Governance.update_joint_venture(item, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket) |> put_flash(:info, "Joint venture updated") |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update joint venture")}
    end
  end

  def handle_event("delete_jv", %{"id" => id}, socket) do
    jv = Governance.get_joint_venture!(id)
    Governance.delete_joint_venture(jv)
    {:noreply, reload(socket) |> put_flash(:info, "Joint venture deleted")}
  end

  # --- Powers of Attorney ---
  def handle_event("save_poa", %{"power_of_attorney" => params}, socket) do
    case Governance.create_power_of_attorney(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket) |> put_flash(:info, "Power of attorney added") |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add power of attorney")}
    end
  end

  def handle_event("edit_poa", %{"id" => id}, socket) do
    item = Governance.get_power_of_attorney!(id)
    {:noreply, assign(socket, show_form: :edit, editing_item: item)}
  end

  def handle_event("update_poa", %{"power_of_attorney" => params}, socket) do
    item = socket.assigns.editing_item

    case Governance.update_power_of_attorney(item, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket) |> put_flash(:info, "Power of attorney updated") |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update power of attorney")}
    end
  end

  def handle_event("delete_poa", %{"id" => id}, socket) do
    poa = Governance.get_power_of_attorney!(id)
    Governance.delete_power_of_attorney(poa)
    {:noreply, reload(socket) |> put_flash(:info, "Power of attorney deleted")}
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, reload(socket)}

  defp reload(socket) do
    assign(socket,
      meetings: Governance.list_board_meetings(),
      cap_table: Governance.list_cap_table_entries(),
      resolutions: Governance.list_shareholder_resolutions(),
      deals: Governance.list_deals(),
      equity_plans: Governance.list_equity_incentive_plans(),
      joint_ventures: Governance.list_joint_ventures(),
      powers: Governance.list_powers_of_attorney()
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <h1>Governance</h1>
      <p class="deck">
        Board meetings, cap table, resolutions, deals, equity plans, JVs, and powers of attorney
      </p>
      <hr class="page-title-rule" />
    </div>

    <div class="tabs">
      <button
        :for={tab <- @tabs}
        class={"tab #{if @active_tab == tab, do: "tab-active"}"}
        phx-click="switch_tab"
        phx-value-tab={tab}
      >
        {tab_label(tab)}
      </button>
    </div>

    <div class="tab-body">
      {render_tab(assigns)}
    </div>
    """
  end

  defp tab_label("meetings"), do: "Board Meetings"
  defp tab_label("cap_table"), do: "Cap Table"
  defp tab_label("resolutions"), do: "Resolutions"
  defp tab_label("deals"), do: "Deals"
  defp tab_label("equity_plans"), do: "Equity Plans"
  defp tab_label("joint_ventures"), do: "Joint Ventures"
  defp tab_label("powers_of_attorney"), do: "Powers of Attorney"

  # ============================================================
  # MEETINGS TAB
  # ============================================================
  defp render_tab(%{active_tab: "meetings"} = assigns) do
    ~H"""
    <div class="section">
      <div class="section-head">
        <h2>Board Meetings</h2>
        <%= if @can_write do %>
          <button class="btn btn-sm btn-primary" phx-click="show_form">Add</button>
        <% end %>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Date</th>
              <th>Company</th>
              <th>Type</th>
              <th>Status</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for bm <- @meetings do %>
              <tr>
                <td class="td-mono">{bm.scheduled_date}</td>
                <td>
                  <%= if bm.company do %>
                    <.link navigate={~p"/companies/#{bm.company.id}"} class="td-link">{bm.company.name}</.link>
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td>{bm.meeting_type}</td>
                <td><span class="tag tag-ink">{bm.status}</span></td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit_meeting" phx-value-id={bm.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button
                        phx-click="delete_meeting"
                        phx-value-id={bm.id}
                        class="btn btn-danger btn-sm"
                        data-confirm="Delete?"
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
      </div>
      <%= if @meetings == [] do %>
        <div class="empty-state">
          <p>No board meetings recorded yet.</p>
          <p style="color: var(--muted); font-size: 0.9rem;">Track board meetings, AGMs, and special meetings for your companies.</p>
          <%= if @can_write do %>
            <button class="btn btn-primary btn-sm" phx-click="show_form" style="margin-top: 0.75rem;">Create first meeting</button>
          <% end %>
        </div>
      <% end %>
    </div>
    <%= if @show_form == :add do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click="noop">
          <div class="modal-header">
            <h3>Add Board Meeting</h3>
          </div>
          <div class="modal-body">
            <form phx-submit="save_meeting">
              <div class="form-group">
                <label class="form-label">Company *</label><select
                  name="board_meeting[company_id]"
                  class="form-select"
                  required
                ><option value="">Select</option><%= for c <- @companies do %><option value={c.id}><%= c.name %></option><% end %></select>
              </div>
              <div class="form-group">
                <label class="form-label">Date *</label>
                <input
                  type="text"
                  name="board_meeting[scheduled_date]"
                  class="form-input"
                  placeholder="YYYY-MM-DD"
                  required
                />
              </div>
              <div class="form-group">
                <label class="form-label">Type</label><select
                  name="board_meeting[meeting_type]"
                  class="form-select"
                ><option value="regular">Regular</option><option value="special">Special</option><option value="annual">Annual</option></select>
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label><textarea
                  name="board_meeting[notes]"
                  class="form-input"
                ></textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Add</button><button
                  type="button"
                  phx-click="close_form"
                  class="btn btn-secondary"
                >Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    <%= if @show_form == :edit and @editing_item do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click="noop">
          <div class="modal-header">
            <h3>Edit Board Meeting</h3>
          </div>
          <div class="modal-body">
            <form phx-submit="update_meeting">
              <div class="form-group">
                <label class="form-label">Company *</label><select
                  name="board_meeting[company_id]"
                  class="form-select"
                  required
                ><option value="">Select</option><%= for c <- @companies do %><option value={c.id} selected={@editing_item.company_id == c.id}><%= c.name %></option><% end %></select>
              </div>
              <div class="form-group">
                <label class="form-label">Date *</label>
                <input
                  type="text"
                  name="board_meeting[scheduled_date]"
                  class="form-input"
                  placeholder="YYYY-MM-DD"
                  value={@editing_item.scheduled_date}
                  required
                />
              </div>
              <div class="form-group">
                <label class="form-label">Type</label><select
                  name="board_meeting[meeting_type]"
                  class="form-select"
                ><option value="regular" selected={@editing_item.meeting_type == "regular"}>Regular</option><option value="special" selected={@editing_item.meeting_type == "special"}>Special</option><option value="annual" selected={@editing_item.meeting_type == "annual"}>Annual</option></select>
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label><textarea
                  name="board_meeting[notes]"
                  class="form-input"
                ><%= @editing_item.notes %></textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Save</button><button
                  type="button"
                  phx-click="close_form"
                  class="btn btn-secondary"
                >Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  # ============================================================
  # CAP TABLE TAB
  # ============================================================
  defp render_tab(%{active_tab: "cap_table"} = assigns) do
    ~H"""
    <div class="section">
      <div class="section-head">
        <h2>Cap Table</h2>
        <%= if @can_write do %>
          <button class="btn btn-sm btn-primary" phx-click="show_form">Add</button>
        <% end %>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Investor</th>
              <th>Round</th>
              <th>Shares</th>
              <th>Amount</th>
              <th>Company</th>
              <th>Date</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for ct <- @cap_table do %>
              <tr>
                <td class="td-name">{ct.investor}</td>
                <td>{ct.round_name}</td>
                <td class="td-num">{ct.shares}</td>
                <td class="td-num">{ct.amount_invested} {ct.currency}</td>
                <td>
                  <%= if ct.company do %>
                    <.link navigate={~p"/companies/#{ct.company.id}"} class="td-link">{ct.company.name}</.link>
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td class="td-mono">{ct.date}</td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit_cap_table" phx-value-id={ct.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button
                        phx-click="delete_cap_table"
                        phx-value-id={ct.id}
                        class="btn btn-danger btn-sm"
                        data-confirm="Delete?"
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
      </div>
      <%= if @cap_table == [] do %>
        <div class="empty-state">
          <p>No cap table entries recorded yet.</p>
          <p style="color: var(--muted); font-size: 0.9rem;">Record investors, funding rounds, and share allocations.</p>
          <%= if @can_write do %>
            <button class="btn btn-primary btn-sm" phx-click="show_form" style="margin-top: 0.75rem;">Create first entry</button>
          <% end %>
        </div>
      <% end %>
    </div>
    <%= if @show_form == :add do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click="noop">
          <div class="modal-header">
            <h3>Add Cap Table Entry</h3>
          </div>
          <div class="modal-body">
            <form phx-submit="save_cap_table">
              <div class="form-group">
                <label class="form-label">Company *</label><select
                  name="cap_table_entry[company_id]"
                  class="form-select"
                  required
                ><option value="">Select</option><%= for c <- @companies do %><option value={c.id}><%= c.name %></option><% end %></select>
              </div>
              <div class="form-group">
                <label class="form-label">Investor *</label>
                <input type="text" name="cap_table_entry[investor]" class="form-input" required />
              </div>
              <div class="form-group">
                <label class="form-label">Round Name</label>
                <input type="text" name="cap_table_entry[round_name]" class="form-input" />
              </div>
              <div class="form-group">
                <label class="form-label">Shares</label>
                <input type="number" name="cap_table_entry[shares]" class="form-input" step="any" />
              </div>
              <div class="form-group">
                <label class="form-label">Amount Invested</label>
                <input
                  type="number"
                  name="cap_table_entry[amount_invested]"
                  class="form-input"
                  step="any"
                />
              </div>
              <div class="form-group">
                <label class="form-label">Date</label>
                <input
                  type="text"
                  name="cap_table_entry[date]"
                  class="form-input"
                  placeholder="YYYY-MM-DD"
                />
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Add</button><button
                  type="button"
                  phx-click="close_form"
                  class="btn btn-secondary"
                >Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    <%= if @show_form == :edit and @editing_item do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click="noop">
          <div class="modal-header">
            <h3>Edit Cap Table Entry</h3>
          </div>
          <div class="modal-body">
            <form phx-submit="update_cap_table">
              <div class="form-group">
                <label class="form-label">Company *</label><select
                  name="cap_table_entry[company_id]"
                  class="form-select"
                  required
                ><option value="">Select</option><%= for c <- @companies do %><option value={c.id} selected={@editing_item.company_id == c.id}><%= c.name %></option><% end %></select>
              </div>
              <div class="form-group">
                <label class="form-label">Investor *</label>
                <input type="text" name="cap_table_entry[investor]" class="form-input" value={@editing_item.investor} required />
              </div>
              <div class="form-group">
                <label class="form-label">Round Name</label>
                <input type="text" name="cap_table_entry[round_name]" class="form-input" value={@editing_item.round_name} />
              </div>
              <div class="form-group">
                <label class="form-label">Shares</label>
                <input type="number" name="cap_table_entry[shares]" class="form-input" step="any" value={@editing_item.shares} />
              </div>
              <div class="form-group">
                <label class="form-label">Amount Invested</label>
                <input
                  type="number"
                  name="cap_table_entry[amount_invested]"
                  class="form-input"
                  step="any"
                  value={@editing_item.amount_invested}
                />
              </div>
              <div class="form-group">
                <label class="form-label">Date</label>
                <input
                  type="text"
                  name="cap_table_entry[date]"
                  class="form-input"
                  placeholder="YYYY-MM-DD"
                  value={@editing_item.date}
                />
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Save</button><button
                  type="button"
                  phx-click="close_form"
                  class="btn btn-secondary"
                >Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  # ============================================================
  # RESOLUTIONS TAB
  # ============================================================
  defp render_tab(%{active_tab: "resolutions"} = assigns) do
    ~H"""
    <div class="section">
      <div class="section-head">
        <h2>Shareholder Resolutions</h2>
        <%= if @can_write do %>
          <button class="btn btn-sm btn-primary" phx-click="show_form">Add</button>
        <% end %>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Title</th>
              <th>Type</th>
              <th>Company</th>
              <th>Date</th>
              <th>Passed</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for res <- @resolutions do %>
              <tr>
                <td class="td-name">{res.title}</td>
                <td>{res.resolution_type}</td>
                <td>
                  <%= if res.company do %>
                    <.link navigate={~p"/companies/#{res.company.id}"} class="td-link">{res.company.name}</.link>
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td class="td-mono">{res.date}</td>
                <td>{if res.passed, do: "Yes", else: "No"}</td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit_resolution" phx-value-id={res.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button
                        phx-click="delete_resolution"
                        phx-value-id={res.id}
                        class="btn btn-danger btn-sm"
                        data-confirm="Delete?"
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
      </div>
      <%= if @resolutions == [] do %>
        <div class="empty-state">
          <p>No shareholder resolutions recorded yet.</p>
          <p style="color: var(--muted); font-size: 0.9rem;">Track shareholder resolutions and voting outcomes.</p>
          <%= if @can_write do %>
            <button class="btn btn-primary btn-sm" phx-click="show_form" style="margin-top: 0.75rem;">Create first resolution</button>
          <% end %>
        </div>
      <% end %>
    </div>
    <%= if @show_form == :add do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click="noop">
          <div class="modal-header">
            <h3>Add Resolution</h3>
          </div>
          <div class="modal-body">
            <form phx-submit="save_resolution">
              <div class="form-group">
                <label class="form-label">Company *</label><select
                  name="resolution[company_id]"
                  class="form-select"
                  required
                ><option value="">Select</option><%= for c <- @companies do %><option value={c.id}><%= c.name %></option><% end %></select>
              </div>
              <div class="form-group">
                <label class="form-label">Title *</label>
                <input type="text" name="resolution[title]" class="form-input" required />
              </div>
              <div class="form-group">
                <label class="form-label">Date *</label>
                <input
                  type="text"
                  name="resolution[date]"
                  class="form-input"
                  placeholder="YYYY-MM-DD"
                  required
                />
              </div>
              <div class="form-group">
                <label class="form-label">Type</label><select
                  name="resolution[resolution_type]"
                  class="form-select"
                ><option value="ordinary">Ordinary</option><option value="special">Special</option></select>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Add</button><button
                  type="button"
                  phx-click="close_form"
                  class="btn btn-secondary"
                >Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    <%= if @show_form == :edit and @editing_item do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click="noop">
          <div class="modal-header">
            <h3>Edit Resolution</h3>
          </div>
          <div class="modal-body">
            <form phx-submit="update_resolution">
              <div class="form-group">
                <label class="form-label">Company *</label><select
                  name="resolution[company_id]"
                  class="form-select"
                  required
                ><option value="">Select</option><%= for c <- @companies do %><option value={c.id} selected={@editing_item.company_id == c.id}><%= c.name %></option><% end %></select>
              </div>
              <div class="form-group">
                <label class="form-label">Title *</label>
                <input type="text" name="resolution[title]" class="form-input" value={@editing_item.title} required />
              </div>
              <div class="form-group">
                <label class="form-label">Date *</label>
                <input
                  type="text"
                  name="resolution[date]"
                  class="form-input"
                  placeholder="YYYY-MM-DD"
                  value={@editing_item.date}
                  required
                />
              </div>
              <div class="form-group">
                <label class="form-label">Type</label><select
                  name="resolution[resolution_type]"
                  class="form-select"
                ><option value="ordinary" selected={@editing_item.resolution_type == "ordinary"}>Ordinary</option><option value="special" selected={@editing_item.resolution_type == "special"}>Special</option></select>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Save</button><button
                  type="button"
                  phx-click="close_form"
                  class="btn btn-secondary"
                >Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  # ============================================================
  # DEALS TAB
  # ============================================================
  defp render_tab(%{active_tab: "deals"} = assigns) do
    ~H"""
    <div class="section">
      <div class="section-head">
        <h2>Deals</h2>
        <%= if @can_write do %>
          <button class="btn btn-sm btn-primary" phx-click="show_form">Add</button>
        <% end %>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Type</th>
              <th>Counterparty</th>
              <th>Company</th>
              <th>Value</th>
              <th>Status</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for d <- @deals do %>
              <tr>
                <td>{d.deal_type}</td>
                <td class="td-name">{d.counterparty}</td>
                <td>
                  <%= if d.company do %>
                    <.link navigate={~p"/companies/#{d.company.id}"} class="td-link">{d.company.name}</.link>
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td class="td-num">{d.value} {d.currency}</td>
                <td><span class="tag tag-ink">{d.status}</span></td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit_deal" phx-value-id={d.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button
                        phx-click="delete_deal"
                        phx-value-id={d.id}
                        class="btn btn-danger btn-sm"
                        data-confirm="Delete?"
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
      </div>
      <%= if @deals == [] do %>
        <div class="empty-state">
          <p>No deals recorded yet.</p>
          <p style="color: var(--muted); font-size: 0.9rem;">Track acquisitions, divestitures, mergers, and investments.</p>
          <%= if @can_write do %>
            <button class="btn btn-primary btn-sm" phx-click="show_form" style="margin-top: 0.75rem;">Create first deal</button>
          <% end %>
        </div>
      <% end %>
    </div>
    <%= if @show_form == :add do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click="noop">
          <div class="modal-header">
            <h3>Add Deal</h3>
          </div>
          <div class="modal-body">
            <form phx-submit="save_deal">
              <div class="form-group">
                <label class="form-label">Company *</label><select
                  name="deal[company_id]"
                  class="form-select"
                  required
                ><option value="">Select</option><%= for c <- @companies do %><option value={c.id}><%= c.name %></option><% end %></select>
              </div>
              <div class="form-group">
                <label class="form-label">Counterparty *</label>
                <input type="text" name="deal[counterparty]" class="form-input" required />
              </div>
              <div class="form-group">
                <label class="form-label">Type</label><select
                  name="deal[deal_type]"
                  class="form-select"
                ><option value="acquisition">Acquisition</option><option value="divestiture">Divestiture</option><option value="merger">Merger</option><option value="investment">Investment</option></select>
              </div>
              <div class="form-group">
                <label class="form-label">Value</label>
                <input type="number" name="deal[value]" class="form-input" step="any" />
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Add</button><button
                  type="button"
                  phx-click="close_form"
                  class="btn btn-secondary"
                >Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    <%= if @show_form == :edit and @editing_item do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click="noop">
          <div class="modal-header">
            <h3>Edit Deal</h3>
          </div>
          <div class="modal-body">
            <form phx-submit="update_deal">
              <div class="form-group">
                <label class="form-label">Company *</label><select
                  name="deal[company_id]"
                  class="form-select"
                  required
                ><option value="">Select</option><%= for c <- @companies do %><option value={c.id} selected={@editing_item.company_id == c.id}><%= c.name %></option><% end %></select>
              </div>
              <div class="form-group">
                <label class="form-label">Counterparty *</label>
                <input type="text" name="deal[counterparty]" class="form-input" value={@editing_item.counterparty} required />
              </div>
              <div class="form-group">
                <label class="form-label">Type</label><select
                  name="deal[deal_type]"
                  class="form-select"
                ><option value="acquisition" selected={@editing_item.deal_type == "acquisition"}>Acquisition</option><option value="divestiture" selected={@editing_item.deal_type == "divestiture"}>Divestiture</option><option value="merger" selected={@editing_item.deal_type == "merger"}>Merger</option><option value="investment" selected={@editing_item.deal_type == "investment"}>Investment</option></select>
              </div>
              <div class="form-group">
                <label class="form-label">Value</label>
                <input type="number" name="deal[value]" class="form-input" step="any" value={@editing_item.value} />
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Save</button><button
                  type="button"
                  phx-click="close_form"
                  class="btn btn-secondary"
                >Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  # ============================================================
  # EQUITY PLANS TAB
  # ============================================================
  defp render_tab(%{active_tab: "equity_plans"} = assigns) do
    ~H"""
    <div class="section">
      <div class="section-head">
        <h2>Equity Incentive Plans</h2>
        <%= if @can_write do %>
          <button class="btn btn-sm btn-primary" phx-click="show_form">Add</button>
        <% end %>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Plan Name</th>
              <th>Company</th>
              <th>Total Pool</th>
              <th>Vesting</th>
              <th>Approval Date</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for ep <- @equity_plans do %>
              <tr>
                <td class="td-name">{ep.plan_name}</td>
                <td>
                  <%= if ep.company do %>
                    <.link navigate={~p"/companies/#{ep.company.id}"} class="td-link">{ep.company.name}</.link>
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td class="td-num">{ep.total_pool}</td>
                <td>{ep.vesting_schedule}</td>
                <td class="td-mono">{ep.board_approval_date}</td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit_equity_plan" phx-value-id={ep.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button
                        phx-click="delete_equity_plan"
                        phx-value-id={ep.id}
                        class="btn btn-danger btn-sm"
                        data-confirm="Delete?"
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
      </div>
      <%= if @equity_plans == [] do %>
        <div class="empty-state">
          <p>No equity incentive plans recorded yet.</p>
          <p style="color: var(--muted); font-size: 0.9rem;">Manage employee stock option plans and equity incentives.</p>
          <%= if @can_write do %>
            <button class="btn btn-primary btn-sm" phx-click="show_form" style="margin-top: 0.75rem;">Create first equity plan</button>
          <% end %>
        </div>
      <% end %>
    </div>
    <%= if @show_form == :add do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click="noop">
          <div class="modal-header">
            <h3>Add Equity Plan</h3>
          </div>
          <div class="modal-body">
            <form phx-submit="save_equity_plan">
              <div class="form-group">
                <label class="form-label">Company *</label><select
                  name="equity_plan[company_id]"
                  class="form-select"
                  required
                ><option value="">Select</option><%= for c <- @companies do %><option value={c.id}><%= c.name %></option><% end %></select>
              </div>
              <div class="form-group">
                <label class="form-label">Plan Name *</label>
                <input type="text" name="equity_plan[plan_name]" class="form-input" required />
              </div>
              <div class="form-group">
                <label class="form-label">Total Pool</label>
                <input type="number" name="equity_plan[total_pool]" class="form-input" />
              </div>
              <div class="form-group">
                <label class="form-label">Vesting Schedule</label>
                <input type="text" name="equity_plan[vesting_schedule]" class="form-input" />
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Add</button><button
                  type="button"
                  phx-click="close_form"
                  class="btn btn-secondary"
                >Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    <%= if @show_form == :edit and @editing_item do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click="noop">
          <div class="modal-header">
            <h3>Edit Equity Plan</h3>
          </div>
          <div class="modal-body">
            <form phx-submit="update_equity_plan">
              <div class="form-group">
                <label class="form-label">Company *</label><select
                  name="equity_plan[company_id]"
                  class="form-select"
                  required
                ><option value="">Select</option><%= for c <- @companies do %><option value={c.id} selected={@editing_item.company_id == c.id}><%= c.name %></option><% end %></select>
              </div>
              <div class="form-group">
                <label class="form-label">Plan Name *</label>
                <input type="text" name="equity_plan[plan_name]" class="form-input" value={@editing_item.plan_name} required />
              </div>
              <div class="form-group">
                <label class="form-label">Total Pool</label>
                <input type="number" name="equity_plan[total_pool]" class="form-input" value={@editing_item.total_pool} />
              </div>
              <div class="form-group">
                <label class="form-label">Vesting Schedule</label>
                <input type="text" name="equity_plan[vesting_schedule]" class="form-input" value={@editing_item.vesting_schedule} />
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Save</button><button
                  type="button"
                  phx-click="close_form"
                  class="btn btn-secondary"
                >Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  # ============================================================
  # JOINT VENTURES TAB
  # ============================================================
  defp render_tab(%{active_tab: "joint_ventures"} = assigns) do
    ~H"""
    <div class="section">
      <div class="section-head">
        <h2>Joint Ventures</h2>
        <%= if @can_write do %>
          <button class="btn btn-sm btn-primary" phx-click="show_form">Add</button>
        <% end %>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>Partner</th>
              <th>Company</th>
              <th>Ownership</th>
              <th>Status</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for jv <- @joint_ventures do %>
              <tr>
                <td class="td-name">{jv.name}</td>
                <td>{jv.partner}</td>
                <td>
                  <%= if jv.company do %>
                    <.link navigate={~p"/companies/#{jv.company.id}"} class="td-link">{jv.company.name}</.link>
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td class="td-num">{jv.ownership_pct}%</td>
                <td><span class="tag tag-ink">{jv.status}</span></td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit_jv" phx-value-id={jv.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button
                        phx-click="delete_jv"
                        phx-value-id={jv.id}
                        class="btn btn-danger btn-sm"
                        data-confirm="Delete?"
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
      </div>
      <%= if @joint_ventures == [] do %>
        <div class="empty-state">
          <p>No joint ventures recorded yet.</p>
          <p style="color: var(--muted); font-size: 0.9rem;">Track joint venture partnerships and ownership stakes.</p>
          <%= if @can_write do %>
            <button class="btn btn-primary btn-sm" phx-click="show_form" style="margin-top: 0.75rem;">Create first joint venture</button>
          <% end %>
        </div>
      <% end %>
    </div>
    <%= if @show_form == :add do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click="noop">
          <div class="modal-header">
            <h3>Add Joint Venture</h3>
          </div>
          <div class="modal-body">
            <form phx-submit="save_jv">
              <div class="form-group">
                <label class="form-label">Company *</label><select
                  name="joint_venture[company_id]"
                  class="form-select"
                  required
                ><option value="">Select</option><%= for c <- @companies do %><option value={c.id}><%= c.name %></option><% end %></select>
              </div>
              <div class="form-group">
                <label class="form-label">Name *</label>
                <input type="text" name="joint_venture[name]" class="form-input" required />
              </div>
              <div class="form-group">
                <label class="form-label">Partner *</label>
                <input type="text" name="joint_venture[partner]" class="form-input" required />
              </div>
              <div class="form-group">
                <label class="form-label">Ownership %</label>
                <input
                  type="number"
                  name="joint_venture[ownership_pct]"
                  class="form-input"
                  step="any"
                  value="50"
                />
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Add</button><button
                  type="button"
                  phx-click="close_form"
                  class="btn btn-secondary"
                >Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    <%= if @show_form == :edit and @editing_item do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click="noop">
          <div class="modal-header">
            <h3>Edit Joint Venture</h3>
          </div>
          <div class="modal-body">
            <form phx-submit="update_jv">
              <div class="form-group">
                <label class="form-label">Company *</label><select
                  name="joint_venture[company_id]"
                  class="form-select"
                  required
                ><option value="">Select</option><%= for c <- @companies do %><option value={c.id} selected={@editing_item.company_id == c.id}><%= c.name %></option><% end %></select>
              </div>
              <div class="form-group">
                <label class="form-label">Name *</label>
                <input type="text" name="joint_venture[name]" class="form-input" value={@editing_item.name} required />
              </div>
              <div class="form-group">
                <label class="form-label">Partner *</label>
                <input type="text" name="joint_venture[partner]" class="form-input" value={@editing_item.partner} required />
              </div>
              <div class="form-group">
                <label class="form-label">Ownership %</label>
                <input
                  type="number"
                  name="joint_venture[ownership_pct]"
                  class="form-input"
                  step="any"
                  value={@editing_item.ownership_pct}
                />
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Save</button><button
                  type="button"
                  phx-click="close_form"
                  class="btn btn-secondary"
                >Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  # ============================================================
  # POWERS OF ATTORNEY TAB
  # ============================================================
  defp render_tab(%{active_tab: "powers_of_attorney"} = assigns) do
    ~H"""
    <div class="section">
      <div class="section-head">
        <h2>Powers of Attorney</h2>
        <%= if @can_write do %>
          <button class="btn btn-sm btn-primary" phx-click="show_form">Add</button>
        <% end %>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Grantor</th>
              <th>Grantee</th>
              <th>Company</th>
              <th>Scope</th>
              <th>Start</th>
              <th>End</th>
              <th>Status</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for poa <- @powers do %>
              <tr>
                <td class="td-name">{poa.grantor}</td>
                <td>{poa.grantee}</td>
                <td>
                  <%= if poa.company do %>
                    <.link navigate={~p"/companies/#{poa.company.id}"} class="td-link">{poa.company.name}</.link>
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td>{poa.scope}</td>
                <td class="td-mono">{poa.start_date}</td>
                <td class="td-mono">{poa.end_date}</td>
                <td><span class="tag tag-ink">{poa.status}</span></td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button phx-click="edit_poa" phx-value-id={poa.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button
                        phx-click="delete_poa"
                        phx-value-id={poa.id}
                        class="btn btn-danger btn-sm"
                        data-confirm="Delete?"
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
      </div>
      <%= if @powers == [] do %>
        <div class="empty-state">
          <p>No powers of attorney recorded yet.</p>
          <p style="color: var(--muted); font-size: 0.9rem;">Manage powers of attorney granted across your entities.</p>
          <%= if @can_write do %>
            <button class="btn btn-primary btn-sm" phx-click="show_form" style="margin-top: 0.75rem;">Create first power of attorney</button>
          <% end %>
        </div>
      <% end %>
    </div>
    <%= if @show_form == :add do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click="noop">
          <div class="modal-header">
            <h3>Add Power of Attorney</h3>
          </div>
          <div class="modal-body">
            <form phx-submit="save_poa">
              <div class="form-group">
                <label class="form-label">Company *</label><select
                  name="power_of_attorney[company_id]"
                  class="form-select"
                  required
                ><option value="">Select</option><%= for c <- @companies do %><option value={c.id}><%= c.name %></option><% end %></select>
              </div>
              <div class="form-group">
                <label class="form-label">Grantor *</label>
                <input type="text" name="power_of_attorney[grantor]" class="form-input" required />
              </div>
              <div class="form-group">
                <label class="form-label">Grantee *</label>
                <input type="text" name="power_of_attorney[grantee]" class="form-input" required />
              </div>
              <div class="form-group">
                <label class="form-label">Scope</label>
                <input type="text" name="power_of_attorney[scope]" class="form-input" />
              </div>
              <div class="form-group">
                <label class="form-label">Start Date</label>
                <input
                  type="text"
                  name="power_of_attorney[start_date]"
                  class="form-input"
                  placeholder="YYYY-MM-DD"
                />
              </div>
              <div class="form-group">
                <label class="form-label">End Date</label>
                <input
                  type="text"
                  name="power_of_attorney[end_date]"
                  class="form-input"
                  placeholder="YYYY-MM-DD"
                />
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Add</button><button
                  type="button"
                  phx-click="close_form"
                  class="btn btn-secondary"
                >Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    <%= if @show_form == :edit and @editing_item do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click="noop">
          <div class="modal-header">
            <h3>Edit Power of Attorney</h3>
          </div>
          <div class="modal-body">
            <form phx-submit="update_poa">
              <div class="form-group">
                <label class="form-label">Company *</label><select
                  name="power_of_attorney[company_id]"
                  class="form-select"
                  required
                ><option value="">Select</option><%= for c <- @companies do %><option value={c.id} selected={@editing_item.company_id == c.id}><%= c.name %></option><% end %></select>
              </div>
              <div class="form-group">
                <label class="form-label">Grantor *</label>
                <input type="text" name="power_of_attorney[grantor]" class="form-input" value={@editing_item.grantor} required />
              </div>
              <div class="form-group">
                <label class="form-label">Grantee *</label>
                <input type="text" name="power_of_attorney[grantee]" class="form-input" value={@editing_item.grantee} required />
              </div>
              <div class="form-group">
                <label class="form-label">Scope</label>
                <input type="text" name="power_of_attorney[scope]" class="form-input" value={@editing_item.scope} />
              </div>
              <div class="form-group">
                <label class="form-label">Start Date</label>
                <input
                  type="text"
                  name="power_of_attorney[start_date]"
                  class="form-input"
                  placeholder="YYYY-MM-DD"
                  value={@editing_item.start_date}
                />
              </div>
              <div class="form-group">
                <label class="form-label">End Date</label>
                <input
                  type="text"
                  name="power_of_attorney[end_date]"
                  class="form-input"
                  placeholder="YYYY-MM-DD"
                  value={@editing_item.end_date}
                />
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Save</button><button
                  type="button"
                  phx-click="close_form"
                  class="btn btn-secondary"
                >Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end
end
