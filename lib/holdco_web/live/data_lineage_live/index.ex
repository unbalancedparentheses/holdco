defmodule HoldcoWeb.DataLineageLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.Platform

  @impl true
  def mount(_params, _session, socket) do
    records = Platform.list_data_lineage()

    {:ok,
     assign(socket,
       page_title: "Data Lineage Tracker",
       records: records,
       show_form: false,
       editing_item: nil,
       filter_source_type: nil,
       filter_verified: nil
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: :add, editing_item: nil)}
  end

  def handle_event("close_form", _, socket) do
    {:noreply, assign(socket, show_form: false, editing_item: nil)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    record = Platform.get_data_lineage!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: record)}
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

  def handle_event("save", %{"data_lineage" => params}, socket) do
    case Platform.create_data_lineage(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Data lineage record created")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create data lineage record")}
    end
  end

  def handle_event("update", %{"data_lineage" => params}, socket) do
    record = socket.assigns.editing_item

    case Platform.update_data_lineage(record, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Data lineage record updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update data lineage record")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    record = Platform.get_data_lineage!(String.to_integer(id))

    case Platform.delete_data_lineage(record) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Data lineage record deleted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete data lineage record")}
    end
  end

  def handle_event("verify", %{"id" => id}, socket) do
    record = Platform.get_data_lineage!(String.to_integer(id))

    case Platform.update_data_lineage(record, %{verified: true, verified_at: DateTime.utc_now() |> DateTime.truncate(:second)}) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Record verified")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to verify record")}
    end
  end

  def handle_event("filter_source", %{"source_type" => source_type}, socket) do
    source_type = if source_type == "", do: nil, else: source_type
    records = Platform.list_data_lineage(%{entity_type: source_type})
    {:noreply, assign(socket, records: records, filter_source_type: source_type)}
  end

  def handle_event("show_unverified", _, socket) do
    records = Platform.unverified_lineage()
    {:noreply, assign(socket, records: records, filter_verified: false)}
  end

  def handle_event("clear_filters", _, socket) do
    {:noreply, reload(socket) |> assign(filter_source_type: nil, filter_verified: nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Data Lineage Tracker</h1>
          <p class="deck">Track data origins and transformations through the system</p>
        </div>
        <%= if @can_write do %>
          <button class="btn btn-primary" phx-click="show_form">Add Record</button>
        <% end %>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Records</div>
        <div class="metric-value">{length(@records)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Verified</div>
        <div class="metric-value">{Enum.count(@records, & &1.verified)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Unverified</div>
        <div class="metric-value">{Enum.count(@records, &(!&1.verified))}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">High Confidence</div>
        <div class="metric-value">{Enum.count(@records, &(&1.confidence == "high"))}</div>
      </div>
    </div>

    <div class="section">
      <div class="section-head"><h2>Filters</h2></div>
      <div class="panel" style="padding: 1rem; display: flex; gap: 1rem; align-items: center;">
        <button phx-click="show_unverified" class="btn btn-secondary btn-sm">Show Unverified Only</button>
        <button phx-click="clear_filters" class="btn btn-secondary btn-sm">Clear Filters</button>
      </div>
    </div>

    <div class="section">
      <div class="section-head"><h2>Lineage Records</h2></div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Source Type</th><th>Source ID</th><th>Target Entity</th><th>Target ID</th>
              <th>Transformation</th><th>Confidence</th><th>Verified</th><th></th>
            </tr>
          </thead>
          <tbody>
            <%= for r <- @records do %>
              <tr>
                <td><span class={"tag #{source_tag(r.source_type)}"}>{humanize(r.source_type)}</span></td>
                <td class="td-mono">{r.source_identifier || "---"}</td>
                <td>{r.target_entity_type}</td>
                <td class="td-mono">{r.target_entity_id}</td>
                <td>{r.transformation || "---"}</td>
                <td><span class={"tag #{confidence_tag(r.confidence)}"}>{humanize(r.confidence)}</span></td>
                <td>
                  <%= if r.verified do %>
                    <span class="tag tag-jade">Verified</span>
                  <% else %>
                    <span class="tag tag-lemon">Unverified</span>
                  <% end %>
                </td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <%= if !r.verified do %>
                        <button phx-click="verify" phx-value-id={r.id} class="btn btn-secondary btn-sm">Verify</button>
                      <% end %>
                      <button phx-click="edit" phx-value-id={r.id} class="btn btn-secondary btn-sm">Edit</button>
                      <button phx-click="delete" phx-value-id={r.id} class="btn btn-danger btn-sm" data-confirm="Delete this record?">Del</button>
                    </div>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @records == [] do %>
          <div class="empty-state">
            <p>No data lineage records found.</p>
            <%= if @can_write do %>
              <button class="btn btn-primary" phx-click="show_form">Add Your First Record</button>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit Data Lineage", else: "Add Data Lineage"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Source Type *</label>
                <select name="data_lineage[source_type]" class="form-select" required>
                  <%= for t <- ~w(manual_entry import bank_feed api_sync calculation migration) do %>
                    <option value={t} selected={@editing_item && @editing_item.source_type == t}>{humanize(t)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Source Identifier</label>
                <input type="text" name="data_lineage[source_identifier]" class="form-input" value={if @editing_item, do: @editing_item.source_identifier, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Target Entity Type *</label>
                <input type="text" name="data_lineage[target_entity_type]" class="form-input" value={if @editing_item, do: @editing_item.target_entity_type, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Target Entity ID *</label>
                <input type="number" name="data_lineage[target_entity_id]" class="form-input" value={if @editing_item, do: @editing_item.target_entity_id, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Transformation</label>
                <textarea name="data_lineage[transformation]" class="form-input">{if @editing_item, do: @editing_item.transformation, else: ""}</textarea>
              </div>
              <div class="form-group">
                <label class="form-label">Confidence</label>
                <select name="data_lineage[confidence]" class="form-select">
                  <%= for c <- ~w(high medium low) do %>
                    <option value={c} selected={@editing_item && @editing_item.confidence == c}>{humanize(c)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="data_lineage[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">{if @show_form == :edit, do: "Update", else: "Add Record"}</button>
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
    assign(socket, records: Platform.list_data_lineage())
  end

  defp humanize(str) when is_binary(str), do: str |> String.replace("_", " ") |> String.split(" ") |> Enum.map(&String.capitalize/1) |> Enum.join(" ")
  defp humanize(nil), do: "---"

  defp source_tag("manual_entry"), do: "tag-sky"
  defp source_tag("import"), do: "tag-jade"
  defp source_tag("bank_feed"), do: "tag-jade"
  defp source_tag("api_sync"), do: "tag-lemon"
  defp source_tag("calculation"), do: ""
  defp source_tag("migration"), do: "tag-lemon"
  defp source_tag(_), do: ""

  defp confidence_tag("high"), do: "tag-jade"
  defp confidence_tag("medium"), do: "tag-sky"
  defp confidence_tag("low"), do: "tag-lemon"
  defp confidence_tag(_), do: ""
end
