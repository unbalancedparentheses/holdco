defmodule Holdco.Documents.SignatureWorkflow do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(draft pending_signatures partially_signed completed expired cancelled)
  @reminder_frequencies ~w(daily weekly none)

  schema "signature_workflows" do
    field :title, :string
    field :status, :string, default: "draft"
    field :created_by, :string
    field :signers, {:array, :map}, default: []
    field :expiry_date, :date
    field :reminder_frequency, :string, default: "none"
    field :last_reminder_sent, :utc_datetime
    field :notes, :string

    belongs_to :document, Holdco.Documents.Document
    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(workflow, attrs) do
    workflow
    |> cast(attrs, [
      :document_id, :company_id, :title, :status, :created_by, :signers,
      :expiry_date, :reminder_frequency, :last_reminder_sent, :notes
    ])
    |> validate_required([:company_id, :title])
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:reminder_frequency, @reminder_frequencies)
    |> foreign_key_constraint(:company_id)
    |> foreign_key_constraint(:document_id)
  end
end
