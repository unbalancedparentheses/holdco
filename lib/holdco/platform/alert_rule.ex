defmodule Holdco.Platform.AlertRule do
  use Ecto.Schema
  import Ecto.Changeset

  schema "alert_rules" do
    field :name, :string
    field :description, :string
    field :metric, :string
    field :condition, :string
    field :threshold, :decimal
    field :target, :string
    field :severity, :string, default: "warning"
    field :is_active, :boolean, default: true
    field :cooldown_minutes, :integer, default: 60
    field :last_triggered_at, :utc_datetime
    belongs_to :company, Holdco.Corporate.Company
    belongs_to :created_by, Holdco.Accounts.User
    has_many :alerts, Holdco.Platform.Alert
    timestamps(type: :utc_datetime)
  end

  def changeset(alert_rule, attrs) do
    alert_rule
    |> cast(attrs, [
      :name, :description, :metric, :condition, :threshold, :target,
      :severity, :is_active, :cooldown_minutes, :last_triggered_at,
      :company_id, :created_by_id
    ])
    |> validate_required([:name, :metric, :condition, :threshold])
    |> validate_inclusion(:metric, ~w(nav cash_balance holding_value fx_rate liability_total portfolio_concentration expense_ratio))
    |> validate_inclusion(:condition, ~w(above below change_pct_above change_pct_below))
    |> validate_inclusion(:severity, ~w(info warning critical))
    |> validate_number(:threshold, greater_than_or_equal_to: 0)
    |> validate_number(:cooldown_minutes, greater_than: 0)
  end
end
