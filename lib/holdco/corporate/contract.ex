defmodule Holdco.Corporate.Contract do
  use Ecto.Schema
  import Ecto.Changeset

  @contract_types ~w(nda service license lease employment consulting vendor partnership loan other)
  @statuses ~w(draft under_review active expiring expired terminated renewed)

  schema "contracts" do
    field :title, :string
    field :counterparty, :string
    field :contract_type, :string, default: "other"
    field :start_date, :date
    field :end_date, :date
    field :auto_renew, :boolean, default: false
    field :renewal_notice_days, :integer
    field :value, :decimal
    field :currency, :string, default: "USD"
    field :payment_terms, :string
    field :status, :string, default: "draft"
    field :signed_date, :date
    field :termination_date, :date
    field :termination_reason, :string
    field :key_terms, :string
    field :tags, {:array, :string}, default: []
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(contract, attrs) do
    contract
    |> cast(attrs, [
      :company_id,
      :title,
      :counterparty,
      :contract_type,
      :start_date,
      :end_date,
      :auto_renew,
      :renewal_notice_days,
      :value,
      :currency,
      :payment_terms,
      :status,
      :signed_date,
      :termination_date,
      :termination_reason,
      :key_terms,
      :tags,
      :notes
    ])
    |> validate_required([:company_id, :title, :counterparty, :contract_type])
    |> validate_inclusion(:contract_type, @contract_types)
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:renewal_notice_days, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:company_id)
  end

  def contract_types, do: @contract_types
  def statuses, do: @statuses
end
