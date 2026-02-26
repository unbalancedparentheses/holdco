defmodule Holdco.AuditDiff do
  @moduledoc """
  Computes diffs from Ecto changesets and stores old/new values on audit logs.
  """

  def compute_diff(%Ecto.Changeset{} = changeset) do
    changes = changeset.changes

    old_values =
      changes
      |> Map.keys()
      |> Enum.reduce(%{}, fn field, acc ->
        old_val = Map.get(changeset.data, field)
        Map.put(acc, field, old_val)
      end)

    new_values =
      changes
      |> Enum.reduce(%{}, fn {field, val}, acc ->
        Map.put(acc, field, val)
      end)

    %{
      old_values: Jason.encode!(old_values),
      new_values: Jason.encode!(new_values)
    }
  end

  def format_diff(nil, nil), do: []

  def format_diff(old_json, new_json) do
    old = safe_decode(old_json)
    new = safe_decode(new_json)

    all_keys = Map.keys(old) ++ Map.keys(new)

    all_keys
    |> Enum.uniq()
    |> Enum.map(fn key ->
      %{
        field: key,
        old_value: Map.get(old, key),
        new_value: Map.get(new, key)
      }
    end)
    |> Enum.filter(fn %{old_value: o, new_value: n} -> o != n end)
  end

  defp safe_decode(nil), do: %{}
  defp safe_decode(""), do: %{}

  defp safe_decode(json) when is_binary(json) do
    case Jason.decode(json) do
      {:ok, map} when is_map(map) -> map
      _ -> %{}
    end
  end
end
