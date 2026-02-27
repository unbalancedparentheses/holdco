defmodule Holdco.Workers.SnapshotPricesWorker do
  use Oban.Worker, queue: :prices, max_attempts: 3

  alias Holdco.{Assets, Pricing}

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    tickers =
      Assets.list_holdings()
      |> Enum.map(& &1.ticker)
      |> Enum.reject(&is_nil/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()

    results =
      for ticker <- tickers do
        case Holdco.Pricing.YahooClient.fetch_price(ticker) do
          {:ok, price} ->
            Pricing.record_price(ticker, price)
            :ok

          {:error, reason} ->
            Logger.warning("SnapshotPricesWorker: failed to fetch price for #{ticker}: #{inspect(reason)}")
            :error
        end
      end

    failures = Enum.count(results, &(&1 == :error))

    if failures > 0 do
      Logger.warning("SnapshotPricesWorker: #{failures}/#{length(tickers)} tickers failed")
    end

    :ok
  end
end
