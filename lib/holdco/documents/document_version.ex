defmodule Holdco.Documents.DocumentVersion do
  use Ecto.Schema
  import Ecto.Changeset

  schema "document_versions" do
    field :version_number, :integer, default: 1
    field :url, :string
    field :uploaded_by, :string
    field :notes, :string

    belongs_to :document, Holdco.Documents.Document

    timestamps(type: :utc_datetime)
  end

  def changeset(document_version, attrs) do
    document_version
    |> cast(attrs, [:document_id, :version_number, :url, :uploaded_by, :notes])
    |> validate_required([:document_id])
  end
end
