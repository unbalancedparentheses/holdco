defmodule HoldcoWeb.RegisterLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Corporate, Corporate.RegisterEntry}

  @register_tabs RegisterEntry.register_types()

  @impl true
  def mount(_params, _session, socket) do
    companies = Corporate.list_companies()

    {:ok,
     assign(socket,
       page_title: "Corporate Registers",
       companies: companies,
       selected_company_id: "",
       active_tab: hd(@register_tabs),
       register_tabs: @register_tabs,
       entries: [],
       summary: %{},
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
         entries: [],
         summary: %{},
         show_form: false,
         editing_item: nil
       )}
    else
      cid = String.to_integer(id)
      tab = socket.assigns.active_tab
      entries = Corporate.current_register(cid, tab)
      summary = Corporate.register_summary(cid)

      {:noreply,
       assign(socket,
         selected_company_id: id,
         entries: entries,
         summary: summary,
         show_form: false,
         editing_item: nil
       )}
    end
  end

  def handle_event("switch_tab", %{"tab" => tab}, socket) when tab in @register_tabs do
    entries =
      if socket.assigns.selected_company_id != "" do
        cid = String.to_integer(socket.assigns.selected_company_id)
        Corporate.current_register(cid, tab)
      else
        []
      end

    {:noreply,
     assign(socket,
       active_tab: tab,
       entries: entries,
       show_form: false,
       editing_item: nil
     )}
  end

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: :add, editing_item: nil)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false, editing_item: nil)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    entry = Corporate.get_register_entry!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: entry)}
  end

  def handle_event("cease", %{"id" => id}, socket) do
    entry = Corporate.get_register_entry!(String.to_integer(id))
    today = Date.utc_today() |> Date.to_iso8601()

    case Corporate.update_register_entry(entry, %{status: "historical", cessation_date: today}) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Entry ceased")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to cease entry")}
    end
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

  def handle_event("save", %{"register_entry" => params}, socket) do
    params = Map.put(params, "register_type", socket.assigns.active_tab)

    case Corporate.create_register_entry(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Register entry added")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add register entry")}
    end
  end

  def handle_event("update", %{"register_entry" => params}, socket) do
    entry = socket.assigns.editing_item

    case Corporate.update_register_entry(entry, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Register entry updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update register entry")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    entry = Corporate.get_register_entry!(String.to_integer(id))

    case Corporate.delete_register_entry(entry) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Register entry deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete register entry")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Corporate Registers</h1>
          <p class="deck">Statutory registers for directors, shareholders, charges, and more</p>
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
            <button class="btn btn-primary" phx-click="show_form">Add Entry</button>
          <% end %>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <%= if @selected_company_id != "" do %>
      <div class="metrics-strip">
        <%= for tab <- @register_tabs do %>
          <div class="metric-cell" style="cursor: pointer;" phx-click="switch_tab" phx-value-tab={tab}>
            <div class="metric-label">{humanize_type(tab)}</div>
            <div class={"metric-value #{if @active_tab == tab, do: "num-positive", else: ""}"}>{Map.get(@summary, tab, 0)}</div>
          </div>
        <% end %>
      </div>

      <div class="section">
        <div class="section-head">
          <h2>{humanize_type(@active_tab)} Register</h2>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Person / Entity</th>
                <th>Role / Description</th>
                <th>Entry Date</th>
                <th>Appointment</th>
                <th>Cessation</th>
                <%= if @active_tab in ~w(shareholders beneficial_owners) do %>
                  <th class="th-num">Shares</th>
                  <th>Class</th>
                <% end %>
                <th>Status</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <%= for entry <- @entries do %>
                <tr>
                  <td class="td-name">{entry.person_name || "-"}</td>
                  <td>{entry.role_or_description || "-"}</td>
                  <td>{entry.entry_date}</td>
                  <td>{entry.appointment_date || "-"}</td>
                  <td>{entry.cessation_date || "-"}</td>
                  <%= if @active_tab in ~w(shareholders beneficial_owners) do %>
                    <td class="td-num">{if entry.shares_held, do: Decimal.to_string(entry.shares_held), else: "-"}</td>
                    <td>{entry.share_class || "-"}</td>
                  <% end %>
                  <td><span class={"tag #{register_status_tag(entry.status)}"}>{entry.status}</span></td>
                  <td style="text-align: right;">
                    <%= if @can_write do %>
                      <button phx-click="edit" phx-value-id={entry.id} class="btn btn-sm">Edit</button>
                      <%= if entry.status == "current" do %>
                        <button phx-click="cease" phx-value-id={entry.id} class="btn btn-sm" data-confirm="Cease this entry?">Cease</button>
                      <% end %>
                      <button phx-click="delete" phx-value-id={entry.id} class="btn btn-sm btn-danger" data-confirm="Delete this entry?">Delete</button>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
          <%= if @entries == [] do %>
            <p style="padding: 1rem; color: var(--text-muted);">No entries in this register.</p>
          <% end %>
        </div>
      </div>
    <% else %>
      <div class="section">
        <div class="panel" style="padding: 2rem; text-align: center; color: var(--text-muted);">
          Select a company to view its statutory registers.
        </div>
      </div>
    <% end %>

    <%= if @show_form do %>
      <div class="modal-backdrop" phx-click="close_form">
        <div class="modal" phx-click="noop">
          <div class="modal-header">
            <h3>{if @show_form == :edit, do: "Edit Entry", else: "Add Entry"}</h3>
          </div>
          <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
            <div class="form-group">
              <label class="form-label">Company</label>
              <select name="register_entry[company_id]" class="form-select" required>
                <option value="">Select company</option>
                <%= for c <- @companies do %>
                  <option value={c.id} selected={(@editing_item && @editing_item.company_id == c.id) || to_string(c.id) == @selected_company_id}>{c.name}</option>
                <% end %>
              </select>
            </div>
            <div class="form-group">
              <label class="form-label">Entry Date</label>
              <input type="date" name="register_entry[entry_date]" class="form-input" required value={if @editing_item, do: @editing_item.entry_date, else: ""} />
            </div>
            <div class="form-group">
              <label class="form-label">Person / Entity Name</label>
              <input type="text" name="register_entry[person_name]" class="form-input" value={if @editing_item, do: @editing_item.person_name, else: ""} />
            </div>
            <div class="form-group">
              <label class="form-label">Role / Description</label>
              <input type="text" name="register_entry[role_or_description]" class="form-input" value={if @editing_item, do: @editing_item.role_or_description, else: ""} />
            </div>
            <div class="form-group">
              <label class="form-label">Appointment Date</label>
              <input type="date" name="register_entry[appointment_date]" class="form-input" value={if @editing_item, do: @editing_item.appointment_date, else: ""} />
            </div>
            <%= if @active_tab in ~w(shareholders beneficial_owners) do %>
              <div class="form-group">
                <label class="form-label">Shares Held</label>
                <input type="number" name="register_entry[shares_held]" class="form-input" step="any" value={if @editing_item && @editing_item.shares_held, do: Decimal.to_string(@editing_item.shares_held), else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Share Class</label>
                <input type="text" name="register_entry[share_class]" class="form-input" value={if @editing_item, do: @editing_item.share_class, else: ""} />
              </div>
            <% end %>
            <div class="form-group">
              <label class="form-label">Status</label>
              <select name="register_entry[status]" class="form-select">
                <%= for s <- RegisterEntry.statuses() do %>
                  <option value={s} selected={@editing_item && @editing_item.status == s}>{String.capitalize(s)}</option>
                <% end %>
              </select>
            </div>
            <div class="form-group">
              <label class="form-label">Notes</label>
              <textarea name="register_entry[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
            </div>
            <div class="form-actions">
              <button type="submit" class="btn btn-primary">{if @show_form == :edit, do: "Update Entry", else: "Add Entry"}</button>
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
        assign(socket, entries: [], summary: %{})

      id ->
        cid = String.to_integer(id)
        tab = socket.assigns.active_tab
        assign(socket,
          entries: Corporate.current_register(cid, tab),
          summary: Corporate.register_summary(cid)
        )
    end
  end

  defp humanize_type(type) do
    type
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp register_status_tag("current"), do: "tag-jade"
  defp register_status_tag("historical"), do: "tag-lemon"
  defp register_status_tag(_), do: ""
end
