defmodule HoldcoWeb.DocumentsLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Documents, Corporate}

  @upload_dir Path.join([:code.priv_dir(:holdco), "static", "uploads"])

  @impl true
  def mount(_params, _session, socket) do
    all_documents = Documents.list_documents()
    companies = Corporate.list_companies()

    total_files =
      all_documents
      |> Enum.flat_map(fn d ->
        if Ecto.assoc_loaded?(d.uploads), do: d.uploads, else: []
      end)
      |> length()

    doc_types =
      all_documents
      |> Enum.map(& &1.doc_type)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> Enum.sort()

    recent_uploads =
      all_documents
      |> Enum.sort_by(& &1.inserted_at, {:desc, NaiveDateTime})
      |> Enum.take(5)

    {:ok,
     socket
     |> assign(
       page_title: "Documents",
       documents: all_documents,
       all_documents: all_documents,
       total_files: total_files,
       doc_types: doc_types,
       recent_uploads: recent_uploads,
       companies: companies,
       selected_company_id: "",
       selected_doc_type: "",
       search_query: "",
       show_form: false,
       editing_item: nil
     )
     |> allow_upload(:file,
       accept: ~w(.pdf .doc .docx .xls .xlsx .png .jpg),
       max_file_size: 20_000_000
     )}
  end

  @impl true
  def handle_event("show_form", _, socket),
    do: {:noreply, assign(socket, show_form: :add, editing_item: nil)}

  def handle_event("close_form", _, socket),
    do: {:noreply, assign(socket, show_form: false, editing_item: nil)}

  def handle_event("noop", _, socket), do: {:noreply, socket}
  def handle_event("validate", _params, socket), do: {:noreply, socket}

  def handle_event("edit", %{"id" => id}, socket) do
    document = Documents.get_document!(String.to_integer(id))
    {:noreply, assign(socket, show_form: :edit, editing_item: document)}
  end

  def handle_event("filter_company", %{"company_id" => id}, socket) do
    {:noreply, assign(socket, selected_company_id: id) |> apply_filters()}
  end

  def handle_event("filter_doc_type", %{"doc_type" => type}, socket) do
    {:noreply, assign(socket, selected_doc_type: type) |> apply_filters()}
  end

  def handle_event("search_docs", %{"q" => q}, socket) do
    {:noreply, assign(socket, search_query: q) |> apply_filters()}
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

  def handle_event("save", %{"document" => params}, socket) do
    case Documents.create_document(params) do
      {:ok, document} ->
        process_uploads(socket, document)

        {:noreply,
         reload(socket)
         |> assign(show_form: false, editing_item: nil)
         |> put_flash(:info, "Document added")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add document")}
    end
  end

  def handle_event("update", %{"document" => params}, socket) do
    document = socket.assigns.editing_item

    case Documents.update_document(document, params) do
      {:ok, _} ->
        {:noreply,
         reload(socket)
         |> assign(show_form: false, editing_item: nil)
         |> put_flash(:info, "Document updated")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update document")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    document = Documents.get_document!(String.to_integer(id))
    Documents.delete_document(document)
    {:noreply, reload(socket) |> put_flash(:info, "Document deleted")}
  end

  defp reload(socket) do
    all_documents = Documents.list_documents()

    total_files =
      all_documents
      |> Enum.flat_map(fn d ->
        if Ecto.assoc_loaded?(d.uploads), do: d.uploads, else: []
      end)
      |> length()

    doc_types =
      all_documents
      |> Enum.map(& &1.doc_type)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> Enum.sort()

    socket
    |> assign(
      all_documents: all_documents,
      total_files: total_files,
      doc_types: doc_types
    )
    |> apply_filters()
  end

  defp apply_filters(socket) do
    docs = socket.assigns.all_documents
    company_id = socket.assigns.selected_company_id
    doc_type = socket.assigns.selected_doc_type
    query = String.downcase(socket.assigns.search_query || "")

    docs =
      if company_id != "" do
        cid = String.to_integer(company_id)
        Enum.filter(docs, &(&1.company_id == cid))
      else
        docs
      end

    docs =
      if doc_type != "" do
        Enum.filter(docs, &(&1.doc_type == doc_type))
      else
        docs
      end

    docs =
      if query != "" do
        Enum.filter(docs, fn d ->
          String.contains?(String.downcase(d.name || ""), query) or
            String.contains?(String.downcase(d.doc_type || ""), query)
        end)
      else
        docs
      end

    recent_uploads =
      docs
      |> Enum.sort_by(& &1.inserted_at, {:desc, NaiveDateTime})
      |> Enum.take(5)

    assign(socket, documents: docs, recent_uploads: recent_uploads)
  end

  defp process_uploads(socket, document) do
    File.mkdir_p!(@upload_dir)

    consume_uploaded_entries(socket, :file, fn %{path: tmp_path}, entry ->
      unique_name = unique_file_name(entry.client_name)
      dest = Path.join(@upload_dir, unique_name)
      File.cp!(tmp_path, dest)

      Documents.create_document_upload(%{
        document_id: document.id,
        file_path: dest,
        file_name: entry.client_name,
        file_size: entry.client_size,
        content_type: entry.client_type
      })

      {:ok, unique_name}
    end)
  end

  defp unique_file_name(original_name) do
    ext = Path.extname(original_name)
    base = Path.basename(original_name, ext)
    timestamp = System.system_time(:millisecond)
    random = :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
    "#{base}_#{timestamp}_#{random}#{ext}"
  end

  defp upload_count(document) do
    if Ecto.assoc_loaded?(document.uploads) do
      length(document.uploads)
    else
      0
    end
  end

  defp uploads_for(document) do
    if Ecto.assoc_loaded?(document.uploads), do: document.uploads, else: []
  end

  defp image?(upload) do
    String.starts_with?(upload.content_type || "", "image/") or
      Path.extname(upload.file_name) in ~w(.png .jpg .jpeg .gif .webp)
  end

  defp pdf?(upload) do
    upload.content_type == "application/pdf" or
      Path.extname(upload.file_name) == ".pdf"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Documents</h1>
          <p class="deck">{length(@documents)} documents in the library</p>
        </div>
        <%= if @can_write do %>
          <button class="btn btn-primary" phx-click="show_form">Add Document</button>
        <% end %>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Documents</div>
        <div class="metric-value">{length(@all_documents)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Total Files</div>
        <div class="metric-value">{@total_files}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Document Types</div>
        <div class="metric-value">{length(@doc_types)}</div>
      </div>
    </div>

    <div style="margin-bottom: 1rem; display: flex; gap: 1rem; flex-wrap: wrap; align-items: center;">
      <form phx-change="filter_company" style="display: flex; align-items: center; gap: 0.5rem;">
        <label class="form-label" style="margin: 0; font-size: 0.85rem;">Company</label>
        <select name="company_id" class="form-select" style="width: auto; padding: 0.3rem 0.5rem;">
          <option value="">All Companies</option>
          <%= for c <- @companies do %>
            <option value={c.id} selected={to_string(c.id) == @selected_company_id}>{c.name}</option>
          <% end %>
        </select>
      </form>
      <form phx-change="filter_doc_type" style="display: flex; align-items: center; gap: 0.5rem;">
        <label class="form-label" style="margin: 0; font-size: 0.85rem;">Type</label>
        <select name="doc_type" class="form-select" style="width: auto; padding: 0.3rem 0.5rem;">
          <option value="">All Types</option>
          <%= for t <- @doc_types do %>
            <option value={t} selected={t == @selected_doc_type}>{t}</option>
          <% end %>
        </select>
      </form>
      <form phx-change="search_docs" style="display: flex; align-items: center; gap: 0.5rem;">
        <input type="text" name="q" value={@search_query} placeholder="Search documents..." class="form-input" style="width: 200px; padding: 0.3rem 0.5rem;" phx-debounce="200" />
      </form>
    </div>

    <div class="section">
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>Type</th>
              <th>Company</th>
              <th>Files</th>
              <th>Date</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for doc <- @documents do %>
              <tr>
                <td class="td-name">{doc.name}</td>
                <td><span class="tag tag-ink">{doc.doc_type}</span></td>
                <td>
                  <%= if doc.company do %>
                    <.link navigate={~p"/companies/#{doc.company.id}"} class="td-link">{doc.company.name}</.link>
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td>
                  <%= if upload_count(doc) > 0 do %>
                    <div style="display: flex; flex-direction: column; gap: 0.35rem;">
                      <%= for upload <- uploads_for(doc) do %>
                        <div style="display: flex; align-items: center; gap: 0.5rem; flex-wrap: wrap;">
                          <%= if image?(upload) do %>
                            <a href={~p"/downloads/#{upload.id}/preview"} target="_blank">
                              <img
                                src={~p"/downloads/#{upload.id}/preview"}
                                alt={upload.file_name}
                                style="max-width: 48px; max-height: 48px; border-radius: 4px; border: 1px solid var(--border);"
                              />
                            </a>
                          <% end %>
                          <span style="font-size: 0.85rem;">{upload.file_name}</span>
                          <a href={~p"/downloads/#{upload.id}"} class="btn btn-secondary btn-sm">
                            Download
                          </a>
                          <%= if pdf?(upload) do %>
                            <a
                              href={~p"/downloads/#{upload.id}/preview"}
                              target="_blank"
                              class="btn btn-secondary btn-sm"
                            >
                              View
                            </a>
                          <% end %>
                        </div>
                      <% end %>
                    </div>
                  <% else %>
                    <span style="color: var(--muted);">---</span>
                  <% end %>
                </td>
                <td class="td-mono">
                  {if doc.inserted_at, do: Calendar.strftime(doc.inserted_at, "%Y-%m-%d")}
                </td>
                <td>
                  <%= if @can_write do %>
                    <div style="display: flex; gap: 0.25rem;">
                      <button
                        phx-click="edit"
                        phx-value-id={doc.id}
                        class="btn btn-secondary btn-sm"
                      >
                        Edit
                      </button>
                      <button
                        phx-click="delete"
                        phx-value-id={doc.id}
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
        <%= if @documents == [] do %>
          <div class="empty-state">
            <p>No documents yet.</p>
            <p style="color: var(--muted); font-size: 0.9rem;">Store contracts, certificates, reports, and other files for your entities.</p>
          </div>
        <% end %>
      </div>
    </div>

    <%= if @recent_uploads != [] do %>
      <div class="section">
        <div class="section-head">
          <h2>Recent Uploads</h2>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Name</th>
                <th>Type</th>
                <th>Date</th>
              </tr>
            </thead>
            <tbody>
              <%= for doc <- @recent_uploads do %>
                <tr>
                  <td class="td-name">{doc.name}</td>
                  <td><span class="tag tag-ink">{doc.doc_type}</span></td>
                  <td class="td-mono">{if doc.inserted_at, do: Calendar.strftime(doc.inserted_at, "%Y-%m-%d")}</td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    <% end %>

    <%= if @show_form == :add do %>
      <div class="dialog-overlay" phx-click="close_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>Add Document</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit="save" phx-change="validate">
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="document[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Name *</label>
                <input type="text" name="document[name]" class="form-input" required />
              </div>
              <div class="form-group">
                <label class="form-label">Type</label>
                <input
                  type="text"
                  name="document[doc_type]"
                  class="form-input"
                  placeholder="e.g. contract, certificate, report"
                />
              </div>
              <div class="form-group">
                <label class="form-label">URL</label>
                <input type="text" name="document[url]" class="form-input" />
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label><textarea
                  name="document[notes]"
                  class="form-input"
                ></textarea>
              </div>
              <div class="form-group">
                <label class="form-label">Attach Files</label>
                <.live_file_input upload={@uploads.file} />
                <%= for entry <- @uploads.file.entries do %>
                  <div style="margin-top: 0.5rem; font-size: 0.875rem;">
                    <span>{entry.client_name}</span>
                    <progress
                      value={entry.progress}
                      max="100"
                      style="width: 100px; margin-left: 0.5rem;"
                    >
                      {entry.progress}%
                    </progress>
                    <%= for err <- upload_errors(@uploads.file, entry) do %>
                      <span style="color: var(--danger);">&mdash; {humanize_upload_error(err)}</span>
                    <% end %>
                  </div>
                <% end %>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Add Document</button>
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
          <div class="dialog-header">
            <h3>Edit Document</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit="update">
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="document[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %>
                    <option value={c.id} selected={c.id == @editing_item.company_id}>{c.name}</option>
                  <% end %>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Name *</label>
                <input type="text" name="document[name]" class="form-input" value={@editing_item.name} required />
              </div>
              <div class="form-group">
                <label class="form-label">Type</label>
                <input
                  type="text"
                  name="document[doc_type]"
                  class="form-input"
                  value={@editing_item.doc_type}
                  placeholder="e.g. contract, certificate, report"
                />
              </div>
              <div class="form-group">
                <label class="form-label">URL</label>
                <input type="text" name="document[url]" class="form-input" value={@editing_item.url} />
              </div>
              <div class="form-group">
                <label class="form-label">Notes</label><textarea
                  name="document[notes]"
                  class="form-input"
                >{@editing_item.notes}</textarea>
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Update Document</button>
                <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp humanize_upload_error(:too_large), do: "File is too large (max 20 MB)"
  defp humanize_upload_error(:too_many_files), do: "Too many files"
  defp humanize_upload_error(:not_accepted), do: "File type not accepted"
  defp humanize_upload_error(err), do: "Upload error: #{inspect(err)}"
end
