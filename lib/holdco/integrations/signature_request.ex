defmodule Holdco.Integrations.SignatureRequest do
  use Ecto.Schema
  import Ecto.Changeset

  schema "signature_requests" do
    field :provider, :string
    field :external_id, :string, default: ""
    field :status, :string, default: "draft"
    field :signers, :string, default: ""
    field :sent_at, :utc_datetime
    field :completed_at, :utc_datetime
    field :notes, :string, default: ""

    belongs_to :company, Holdco.Corporate.Company
    belongs_to :document, Holdco.Documents.Document

    timestamps(type: :utc_datetime)
  end

  def changeset(signature_request, attrs) do
    signature_request
    |> cast(attrs, [
      :company_id,
      :document_id,
      :provider,
      :external_id,
      :status,
      :signers,
      :sent_at,
      :completed_at,
      :notes
    ])
    |> validate_required([:company_id, :document_id, :provider])
  end
end
