defmodule Holdco.AI.Conversation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ai_conversations" do
    field :title, :string
    belongs_to :user, Holdco.Accounts.User
    has_many :messages, Holdco.AI.Message

    timestamps(type: :utc_datetime)
  end

  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:title, :user_id])
    |> validate_required([:user_id])
  end
end
