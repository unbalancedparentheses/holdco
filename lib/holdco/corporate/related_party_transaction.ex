defmodule Holdco.Corporate.RelatedPartyTransaction do
  use Ecto.Schema
  import Ecto.Changeset

  @relationships ~w(parent subsidiary affiliate director officer shareholder family_member)
  @transaction_types ~w(sale purchase service loan guarantee lease other)
  @disclosure_statuses ~w(not_required pending disclosed)

  schema "related_party_transactions" do
    field :related_party_name, :string
    field :relationship, :string
    field :transaction_type, :string
    field :transaction_date, :date
    field :amount, :decimal
    field :currency, :string, default: "USD"
    field :terms_description, :string
    field :arm_length_confirmation, :boolean, default: false
    field :board_approval_date, :date
    field :board_approval_reference, :string
    field :disclosure_required, :boolean, default: false
    field :disclosure_status, :string, default: "not_required"
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(rpt, attrs) do
    rpt
    |> cast(attrs, [
      :company_id,
      :related_party_name,
      :relationship,
      :transaction_type,
      :transaction_date,
      :amount,
      :currency,
      :terms_description,
      :arm_length_confirmation,
      :board_approval_date,
      :board_approval_reference,
      :disclosure_required,
      :disclosure_status,
      :notes
    ])
    |> validate_required([:company_id, :related_party_name, :relationship, :transaction_type, :transaction_date, :amount])
    |> validate_inclusion(:relationship, @relationships)
    |> validate_inclusion(:transaction_type, @transaction_types)
    |> validate_inclusion(:disclosure_status, @disclosure_statuses)
    |> validate_number(:amount, greater_than: Decimal.new(0))
    |> foreign_key_constraint(:company_id)
  end

  def relationships, do: @relationships
  def transaction_types, do: @transaction_types
  def disclosure_statuses, do: @disclosure_statuses
end
