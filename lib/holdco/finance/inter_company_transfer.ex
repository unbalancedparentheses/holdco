defmodule Holdco.Finance.InterCompanyTransfer do
  use Ecto.Schema
  import Ecto.Changeset

  schema "inter_company_transfers" do
    field :amount, :float
    field :currency, :string, default: "USD"
    field :date, :string
    field :description, :string
    field :status, :string, default: "completed"
    field :notes, :string

    belongs_to :from_company, Holdco.Corporate.Company
    belongs_to :to_company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(inter_company_transfer, attrs) do
    inter_company_transfer
    |> cast(attrs, [
      :from_company_id,
      :to_company_id,
      :amount,
      :currency,
      :date,
      :description,
      :status,
      :notes
    ])
    |> validate_required([:from_company_id, :to_company_id, :amount, :date])
  end
end
