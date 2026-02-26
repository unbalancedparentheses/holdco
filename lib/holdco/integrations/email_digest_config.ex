defmodule Holdco.Integrations.EmailDigestConfig do
  use Ecto.Schema
  import Ecto.Changeset

  schema "email_digest_configs" do
    field :frequency, :string, default: "weekly"
    field :is_active, :boolean, default: true
    field :include_portfolio, :boolean, default: true
    field :include_deadlines, :boolean, default: true
    field :include_audit_log, :boolean, default: true
    field :include_transactions, :boolean, default: true
    field :last_sent_at, :utc_datetime

    belongs_to :user, Holdco.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(email_digest_config, attrs) do
    email_digest_config
    |> cast(attrs, [
      :user_id,
      :frequency,
      :is_active,
      :include_portfolio,
      :include_deadlines,
      :include_audit_log,
      :include_transactions,
      :last_sent_at
    ])
    |> validate_required([:user_id])
  end
end
