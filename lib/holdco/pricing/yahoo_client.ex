defmodule Holdco.Pricing.YahooClient do
  @moduledoc """
  Fetches live prices from Yahoo Finance REST API via Req.
  Uses ETS for caching with 5-minute TTL.
  """

  @cache_table :yahoo_price_cache
  @cache_ttl_ms 300_000

  @ticker_map %{
    "XAUUSD" => "GC=F",
    "XAGUSD" => "SI=F",
    "BTC" => "BTC-USD",
    "ETH" => "ETH-USD",
    "SOL" => "SOL-USD"
  }

  @fx_tickers %{
    "EUR" => "EURUSD=X",
    "GBP" => "GBPUSD=X",
    "ARS" => "ARSUSD=X",
    "BRL" => "BRLUSD=X"
  }

  def start_link(_opts \\ []) do
    :ets.new(@cache_table, [:set, :public, :named_table])
    :ignore
  rescue
    ArgumentError -> :ignore
  end

  def ensure_cache_table do
    try do
      :ets.info(@cache_table)
    rescue
      _ -> :ets.new(@cache_table, [:set, :public, :named_table])
    end
  end

  def resolve_ticker(ticker), do: Map.get(@ticker_map, ticker, ticker)

  def fetch_price(ticker) do
    ensure_cache_table()
    yf_ticker = resolve_ticker(ticker)

    case get_cached(yf_ticker) do
      {:ok, price} -> {:ok, price}
      :miss -> fetch_and_cache(yf_ticker, ticker)
    end
  end

  def fetch_fx_rate("USD"), do: {:ok, 1.0}

  def fetch_fx_rate(currency) do
    case Map.get(@fx_tickers, currency) do
      nil -> {:error, :unsupported_currency}
      ticker -> fetch_price(ticker)
    end
  end

  defp get_cached(ticker) do
    case :ets.lookup(@cache_table, ticker) do
      [{^ticker, price, ts}] ->
        if System.monotonic_time(:millisecond) - ts < @cache_ttl_ms do
          {:ok, price}
        else
          :miss
        end

      [] ->
        :miss
    end
  rescue
    _ -> :miss
  end

  defp fetch_and_cache(yf_ticker, original_ticker) do
    url = "https://query1.finance.yahoo.com/v8/finance/chart/#{yf_ticker}?interval=1d&range=1d"

    case Req.get(url, headers: [{"user-agent", "Mozilla/5.0"}]) do
      {:ok, %{status: 200, body: body}} ->
        price =
          get_in(body, ["chart", "result", Access.at(0), "meta", "regularMarketPrice"])

        if price do
          price = price / 1.0
          :ets.insert(@cache_table, {yf_ticker, price, System.monotonic_time(:millisecond)})

          if original_ticker != yf_ticker do
            :ets.insert(
              @cache_table,
              {original_ticker, price, System.monotonic_time(:millisecond)}
            )
          end

          {:ok, price}
        else
          {:error, :no_price}
        end

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    e -> {:error, e}
  end
end
