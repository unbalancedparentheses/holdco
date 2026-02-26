defmodule Holdco.Compliance.SanctionsCheck do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sanctions_checks" do
    field :checked_name, :string
    field :status, :string, default: "clear"
    field :notes, :string, default: ""

    belongs_to :company, Holdco.Corporate.Company
    belongs_to :matched_entry, Holdco.Compliance.SanctionsEntry

    timestamps(type: :utc_datetime)
  end

  def changeset(sanctions_check, attrs) do
    sanctions_check
    |> cast(attrs, [:company_id, :checked_name, :status, :matched_entry_id, :notes])
    |> validate_required([:company_id, :checked_name])
  end
end
