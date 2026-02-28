defmodule Holdco.Corporate.ShareClass do
  use Ecto.Schema
  import Ecto.Changeset

  @dividend_preferences ~w(none cumulative non_cumulative participating)
  @statuses ~w(active retired)

  schema "share_classes" do
    field :name, :string
    field :class_code, :string
    field :shares_authorized, :decimal
    field :shares_issued, :decimal
    field :shares_outstanding, :decimal
    field :par_value, :decimal
    field :currency, :string, default: "USD"
    field :voting_rights_per_share, :decimal
    field :dividend_preference, :string, default: "none"
    field :liquidation_preference, :decimal
    field :conversion_ratio, :decimal
    field :is_convertible, :boolean, default: false
    field :is_redeemable, :boolean, default: false
    field :status, :string, default: "active"
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(share_class, attrs) do
    share_class
    |> cast(attrs, [
      :company_id,
      :name,
      :class_code,
      :shares_authorized,
      :shares_issued,
      :shares_outstanding,
      :par_value,
      :currency,
      :voting_rights_per_share,
      :dividend_preference,
      :liquidation_preference,
      :conversion_ratio,
      :is_convertible,
      :is_redeemable,
      :status,
      :notes
    ])
    |> validate_required([:company_id, :name, :class_code])
    |> validate_inclusion(:dividend_preference, @dividend_preferences)
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:shares_authorized, greater_than_or_equal_to: 0)
    |> validate_number(:shares_issued, greater_than_or_equal_to: 0)
    |> validate_number(:shares_outstanding, greater_than_or_equal_to: 0)
    |> validate_number(:par_value, greater_than_or_equal_to: 0)
    |> unique_constraint([:company_id, :class_code])
    |> foreign_key_constraint(:company_id)
  end

  def dividend_preferences, do: @dividend_preferences
  def statuses, do: @statuses
end
