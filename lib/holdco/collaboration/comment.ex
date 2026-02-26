defmodule Holdco.Collaboration.Comment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "comments" do
    field :entity_type, :string
    field :entity_id, :integer
    field :body, :string
    belongs_to :user, Holdco.Accounts.User
    timestamps(type: :utc_datetime)
  end

  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:user_id, :entity_type, :entity_id, :body])
    |> validate_required([:entity_type, :entity_id, :body])
  end
end
