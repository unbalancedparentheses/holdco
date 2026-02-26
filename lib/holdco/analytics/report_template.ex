defmodule Holdco.Analytics.ReportTemplate do
  use Ecto.Schema
  import Ecto.Changeset

  schema "report_templates" do
    field :name, :string
    field :sections, :string, default: "[]"
    field :company_ids, :string, default: "[]"
    field :date_from, :string
    field :date_to, :string
    field :frequency, :string, default: "monthly"

    belongs_to :user, Holdco.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(template, attrs) do
    template
    |> cast(attrs, [:name, :sections, :company_ids, :date_from, :date_to, :frequency, :user_id])
    |> validate_required([:name])
    |> validate_inclusion(:frequency, ~w(weekly monthly quarterly annually))
  end
end
