defmodule Holdco.Documents.DataRoom do
  use Ecto.Schema
  import Ecto.Changeset

  @access_levels ~w(public restricted confidential)
  @statuses ~w(active archived expired)

  schema "data_rooms" do
    field :name, :string
    field :description, :string
    field :access_level, :string, default: "restricted"
    field :status, :string, default: "active"
    field :expires_at, :utc_datetime
    field :watermark_enabled, :boolean, default: true
    field :download_allowed, :boolean, default: true
    field :visitor_count, :integer, default: 0
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company
    belongs_to :created_by, Holdco.Accounts.User

    has_many :data_room_documents, Holdco.Documents.DataRoomDocument

    timestamps(type: :utc_datetime)
  end

  def changeset(data_room, attrs) do
    data_room
    |> cast(attrs, [
      :company_id,
      :name,
      :description,
      :access_level,
      :status,
      :created_by_id,
      :expires_at,
      :watermark_enabled,
      :download_allowed,
      :visitor_count,
      :notes
    ])
    |> validate_required([:company_id, :name])
    |> validate_inclusion(:access_level, @access_levels)
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:company_id)
    |> foreign_key_constraint(:created_by_id)
  end

  def access_levels, do: @access_levels
  def statuses, do: @statuses
end
