defmodule Holdco.Compliance.RegulatoryFiling do
  use Ecto.Schema
  import Ecto.Changeset

  schema "regulatory_filings" do
    field :jurisdiction, :string
    field :filing_type, :string
    field :due_date, :string
    field :filed_date, :string
    field :status, :string, default: "pending"
    field :reference_number, :string
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(regulatory_filing, attrs) do
    regulatory_filing
    |> cast(attrs, [
      :company_id,
      :jurisdiction,
      :filing_type,
      :due_date,
      :filed_date,
      :status,
      :reference_number,
      :notes
    ])
    |> validate_required([:company_id, :jurisdiction, :filing_type, :due_date])
  end
end
