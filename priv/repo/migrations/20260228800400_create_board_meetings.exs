defmodule Holdco.Repo.Migrations.CreateBoardMeetings do
  use Ecto.Migration

  def change do
    alter table(:board_meetings) do
      add :title, :string
      add :meeting_date, :date
      add :start_time, :time
      add :end_time, :time
      add :location, :string
      add :is_virtual, :boolean, default: false
      add :virtual_link, :string
      add :quorum_required, :integer
      add :attendees_count, :integer, default: 0
      add :agenda, :text
      add :minutes, :text
      add :resolutions, :text
      add :documents, {:array, :string}, default: []
    end
  end
end
