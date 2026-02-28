defmodule HoldcoWeb.BulkEditLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Corporate, Assets, Banking}

  @entity_types ~w(companies holdings transactions bank_accounts)
  @fields_for_entity %{
    "companies" => ~w(category country ownership_pct),
    "holdings" => ~w(asset_type currency),
    "transactions" => ~w(transaction_type currency),
    "bank_accounts" => ~w(currency account_type)
  }

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: "Bulk Edit",
       entity_type: "companies",
       records: [],
       selected: MapSet.new(),
       bulk_field: nil,
       bulk_value: "",
       results: nil,
       confirm_delete: false
     )
     |> load_records()}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  # Block all destructive events for non-writers
  @impl true
  def handle_event("bulk_update", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to edit records")}
  end

  def handle_event("bulk_delete", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to delete records")}
  end

  def handle_event("confirm_delete", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to delete records")}
  end

  def handle_event("switch_entity", %{"entity_type" => type}, socket)
      when type in @entity_types do
    {:noreply,
     socket
     |> assign(
       entity_type: type,
       selected: MapSet.new(),
       bulk_field: nil,
       bulk_value: "",
       results: nil,
       confirm_delete: false
     )
     |> load_records()}
  end

  def handle_event("toggle_select", %{"id" => id}, socket) do
    id = String.to_integer(id)
    selected = socket.assigns.selected

    new_selected =
      if MapSet.member?(selected, id) do
        MapSet.delete(selected, id)
      else
        MapSet.put(selected, id)
      end

    {:noreply, assign(socket, selected: new_selected)}
  end

  def handle_event("select_all", _params, socket) do
    all_ids = Enum.map(socket.assigns.records, & &1.id)
    {:noreply, assign(socket, selected: MapSet.new(all_ids))}
  end

  def handle_event("deselect_all", _params, socket) do
    {:noreply, assign(socket, selected: MapSet.new())}
  end

  def handle_event("set_bulk_field", %{"field" => field}, socket) do
    {:noreply, assign(socket, bulk_field: field, bulk_value: "")}
  end

  def handle_event("set_bulk_value", %{"value" => value}, socket) do
    {:noreply, assign(socket, bulk_value: value)}
  end

  def handle_event("bulk_update", _params, socket) do
    selected = socket.assigns.selected

    if MapSet.size(selected) == 0 do
      {:noreply, put_flash(socket, :error, "No records selected")}
    else
      field = socket.assigns.bulk_field
      value = socket.assigns.bulk_value

      if is_nil(field) or field == "" do
        {:noreply, put_flash(socket, :error, "Please select a field to update")}
      else
        ids = MapSet.to_list(selected)
        attrs = %{field => value}
        {success, failures} = do_bulk_update(socket.assigns.entity_type, ids, attrs)

        {:noreply,
         socket
         |> assign(
           results: %{action: "update", success: success, failures: failures},
           selected: MapSet.new(),
           bulk_field: nil,
           bulk_value: ""
         )
         |> load_records()}
      end
    end
  end

  def handle_event("confirm_delete", _params, socket) do
    if MapSet.size(socket.assigns.selected) == 0 do
      {:noreply, put_flash(socket, :error, "No records selected")}
    else
      {:noreply, assign(socket, confirm_delete: true)}
    end
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, confirm_delete: false)}
  end

  def handle_event("bulk_delete", _params, socket) do
    selected = socket.assigns.selected

    if MapSet.size(selected) == 0 do
      {:noreply, put_flash(socket, :error, "No records selected")}
    else
      ids = MapSet.to_list(selected)
      {success, failures} = do_bulk_delete(socket.assigns.entity_type, ids)

      {:noreply,
       socket
       |> assign(
         results: %{action: "delete", success: success, failures: failures},
         selected: MapSet.new(),
         confirm_delete: false
       )
       |> load_records()}
    end
  end

  defp load_records(socket) do
    records =
      case socket.assigns.entity_type do
        "companies" -> Corporate.list_companies()
        "holdings" -> Assets.list_holdings()
        "transactions" -> Banking.list_transactions()
        "bank_accounts" -> Banking.list_bank_accounts()
      end

    assign(socket, records: records)
  end

  defp do_bulk_update("companies", ids, attrs), do: Corporate.bulk_update_companies(ids, attrs)
  defp do_bulk_update("holdings", ids, attrs), do: Assets.bulk_update_holdings(ids, attrs)
  defp do_bulk_update("transactions", ids, attrs), do: Banking.bulk_update_transactions(ids, attrs)
  defp do_bulk_update("bank_accounts", ids, attrs), do: Banking.bulk_update_bank_accounts(ids, attrs)

  defp do_bulk_delete("companies", ids), do: Corporate.bulk_delete_companies(ids)
  defp do_bulk_delete("holdings", ids), do: Assets.bulk_delete_holdings(ids)
  defp do_bulk_delete("transactions", ids), do: Banking.bulk_delete_transactions(ids)
  defp do_bulk_delete("bank_accounts", ids), do: Banking.bulk_delete_bank_accounts(ids)

  defp available_fields(entity_type) do
    Map.get(@fields_for_entity, entity_type, [])
  end

  defp record_label(record, "companies"), do: record.name
  defp record_label(record, "holdings"), do: record.asset || "Holding ##{record.id}"
  defp record_label(record, "transactions"), do: record.description || "Transaction ##{record.id}"
  defp record_label(record, "bank_accounts"), do: record.bank_name || "Account ##{record.id}"

  defp format_entity_type(type) do
    type
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Bulk Edit</h1>
          <p class="deck">Select records and apply bulk operations</p>
        </div>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="section">
      <%!-- Entity type selector --%>
      <div style="display: flex; gap: 0.5rem; margin-bottom: 1.5rem;">
        <%= for type <- ~w(companies holdings transactions bank_accounts) do %>
          <button
            phx-click="switch_entity"
            phx-value-entity_type={type}
            class={"btn #{if @entity_type == type, do: "btn-primary", else: "btn-secondary"}"}
          >
            {format_entity_type(type)}
          </button>
        <% end %>
      </div>

      <div class="panel" style="padding: 1.5rem;">
        <%!-- Results summary --%>
        <%= if @results do %>
          <div
            style="margin-bottom: 1rem; padding: 1rem; border: 1px solid var(--border, #ddd); border-radius: 4px;"
            id="bulk-results"
          >
            <h4>Bulk {String.capitalize(@results.action)} Results</h4>
            <div style="margin-top: 0.5rem;">
              <span class="tag tag-jade">{@results.success} succeeded</span>
              <%= if @results.failures > 0 do %>
                <span class="tag tag-crimson" style="margin-left: 0.5rem;">
                  {@results.failures} failed
                </span>
              <% end %>
            </div>
          </div>
        <% end %>

        <%!-- Selection controls --%>
        <div style="display: flex; gap: 0.5rem; margin-bottom: 1rem; align-items: center;">
          <button phx-click="select_all" class="btn btn-secondary btn-sm">
            Select All
          </button>
          <button phx-click="deselect_all" class="btn btn-secondary btn-sm">
            Deselect All
          </button>
          <span style="color: var(--text-muted, #666); margin-left: 0.5rem;">
            {MapSet.size(@selected)} of {length(@records)} selected
          </span>
        </div>

        <%!-- Records table --%>
        <div style="max-height: 400px; overflow-y: auto; margin-bottom: 1rem;">
          <table>
            <thead>
              <tr>
                <th style="width: 40px;"></th>
                <th>Name / Label</th>
                <th>ID</th>
              </tr>
            </thead>
            <tbody>
              <%= if length(@records) == 0 do %>
                <tr>
                  <td colspan="3" class="empty-state" style="text-align: center; padding: 2rem;">
                    No {format_entity_type(@entity_type)} found.
                  </td>
                </tr>
              <% end %>
              <%= for record <- @records do %>
                <tr style={if MapSet.member?(@selected, record.id), do: "background: var(--bg-wash, #f0f8ff);", else: ""}>
                  <td>
                    <input
                      type="checkbox"
                      checked={MapSet.member?(@selected, record.id)}
                      phx-click="toggle_select"
                      phx-value-id={record.id}
                    />
                  </td>
                  <td>{record_label(record, @entity_type)}</td>
                  <td>{record.id}</td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>

        <%!-- Bulk actions --%>
        <%= if @can_write do %>
          <div style="border-top: 1px solid var(--border, #ddd); padding-top: 1rem;">
            <h4 style="margin-bottom: 0.75rem;">Bulk Actions</h4>

            <%!-- Update section --%>
            <div style="display: flex; gap: 0.5rem; align-items: flex-end; margin-bottom: 1rem; flex-wrap: wrap;">
              <div>
                <label class="form-label">Field</label>
                <select
                  class="form-select"
                  phx-change="set_bulk_field"
                  name="field"
                  style="min-width: 150px;"
                >
                  <option value="">-- Select field --</option>
                  <%= for field <- available_fields(@entity_type) do %>
                    <option value={field} selected={@bulk_field == field}>
                      {field |> String.replace("_", " ") |> String.capitalize()}
                    </option>
                  <% end %>
                </select>
              </div>

              <div>
                <label class="form-label">New Value</label>
                <input
                  type="text"
                  class="form-input"
                  value={@bulk_value}
                  phx-change="set_bulk_value"
                  phx-debounce="300"
                  name="value"
                  style="min-width: 200px;"
                />
              </div>

              <button phx-click="bulk_update" class="btn btn-primary">
                Update Selected
              </button>
            </div>

            <%!-- Delete section --%>
            <div style="margin-top: 1rem;">
              <%= if @confirm_delete do %>
                <div style="padding: 0.75rem; background: var(--bg-error, #fef2f2); border: 1px solid var(--border-error, #fca5a5); border-radius: 4px;">
                  <p style="margin-bottom: 0.5rem;">
                    <strong>Are you sure?</strong>
                    This will permanently delete {MapSet.size(@selected)} record(s).
                  </p>
                  <button phx-click="bulk_delete" class="btn btn-danger" style="margin-right: 0.5rem;">
                    Yes, Delete
                  </button>
                  <button phx-click="cancel_delete" class="btn btn-secondary">
                    Cancel
                  </button>
                </div>
              <% else %>
                <button phx-click="confirm_delete" class="btn btn-danger">
                  Delete Selected
                </button>
              <% end %>
            </div>
          </div>
        <% else %>
          <div style="border-top: 1px solid var(--border, #ddd); padding-top: 1rem; color: var(--text-muted, #666);">
            You don't have permission to perform bulk operations.
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
