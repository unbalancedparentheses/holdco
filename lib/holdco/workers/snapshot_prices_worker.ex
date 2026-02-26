defmodule Holdco.Workers.SnapshotPricesWorker do
  use Oban.Worker, queue: :prices, max_attempts: 3

  alias Holdco.{Assets, Pricing}

  @impl Oban.Worker
  def perform(_job) do
    tickers =
      Assets.list_holdings()
      |> Enum.map(& &1.ticker)
      |> Enum.reject(&is_nil/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()

    for ticker <- tickers do
      case Holdco.Pricing.YahooClient.fetch_price(ticker) do
        {:ok, price} -> Pricing.record_price(ticker, price)
        {:error, _} -> :skip
      end
    end

    :ok
  end
end
