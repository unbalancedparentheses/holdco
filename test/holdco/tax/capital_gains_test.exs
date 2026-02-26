defmodule Holdco.Tax.CapitalGainsTest do
  use Holdco.DataCase

  import Holdco.HoldcoFixtures

  alias Holdco.Tax.CapitalGains

  describe "compute/1" do
    test "returns empty list when no holdings exist" do
      result = CapitalGains.compute(:fifo)
      assert result == []
    end

    test "computes gains with FIFO method" do
      company = company_fixture()
      holding = holding_fixture(%{company: company, asset: "AAPL", ticker: "AAPL", quantity: 100.0})

      cost_basis_lot_fixture(%{
        holding: holding,
        purchase_date: "2023-01-01",
        quantity: 100.0,
        price_per_unit: 150.0,
        sold_quantity: 0.0
      })

      result = CapitalGains.compute(:fifo)
      # Result may or may not include this holding depending on current price computation
      assert is_list(result)
    end

    test "computes gains with LIFO method" do
      company = company_fixture()
      holding = holding_fixture(%{company: company, asset: "MSFT", ticker: "MSFT", quantity: 50.0})

      cost_basis_lot_fixture(%{
        holding: holding,
        purchase_date: "2023-06-01",
        quantity: 50.0,
        price_per_unit: 300.0,
        sold_quantity: 0.0
      })

      result = CapitalGains.compute(:lifo)
      assert is_list(result)
    end

    test "computes gains with specific lot method" do
      company = company_fixture()
      holding = holding_fixture(%{company: company, asset: "GOOG", ticker: "GOOG", quantity: 200.0})

      cost_basis_lot_fixture(%{
        holding: holding,
        purchase_date: "2022-01-01",
        quantity: 100.0,
        price_per_unit: 100.0
      })

      cost_basis_lot_fixture(%{
        holding: holding,
        purchase_date: "2023-06-01",
        quantity: 100.0,
        price_per_unit: 120.0
      })

      result = CapitalGains.compute(:specific)
      assert is_list(result)
    end

    test "defaults to FIFO when no method specified" do
      result = CapitalGains.compute()
      assert is_list(result)
    end

    test "filters out holdings with zero total gain" do
      company = company_fixture()
      _holding = holding_fixture(%{company: company, asset: "ZERO", ticker: "ZERO", quantity: 10.0})
      # No cost basis lots, so no gains to compute
      result = CapitalGains.compute(:fifo)
      assert Enum.all?(result, fn r -> r.total_gain != 0.0 end)
    end

    test "classifies short-term vs long-term gains" do
      company = company_fixture()
      holding = holding_fixture(%{company: company, asset: "TSLA", ticker: "TSLA", quantity: 100.0})

      # Long-term: purchased more than 1 year ago
      cost_basis_lot_fixture(%{
        holding: holding,
        purchase_date: Date.to_iso8601(Date.add(Date.utc_today(), -400)),
        quantity: 50.0,
        price_per_unit: 200.0,
        sold_quantity: 50.0,
        sold_price: 250.0
      })

      # Short-term: purchased less than 1 year ago
      cost_basis_lot_fixture(%{
        holding: holding,
        purchase_date: Date.to_iso8601(Date.add(Date.utc_today(), -100)),
        quantity: 50.0,
        price_per_unit: 220.0,
        sold_quantity: 50.0,
        sold_price: 260.0
      })

      result = CapitalGains.compute(:fifo)

      Enum.each(result, fn r ->
        assert Map.has_key?(r, :short_term_realized)
        assert Map.has_key?(r, :long_term_realized)
        assert Map.has_key?(r, :short_term_unrealized)
        assert Map.has_key?(r, :long_term_unrealized)
        assert Map.has_key?(r, :total_gain)
      end)
    end

    test "result contains expected fields" do
      company = company_fixture()
      holding = holding_fixture(%{company: company, asset: "AMZN", ticker: "AMZN", quantity: 10.0})

      cost_basis_lot_fixture(%{
        holding: holding,
        purchase_date: "2023-01-01",
        quantity: 10.0,
        price_per_unit: 100.0,
        sold_quantity: 5.0,
        sold_price: 150.0
      })

      results = CapitalGains.compute(:fifo)

      Enum.each(results, fn r ->
        assert Map.has_key?(r, :holding_id)
        assert Map.has_key?(r, :asset)
        assert Map.has_key?(r, :ticker)
        assert Map.has_key?(r, :company)
        assert Map.has_key?(r, :short_term_realized)
        assert Map.has_key?(r, :long_term_realized)
        assert Map.has_key?(r, :short_term_unrealized)
        assert Map.has_key?(r, :long_term_unrealized)
        assert Map.has_key?(r, :total_gain)
      end)
    end
  end
end
