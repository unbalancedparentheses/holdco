defmodule Holdco.Compliance.EsgReport do
  use Ecto.Schema
  import Ecto.Changeset

  @frameworks ~w(gri sasb tcfd custom)
  @statuses ~w(draft under_review published)

  schema "esg_reports" do
    field :framework, :string, default: "gri"
    field :reporting_period_start, :date
    field :reporting_period_end, :date
    field :title, :string
    field :metrics, :map, default: %{}
    field :score, :decimal
    field :status, :string, default: "draft"
    field :published_date, :date
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(esg_report, attrs) do
    esg_report
    |> cast(attrs, [
      :company_id,
      :framework,
      :reporting_period_start,
      :reporting_period_end,
      :title,
      :metrics,
      :score,
      :status,
      :published_date,
      :notes
    ])
    |> validate_required([:company_id, :framework, :reporting_period_start, :reporting_period_end, :title])
    |> validate_inclusion(:framework, @frameworks)
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:company_id)
  end

  def frameworks, do: @frameworks
  def statuses, do: @statuses
end
