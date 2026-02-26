defmodule Holdco.Platform.AuditLog do
  use Ecto.Schema
  import Ecto.Changeset

  schema "audit_logs" do
    field :action, :string
    field :table_name, :string
    field :record_id, :integer
    field :details, :string
    field :old_values, :string
    field :new_values, :string
    belongs_to :user, Holdco.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(audit_log, attrs) do
    audit_log
    |> cast(attrs, [:action, :table_name, :record_id, :details, :user_id, :old_values, :new_values])
    |> validate_required([:action, :table_name])
  end
end
