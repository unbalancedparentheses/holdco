defmodule Holdco.Fund.CapitalCall do
  use Ecto.Schema
  import Ecto.Changeset

  schema "capital_calls" do
    field :call_number, :integer
    field :call_date, :date
    field :due_date, :date
    field :total_amount, :decimal
    field :currency, :string, default: "USD"
    field :purpose, :string
    field :status, :string, default: "pending"
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company
    has_many :lines, Holdco.Fund.CapitalCallLine

    timestamps(type: :utc_datetime)
  end

  def changeset(capital_call, attrs) do
    capital_call
    |> cast(attrs, [:company_id, :call_number, :call_date, :due_date, :total_amount, :currency, :purpose, :status, :notes])
    |> validate_required([:company_id, :call_date, :total_amount])
    |> validate_inclusion(:purpose, ~w(investment fees expenses follow_on))
    |> validate_inclusion(:status, ~w(pending partially_funded funded cancelled))
    |> foreign_key_constraint(:company_id)
  end
end
