defmodule Holdco.Corporate.RegisterEntry do
  use Ecto.Schema
  import Ecto.Changeset
  import Holdco.Validators

  @register_types ~w(directors shareholders charges mortgages debentures beneficial_owners secretary auditors registered_office)
  @statuses ~w(current historical)

  schema "register_entries" do
    field :register_type, :string
    field :entry_date, :string
    field :person_name, :string
    field :role_or_description, :string
    field :shares_held, :decimal
    field :share_class, :string
    field :appointment_date, :string
    field :cessation_date, :string
    field :status, :string, default: "current"
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(register_entry, attrs) do
    register_entry
    |> cast(attrs, [
      :company_id,
      :register_type,
      :entry_date,
      :person_name,
      :role_or_description,
      :shares_held,
      :share_class,
      :appointment_date,
      :cessation_date,
      :status,
      :notes
    ])
    |> validate_required([:company_id, :register_type, :entry_date])
    |> validate_inclusion(:register_type, @register_types)
    |> validate_inclusion(:status, @statuses)
    |> validate_date_format(:entry_date)
    |> validate_date_format(:appointment_date)
    |> validate_date_format(:cessation_date)
    |> validate_number(:shares_held, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:company_id)
  end

  def register_types, do: @register_types
  def statuses, do: @statuses
end
