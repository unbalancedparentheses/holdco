defmodule Holdco.Analytics.CounterpartyExposure do
  use Ecto.Schema
  import Ecto.Changeset

  @counterparty_types ~w(bank broker custodian borrower lender vendor insurer)
  @credit_ratings ~w(AAA AA A BBB BB B CCC CC C D NR)
  @statuses ~w(active inactive watchlist restricted)

  schema "counterparty_exposures" do
    field :counterparty_name, :string
    field :counterparty_type, :string
    field :exposure_amount, :decimal
    field :currency, :string, default: "USD"
    field :credit_rating, :string
    field :rating_agency, :string
    field :max_exposure_limit, :decimal
    field :utilization_pct, :decimal
    field :risk_score, :decimal
    field :last_review_date, :date
    field :next_review_date, :date
    field :notes, :string
    field :status, :string, default: "active"

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(exposure, attrs) do
    exposure
    |> cast(attrs, [
      :company_id,
      :counterparty_name,
      :counterparty_type,
      :exposure_amount,
      :currency,
      :credit_rating,
      :rating_agency,
      :max_exposure_limit,
      :utilization_pct,
      :risk_score,
      :last_review_date,
      :next_review_date,
      :notes,
      :status
    ])
    |> validate_required([:counterparty_name])
    |> validate_inclusion(:counterparty_type, @counterparty_types)
    |> validate_inclusion(:credit_rating, @credit_ratings)
    |> validate_inclusion(:status, @statuses)
  end
end
