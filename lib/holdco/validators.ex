defmodule Holdco.Validators do
  @moduledoc """
  Shared changeset validators.
  """
  import Ecto.Changeset

  @doc """
  Validates that a string field contains a valid ISO 8601 date (YYYY-MM-DD).
  Allows nil values (use validate_required separately if needed).
  """
  def validate_date_format(changeset, field) do
    validate_change(changeset, field, fn _, value ->
      case Date.from_iso8601(value) do
        {:ok, _} -> []
        {:error, _} -> [{field, "must be a valid date (YYYY-MM-DD)"}]
      end
    end)
  end
end
