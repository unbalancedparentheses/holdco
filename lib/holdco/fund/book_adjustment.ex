defmodule Holdco.Fund.BookAdjustment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "book_adjustments" do
    field :adjustment_type, :string
    field :amount, :decimal
    field :description, :string
    field :effective_date, :date

    belongs_to :accounting_book, Holdco.Fund.AccountingBook, foreign_key: :book_id
    belongs_to :journal_entry, Holdco.Finance.JournalEntry
    belongs_to :debit_account, Holdco.Finance.Account
    belongs_to :credit_account, Holdco.Finance.Account

    timestamps(type: :utc_datetime)
  end

  @valid_adjustment_types ~w(reclassification measurement elimination other)

  def changeset(adjustment, attrs) do
    adjustment
    |> cast(attrs, [
      :book_id,
      :journal_entry_id,
      :adjustment_type,
      :debit_account_id,
      :credit_account_id,
      :amount,
      :description,
      :effective_date
    ])
    |> validate_required([:book_id, :adjustment_type, :amount, :effective_date])
    |> validate_inclusion(:adjustment_type, @valid_adjustment_types)
    |> validate_number(:amount, greater_than: 0)
    |> foreign_key_constraint(:book_id)
    |> foreign_key_constraint(:journal_entry_id)
    |> foreign_key_constraint(:debit_account_id)
    |> foreign_key_constraint(:credit_account_id)
  end
end
