defmodule Holdco.Corporate.KeyPersonnel do
  use Ecto.Schema
  import Ecto.Changeset

  schema "key_personnel" do
    field :name, :string
    field :title, :string
    field :department, :string
    field :email, :string
    field :phone, :string
    field :start_date, :string
    field :end_date, :string
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(key_personnel, attrs) do
    key_personnel
    |> cast(attrs, [:company_id, :name, :title, :department, :email, :phone,
                     :start_date, :end_date, :notes])
    |> validate_required([:company_id, :name])
  end
end
