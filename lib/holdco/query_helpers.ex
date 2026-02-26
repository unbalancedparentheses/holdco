defmodule Holdco.QueryHelpers do
  import Ecto.Query

  def apply_filters(query, filters) when is_map(filters) do
    Enum.reduce(filters, query, fn
      {_key, nil}, query ->
        query

      {_key, ""}, query ->
        query

      {:sort_by, field}, query when is_atom(field) ->
        order_by(query, [q], asc: ^field)

      {:sort_dir, _dir}, query ->
        query

      {key, value}, query ->
        if has_field?(query, key) do
          where(query, [q], field(q, ^key) == ^value)
        else
          query
        end
    end)
  end

  def apply_filters(query, _), do: query

  defp has_field?(query, field) do
    %{from: %{source: {_, schema}}} = query
    field in schema.__schema__(:fields)
  rescue
    _ -> false
  end
end
