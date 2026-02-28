defmodule Holdco.Platform.SecurityKey do
  use Ecto.Schema
  import Ecto.Changeset

  schema "security_keys" do
    field :name, :string
    field :credential_id, :string
    field :public_key, :string
    field :sign_count, :integer, default: 0
    field :aaguid, :string
    field :transports, {:array, :string}, default: []
    field :registered_at, :utc_datetime
    field :last_used_at, :utc_datetime
    field :is_active, :boolean, default: true
    field :notes, :string

    belongs_to :user, Holdco.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(security_key, attrs) do
    security_key
    |> cast(attrs, [
      :user_id,
      :name,
      :credential_id,
      :public_key,
      :sign_count,
      :aaguid,
      :transports,
      :registered_at,
      :last_used_at,
      :is_active,
      :notes
    ])
    |> validate_required([:user_id, :name, :credential_id, :public_key])
    |> validate_number(:sign_count, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:user_id)
  end
end
