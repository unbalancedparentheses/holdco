defmodule Holdco.Finance.JournalEntry do
  use Ecto.Schema
  import Ecto.Changeset

  schema "journal_entries" do
    field :date, :string
    field :description, :string
    field :reference, :string

    has_many :lines, Holdco.Finance.JournalLine, foreign_key: :entry_id

    timestamps(type: :utc_datetime)
  end

  def changeset(journal_entry, attrs) do
    journal_entry
    |> cast(attrs, [:date, :description, :reference])
    |> validate_required([:date, :description])
  end
end
