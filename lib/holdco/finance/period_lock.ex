defmodule Holdco.Finance.PeriodLock do
  use Ecto.Schema
  import Ecto.Changeset

  schema "period_locks" do
    field :period_start, :date
    field :period_end, :date
    field :period_type, :string
    field :status, :string, default: "locked"
    field :locked_at, :utc_datetime
    field :locked_by_id, :id
    field :unlocked_at, :utc_datetime
    field :unlocked_by_id, :id
    field :unlock_reason, :string
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(period_lock, attrs) do
    period_lock
    |> cast(attrs, [
      :company_id,
      :period_start,
      :period_end,
      :period_type,
      :status,
      :locked_at,
      :locked_by_id,
      :unlocked_at,
      :unlocked_by_id,
      :unlock_reason,
      :notes
    ])
    |> validate_required([:company_id, :period_start, :period_end, :period_type, :status])
    |> validate_inclusion(:period_type, ~w(month quarter year))
    |> validate_inclusion(:status, ~w(locked unlocked))
  end
end
