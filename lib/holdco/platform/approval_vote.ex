defmodule Holdco.Platform.ApprovalVote do
  use Ecto.Schema
  import Ecto.Changeset

  schema "approval_votes" do
    field :decision, :string
    field :notes, :string

    belongs_to :approval_request, Holdco.Platform.ApprovalRequest
    belongs_to :user, Holdco.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(vote, attrs) do
    vote
    |> cast(attrs, [:approval_request_id, :user_id, :decision, :notes])
    |> validate_required([:approval_request_id, :user_id, :decision])
    |> validate_inclusion(:decision, ~w(approved rejected))
    |> unique_constraint([:approval_request_id, :user_id])
  end
end
