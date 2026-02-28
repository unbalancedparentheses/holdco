defmodule Holdco.Integrations.DefiScanner do
  @moduledoc """
  DeFi wallet balance and price tracking.

  Fetches on-chain ERC-20 / native token balances via public JSON-RPC
  endpoints and token prices from the CoinGecko free API. Results are
  cached in an ETS table with a 5-minute TTL to avoid rate-limiting.
  """

  require Logger

  alias Holdco.Analytics
  alias Holdco.Analytics.DefiPosition

  @price_cache_table :defi_price_cache
  @cache_ttl_ms :timer.minutes(5)

  @coingecko_base_url "https://api.coingecko.com/api/v3"

  @token_id_map %{
    "ETH" => "ethereum",
    "WETH" => "ethereum",
    "BTC" => "bitcoin",
    "WBTC" => "wrapped-bitcoin",
    "USDC" => "usd-coin",
    "USDT" => "tether",
    "DAI" => "dai",
    "LINK" => "chainlink",
    "UNI" => "uniswap",
    "AAVE" => "aave",
    "CRV" => "curve-dao-token",
    "SOL" => "solana",
    "MATIC" => "matic-network",
    "AVAX" => "avalanche-2",
    "ARB" => "arbitrum",
    "OP" => "optimism",
    "STETH" => "staked-ether",
    "RETH" => "rocket-pool-eth"
  }

  @chain_rpc_urls %{
    "ethereum" => "https://eth.llamarpc.com",
    "polygon" => "https://polygon.llamarpc.com",
    "arbitrum" => "https://arbitrum.llamarpc.com",
    "avalanche" => "https://avalanche.llamarpc.com",
    "bsc" => "https://bsc.llamarpc.com"
  }

  # ── Public API ──────────────────────────────────────────────────────

  @doc "Return the internal token-symbol-to-CoinGecko-ID mapping."
  def token_id_map, do: @token_id_map

  @doc "Return the chain-to-RPC-URL mapping."
  def chain_rpc_urls, do: @chain_rpc_urls

  @doc """
  Fetch the current USD price for a token symbol (e.g. "ETH", "WBTC").

  Returns `{:ok, %Decimal{}}` or `{:error, reason}`.
  """
  def fetch_token_price(symbol) when is_binary(symbol) do
    init()
    symbol = String.upcase(symbol)

    case Map.get(@token_id_map, symbol) do
      nil ->
        {:error, :unknown_token}

      coingecko_id ->
        case read_cache(coingecko_id) do
          {:ok, price} ->
            {:ok, price}

          :miss ->
            fetch_and_cache_price(coingecko_id)
        end
    end
  end

  @doc """
  Fetch the on-chain balance for an EVM-compatible address.

  * If `contract_address` is `nil` or empty, fetches the native token
    balance via `eth_getBalance`.
  * Otherwise calls `balanceOf(address)` on the given ERC-20 contract.

  Returns `{:ok, %Decimal{}}` (with 18 decimals) or `{:error, reason}`.
  """
  def fetch_erc20_balance(chain, wallet_address, contract_address)
      when is_binary(chain) and is_binary(wallet_address) do
    case Map.get(@chain_rpc_urls, chain) do
      nil ->
        {:error, :unsupported_chain}

      rpc_url ->
        if contract_address in [nil, ""] do
          fetch_native_balance(rpc_url, wallet_address)
        else
          fetch_erc20_token_balance(rpc_url, wallet_address, contract_address)
        end
    end
  end

  def fetch_erc20_balance(_chain, _wallet, _contract), do: {:error, :invalid_arguments}

  @doc """
  Update the value of a single `%DefiPosition{}`.

  Extracts the primary token symbol from `asset_pair`, fetches its price,
  optionally fetches the on-chain balance, and computes `current_value`
  and `unrealized_pnl`.

  Returns `{:ok, %{current_value: Decimal, unrealized_pnl: Decimal}}` or
  `{:error, reason}`.
  """
  def update_position_value(%DefiPosition{} = position) do
    symbol = extract_primary_symbol(position.asset_pair)

    case fetch_token_price(symbol) do
      {:ok, price} ->
        balance_result =
          if has_wallet?(position) do
            fetch_erc20_balance(position.chain, position.wallet_address, position.contract_address)
          else
            {:ok, nil}
          end

        case balance_result do
          {:ok, nil} ->
            # No on-chain balance available; value = deposited_amount * price
            deposited = position.deposited_amount || Decimal.new(0)
            current_value = Decimal.mult(deposited, price)
            unrealized_pnl = Decimal.sub(current_value, deposited)
            {:ok, %{current_value: current_value, unrealized_pnl: unrealized_pnl}}

          {:ok, balance} ->
            current_value = Decimal.mult(balance, price)
            deposited = position.deposited_amount || Decimal.new(0)
            unrealized_pnl = Decimal.sub(current_value, deposited)
            {:ok, %{current_value: current_value, unrealized_pnl: unrealized_pnl}}

          {:error, reason} ->
            Logger.warning(
              "Could not fetch on-chain balance for position #{position.id}: #{inspect(reason)}"
            )

            # Fall back to price * deposited_amount
            deposited = position.deposited_amount || Decimal.new(0)
            current_value = Decimal.mult(deposited, price)
            unrealized_pnl = Decimal.sub(current_value, deposited)
            {:ok, %{current_value: current_value, unrealized_pnl: unrealized_pnl}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Scan every active DeFi position, refresh its value and persist the
  update. Returns `{:ok, %{updated: non_neg_integer, errors: non_neg_integer}}`.
  """
  def scan_all_positions do
    positions =
      Analytics.list_defi_positions()
      |> Enum.filter(&(&1.status == "active"))

    {updated, errors} =
      Enum.reduce(positions, {0, 0}, fn position, {ok_count, err_count} ->
        result =
          try do
            case update_position_value(position) do
              {:ok, values} ->
                attrs = %{
                  current_value: Decimal.to_string(values.current_value),
                  unrealized_pnl: Decimal.to_string(values.unrealized_pnl)
                }

                case Analytics.update_defi_position(position, attrs) do
                  {:ok, _updated_pos} ->
                    Logger.info(
                      "Updated DeFi position #{position.id} (#{position.protocol_name}/#{position.asset_pair})"
                    )

                    :ok

                  {:error, changeset} ->
                    Logger.error(
                      "Failed to persist position #{position.id}: #{inspect(changeset)}"
                    )

                    :error
                end

              {:error, reason} ->
                Logger.warning(
                  "Could not update position #{position.id}: #{inspect(reason)}"
                )

                :error
            end
          rescue
            e ->
              Logger.error(
                "Exception updating position #{position.id}: #{Exception.message(e)}"
              )

              :error
          end

        # Rate-limit: 1 second between positions
        Process.sleep(1_000)

        case result do
          :ok -> {ok_count + 1, err_count}
          :error -> {ok_count, err_count + 1}
        end
      end)

    {:ok, %{updated: updated, errors: errors}}
  end

  # ── ETS price cache ─────────────────────────────────────────────────

  @doc """
  Ensure the ETS cache table exists. Safe to call multiple times.
  """
  def init do
    if :ets.info(@price_cache_table) == :undefined do
      :ets.new(@price_cache_table, [:set, :public, :named_table])
    end

    :ok
  end

  # ── Helpers: symbol extraction ──────────────────────────────────────

  @doc """
  Extract the primary token symbol from an asset pair string.

  Examples:
    "ETH/USDC" -> "ETH"
    "WBTC"     -> "WBTC"
    nil        -> "ETH"
  """
  def extract_primary_symbol(nil), do: "ETH"
  def extract_primary_symbol(""), do: "ETH"

  def extract_primary_symbol(pair) when is_binary(pair) do
    pair
    |> String.split(~r{[/\-_]})
    |> List.first()
    |> String.trim()
    |> String.upcase()
  end

  # ── Private ─────────────────────────────────────────────────────────

  defp has_wallet?(%DefiPosition{wallet_address: nil}), do: false
  defp has_wallet?(%DefiPosition{wallet_address: ""}), do: false
  defp has_wallet?(%DefiPosition{chain: "solana"}), do: false
  defp has_wallet?(%DefiPosition{chain: "other"}), do: false
  defp has_wallet?(_), do: true

  # ── CoinGecko ───────────────────────────────────────────────────────

  defp fetch_and_cache_price(coingecko_id) do
    url = "#{@coingecko_base_url}/simple/price?ids=#{coingecko_id}&vs_currencies=usd"

    case Req.get(url, receive_timeout: 5_000, connect_options: [timeout: 5_000]) do
      {:ok, %Req.Response{status: 200, body: body}} when is_map(body) ->
        case get_in(body, [coingecko_id, "usd"]) do
          nil ->
            {:error, :price_not_found}

          price when is_number(price) ->
            decimal_price = Decimal.new(to_string(price))
            write_cache(coingecko_id, decimal_price)
            {:ok, decimal_price}
        end

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp read_cache(key) do
    case :ets.lookup(@price_cache_table, key) do
      [{^key, price, timestamp}] ->
        if System.monotonic_time(:millisecond) - timestamp < @cache_ttl_ms do
          {:ok, price}
        else
          :ets.delete(@price_cache_table, key)
          :miss
        end

      [] ->
        :miss
    end
  end

  defp write_cache(key, price) do
    :ets.insert(@price_cache_table, {key, price, System.monotonic_time(:millisecond)})
  end

  # ── JSON-RPC helpers ────────────────────────────────────────────────

  defp fetch_native_balance(rpc_url, wallet_address) do
    payload = %{
      jsonrpc: "2.0",
      id: 1,
      method: "eth_getBalance",
      params: [wallet_address, "latest"]
    }

    call_rpc(rpc_url, payload)
  end

  defp fetch_erc20_token_balance(rpc_url, wallet_address, contract_address) do
    # balanceOf(address) selector = 0x70a08231
    # ABI-encode the address: pad to 32 bytes
    clean_address = String.replace_prefix(wallet_address, "0x", "")
    padded_address = String.pad_leading(clean_address, 64, "0")
    data = "0x70a08231" <> padded_address

    payload = %{
      jsonrpc: "2.0",
      id: 1,
      method: "eth_call",
      params: [%{to: contract_address, data: data}, "latest"]
    }

    call_rpc(rpc_url, payload)
  end

  defp call_rpc(rpc_url, payload) do
    case Req.post(rpc_url,
           json: payload,
           receive_timeout: 5_000,
           connect_options: [timeout: 5_000]
         ) do
      {:ok, %Req.Response{status: 200, body: %{"result" => hex_result}}}
      when is_binary(hex_result) ->
        parse_hex_balance(hex_result)

      {:ok, %Req.Response{status: 200, body: %{"error" => error}}} ->
        {:error, {:rpc_error, error}}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp parse_hex_balance("0x"), do: {:ok, Decimal.new(0)}
  defp parse_hex_balance("0x0"), do: {:ok, Decimal.new(0)}

  defp parse_hex_balance("0x" <> hex) do
    case Integer.parse(hex, 16) do
      {wei, ""} ->
        # Convert from wei (18 decimals) to token units
        decimal_wei = Decimal.new(wei)
        divisor = Decimal.new(:math.pow(10, 18) |> round() |> to_string())
        {:ok, Decimal.div(decimal_wei, divisor)}

      _ ->
        {:error, :invalid_hex}
    end
  end

  defp parse_hex_balance(_), do: {:error, :invalid_hex}
end
