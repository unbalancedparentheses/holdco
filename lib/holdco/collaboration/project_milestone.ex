defmodule Holdco.Collaboration.ProjectMilestone do
  use Ecto.Schema
  import Ecto.Changeset

  schema "project_milestones" do
    field :name, :string
    field :due_date, :string
    field :status, :string, default: "pending"
    field :notes, :string

    belongs_to :project, Holdco.Collaboration.Project

    timestamps(type: :utc_datetime)
  end

  @statuses ~w(pending in_progress completed cancelled)

  def changeset(milestone, attrs) do
    milestone
    |> cast(attrs, [:project_id, :name, :due_date, :status, :notes])
    |> validate_required([:project_id, :name])
    |> validate_inclusion(:status, @statuses)
  end
end
