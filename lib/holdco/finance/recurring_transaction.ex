defmodule Holdco.Finance.RecurringTransaction do
  use Ecto.Schema
  import Ecto.Changeset
  import Holdco.Validators

  schema "recurring_transactions" do
    field :description, :string
    field :amount, :decimal
    field :currency, :string, default: "USD"
    field :frequency, :string
    field :start_date, :string
    field :end_date, :string
    field :next_run_date, :string
    field :last_run_date, :string
    field :is_active, :boolean, default: true
    field :transaction_type, :string
    field :counterparty, :string
    field :auto_post, :boolean, default: false
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company
    belongs_to :debit_account, Holdco.Finance.Account
    belongs_to :credit_account, Holdco.Finance.Account

    timestamps(type: :utc_datetime)
  end

  def changeset(recurring_transaction, attrs) do
    recurring_transaction
    |> cast(attrs, [
      :company_id,
      :description,
      :amount,
      :currency,
      :frequency,
      :start_date,
      :end_date,
      :next_run_date,
      :last_run_date,
      :is_active,
      :transaction_type,
      :counterparty,
      :debit_account_id,
      :credit_account_id,
      :auto_post,
      :notes
    ])
    |> validate_required([:company_id, :description, :amount, :frequency, :start_date, :next_run_date])
    |> validate_number(:amount, greater_than: 0)
    |> validate_inclusion(:frequency, ~w(daily weekly monthly quarterly yearly))
    |> validate_date_format(:start_date)
    |> validate_date_format(:next_run_date)
  end
end
