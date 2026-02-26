defmodule Holdco.Finance.Account do
  use Ecto.Schema
  import Ecto.Changeset

  schema "accounts" do
    field :name, :string
    field :account_type, :string
    field :code, :string
    field :currency, :string, default: "USD"
    field :notes, :string
    field :external_id, :string

    belongs_to :parent, __MODULE__
    belongs_to :company, Holdco.Corporate.Company
    belongs_to :segment, Holdco.Finance.Segment
    has_many :children, __MODULE__, foreign_key: :parent_id

    timestamps(type: :utc_datetime)
  end

  def changeset(account, attrs) do
    account
    |> cast(attrs, [:name, :account_type, :code, :parent_id, :company_id, :currency, :notes, :external_id, :segment_id])
    |> validate_required([:name, :account_type])
    |> unique_constraint(:code)
  end
end
