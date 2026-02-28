defmodule Holdco.Compliance.ReportingTemplate do
  use Ecto.Schema
  import Ecto.Changeset

  @template_types ~w(crs fatca bo_register aml_report regulatory_return tax_return)
  @frequencies ~w(annual semi_annual quarterly monthly ad_hoc)

  schema "reporting_templates" do
    field :name, :string
    field :template_type, :string, default: "crs"
    field :jurisdiction, :string
    field :frequency, :string, default: "annual"
    field :due_date_formula, :string
    field :fields, :map, default: %{}
    field :is_active, :boolean, default: true
    field :notes, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(template, attrs) do
    template
    |> cast(attrs, [
      :name,
      :template_type,
      :jurisdiction,
      :frequency,
      :due_date_formula,
      :fields,
      :is_active,
      :notes
    ])
    |> validate_required([:name, :template_type, :frequency])
    |> validate_inclusion(:template_type, @template_types)
    |> validate_inclusion(:frequency, @frequencies)
  end

  def template_types, do: @template_types
  def frequencies, do: @frequencies
end
