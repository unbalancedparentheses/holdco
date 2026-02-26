defmodule Holdco.Collaboration.Project do
  use Ecto.Schema
  import Ecto.Changeset

  schema "projects" do
    field :name, :string
    field :status, :string, default: "planned"
    field :project_type, :string
    field :description, :string
    field :start_date, :date
    field :target_date, :date
    field :budget, :decimal
    field :currency, :string, default: "USD"
    field :notes, :string

    belongs_to :contact, Holdco.Collaboration.Contact

    many_to_many :companies, Holdco.Corporate.Company,
      join_through: "project_companies",
      on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @required ~w(name)a
  @optional ~w(status project_type description start_date target_date budget currency notes contact_id)a

  def changeset(project, attrs) do
    project
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:status, ~w(planned active on_hold completed cancelled))
  end
end
