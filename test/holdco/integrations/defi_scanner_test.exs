defmodule Holdco.Integrations.DefiScannerTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Integrations.DefiScanner
  alias Holdco.Analytics.DefiPosition

  # Ensure the ETS cache is available for every test
  setup do
    DefiScanner.init()
    :ok
  end

  # ── Token symbol extraction ──────────────────────────────────────────

  describe "extract_primary_symbol/1" do
    test "extracts first token from slash-separated pair" do
      assert DefiScanner.extract_primary_symbol("ETH/USDC") == "ETH"
    end

    test "extracts first token from dash-separated pair" do
      assert DefiScanner.extract_primary_symbol("WBTC-DAI") == "WBTC"
    end

    test "extracts first token from underscore-separated pair" do
      assert DefiScanner.extract_primary_symbol("aave_eth") == "AAVE"
    end

    test "returns the symbol itself when no separator" do
      assert DefiScanner.extract_primary_symbol("SOL") == "SOL"
    end

    test "defaults to ETH for nil input" do
      assert DefiScanner.extract_primary_symbol(nil) == "ETH"
    end

    test "defaults to ETH for empty string" do
      assert DefiScanner.extract_primary_symbol("") == "ETH"
    end

    test "uppercases the result" do
      assert DefiScanner.extract_primary_symbol("eth/usdc") == "ETH"
    end
  end

  # ── fetch_token_price/1 ──────────────────────────────────────────────

  describe "fetch_token_price/1" do
    test "returns error for unknown token symbol" do
      assert {:error, :unknown_token} = DefiScanner.fetch_token_price("FAKECOIN")
    end

    test "returns error for empty string" do
      assert {:error, :unknown_token} = DefiScanner.fetch_token_price("")
    end

    test "is case-insensitive" do
      # Pre-seed cache so we don't hit the network
      :ets.insert(:defi_price_cache, {"ethereum", Decimal.new("3500.00"), System.monotonic_time(:millisecond)})

      # Both uppercase and lowercase should resolve to the same CoinGecko ID
      assert {:ok, _price} = DefiScanner.fetch_token_price("ETH")
      assert {:ok, _price} = DefiScanner.fetch_token_price("eth")
    end
  end

  # ── Price cache ──────────────────────────────────────────────────────

  describe "price cache" do
    test "caches a price and retrieves it on second call" do
      # Manually insert a price into the ETS cache to simulate a successful fetch
      :ets.insert(:defi_price_cache, {"ethereum", Decimal.new("3500.00"), System.monotonic_time(:millisecond)})

      # Reading the cached price should succeed
      assert {:ok, %Decimal{}} = DefiScanner.fetch_token_price("ETH")
    end

    test "expired cache entries are treated as a miss" do
      # Insert a price with a timestamp far in the past (expired)
      expired_ts = System.monotonic_time(:millisecond) - :timer.minutes(10)
      :ets.insert(:defi_price_cache, {"bitcoin", Decimal.new("60000"), expired_ts})

      # After expiry the entry should be deleted from ETS
      # We can verify by checking the ETS table directly after a lookup attempt
      # (the fetch will try the network and likely error in test, but
      # the important thing is the stale entry was evicted)
      _result = DefiScanner.fetch_token_price("BTC")

      # The expired entry should have been removed from the cache
      assert :ets.lookup(:defi_price_cache, "bitcoin") == [] ||
               # or it was refreshed with a new timestamp
               match?(
                 [{_, _, ts}] when ts > expired_ts,
                 :ets.lookup(:defi_price_cache, "bitcoin")
               )
    end
  end

  # ── Chain RPC mapping ────────────────────────────────────────────────

  describe "chain_rpc_urls/0" do
    test "contains all supported EVM chains" do
      urls = DefiScanner.chain_rpc_urls()
      assert Map.has_key?(urls, "ethereum")
      assert Map.has_key?(urls, "polygon")
      assert Map.has_key?(urls, "arbitrum")
      assert Map.has_key?(urls, "avalanche")
      assert Map.has_key?(urls, "bsc")
    end

    test "does not contain solana or other" do
      urls = DefiScanner.chain_rpc_urls()
      refute Map.has_key?(urls, "solana")
      refute Map.has_key?(urls, "other")
    end
  end

  # ── fetch_erc20_balance/3 ────────────────────────────────────────────

  describe "fetch_erc20_balance/3" do
    test "returns unsupported_chain for solana" do
      assert {:error, :unsupported_chain} =
               DefiScanner.fetch_erc20_balance("solana", "0xabc", nil)
    end

    test "returns unsupported_chain for other" do
      assert {:error, :unsupported_chain} =
               DefiScanner.fetch_erc20_balance("other", "0xabc", nil)
    end

    test "returns unsupported_chain for unknown chain" do
      assert {:error, :unsupported_chain} =
               DefiScanner.fetch_erc20_balance("fantom", "0xabc", nil)
    end
  end

  # ── update_position_value/1 ──────────────────────────────────────────

  describe "update_position_value/1" do
    test "returns value based on deposited_amount when no wallet address" do
      # Seed a known price in the cache so we don't hit the network
      :ets.insert(:defi_price_cache, {"ethereum", Decimal.new("3000"), System.monotonic_time(:millisecond)})

      position = %DefiPosition{
        id: 999,
        asset_pair: "ETH/USDC",
        wallet_address: nil,
        contract_address: nil,
        chain: "ethereum",
        deposited_amount: Decimal.new("10"),
        current_value: nil,
        status: "active"
      }

      assert {:ok, result} = DefiScanner.update_position_value(position)
      # 10 * 3000 = 30000
      assert Decimal.equal?(result.current_value, Decimal.new("30000"))
      # 30000 - 10 = 29990
      assert Decimal.equal?(result.unrealized_pnl, Decimal.new("29990"))
    end

    test "returns value based on deposited_amount when chain is solana (unsupported for on-chain)" do
      :ets.insert(:defi_price_cache, {"solana", Decimal.new("150"), System.monotonic_time(:millisecond)})

      position = %DefiPosition{
        id: 998,
        asset_pair: "SOL",
        wallet_address: "SomeSOLAddress123",
        contract_address: nil,
        chain: "solana",
        deposited_amount: Decimal.new("100"),
        current_value: nil,
        status: "active"
      }

      assert {:ok, result} = DefiScanner.update_position_value(position)
      # 100 * 150 = 15000
      assert Decimal.equal?(result.current_value, Decimal.new("15000"))
    end

    test "returns error when asset pair maps to unknown token" do
      position = %DefiPosition{
        id: 997,
        asset_pair: "FAKE/USDC",
        wallet_address: nil,
        contract_address: nil,
        chain: "ethereum",
        deposited_amount: Decimal.new("100"),
        current_value: nil,
        status: "active"
      }

      assert {:error, :unknown_token} = DefiScanner.update_position_value(position)
    end

    test "handles nil deposited_amount gracefully" do
      :ets.insert(:defi_price_cache, {"ethereum", Decimal.new("3000"), System.monotonic_time(:millisecond)})

      position = %DefiPosition{
        id: 996,
        asset_pair: "ETH",
        wallet_address: nil,
        contract_address: nil,
        chain: "ethereum",
        deposited_amount: nil,
        current_value: nil,
        status: "active"
      }

      assert {:ok, result} = DefiScanner.update_position_value(position)
      assert Decimal.equal?(result.current_value, Decimal.new("0"))
      assert Decimal.equal?(result.unrealized_pnl, Decimal.new("0"))
    end
  end

  # ── token_id_map/0 ──────────────────────────────────────────────────

  describe "token_id_map/0" do
    test "maps ETH and WETH to ethereum" do
      map = DefiScanner.token_id_map()
      assert map["ETH"] == "ethereum"
      assert map["WETH"] == "ethereum"
    end

    test "contains all expected tokens" do
      map = DefiScanner.token_id_map()
      expected = ~w(ETH WETH BTC WBTC USDC USDT DAI LINK UNI AAVE CRV SOL MATIC AVAX ARB OP STETH RETH)
      for token <- expected do
        assert Map.has_key?(map, token), "Missing token: #{token}"
      end
    end
  end
end
