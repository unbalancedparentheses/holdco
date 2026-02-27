defmodule Holdco.Integrations.BankFeedTransaction do
  use Ecto.Schema
  import Ecto.Changeset
  import Holdco.Validators

  schema "bank_feed_transactions" do
    field :external_id, :string
    field :date, :string
    field :description, :string, default: ""
    field :amount, :decimal, default: 0
    field :currency, :string, default: "USD"
    field :category, :string, default: ""
    field :is_matched, :boolean, default: false
    field :matched_transaction_id, :id

    belongs_to :feed_config, Holdco.Integrations.BankFeedConfig

    timestamps(type: :utc_datetime)
  end

  def changeset(bank_feed_transaction, attrs) do
    bank_feed_transaction
    |> cast(attrs, [
      :feed_config_id,
      :external_id,
      :date,
      :description,
      :amount,
      :currency,
      :category,
      :is_matched,
      :matched_transaction_id
    ])
    |> validate_required([:feed_config_id, :external_id, :date])
    |> validate_date_format(:date)
  end
end
