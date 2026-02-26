defmodule Holdco.Documents.DocumentUpload do
  use Ecto.Schema
  import Ecto.Changeset

  schema "document_uploads" do
    field :storage_backend, :string, default: "local"
    field :file_path, :string
    field :file_name, :string
    field :file_size, :integer, default: 0
    field :content_type, :string, default: ""
    field :checksum, :string, default: ""
    field :uploaded_by, :string, default: ""

    belongs_to :document, Holdco.Documents.Document

    timestamps(type: :utc_datetime)
  end

  def changeset(document_upload, attrs) do
    document_upload
    |> cast(attrs, [
      :document_id,
      :storage_backend,
      :file_path,
      :file_name,
      :file_size,
      :content_type,
      :checksum,
      :uploaded_by
    ])
    |> validate_required([:document_id, :file_path, :file_name])
  end
end
