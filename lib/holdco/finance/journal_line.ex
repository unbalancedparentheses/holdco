defmodule Holdco.Finance.JournalLine do
  use Ecto.Schema
  import Ecto.Changeset

  schema "journal_lines" do
    field :debit, :float, default: 0.0
    field :credit, :float, default: 0.0
    field :notes, :string

    belongs_to :entry, Holdco.Finance.JournalEntry
    belongs_to :account, Holdco.Finance.Account
    belongs_to :segment, Holdco.Finance.Segment

    timestamps(type: :utc_datetime)
  end

  def changeset(journal_line, attrs) do
    journal_line
    |> cast(attrs, [:entry_id, :account_id, :debit, :credit, :notes, :segment_id])
    |> validate_required([:entry_id, :account_id])
  end
end
