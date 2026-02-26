defmodule Holdco.Documents.Document do
  use Ecto.Schema
  import Ecto.Changeset

  schema "documents" do
    field :name, :string
    field :doc_type, :string
    field :url, :string
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company
    has_many :versions, Holdco.Documents.DocumentVersion
    has_many :uploads, Holdco.Documents.DocumentUpload

    timestamps(type: :utc_datetime)
  end

  def changeset(document, attrs) do
    document
    |> cast(attrs, [:company_id, :name, :doc_type, :url, :notes])
    |> validate_required([:company_id, :name])
  end
end
