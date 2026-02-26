defmodule Holdco.Governance.BoardMeeting do
  use Ecto.Schema
  import Ecto.Changeset

  schema "board_meetings" do
    field :meeting_type, :string, default: "regular"
    field :scheduled_date, :string
    field :status, :string, default: "scheduled"
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(board_meeting, attrs) do
    board_meeting
    |> cast(attrs, [:company_id, :meeting_type, :scheduled_date, :status, :notes])
    |> validate_required([:company_id, :scheduled_date])
  end
end
