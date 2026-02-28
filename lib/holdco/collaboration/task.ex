defmodule Holdco.Collaboration.Task do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tasks" do
    field :title, :string
    field :description, :string
    field :status, :string, default: "open"
    field :priority, :string, default: "medium"
    field :due_date, :string
    field :completed_at, :utc_datetime
    field :linked_entity_type, :string
    field :linked_entity_id, :id
    field :created_from, :string
    field :notes, :string

    belongs_to :assignee, Holdco.Accounts.User
    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  @required ~w(title)a
  @optional ~w(description status priority due_date completed_at linked_entity_type linked_entity_id created_from notes assignee_id company_id)a

  def changeset(task, attrs) do
    task
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:status, ~w(open in_progress completed cancelled))
    |> validate_inclusion(:priority, ~w(low medium high urgent))
    |> validate_inclusion(:created_from, ~w(meeting deadline audit manual), message: "must be meeting, deadline, audit, or manual")
    |> validate_inclusion(:linked_entity_type, ~w(meeting deadline audit company), message: "must be meeting, deadline, audit, or company")
    |> maybe_validate_due_date()
  end

  defp maybe_validate_due_date(changeset) do
    validate_change(changeset, :due_date, fn :due_date, value ->
      case Date.from_iso8601(value) do
        {:ok, _} -> []
        {:error, _} -> [due_date: "must be a valid date (YYYY-MM-DD)"]
      end
    end)
  end
end
