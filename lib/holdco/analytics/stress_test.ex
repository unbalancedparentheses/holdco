defmodule Holdco.Analytics.StressTest do
  use Ecto.Schema
  import Ecto.Changeset

  schema "stress_tests" do
    field :name, :string
    field :description, :string
    field :status, :string, default: "draft"
    field :shocks, :map
    field :results, :map
    field :run_at, :utc_datetime

    belongs_to :company, Holdco.Corporate.Company
    belongs_to :created_by, Holdco.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(stress_test, attrs) do
    stress_test
    |> cast(attrs, [:name, :description, :status, :shocks, :results, :run_at, :company_id, :created_by_id])
    |> validate_required([:name, :shocks])
    |> validate_inclusion(:status, ~w(draft running completed failed))
  end
end
