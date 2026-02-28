defmodule Holdco.Fund.CapitalCallLine do
  use Ecto.Schema
  import Ecto.Changeset

  schema "capital_call_lines" do
    field :investor_name, :string
    field :commitment_amount, :decimal
    field :call_amount, :decimal
    field :paid_amount, :decimal, default: Decimal.new(0)
    field :status, :string, default: "pending"
    field :paid_date, :date

    belongs_to :capital_call, Holdco.Fund.CapitalCall

    timestamps(type: :utc_datetime)
  end

  def changeset(line, attrs) do
    line
    |> cast(attrs, [:capital_call_id, :investor_name, :commitment_amount, :call_amount, :paid_amount, :status, :paid_date])
    |> validate_required([:capital_call_id, :investor_name, :call_amount])
    |> validate_inclusion(:status, ~w(pending paid overdue))
    |> foreign_key_constraint(:capital_call_id)
  end
end
