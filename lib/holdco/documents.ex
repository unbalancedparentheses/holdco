defmodule Holdco.Documents do
  import Ecto.Query
  alias Holdco.Repo
  alias Holdco.Documents.{Document, DocumentVersion, DocumentUpload, SignatureWorkflow}

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

  # Signature Workflows
  def list_signature_workflows(company_id \\ nil) do
    query = from(sw in SignatureWorkflow,
      order_by: [desc: sw.inserted_at],
      preload: [:company, :document]
    )
    query = if company_id, do: where(query, [sw], sw.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_signature_workflow!(id) do
    Repo.get!(SignatureWorkflow, id)
    |> Repo.preload([:company, :document])
  end

  def create_signature_workflow(attrs) do
    %SignatureWorkflow{}
    |> SignatureWorkflow.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("signature_workflows", "create")
  end

  def update_signature_workflow(%SignatureWorkflow{} = sw, attrs) do
    sw
    |> SignatureWorkflow.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("signature_workflows", "update")
  end

  def delete_signature_workflow(%SignatureWorkflow{} = sw) do
    Repo.delete(sw)
    |> audit_and_broadcast("signature_workflows", "delete")
  end

  def pending_signatures do
    from(sw in SignatureWorkflow,
      where: sw.status in ["pending_signatures", "partially_signed"],
      order_by: [asc: sw.expiry_date],
      preload: [:company, :document]
    )
    |> Repo.all()
  end

  def sign_document(workflow_id, signer_email) do
    workflow = get_signature_workflow!(workflow_id)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    updated_signers =
      Enum.map(workflow.signers, fn signer ->
        if signer["email"] == signer_email and signer["status"] != "signed" do
          Map.merge(signer, %{"status" => "signed", "signed_at" => DateTime.to_iso8601(now)})
        else
          signer
        end
      end)

    all_signed = Enum.all?(updated_signers, fn s -> s["status"] == "signed" end)
    any_signed = Enum.any?(updated_signers, fn s -> s["status"] == "signed" end)

    new_status =
      cond do
        all_signed -> "completed"
        any_signed -> "partially_signed"
        true -> workflow.status
      end

    update_signature_workflow(workflow, %{signers: updated_signers, status: new_status})
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
