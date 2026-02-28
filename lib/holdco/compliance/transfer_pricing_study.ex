defmodule Holdco.Compliance.TransferPricingStudy do
  use Ecto.Schema
  import Ecto.Changeset

  @transaction_types ~w(goods services ip_licensing financing cost_sharing)
  @methods ~w(cup resale_price cost_plus tnmm profit_split)
  @conclusions ~w(within_range below_range above_range)
  @documentation_statuses ~w(not_started in_progress complete filed)

  schema "transfer_pricing_studies" do
    field :study_name, :string
    field :fiscal_year, :integer
    field :related_party_name, :string
    field :transaction_type, :string, default: "goods"
    field :transaction_amount, :decimal, default: 0
    field :currency, :string, default: "USD"
    field :method, :string, default: "cup"
    field :arm_length_range_low, :decimal
    field :arm_length_range_high, :decimal
    field :tested_party_margin, :decimal
    field :conclusion, :string, default: "within_range"
    field :adjustment_needed, :decimal, default: 0
    field :documentation_status, :string, default: "not_started"
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(study, attrs) do
    study
    |> cast(attrs, [
      :company_id,
      :study_name,
      :fiscal_year,
      :related_party_name,
      :transaction_type,
      :transaction_amount,
      :currency,
      :method,
      :arm_length_range_low,
      :arm_length_range_high,
      :tested_party_margin,
      :conclusion,
      :adjustment_needed,
      :documentation_status,
      :notes
    ])
    |> validate_required([:company_id, :study_name, :fiscal_year, :related_party_name])
    |> validate_inclusion(:transaction_type, @transaction_types)
    |> validate_inclusion(:method, @methods)
    |> validate_inclusion(:conclusion, @conclusions)
    |> validate_inclusion(:documentation_status, @documentation_statuses)
    |> foreign_key_constraint(:company_id)
  end

  def transaction_types, do: @transaction_types
  def methods, do: @methods
  def conclusions, do: @conclusions
  def documentation_statuses, do: @documentation_statuses
end
