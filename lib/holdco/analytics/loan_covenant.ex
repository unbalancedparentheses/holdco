defmodule Holdco.Analytics.LoanCovenant do
  use Ecto.Schema
  import Ecto.Changeset

  @covenant_types ~w(financial reporting affirmative negative)
  @comparisons ~w(above below between)
  @statuses ~w(compliant warning breached waived)
  @frequencies ~w(monthly quarterly annually)

  schema "loan_covenants" do
    field :name, :string
    field :description, :string
    field :covenant_type, :string
    field :metric, :string
    field :threshold, :decimal
    field :comparison, :string
    field :upper_bound, :decimal
    field :current_value, :decimal
    field :status, :string, default: "compliant"
    field :measurement_frequency, :string, default: "quarterly"
    field :last_measured_at, :utc_datetime
    field :next_measurement_date, :date
    field :breach_count, :integer, default: 0
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company
    belongs_to :liability, Holdco.Finance.Liability

    timestamps(type: :utc_datetime)
  end

  def changeset(covenant, attrs) do
    covenant
    |> cast(attrs, [
      :company_id,
      :liability_id,
      :name,
      :description,
      :covenant_type,
      :metric,
      :threshold,
      :comparison,
      :upper_bound,
      :current_value,
      :status,
      :measurement_frequency,
      :last_measured_at,
      :next_measurement_date,
      :breach_count,
      :notes
    ])
    |> validate_required([:name, :covenant_type])
    |> validate_inclusion(:covenant_type, @covenant_types)
    |> validate_inclusion(:comparison, @comparisons)
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:measurement_frequency, @frequencies)
  end
end
