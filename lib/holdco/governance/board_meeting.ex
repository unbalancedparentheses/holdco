defmodule Holdco.Governance.BoardMeeting do
  use Ecto.Schema
  import Ecto.Changeset

  @meeting_types ~w(regular special annual emergency)
  @statuses ~w(scheduled in_progress completed cancelled)

  schema "board_meetings" do
    field :title, :string
    field :meeting_type, :string, default: "regular"
    field :scheduled_date, :string
    field :meeting_date, :date
    field :start_time, :time
    field :end_time, :time
    field :location, :string
    field :is_virtual, :boolean, default: false
    field :virtual_link, :string
    field :status, :string, default: "scheduled"
    field :quorum_required, :integer
    field :attendees_count, :integer, default: 0
    field :agenda, :string
    field :minutes, :string
    field :resolutions, :string
    field :documents, {:array, :string}, default: []
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(board_meeting, attrs) do
    board_meeting
    |> cast(attrs, [
      :company_id, :title, :meeting_type, :scheduled_date, :meeting_date,
      :start_time, :end_time, :location, :is_virtual, :virtual_link, :status,
      :quorum_required, :attendees_count, :agenda, :minutes, :resolutions,
      :documents, :notes
    ])
    |> validate_required([:company_id, :scheduled_date])
    |> validate_inclusion(:meeting_type, @meeting_types)
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:quorum_required, greater_than_or_equal_to: 0)
    |> validate_number(:attendees_count, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:company_id)
  end
end
