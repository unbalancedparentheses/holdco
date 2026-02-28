defmodule Holdco.Finance.CompensationRecord do
  use Ecto.Schema
  import Ecto.Changeset

  @compensation_types ~w(salary bonus equity commission benefit severance)
  @frequencies ~w(monthly quarterly annual one_time)
  @statuses ~w(active pending terminated)

  schema "compensation_records" do
    field :employee_name, :string
    field :role, :string
    field :department, :string
    field :compensation_type, :string, default: "salary"
    field :amount, :decimal
    field :currency, :string, default: "USD"
    field :frequency, :string, default: "annual"
    field :effective_date, :date
    field :end_date, :date
    field :vesting_schedule, :string
    field :status, :string, default: "active"
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(compensation_record, attrs) do
    compensation_record
    |> cast(attrs, [
      :company_id,
      :employee_name,
      :role,
      :department,
      :compensation_type,
      :amount,
      :currency,
      :frequency,
      :effective_date,
      :end_date,
      :vesting_schedule,
      :status,
      :notes
    ])
    |> validate_required([:company_id, :employee_name, :compensation_type, :amount, :frequency])
    |> validate_inclusion(:compensation_type, @compensation_types)
    |> validate_inclusion(:frequency, @frequencies)
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:amount, greater_than: 0)
    |> foreign_key_constraint(:company_id)
  end

  def compensation_types, do: @compensation_types
  def frequencies, do: @frequencies
  def statuses, do: @statuses
end
