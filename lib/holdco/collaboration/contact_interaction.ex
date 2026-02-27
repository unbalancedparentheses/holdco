defmodule Holdco.Collaboration.ContactInteraction do
  use Ecto.Schema
  import Ecto.Changeset
  import Holdco.Validators

  schema "contact_interactions" do
    field :interaction_type, :string
    field :summary, :string
    field :date, :string
    field :notes, :string

    belongs_to :contact, Holdco.Collaboration.Contact

    timestamps(type: :utc_datetime)
  end

  @types ~w(call meeting email note)

  def changeset(interaction, attrs) do
    interaction
    |> cast(attrs, [:contact_id, :interaction_type, :summary, :date, :notes])
    |> validate_required([:contact_id, :interaction_type, :summary])
    |> validate_inclusion(:interaction_type, @types)
    |> validate_date_format(:date)
  end
end
