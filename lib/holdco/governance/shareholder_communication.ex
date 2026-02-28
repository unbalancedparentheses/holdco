defmodule Holdco.Governance.ShareholderCommunication do
  use Ecto.Schema
  import Ecto.Changeset

  @communication_types ~w(notice circular annual_report interim_report proxy_statement dividend_notice agm_notice special_notice)
  @target_audiences ~w(all_shareholders preferred common institutional retail)
  @statuses ~w(draft approved sent acknowledged)
  @delivery_methods ~w(email postal portal all)

  schema "shareholder_communications" do
    field :communication_type, :string
    field :title, :string
    field :content, :string
    field :target_audience, :string, default: "all_shareholders"
    field :distribution_date, :date
    field :response_deadline, :date
    field :status, :string, default: "draft"
    field :delivery_method, :string, default: "email"
    field :recipients_count, :integer, default: 0
    field :acknowledged_count, :integer, default: 0
    field :documents, {:array, :string}, default: []
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(communication, attrs) do
    communication
    |> cast(attrs, [
      :company_id, :communication_type, :title, :content, :target_audience,
      :distribution_date, :response_deadline, :status, :delivery_method,
      :recipients_count, :acknowledged_count, :documents, :notes
    ])
    |> validate_required([:company_id, :communication_type, :title])
    |> validate_inclusion(:communication_type, @communication_types)
    |> validate_inclusion(:target_audience, @target_audiences)
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:delivery_method, @delivery_methods)
    |> validate_number(:recipients_count, greater_than_or_equal_to: 0)
    |> validate_number(:acknowledged_count, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:company_id)
  end
end
