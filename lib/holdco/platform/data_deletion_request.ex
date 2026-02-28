defmodule Holdco.Platform.DataDeletionRequest do
  use Ecto.Schema
  import Ecto.Changeset

  schema "data_deletion_requests" do
    field :requested_by_email, :string
    field :request_type, :string
    field :status, :string, default: "pending"
    field :data_categories, {:array, :string}, default: []
    field :reason, :string
    field :processed_by_id, :integer
    field :processed_at, :utc_datetime
    field :denial_reason, :string
    field :notes, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(request, attrs) do
    request
    |> cast(attrs, [
      :requested_by_email,
      :request_type,
      :status,
      :data_categories,
      :reason,
      :processed_by_id,
      :processed_at,
      :denial_reason,
      :notes
    ])
    |> validate_required([:requested_by_email, :request_type])
    |> validate_inclusion(:request_type, ~w(erasure portability access rectification))
    |> validate_inclusion(:status, ~w(pending in_progress completed denied))
    |> validate_format(:requested_by_email, ~r/@/)
  end
end
