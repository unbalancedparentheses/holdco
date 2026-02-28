defmodule Holdco.Fund.FundraisingPipeline do
  use Ecto.Schema
  import Ecto.Changeset

  schema "fundraising_pipelines" do
    field :fund_name, :string
    field :target_amount, :decimal
    field :hard_cap, :decimal
    field :soft_cap, :decimal
    field :amount_raised, :decimal, default: Decimal.new(0)
    field :currency, :string, default: "USD"
    field :status, :string, default: "prospecting"
    field :first_close_date, :date
    field :final_close_date, :date
    field :management_fee_rate, :decimal
    field :carried_interest_rate, :decimal
    field :hurdle_rate, :decimal
    field :fund_term_years, :integer
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company
    has_many :prospects, Holdco.Fund.Prospect, foreign_key: :pipeline_id

    timestamps(type: :utc_datetime)
  end

  @valid_statuses ~w(prospecting marketing closing final_close closed)

  def changeset(pipeline, attrs) do
    pipeline
    |> cast(attrs, [
      :company_id,
      :fund_name,
      :target_amount,
      :hard_cap,
      :soft_cap,
      :amount_raised,
      :currency,
      :status,
      :first_close_date,
      :final_close_date,
      :management_fee_rate,
      :carried_interest_rate,
      :hurdle_rate,
      :fund_term_years,
      :notes
    ])
    |> validate_required([:company_id, :fund_name, :target_amount])
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_number(:target_amount, greater_than: 0)
    |> validate_number(:fund_term_years, greater_than: 0)
    |> foreign_key_constraint(:company_id)
  end
end
