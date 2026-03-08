defmodule Holdco.Documents do
  import Ecto.Query
  alias Holdco.Repo
  alias Holdco.Documents.{Document, DocumentVersion, DocumentUpload}

  # Documents
  def list_documents(company_id \\ nil) do
    query = from(d in Document, order_by: d.name, preload: [:company, :versions, :uploads])
    query = if company_id, do: where(query, [d], d.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_document!(id) do
    Repo.get!(Document, id)
    |> Repo.preload([:company, :versions, :uploads])
  end

  def create_document(attrs) do
    %Document{}
    |> Document.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("documents", "create")
  end

  def update_document(%Document{} = doc, attrs) do
    doc
    |> Document.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("documents", "update")
  end

  def delete_document(%Document{} = doc) do
    Repo.delete(doc)
    |> audit_and_broadcast("documents", "delete")
  end

  # Document Versions
  def list_document_versions(document_id) do
    from(dv in DocumentVersion,
      where: dv.document_id == ^document_id,
      order_by: [desc: dv.version_number]
    )
    |> Repo.all()
  end

  def get_document_version!(id), do: Repo.get!(DocumentVersion, id)

  def create_document_version(attrs) do
    %DocumentVersion{}
    |> DocumentVersion.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("document_versions", "create")
  end

  def update_document_version(%DocumentVersion{} = dv, attrs) do
    dv
    |> DocumentVersion.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("document_versions", "update")
  end

  def delete_document_version(%DocumentVersion{} = dv) do
    Repo.delete(dv)
    |> audit_and_broadcast("document_versions", "delete")
  end

  # Document Uploads
  def list_document_uploads(document_id) do
    from(du in DocumentUpload,
      where: du.document_id == ^document_id,
      order_by: [desc: du.inserted_at]
    )
    |> Repo.all()
  end

  def get_document_upload!(id), do: Repo.get!(DocumentUpload, id)

  def create_document_upload(attrs) do
    %DocumentUpload{}
    |> DocumentUpload.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("document_uploads", "create")
  end

  def update_document_upload(%DocumentUpload{} = du, attrs) do
    du
    |> DocumentUpload.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("document_uploads", "update")
  end

  def delete_document_upload(%DocumentUpload{} = du) do
    Repo.delete(du)
    |> audit_and_broadcast("document_uploads", "delete")
  end

  # PubSub
  def subscribe, do: Phoenix.PubSub.subscribe(Holdco.PubSub, "documents")
  defp broadcast(message), do: Phoenix.PubSub.broadcast(Holdco.PubSub, "documents", message)

  defp audit_and_broadcast(result, table, action) do
    case result do
      {:ok, record} ->
        Holdco.Platform.log_action(action, table, record.id)
        broadcast({String.to_atom("#{table}_#{action}d"), record})
        {:ok, record}

      error ->
        error
    end
  end
end
