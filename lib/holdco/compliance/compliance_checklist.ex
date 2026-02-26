defmodule Holdco.Compliance.ComplianceChecklist do
  use Ecto.Schema
  import Ecto.Changeset

  schema "compliance_checklists" do
    field :jurisdiction, :string
    field :item, :string
    field :category, :string, default: "regulatory"
    field :completed, :boolean, default: false
    field :due_date, :string
    field :completed_date, :string
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(compliance_checklist, attrs) do
    compliance_checklist
    |> cast(attrs, [
      :company_id,
      :jurisdiction,
      :item,
      :category,
      :completed,
      :due_date,
      :completed_date,
      :notes
    ])
    |> validate_required([:company_id, :jurisdiction, :item])
  end
end
