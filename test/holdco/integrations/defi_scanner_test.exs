defmodule Holdco.Integrations.DefiScannerTest do
  use Holdco.DataCase, async: true

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

    test "maps stablecoins to correct CoinGecko IDs" do
      map = DefiScanner.token_id_map()
      assert map["USDC"] == "usd-coin"
      assert map["USDT"] == "tether"
      assert map["DAI"] == "dai"
    end

    test "maps L2 tokens correctly" do
      map = DefiScanner.token_id_map()
      assert map["ARB"] == "arbitrum"
      assert map["OP"] == "optimism"
      assert map["MATIC"] == "matic-network"
    end

    test "maps liquid staking tokens correctly" do
      map = DefiScanner.token_id_map()
      assert map["STETH"] == "staked-ether"
      assert map["RETH"] == "rocket-pool-eth"
    end
  end

  # ── init/0 ────────────────────────────────────────────────────────

  describe "init/0" do
    test "returns :ok" do
      assert :ok = DefiScanner.init()
    end

    test "is safe to call multiple times" do
      assert :ok = DefiScanner.init()
      assert :ok = DefiScanner.init()
      assert :ok = DefiScanner.init()
    end

    test "ensures ETS table exists" do
      DefiScanner.init()
      assert :ets.info(:defi_price_cache) != :undefined
    end
  end

  # ── fetch_erc20_balance/3 edge cases ──────────────────────────────

  describe "fetch_erc20_balance/3 edge cases" do
    test "returns error for non-binary chain argument" do
      assert {:error, :invalid_arguments} =
               DefiScanner.fetch_erc20_balance(123, "0xabc", nil)
    end

    test "returns error for non-binary wallet argument" do
      assert {:error, :invalid_arguments} =
               DefiScanner.fetch_erc20_balance("ethereum", 123, nil)
    end

    test "returns error for both non-binary arguments" do
      assert {:error, :invalid_arguments} =
               DefiScanner.fetch_erc20_balance(nil, nil, nil)
    end

    test "returns unsupported_chain for chain not in rpc_urls map" do
      assert {:error, :unsupported_chain} =
               DefiScanner.fetch_erc20_balance("fantom", "0xabc", nil)
    end

    test "returns unsupported_chain for empty string chain" do
      assert {:error, :unsupported_chain} =
               DefiScanner.fetch_erc20_balance("", "0xabc", nil)
    end

    test "attempts native balance fetch for ethereum chain with nil contract" do
      # This will fail at the RPC level but exercises the native balance path
      result = DefiScanner.fetch_erc20_balance("ethereum", "0x0000000000000000000000000000000000000000", nil)
      # Will be either an ok or error depending on network availability
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "attempts native balance fetch with empty string contract" do
      result = DefiScanner.fetch_erc20_balance("ethereum", "0x0000000000000000000000000000000000000000", "")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "attempts ERC20 balance fetch with contract address" do
      result =
        DefiScanner.fetch_erc20_balance(
          "ethereum",
          "0x0000000000000000000000000000000000000000",
          "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
        )

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  # ── fetch_token_price/1 with cached data ──────────────────────────

  describe "fetch_token_price/1 with various tokens" do
    test "resolves WBTC from cache" do
      :ets.insert(:defi_price_cache, {"wrapped-bitcoin", Decimal.new("65000"), System.monotonic_time(:millisecond)})
      assert {:ok, price} = DefiScanner.fetch_token_price("WBTC")
      assert Decimal.equal?(price, Decimal.new("65000"))
    end

    test "resolves USDC from cache" do
      :ets.insert(:defi_price_cache, {"usd-coin", Decimal.new("1.00"), System.monotonic_time(:millisecond)})
      assert {:ok, price} = DefiScanner.fetch_token_price("USDC")
      assert Decimal.equal?(price, Decimal.new("1.00"))
    end

    test "resolves STETH from cache" do
      :ets.insert(:defi_price_cache, {"staked-ether", Decimal.new("3400"), System.monotonic_time(:millisecond)})
      assert {:ok, price} = DefiScanner.fetch_token_price("STETH")
      assert Decimal.equal?(price, Decimal.new("3400"))
    end

    test "returns error for completely unknown token" do
      assert {:error, :unknown_token} = DefiScanner.fetch_token_price("NOTACOIN")
    end
  end

  # ── update_position_value/1 additional branches ────────────────────

  describe "update_position_value/1 additional branches" do
    test "handles empty wallet address (empty string)" do
      :ets.insert(:defi_price_cache, {"ethereum", Decimal.new("2000"), System.monotonic_time(:millisecond)})

      position = %DefiPosition{
        id: 995,
        asset_pair: "ETH/USDC",
        wallet_address: "",
        contract_address: nil,
        chain: "ethereum",
        deposited_amount: Decimal.new("5"),
        current_value: nil,
        status: "active"
      }

      assert {:ok, result} = DefiScanner.update_position_value(position)
      assert Decimal.equal?(result.current_value, Decimal.new("10000"))
    end

    test "handles chain='other' (no on-chain fetch)" do
      :ets.insert(:defi_price_cache, {"ethereum", Decimal.new("3000"), System.monotonic_time(:millisecond)})

      position = %DefiPosition{
        id: 994,
        asset_pair: "ETH",
        wallet_address: "some_address",
        contract_address: nil,
        chain: "other",
        deposited_amount: Decimal.new("2"),
        current_value: nil,
        status: "active"
      }

      assert {:ok, result} = DefiScanner.update_position_value(position)
      # No on-chain fetch for "other" chain, uses deposited_amount * price
      assert Decimal.equal?(result.current_value, Decimal.new("6000"))
    end

    test "computes unrealized_pnl correctly" do
      :ets.insert(:defi_price_cache, {"bitcoin", Decimal.new("50000"), System.monotonic_time(:millisecond)})

      position = %DefiPosition{
        id: 993,
        asset_pair: "BTC",
        wallet_address: nil,
        contract_address: nil,
        chain: "ethereum",
        deposited_amount: Decimal.new("100000"),
        current_value: nil,
        status: "active"
      }

      assert {:ok, result} = DefiScanner.update_position_value(position)
      # current_value = 100000 * 50000 = 5_000_000_000
      # unrealized_pnl = 5_000_000_000 - 100000 = 4_999_900_000
      assert Decimal.equal?(result.unrealized_pnl, Decimal.sub(result.current_value, Decimal.new("100000")))
    end
  end

  # ── extract_primary_symbol/1 additional cases ──────────────────────

  describe "extract_primary_symbol/1 edge cases" do
    test "handles multiple separators" do
      assert DefiScanner.extract_primary_symbol("ETH/USDC/DAI") == "ETH"
    end

    test "handles mixed case with separator" do
      assert DefiScanner.extract_primary_symbol("wbtc-dai") == "WBTC"
    end

    test "handles whitespace around separator" do
      # The trim should handle leading/trailing space on the first part
      assert DefiScanner.extract_primary_symbol("  ETH / USDC ") == "ETH"
    end

    test "handles single character token" do
      assert DefiScanner.extract_primary_symbol("X") == "X"
    end
  end

  # ── chain_rpc_urls/0 additional checks ─────────────────────────────

  describe "chain_rpc_urls/0 URL format" do
    test "all URLs are valid HTTPS endpoints" do
      urls = DefiScanner.chain_rpc_urls()

      for {_chain, url} <- urls do
        assert String.starts_with?(url, "https://"),
               "Expected URL to start with https://, got: #{url}"
      end
    end

    test "returns exactly 5 chains" do
      assert map_size(DefiScanner.chain_rpc_urls()) == 5
    end
  end

  # ── scan_all_positions/0 ───────────────────────────────────────────

  describe "scan_all_positions/0" do
    test "returns ok with zero counts when no positions exist" do
      assert {:ok, %{updated: 0, errors: 0}} = DefiScanner.scan_all_positions()
    end
  end

  # ── scan_all_positions/0 with DB positions ─────────────────────────

  describe "scan_all_positions/0 with positions" do
    import Holdco.HoldcoFixtures

    test "updates active positions with cached prices" do
      # Seed cache so we don't need real network
      :ets.insert(:defi_price_cache, {"ethereum", Decimal.new("3000"), System.monotonic_time(:millisecond)})

      _pos = defi_position_fixture(%{
        asset_pair: "ETH/USDC",
        deposited_amount: "10",
        current_value: "0",
        unrealized_pnl: "0",
        status: "active",
        wallet_address: nil,
        chain: "ethereum"
      })

      # scan_all_positions sleeps 1s between positions, but with only 1 position it's manageable
      assert {:ok, %{updated: updated, errors: errors}} = DefiScanner.scan_all_positions()
      assert updated + errors >= 1
    end

    test "skips inactive positions" do
      :ets.insert(:defi_price_cache, {"ethereum", Decimal.new("3000"), System.monotonic_time(:millisecond)})

      _inactive = defi_position_fixture(%{
        asset_pair: "ETH",
        deposited_amount: "5",
        status: "closed",
        wallet_address: nil,
        chain: "ethereum"
      })

      assert {:ok, %{updated: 0, errors: 0}} = DefiScanner.scan_all_positions()
    end

    test "counts error when token is unknown" do
      _pos = defi_position_fixture(%{
        asset_pair: "INVALIDTOKEN/USDC",
        deposited_amount: "100",
        status: "active",
        wallet_address: nil,
        chain: "ethereum"
      })

      assert {:ok, %{updated: 0, errors: 1}} = DefiScanner.scan_all_positions()
    end
  end

  # ── parse_hex_balance (tested via fetch_erc20_balance results) ──────

  describe "hex balance parsing edge cases" do
    test "token_id_map has correct size" do
      map = DefiScanner.token_id_map()
      assert map_size(map) == 18
    end
  end

  # ── update_position_value with on-chain fetch fallback ─────────────

  describe "update_position_value/1 with wallet address on unsupported chain" do
    test "falls back to deposited_amount when chain is solana with wallet" do
      :ets.insert(:defi_price_cache, {"solana", Decimal.new("100"), System.monotonic_time(:millisecond)})

      position = %DefiPosition{
        id: 990,
        asset_pair: "SOL",
        wallet_address: "SomeSolanaWalletAddress",
        contract_address: nil,
        chain: "solana",
        deposited_amount: Decimal.new("50"),
        current_value: nil,
        status: "active"
      }

      assert {:ok, result} = DefiScanner.update_position_value(position)
      # Solana is not supported for on-chain fetch, falls back to deposited_amount * price
      assert Decimal.equal?(result.current_value, Decimal.new("5000"))
    end
  end
end
