defmodule Holdco.Governance.ShareholderResolution do
  use Ecto.Schema
  import Ecto.Changeset

  schema "shareholder_resolutions" do
    field :title, :string
    field :resolution_type, :string, default: "ordinary"
    field :date, :string
    field :passed, :boolean, default: false
    field :votes_for, :integer, default: 0
    field :votes_against, :integer, default: 0
    field :abstentions, :integer, default: 0
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(shareholder_resolution, attrs) do
    shareholder_resolution
    |> cast(attrs, [:company_id, :title, :resolution_type, :date, :passed,
                     :votes_for, :votes_against, :abstentions, :notes])
    |> validate_required([:company_id, :title, :date])
  end
end
