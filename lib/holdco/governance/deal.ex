defmodule Holdco.Governance.Deal do
  use Ecto.Schema
  import Ecto.Changeset

  schema "deals" do
    field :deal_type, :string, default: "acquisition"
    field :counterparty, :string
    field :status, :string, default: "pipeline"
    field :value, :decimal
    field :currency, :string, default: "USD"
    field :target_close_date, :string
    field :closed_date, :string
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(deal, attrs) do
    deal
    |> cast(attrs, [
      :company_id,
      :deal_type,
      :counterparty,
      :status,
      :value,
      :currency,
      :target_close_date,
      :closed_date,
      :notes
    ])
    |> validate_required([:company_id, :counterparty])
  end
end
