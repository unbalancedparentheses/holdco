defmodule HoldcoWeb.DocumentsLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Documents, Corporate}

  @impl true
  def mount(_params, _session, socket) do
    documents = Documents.list_documents()
    companies = Corporate.list_companies()

    {:ok, assign(socket,
      page_title: "Documents",
      documents: documents,
      companies: companies,
      show_form: false
    )}
  end

  @impl true
  def handle_event("show_form", _, socket), do: {:noreply, assign(socket, show_form: true)}
  def handle_event("close_form", _, socket), do: {:noreply, assign(socket, show_form: false)}

  def handle_event("save", %{"document" => params}, socket) do
    case Documents.create_document(params) do
      {:ok, _} ->
        documents = Documents.list_documents()
        {:noreply, assign(socket, documents: documents, show_form: false) |> put_flash(:info, "Document added")}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add document")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    document = Documents.get_document!(String.to_integer(id))
    Documents.delete_document(document)
    documents = Documents.list_documents()
    {:noreply, assign(socket, documents: documents) |> put_flash(:info, "Document deleted")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Documents</h1>
          <p class="deck"><%= length(@documents) %> documents in the library</p>
        </div>
        <button class="btn btn-primary" phx-click="show_form">Add Document</button>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="section">
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>Type</th>
              <th>Company</th>
              <th>Date</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for doc <- @documents do %>
              <tr>
                <td class="td-name"><%= doc.name %></td>
                <td><span class="tag tag-ink"><%= doc.doc_type %></span></td>
                <td><%= if doc.company, do: doc.company.name, else: "---" %></td>
                <td class="td-mono"><%= if doc.inserted_at, do: Calendar.strftime(doc.inserted_at, "%Y-%m-%d") %></td>
                <td><button phx-click="delete" phx-value-id={doc.id} class="btn btn-danger btn-sm" data-confirm="Delete?">Del</button></td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @documents == [] do %>
          <div class="empty-state">No documents yet.</div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click-away="close_form">
          <div class="modal-header"><h3>Add Document</h3></div>
          <div class="modal-body">
            <form phx-submit="save">
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="document[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %><option value={c.id}><%= c.name %></option><% end %>
                </select>
              </div>
              <div class="form-group"><label class="form-label">Name *</label><input type="text" name="document[name]" class="form-input" required /></div>
              <div class="form-group"><label class="form-label">Type</label><input type="text" name="document[doc_type]" class="form-input" placeholder="e.g. contract, certificate, report" /></div>
              <div class="form-group"><label class="form-label">URL</label><input type="text" name="document[url]" class="form-input" /></div>
              <div class="form-group"><label class="form-label">Notes</label><textarea name="document[notes]" class="form-input"></textarea></div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Add Document</button>
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
