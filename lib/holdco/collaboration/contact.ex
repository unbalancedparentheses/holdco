defmodule Holdco.Collaboration.Contact do
  use Ecto.Schema
  import Ecto.Changeset

  schema "contacts" do
    field :name, :string
    field :title, :string
    field :organization, :string
    field :email, :string
    field :phone, :string
    field :role_tag, :string
    field :notes, :string

    many_to_many :companies, Holdco.Corporate.Company,
      join_through: "contact_companies",
      on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @required ~w(name)a
  @optional ~w(title organization email phone role_tag notes)a

  def changeset(contact, attrs) do
    contact
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_format(:email, ~r/@/, message: "must contain @")
  end
end
