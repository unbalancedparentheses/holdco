defmodule Holdco.Compliance.TaxDeadline do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tax_deadlines" do
    field :jurisdiction, :string
    field :description, :string
    field :due_date, :string
    field :status, :string, default: "pending"
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(tax_deadline, attrs) do
    tax_deadline
    |> cast(attrs, [:company_id, :jurisdiction, :description, :due_date, :status, :notes])
    |> validate_required([:company_id, :jurisdiction, :description, :due_date])
  end
end
