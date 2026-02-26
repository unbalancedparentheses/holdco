defmodule Holdco.Depreciation do
  @moduledoc """
  Depreciation calculations for fixed assets (straight-line and declining balance).
  """

  import Ecto.Query
  alias Holdco.Repo
  alias Holdco.Finance.FixedAsset

  def list_fixed_assets(company_id \\ nil) do
    query = from(fa in FixedAsset, order_by: fa.name, preload: [:company, :account])
    query = if company_id, do: where(query, [fa], fa.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_fixed_asset!(id), do: Repo.get!(FixedAsset, id) |> Repo.preload([:company, :account])

  def create_fixed_asset(attrs) do
    %FixedAsset{}
    |> FixedAsset.changeset(attrs)
    |> Repo.insert()
    |> audit("fixed_assets", "create")
  end

  def update_fixed_asset(%FixedAsset{} = fa, attrs) do
    fa
    |> FixedAsset.changeset(attrs)
    |> Repo.update()
    |> audit("fixed_assets", "update")
  end

  def delete_fixed_asset(%FixedAsset{} = fa) do
    Repo.delete(fa)
    |> audit("fixed_assets", "delete")
  end

  def schedule(asset) do
    cost = asset.purchase_price || 0.0
    salvage = asset.salvage_value || 0.0
    months = asset.useful_life_months || 1
    method = asset.depreciation_method || "straight_line"
    start = parse_date(asset.purchase_date) || Date.utc_today()

    case method do
      "declining_balance" -> declining_balance_schedule(cost, salvage, months, start)
      _ -> straight_line_schedule(cost, salvage, months, start)
    end
  end

  defp straight_line_schedule(cost, salvage, months, start) do
    depreciable = cost - salvage
    monthly = if months > 0, do: depreciable / months, else: 0.0

    Enum.map(0..(months - 1), fn i ->
      date = Date.add(start, i * 30)
      accumulated = monthly * (i + 1)

      %{
        month: i + 1,
        date: Date.to_iso8601(date),
        depreciation: Float.round(monthly, 2),
        accumulated: Float.round(min(accumulated, depreciable), 2),
        book_value: Float.round(max(cost - accumulated, salvage), 2)
      }
    end)
  end

  defp declining_balance_schedule(cost, salvage, months, start) do
    rate = if months > 0, do: 2.0 / months, else: 0.0

    {rows, _} =
      Enum.reduce(0..(months - 1), {[], cost}, fn i, {acc, book} ->
        depreciation = max(book * rate, 0.0)
        depreciation = min(depreciation, book - salvage)
        depreciation = max(depreciation, 0.0)
        new_book = book - depreciation
        date = Date.add(start, i * 30)

        row = %{
          month: i + 1,
          date: Date.to_iso8601(date),
          depreciation: Float.round(depreciation, 2),
          accumulated: Float.round(cost - new_book, 2),
          book_value: Float.round(new_book, 2)
        }

        {acc ++ [row], new_book}
      end)

    rows
  end

  defp parse_date(nil), do: nil

  defp parse_date(date_str) do
    case Date.from_iso8601(date_str) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp audit(result, table, action) do
    case result do
      {:ok, record} ->
        Holdco.Platform.log_action(action, table, record.id)
        {:ok, record}

      error ->
        error
    end
  end
end
