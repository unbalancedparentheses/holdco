defmodule Holdco.Platform.Alert do
  use Ecto.Schema
  import Ecto.Changeset

  schema "alerts" do
    field :metric_value, :decimal
    field :threshold_value, :decimal
    field :message, :string
    field :severity, :string
    field :status, :string, default: "unread"
    field :acknowledged_at, :utc_datetime
    field :resolved_at, :utc_datetime
    belongs_to :alert_rule, Holdco.Platform.AlertRule
    belongs_to :acknowledged_by, Holdco.Accounts.User
    timestamps(type: :utc_datetime)
  end

  def changeset(alert, attrs) do
    alert
    |> cast(attrs, [
      :alert_rule_id, :metric_value, :threshold_value, :message,
      :severity, :status, :acknowledged_at, :acknowledged_by_id, :resolved_at
    ])
    |> validate_required([:alert_rule_id, :message, :severity])
    |> validate_inclusion(:status, ~w(unread read acknowledged resolved))
    |> validate_inclusion(:severity, ~w(info warning critical))
  end
end
