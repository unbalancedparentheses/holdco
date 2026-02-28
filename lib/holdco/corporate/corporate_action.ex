defmodule Holdco.Corporate.CorporateAction do
  use Ecto.Schema
  import Ecto.Changeset
  import Holdco.Validators

  @action_types ~w(stock_split reverse_split merger acquisition spin_off tender_offer rights_issue buyback dividend_reinvestment delisting)
  @statuses ~w(announced approved in_progress completed cancelled)

  schema "corporate_actions" do
    field :action_type, :string
    field :announcement_date, :string
    field :record_date, :string
    field :effective_date, :string
    field :completion_date, :string
    field :description, :string
    field :ratio_numerator, :integer
    field :ratio_denominator, :integer
    field :price_per_share, :decimal
    field :total_value, :decimal
    field :currency, :string, default: "USD"
    field :status, :string, default: "announced"
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(corporate_action, attrs) do
    corporate_action
    |> cast(attrs, [
      :company_id,
      :action_type,
      :announcement_date,
      :record_date,
      :effective_date,
      :completion_date,
      :description,
      :ratio_numerator,
      :ratio_denominator,
      :price_per_share,
      :total_value,
      :currency,
      :status,
      :notes
    ])
    |> validate_required([:company_id, :action_type])
    |> validate_inclusion(:action_type, @action_types)
    |> validate_inclusion(:status, @statuses)
    |> validate_date_format(:announcement_date)
    |> validate_date_format(:record_date)
    |> validate_date_format(:effective_date)
    |> validate_date_format(:completion_date)
    |> validate_number(:ratio_numerator, greater_than: 0)
    |> validate_number(:ratio_denominator, greater_than: 0)
    |> validate_number(:price_per_share, greater_than_or_equal_to: 0)
    |> validate_number(:total_value, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:company_id)
  end

  def action_types, do: @action_types
  def statuses, do: @statuses
end
