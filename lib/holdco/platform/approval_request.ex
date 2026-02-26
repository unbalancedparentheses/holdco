defmodule Holdco.Platform.ApprovalRequest do
  use Ecto.Schema
  import Ecto.Changeset

  schema "approval_requests" do
    field :requested_by, :string
    field :table_name, :string
    field :record_id, :integer
    field :action, :string
    field :payload, :string, default: "{}"
    field :status, :string, default: "pending"
    field :reviewed_by, :string
    field :notes, :string
    field :reviewed_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(approval_request, attrs) do
    approval_request
    |> cast(attrs, [:requested_by, :table_name, :record_id, :action, :payload,
                     :status, :reviewed_by, :notes, :reviewed_at])
    |> validate_required([:requested_by, :table_name, :action])
  end
end
