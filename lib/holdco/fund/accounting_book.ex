defmodule Holdco.Fund.AccountingBook do
  use Ecto.Schema
  import Ecto.Changeset

  schema "accounting_books" do
    field :name, :string
    field :book_type, :string
    field :base_currency, :string, default: "USD"
    field :is_primary, :boolean, default: false
    field :description, :string
    field :is_active, :boolean, default: true

    belongs_to :company, Holdco.Corporate.Company
    has_many :adjustments, Holdco.Fund.BookAdjustment, foreign_key: :book_id

    timestamps(type: :utc_datetime)
  end

  @valid_book_types ~w(ifrs us_gaap local_gaap tax management)

  def changeset(book, attrs) do
    book
    |> cast(attrs, [:company_id, :name, :book_type, :base_currency, :is_primary, :description, :is_active])
    |> validate_required([:company_id, :name, :book_type])
    |> validate_inclusion(:book_type, @valid_book_types)
    |> foreign_key_constraint(:company_id)
  end
end
