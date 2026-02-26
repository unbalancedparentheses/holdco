defmodule Holdco.Pricing do
  import Ecto.Query
  alias Holdco.Repo
  alias Holdco.Pricing.PriceHistory

  def record_price(ticker, price, currency \\ "USD") do
    %PriceHistory{}
    |> PriceHistory.changeset(%{ticker: ticker, price: price, currency: currency})
    |> Repo.insert()
    |> tap(fn
      {:ok, record} ->
        Holdco.Platform.log_action("create", "price_history", record.id)
        broadcast({:price_recorded, record})
      _ -> :ok
    end)
  end

  def get_latest_price(ticker) do
    from(p in PriceHistory,
      where: p.ticker == ^ticker,
      order_by: [desc: p.inserted_at],
      limit: 1)
    |> Repo.one()
  end

  def get_price_history(ticker, limit \\ 30) do
    from(p in PriceHistory,
      where: p.ticker == ^ticker,
      order_by: [desc: p.inserted_at],
      limit: ^limit)
    |> Repo.all()
  end

  def list_tracked_tickers do
    from(ah in Holdco.Assets.AssetHolding,
      where: not is_nil(ah.ticker) and ah.ticker != "",
      distinct: ah.ticker,
      select: ah.ticker,
      order_by: ah.ticker)
    |> Repo.all()
  end

  # PubSub
  def subscribe, do: Phoenix.PubSub.subscribe(Holdco.PubSub, "prices")
  defp broadcast(message), do: Phoenix.PubSub.broadcast(Holdco.PubSub, "prices", message)
end
