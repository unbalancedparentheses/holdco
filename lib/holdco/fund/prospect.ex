defmodule Holdco.Fund.Prospect do
  use Ecto.Schema
  import Ecto.Changeset

  schema "prospects" do
    field :investor_name, :string
    field :contact_email, :string
    field :commitment_amount, :decimal
    field :status, :string, default: "identified"
    field :last_contact_date, :date
    field :notes, :string

    belongs_to :fundraising_pipeline, Holdco.Fund.FundraisingPipeline, foreign_key: :pipeline_id

    timestamps(type: :utc_datetime)
  end

  @valid_statuses ~w(identified contacted interested committed declined)

  def changeset(prospect, attrs) do
    prospect
    |> cast(attrs, [
      :pipeline_id,
      :investor_name,
      :contact_email,
      :commitment_amount,
      :status,
      :last_contact_date,
      :notes
    ])
    |> validate_required([:pipeline_id, :investor_name])
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_format(:contact_email, ~r/@/, message: "must contain @")
    |> foreign_key_constraint(:pipeline_id)
  end
end
