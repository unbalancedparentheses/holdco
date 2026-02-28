defmodule Holdco.Corporate.EntityLifecycle do
  use Ecto.Schema
  import Ecto.Changeset
  import Holdco.Validators

  @event_types ~w(incorporation registration amendment redomiciliation merger spin_off dissolution reinstatement name_change other)
  @statuses ~w(pending completed rejected)

  schema "entity_lifecycles" do
    field :event_type, :string
    field :event_date, :string
    field :effective_date, :string
    field :jurisdiction, :string
    field :filing_reference, :string
    field :description, :string
    field :status, :string, default: "pending"
    field :documents, {:array, :string}, default: []
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(entity_lifecycle, attrs) do
    entity_lifecycle
    |> cast(attrs, [
      :company_id,
      :event_type,
      :event_date,
      :effective_date,
      :jurisdiction,
      :filing_reference,
      :description,
      :status,
      :documents,
      :notes
    ])
    |> validate_required([:company_id, :event_type, :event_date])
    |> validate_inclusion(:event_type, @event_types)
    |> validate_inclusion(:status, @statuses)
    |> validate_date_format(:event_date)
    |> validate_date_format(:effective_date)
    |> foreign_key_constraint(:company_id)
  end

  def event_types, do: @event_types
  def statuses, do: @statuses
end
