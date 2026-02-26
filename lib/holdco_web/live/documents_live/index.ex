defmodule HoldcoWeb.DocumentsLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Documents, Corporate}

  @upload_dir Path.join([:code.priv_dir(:holdco), "static", "uploads"])

  @impl true
  def mount(_params, _session, socket) do
    documents = Documents.list_documents()
    companies = Corporate.list_companies()

    {:ok,
     socket
     |> assign(
       page_title: "Documents",
       documents: documents,
       companies: companies,
       selected_company_id: "",
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
    company_id = if id == "", do: nil, else: String.to_integer(id)

    documents =
      Documents.list_documents()
      |> then(fn docs ->
        if company_id, do: Enum.filter(docs, &(&1.company_id == company_id)), else: docs
      end)

    {:noreply, assign(socket, selected_company_id: id, documents: documents)}
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
        documents = Documents.list_documents()

        {:noreply,
         socket
         |> assign(documents: documents, show_form: false, editing_item: nil)
         |> put_flash(:info, "Document added")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add document")}
    end
  end

  def handle_event("update", %{"document" => params}, socket) do
    document = socket.assigns.editing_item

    case Documents.update_document(document, params) do
      {:ok, _} ->
        documents = Documents.list_documents()

        {:noreply,
         socket
         |> assign(documents: documents, show_form: false, editing_item: nil)
         |> put_flash(:info, "Document updated")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update document")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    document = Documents.get_document!(String.to_integer(id))
    Documents.delete_document(document)
    documents = Documents.list_documents()
    {:noreply, assign(socket, documents: documents) |> put_flash(:info, "Document deleted")}
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

    <%= if @show_form == :add do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click="noop">
          <div class="modal-header">
            <h3>Add Document</h3>
          </div>
          <div class="modal-body">
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
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click="noop">
          <div class="modal-header">
            <h3>Edit Document</h3>
          </div>
          <div class="modal-body">
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
