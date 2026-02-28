defmodule Holdco.Corporate.IpAsset do
  use Ecto.Schema
  import Ecto.Changeset

  @asset_types ~w(patent trademark copyright trade_secret domain software_license)
  @statuses ~w(pending active expired abandoned transferred)

  schema "ip_assets" do
    field :asset_type, :string, default: "patent"
    field :name, :string
    field :registration_number, :string
    field :jurisdiction, :string
    field :filing_date, :date
    field :grant_date, :date
    field :expiry_date, :date
    field :status, :string, default: "pending"
    field :owner_entity, :string
    field :licensees, {:array, :string}, default: []
    field :annual_cost, :decimal
    field :currency, :string, default: "USD"
    field :valuation, :decimal
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(ip_asset, attrs) do
    ip_asset
    |> cast(attrs, [
      :company_id,
      :asset_type,
      :name,
      :registration_number,
      :jurisdiction,
      :filing_date,
      :grant_date,
      :expiry_date,
      :status,
      :owner_entity,
      :licensees,
      :annual_cost,
      :currency,
      :valuation,
      :notes
    ])
    |> validate_required([:company_id, :name, :asset_type])
    |> validate_inclusion(:asset_type, @asset_types)
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:company_id)
  end

  def asset_types, do: @asset_types
  def statuses, do: @statuses
end
