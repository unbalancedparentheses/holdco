defmodule Holdco.Platform.DataRetentionPolicy do
  use Ecto.Schema
  import Ecto.Changeset

  schema "data_retention_policies" do
    field :name, :string
    field :description, :string
    field :data_category, :string
    field :retention_period_days, :integer
    field :legal_basis, :string
    field :action_on_expiry, :string
    field :is_active, :boolean, default: true
    field :last_applied_at, :utc_datetime
    field :next_scheduled_at, :utc_datetime
    field :affected_tables, {:array, :string}, default: []
    field :notes, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(policy, attrs) do
    policy
    |> cast(attrs, [
      :name,
      :description,
      :data_category,
      :retention_period_days,
      :legal_basis,
      :action_on_expiry,
      :is_active,
      :last_applied_at,
      :next_scheduled_at,
      :affected_tables,
      :notes
    ])
    |> validate_required([:name, :data_category, :retention_period_days, :legal_basis, :action_on_expiry])
    |> validate_inclusion(:data_category, ~w(personal_data financial_records audit_logs communications documents analytics))
    |> validate_inclusion(:legal_basis, ~w(consent contract legal_obligation legitimate_interest public_interest))
    |> validate_inclusion(:action_on_expiry, ~w(delete anonymize archive))
    |> validate_number(:retention_period_days, greater_than: 0)
  end
end
