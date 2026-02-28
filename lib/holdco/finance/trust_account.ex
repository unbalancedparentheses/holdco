defmodule Holdco.Finance.TrustAccount do
  use Ecto.Schema
  import Ecto.Changeset

  @trust_types ~w(revocable irrevocable testamentary charitable special_needs grantor_retained)
  @statuses ~w(active terminated pending suspended)
  @distribution_schedules ~w(monthly quarterly annually discretionary)

  schema "trust_accounts" do
    field :trust_name, :string
    field :trust_type, :string, default: "revocable"
    field :trustee_name, :string
    field :grantor_name, :string
    field :beneficiaries, {:array, :map}, default: []
    field :jurisdiction, :string
    field :date_established, :date
    field :corpus_value, :decimal
    field :currency, :string, default: "USD"
    field :distribution_schedule, :string, default: "quarterly"
    field :last_distribution_date, :date
    field :next_distribution_date, :date
    field :tax_id, :string
    field :status, :string, default: "active"
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company
    has_many :trust_transactions, Holdco.Finance.TrustTransaction

    timestamps(type: :utc_datetime)
  end

  def changeset(trust_account, attrs) do
    trust_account
    |> cast(attrs, [
      :company_id,
      :trust_name,
      :trust_type,
      :trustee_name,
      :grantor_name,
      :beneficiaries,
      :jurisdiction,
      :date_established,
      :corpus_value,
      :currency,
      :distribution_schedule,
      :last_distribution_date,
      :next_distribution_date,
      :tax_id,
      :status,
      :notes
    ])
    |> validate_required([:company_id, :trust_name, :trust_type, :trustee_name])
    |> validate_inclusion(:trust_type, @trust_types)
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:distribution_schedule, @distribution_schedules)
    |> validate_number(:corpus_value, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:company_id)
  end

  def trust_types, do: @trust_types
  def statuses, do: @statuses
  def distribution_schedules, do: @distribution_schedules
end
