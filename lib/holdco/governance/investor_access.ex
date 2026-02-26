defmodule Holdco.Governance.InvestorAccess do
  use Ecto.Schema
  import Ecto.Changeset

  schema "investor_accesses" do
    field :can_view_financials, :boolean, default: true
    field :can_view_holdings, :boolean, default: true
    field :can_view_documents, :boolean, default: false
    field :can_view_cap_table, :boolean, default: true
    field :expires_at, :utc_datetime
    field :notes, :string

    belongs_to :user, Holdco.Accounts.User
    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(investor_access, attrs) do
    investor_access
    |> cast(attrs, [:user_id, :company_id, :can_view_financials, :can_view_holdings,
                     :can_view_documents, :can_view_cap_table, :expires_at, :notes])
    |> validate_required([:user_id, :company_id])
    |> unique_constraint([:user_id, :company_id])
  end
end
