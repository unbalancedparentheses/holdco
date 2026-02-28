defmodule Holdco.Documents.Extraction do
  use Ecto.Schema
  import Ecto.Changeset

  @extraction_types ~w(invoice receipt contract financial_statement tax_form other)
  @statuses ~w(pending processing completed failed)

  schema "extractions" do
    field :extraction_type, :string, default: "other"
    field :status, :string, default: "pending"
    field :extracted_data, :map, default: %{}
    field :confidence_score, :decimal
    field :model_used, :string
    field :processing_time_ms, :integer
    field :reviewed, :boolean, default: false
    field :notes, :string

    belongs_to :document, Holdco.Documents.Document
    belongs_to :reviewed_by, Holdco.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(extraction, attrs) do
    extraction
    |> cast(attrs, [
      :document_id,
      :extraction_type,
      :status,
      :extracted_data,
      :confidence_score,
      :model_used,
      :processing_time_ms,
      :reviewed,
      :reviewed_by_id,
      :notes
    ])
    |> validate_required([:document_id, :extraction_type])
    |> validate_inclusion(:extraction_type, @extraction_types)
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:confidence_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 1)
    |> foreign_key_constraint(:document_id)
    |> foreign_key_constraint(:reviewed_by_id)
  end

  def extraction_types, do: @extraction_types
  def statuses, do: @statuses
end
