defmodule Holdco.Finance.ServiceAgreement do
  use Ecto.Schema
  import Ecto.Changeset
  import Holdco.Validators

  @agreement_types ~w(management_fee shared_services licensing royalty cost_sharing other)
  @frequencies ~w(monthly quarterly annually)
  @transfer_pricing_methods ~w(comparable_uncontrolled resale_price cost_plus profit_split tnmm)
  @statuses ~w(draft active expired terminated)

  schema "service_agreements" do
    field :agreement_type, :string
    field :description, :string
    field :amount, :decimal
    field :currency, :string, default: "USD"
    field :frequency, :string, default: "monthly"
    field :start_date, :string
    field :end_date, :string
    field :markup_pct, :decimal
    field :arm_length_basis, :string
    field :transfer_pricing_method, :string
    field :status, :string, default: "draft"
    field :notes, :string

    belongs_to :provider_company, Holdco.Corporate.Company
    belongs_to :recipient_company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(service_agreement, attrs) do
    service_agreement
    |> cast(attrs, [
      :provider_company_id,
      :recipient_company_id,
      :agreement_type,
      :description,
      :amount,
      :currency,
      :frequency,
      :start_date,
      :end_date,
      :markup_pct,
      :arm_length_basis,
      :transfer_pricing_method,
      :status,
      :notes
    ])
    |> validate_required([:provider_company_id, :recipient_company_id, :agreement_type, :amount])
    |> validate_inclusion(:agreement_type, @agreement_types)
    |> validate_inclusion(:frequency, @frequencies)
    |> validate_inclusion(:transfer_pricing_method, @transfer_pricing_methods ++ [nil])
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:amount, greater_than: 0)
    |> validate_number(:markup_pct, greater_than_or_equal_to: 0)
    |> validate_date_format(:start_date)
    |> validate_date_format(:end_date)
    |> validate_different_companies()
  end

  defp validate_different_companies(changeset) do
    provider = get_field(changeset, :provider_company_id)
    recipient = get_field(changeset, :recipient_company_id)

    if provider && recipient && provider == recipient do
      add_error(changeset, :recipient_company_id, "must be different from provider company")
    else
      changeset
    end
  end
end
