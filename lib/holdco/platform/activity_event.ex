defmodule Holdco.Platform.ActivityEvent do
  use Ecto.Schema
  import Ecto.Changeset

  @actions ~w(created updated deleted approved rejected locked unlocked exported imported dispatched)

  schema "activity_events" do
    field :actor_email, :string
    field :action, :string
    field :entity_type, :string
    field :entity_id, :integer
    field :entity_name, :string
    field :context_module, :string
    field :metadata, :map, default: %{}
    field :ip_address, :string
    field :user_agent, :string

    belongs_to :actor, Holdco.Accounts.User
    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :actor_id, :actor_email, :action, :entity_type, :entity_id,
      :entity_name, :context_module, :metadata, :company_id,
      :ip_address, :user_agent
    ])
    |> validate_required([:action, :entity_type])
    |> validate_inclusion(:action, @actions)
    |> foreign_key_constraint(:actor_id)
    |> foreign_key_constraint(:company_id)
  end

  def actions, do: @actions
end
