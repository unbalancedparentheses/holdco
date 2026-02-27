defmodule Holdco.AI.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ai_messages" do
    field :role, :string
    field :content, :string
    belongs_to :conversation, Holdco.AI.Conversation

    timestamps(type: :utc_datetime)
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:role, :content, :conversation_id])
    |> validate_required([:role, :content, :conversation_id])
    |> validate_inclusion(:role, ~w(user assistant))
  end
end
