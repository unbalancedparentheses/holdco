defmodule Holdco.Documents.DataRoomDocument do
  use Ecto.Schema
  import Ecto.Changeset

  schema "data_room_documents" do
    field :section_name, :string
    field :sort_order, :integer, default: 0

    belongs_to :data_room, Holdco.Documents.DataRoom
    belongs_to :document, Holdco.Documents.Document
    belongs_to :added_by, Holdco.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(data_room_document, attrs) do
    data_room_document
    |> cast(attrs, [
      :data_room_id,
      :document_id,
      :section_name,
      :sort_order,
      :added_by_id
    ])
    |> validate_required([:data_room_id, :document_id])
    |> foreign_key_constraint(:data_room_id)
    |> foreign_key_constraint(:document_id)
    |> foreign_key_constraint(:added_by_id)
  end
end
