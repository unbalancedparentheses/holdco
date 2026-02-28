defmodule HoldcoWeb.DocumentIntelligenceLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.Documents
  alias Holdco.Documents.Extraction

  @impl true
  def mount(_params, _session, socket) do
    extractions = Documents.list_extractions()

    {:ok,
     assign(socket,
       page_title: "Document Intelligence",
       extractions: extractions,
       show_form: false,
       editing_item: nil,
       show_data: nil
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
    extraction = Documents.get_extraction!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: extraction)}
  end

  def handle_event("save", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("update", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("save", %{"extraction" => params}, socket) do
    case Documents.create_extraction(params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Extraction created")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create extraction")}
    end
  end

  def handle_event("update", %{"extraction" => params}, socket) do
    extraction = socket.assigns.editing_item

    case Documents.update_extraction(extraction, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Extraction updated")
         |> assign(show_form: false, editing_item: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update extraction")}
    end
  end

  def handle_event("mark_reviewed", %{"id" => id}, socket) do
    extraction = Documents.get_extraction!(String.to_integer(id))
    user_id = socket.assigns.current_scope.user.id

    case Documents.mark_extraction_reviewed(extraction, user_id) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> put_flash(:info, "Extraction marked as reviewed")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to mark as reviewed")}
    end
  end

  def handle_event("show_data", %{"id" => id}, socket) do
    extraction = Documents.get_extraction!(String.to_integer(id))
    {:noreply, assign(socket, show_data: extraction)}
  end

  def handle_event("close_data", _, socket) do
    {:noreply, assign(socket, show_data: nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Document Intelligence</h1>
          <p class="deck">AI-powered document extraction and analysis</p>
        </div>
        <%= if @can_write do %>
          <button class="btn btn-primary" phx-click="show_form">New Extraction</button>
        <% end %>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Extractions</div>
        <div class="metric-value">{length(@extractions)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Completed</div>
        <div class="metric-value">{Enum.count(@extractions, &(&1.status == "completed"))}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Pending Review</div>
        <div class="metric-value">{Enum.count(@extractions, &(&1.status == "completed" && !&1.reviewed))}</div>
      </div>
    </div>

    <div class="section">
      <div class="section-head"><h2>All Extractions</h2></div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Document</th><th>Type</th><th>Status</th><th>Confidence</th>
              <th>Model</th><th>Reviewed</th><th></th>
            </tr>
          </thead>
          <tbody>
            <%= for e <- @extractions do %>
              <tr>
                <td class="td-name">{if e.document, do: e.document.name, else: "---"}</td>
                <td><span class="tag tag-sky">{humanize(e.extraction_type)}</span></td>
                <td><span class={"tag #{status_tag(e.status)}"}>{humanize(e.status)}</span></td>
                <td class="td-num">{if e.confidence_score, do: "#{Decimal.round(e.confidence_score, 2)}", else: "---"}</td>
                <td>{e.model_used || "---"}</td>
                <td>{if e.reviewed, do: "Yes", else: "No"}</td>
                <td>
                  <div style="display: flex; gap: 0.25rem;">
                    <button phx-click="show_data" phx-value-id={e.id} class="btn btn-secondary btn-sm">View Data</button>
                    <%= if @can_write && !e.reviewed do %>
                      <button phx-click="mark_reviewed" phx-value-id={e.id} class="btn btn-primary btn-sm">Review</button>
                    <% end %>
                    <%= if @can_write do %>
                      <button phx-click="edit" phx-value-id={e.id} class="btn btn-secondary btn-sm">Edit</button>
                    <% end %>
                  </div>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @extractions == [] do %>
          <div class="empty-state">
            <p>No extractions found.</p>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @show_data do %>
      <div class="dialog-overlay" phx-click="close_data">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header"><h3>Extracted Data</h3></div>
          <div class="dialog-body">
            <pre style="background: #f5f5f5; padding: 1rem; border-radius: 4px; overflow: auto; max-height: 400px;">{Jason.encode!(@show_data.extracted_data, pretty: true)}</pre>
            <div class="form-actions">
              <button phx-click="close_data" class="btn btn-secondary">Close</button>
            </div>
          </div>
        </div>
      </div>
    <% end %>

    <%= if @show_form do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_form == :edit, do: "Edit Extraction", else: "New Extraction"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_form == :edit, do: "update", else: "save"}>
              <div class="form-group">
                <label class="form-label">Document ID *</label>
                <input type="number" name="extraction[document_id]" class="form-input" value={if @editing_item, do: @editing_item.document_id, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Extraction Type *</label>
                <select name="extraction[extraction_type]" class="form-select" required>
                  <%= for t <- Extraction.extraction_types() do %>
                    <option value={t} selected={@editing_item && @editing_item.extraction_type == t}>{humanize(t)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Status</label>
                <select name="extraction[status]" class="form-select">
                  <%= for s <- Extraction.statuses() do %>
                    <option value={s} selected={@editing_item && @editing_item.status == s}>{humanize(s)}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Model Used</label>
                <input type="text" name="extraction[model_used]" class="form-input" value={if @editing_item, do: @editing_item.model_used, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label>
                <textarea name="extraction[notes]" class="form-input">{if @editing_item, do: @editing_item.notes, else: ""}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">{if @show_form == :edit, do: "Update", else: "Create"}</button>
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
    assign(socket, extractions: Documents.list_extractions())
  end

  defp humanize(str), do: str |> String.replace("_", " ") |> String.split(" ") |> Enum.map(&String.capitalize/1) |> Enum.join(" ")

  defp status_tag("pending"), do: "tag-lemon"
  defp status_tag("processing"), do: "tag-sky"
  defp status_tag("completed"), do: "tag-jade"
  defp status_tag("failed"), do: "tag-rose"
  defp status_tag(_), do: ""
end
