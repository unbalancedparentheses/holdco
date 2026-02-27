defmodule Holdco.Depreciation do
  @moduledoc """
  Depreciation calculations for fixed assets (straight-line and declining balance).
  """

  import Ecto.Query
  alias Holdco.Repo
  alias Holdco.Finance.FixedAsset
  alias Holdco.Money

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
    cost = Money.to_decimal(asset.purchase_price)
    salvage = Money.to_decimal(asset.salvage_value)
    months = asset.useful_life_months || 1
    method = asset.depreciation_method || "straight_line"
    start = parse_date(asset.purchase_date) || Date.utc_today()

    case method do
      "declining_balance" -> declining_balance_schedule(cost, salvage, months, start)
      _ -> straight_line_schedule(cost, salvage, months, start)
    end
  end

  defp straight_line_schedule(cost, salvage, months, start) do
    depreciable = Money.sub(cost, salvage)
    monthly = if months > 0, do: Money.div(depreciable, months), else: Decimal.new(0)

    Enum.map(0..(months - 1), fn i ->
      date = Date.add(start, i * 30)
      accumulated = Money.mult(monthly, i + 1)

      %{
        month: i + 1,
        date: Date.to_iso8601(date),
        depreciation: Money.to_float(Money.round(monthly, 2)),
        accumulated: Money.to_float(Money.round(Money.min(accumulated, depreciable), 2)),
        book_value: Money.to_float(Money.round(Money.max(Money.sub(cost, accumulated), salvage), 2))
      }
    end)
  end

  defp declining_balance_schedule(cost, salvage, months, start) do
    rate = if months > 0, do: Money.div(Decimal.new(2), months), else: Decimal.new(0)

    {rows, _} =
      Enum.reduce(0..(months - 1), {[], cost}, fn i, {acc, book} ->
        depreciation = Money.max(Money.mult(book, rate), Decimal.new(0))
        depreciation = Money.min(depreciation, Money.sub(book, salvage))
        depreciation = Money.max(depreciation, Decimal.new(0))
        new_book = Money.sub(book, depreciation)
        date = Date.add(start, i * 30)

        row = %{
          month: i + 1,
          date: Date.to_iso8601(date),
          depreciation: Money.to_float(Money.round(depreciation, 2)),
          accumulated: Money.to_float(Money.round(Money.sub(cost, new_book), 2)),
          book_value: Money.to_float(Money.round(new_book, 2))
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
