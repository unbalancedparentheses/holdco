defmodule Holdco.Compliance.FatcaReport do
  use Ecto.Schema
  import Ecto.Changeset

  schema "fatca_reports" do
    field :reporting_year, :integer
    field :jurisdiction, :string
    field :report_type, :string, default: "fatca"
    field :status, :string, default: "not_started"
    field :filed_date, :string
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(fatca_report, attrs) do
    fatca_report
    |> cast(attrs, [:company_id, :reporting_year, :jurisdiction, :report_type,
                     :status, :filed_date, :notes])
    |> validate_required([:company_id, :reporting_year, :jurisdiction])
  end
end
