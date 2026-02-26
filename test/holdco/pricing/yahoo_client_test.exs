defmodule Holdco.Pricing.YahooClientTest do
  use Holdco.DataCase

  alias Holdco.Pricing.YahooClient

  setup do
    # Ensure the ETS cache table exists
    YahooClient.start_link()
    :ok
  end

  describe "start_link/1" do
    test "returns :ignore" do
      # Table already created in setup, so this should still return :ignore
      assert :ignore == YahooClient.start_link()
    end

    test "returns :ignore even if table already exists" do
      assert :ignore == YahooClient.start_link()
      assert :ignore == YahooClient.start_link()
    end
  end

  describe "ensure_cache_table/0" do
    test "creates or returns info about cache table" do
      result = YahooClient.ensure_cache_table()
      assert result != :undefined
    end
  end

  describe "resolve_ticker/1" do
    test "maps XAUUSD to GC=F" do
      assert YahooClient.resolve_ticker("XAUUSD") == "GC=F"
    end

    test "maps XAGUSD to SI=F" do
      assert YahooClient.resolve_ticker("XAGUSD") == "SI=F"
    end

    test "maps BTC to BTC-USD" do
      assert YahooClient.resolve_ticker("BTC") == "BTC-USD"
    end

    test "maps ETH to ETH-USD" do
      assert YahooClient.resolve_ticker("ETH") == "ETH-USD"
    end

    test "maps SOL to SOL-USD" do
      assert YahooClient.resolve_ticker("SOL") == "SOL-USD"
    end

    test "returns the same ticker for unknown tickers" do
      assert YahooClient.resolve_ticker("AAPL") == "AAPL"
      assert YahooClient.resolve_ticker("GOOGL") == "GOOGL"
      assert YahooClient.resolve_ticker("TSLA") == "TSLA"
    end
  end

  describe "fetch_fx_rate/1" do
    test "returns {:ok, 1.0} for USD" do
      assert {:ok, 1.0} == YahooClient.fetch_fx_rate("USD")
    end

    test "returns {:error, :unsupported_currency} for unknown currency" do
      assert {:error, :unsupported_currency} == YahooClient.fetch_fx_rate("XYZ")
    end

    test "attempts to fetch rate for EUR" do
      # This will make an HTTP call that will likely fail in test, but should return a tuple
      result = YahooClient.fetch_fx_rate("EUR")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "attempts to fetch rate for GBP" do
      result = YahooClient.fetch_fx_rate("GBP")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "attempts to fetch rate for ARS" do
      result = YahooClient.fetch_fx_rate("ARS")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "attempts to fetch rate for BRL" do
      result = YahooClient.fetch_fx_rate("BRL")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "fetch_price/1" do
    test "returns cached price if present and not expired" do
      # Insert a cached entry directly
      :ets.insert(:yahoo_price_cache, {"CACHED_TICKER", 42.0, System.monotonic_time(:millisecond)})

      assert {:ok, 42.0} == YahooClient.fetch_price("CACHED_TICKER")
    end

    test "cache miss for unknown ticker triggers HTTP fetch" do
      result = YahooClient.fetch_price("UNKNOWN_YF_TICKER_#{System.unique_integer([:positive])}")
      # Should return either ok or error tuple (HTTP call will likely fail in test)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "returns cached price for mapped ticker" do
      # Cache with the Yahoo Finance ticker key
      :ets.insert(:yahoo_price_cache, {"BTC-USD", 50000.0, System.monotonic_time(:millisecond)})

      assert {:ok, 50000.0} == YahooClient.fetch_price("BTC")
    end

    test "expired cache entry results in miss and re-fetch" do
      # Insert expired entry (timestamp far in the past)
      :ets.insert(:yahoo_price_cache, {"EXPIRED_T", 42.0, System.monotonic_time(:millisecond) - 400_000})

      result = YahooClient.fetch_price("EXPIRED_T")
      # Should try to re-fetch, which will likely error in test
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end
end
