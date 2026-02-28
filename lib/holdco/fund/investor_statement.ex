defmodule Holdco.Fund.InvestorStatement do
  use Ecto.Schema
  import Ecto.Changeset

  schema "investor_statements" do
    field :investor_name, :string
    field :period_start, :date
    field :period_end, :date
    field :beginning_balance, :decimal, default: 0
    field :contributions, :decimal, default: 0
    field :distributions, :decimal, default: 0
    field :income_allocation, :decimal, default: 0
    field :expense_allocation, :decimal, default: 0
    field :unrealized_gain_loss, :decimal, default: 0
    field :ending_balance, :decimal, default: 0
    field :ownership_pct, :decimal
    field :irr, :decimal
    field :moic, :decimal
    field :status, :string, default: "draft"
    field :sent_at, :utc_datetime
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  @valid_statuses ~w(draft review final sent)

  def changeset(statement, attrs) do
    statement
    |> cast(attrs, [
      :company_id,
      :investor_name,
      :period_start,
      :period_end,
      :beginning_balance,
      :contributions,
      :distributions,
      :income_allocation,
      :expense_allocation,
      :unrealized_gain_loss,
      :ending_balance,
      :ownership_pct,
      :irr,
      :moic,
      :status,
      :sent_at,
      :notes
    ])
    |> validate_required([:company_id, :investor_name, :period_start, :period_end])
    |> validate_inclusion(:status, @valid_statuses)
    |> foreign_key_constraint(:company_id)
  end
end
