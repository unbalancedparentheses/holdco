defmodule Holdco.Integrations.BankFeedConfig do
  use Ecto.Schema
  import Ecto.Changeset

  schema "bank_feed_configs" do
    field :provider, :string
    field :external_account_id, :string, default: ""
    field :access_token, :string, default: ""
    field :is_active, :boolean, default: true
    field :last_sync_at, :utc_datetime
    field :notes, :string, default: ""

    belongs_to :company, Holdco.Corporate.Company
    belongs_to :bank_account, Holdco.Banking.BankAccount

    has_many :feed_transactions, Holdco.Integrations.BankFeedTransaction,
      foreign_key: :feed_config_id

    timestamps(type: :utc_datetime)
  end

  def changeset(bank_feed_config, attrs) do
    bank_feed_config
    |> cast(attrs, [
      :company_id,
      :bank_account_id,
      :provider,
      :external_account_id,
      :access_token,
      :is_active,
      :last_sync_at,
      :notes
    ])
    |> validate_required([:company_id, :bank_account_id, :provider])
  end
end
