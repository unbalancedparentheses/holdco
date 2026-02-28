defmodule Holdco.Finance.InterestAccrualTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Finance.InterestAccrual
  alias Holdco.Money

  defp make_transfer(overrides \\ %{}) do
    from_co = company_fixture()
    to_co = company_fixture()

    defaults = %{
      from_company: from_co,
      to_company: to_co,
      amount: 100_000.0,
      date: "2025-01-01",
      description: "Intercompany loan",
      status: "active",
      notes: "rate:0.05"
    }

    inter_company_transfer_fixture(Map.merge(defaults, overrides))
  end

  describe "calculate_interest/1" do
    test "calculates simple interest correctly" do
      transfer = make_transfer(%{amount: 100_000.0, notes: "rate:0.10", date: "2025-01-01"})
      result = InterestAccrual.calculate_interest(transfer)

      assert result.principal == Money.to_decimal(100_000.0)
      assert result.rate == Money.to_decimal("0.10")
      assert result.days > 0
      assert result.transfer_id == transfer.id

      # Interest = 100000 * 0.10 * days / 365
      expected =
        Decimal.new(100_000)
        |> Decimal.mult(Decimal.new("0.10"))
        |> Decimal.mult(Decimal.new(result.days))
        |> Decimal.div(Decimal.new(365))
        |> Decimal.round(2)

      assert Decimal.equal?(result.interest, expected)
    end

    test "returns zero interest for zero rate" do
      transfer = make_transfer(%{notes: "rate:0.00"})
      result = InterestAccrual.calculate_interest(transfer)

      assert Decimal.equal?(result.interest, Decimal.new(0))
      assert Decimal.equal?(result.rate, Decimal.new(0))
    end

    test "returns zero interest when no rate in notes" do
      transfer = make_transfer(%{notes: "some random notes"})
      result = InterestAccrual.calculate_interest(transfer)

      assert Decimal.equal?(result.interest, Decimal.new(0))
    end

    test "returns zero interest when notes is nil" do
      transfer = make_transfer(%{notes: nil})
      result = InterestAccrual.calculate_interest(transfer)

      assert Decimal.equal?(result.interest, Decimal.new(0))
    end

    test "returns zero days for future date transfer" do
      future = Date.utc_today() |> Date.add(30) |> Date.to_string()
      transfer = make_transfer(%{date: future, notes: "rate:0.05"})
      result = InterestAccrual.calculate_interest(transfer)

      assert result.days == 0
      assert Decimal.equal?(result.interest, Decimal.new(0))
    end

    test "captures company IDs and currency" do
      transfer = make_transfer()
      result = InterestAccrual.calculate_interest(transfer)

      assert result.from_company_id == transfer.from_company_id
      assert result.to_company_id == transfer.to_company_id
      assert result.currency == "USD"
    end

    test "handles small principal amounts" do
      transfer = make_transfer(%{amount: 1.0, notes: "rate:0.01"})
      result = InterestAccrual.calculate_interest(transfer)

      assert result.principal == Money.to_decimal(1.0)
      # Interest should be very small but non-negative
      assert Money.gte?(result.interest, 0)
    end

    test "handles large principal amounts" do
      transfer = make_transfer(%{amount: 10_000_000.0, notes: "rate:0.08"})
      result = InterestAccrual.calculate_interest(transfer)

      assert Money.gt?(result.interest, 0)
    end
  end

  describe "accrued_interest_for_transfer/1" do
    test "is an alias for calculate_interest/1" do
      transfer = make_transfer(%{notes: "rate:0.05"})

      result1 = InterestAccrual.calculate_interest(transfer)
      result2 = InterestAccrual.accrued_interest_for_transfer(transfer)

      assert result1 == result2
    end
  end

  describe "generate_journal_entries/1" do
    test "generates entries for transfers with non-zero interest" do
      transfer = make_transfer(%{notes: "rate:0.05"})
      entries = InterestAccrual.generate_journal_entries([transfer])

      assert length(entries) == 1

      [{entry_attrs, lines_attrs}] = entries
      assert entry_attrs["description"] =~ "Interest accrual"
      assert entry_attrs["reference"] =~ "INT-ACC-"
      assert entry_attrs["date"] == Date.utc_today() |> Date.to_string()

      assert length(lines_attrs) == 2

      [debit_line, credit_line] = lines_attrs
      assert Money.gt?(debit_line["debit"], 0)
      assert Decimal.equal?(debit_line["credit"], Decimal.new(0))
      assert Money.gt?(credit_line["credit"], 0)
      assert Decimal.equal?(credit_line["debit"], Decimal.new(0))

      # Debit and credit should be equal
      assert Decimal.equal?(debit_line["debit"], credit_line["credit"])
    end

    test "excludes transfers with zero interest" do
      transfer = make_transfer(%{notes: "rate:0.00"})
      entries = InterestAccrual.generate_journal_entries([transfer])

      assert entries == []
    end

    test "returns empty list for empty input" do
      entries = InterestAccrual.generate_journal_entries([])
      assert entries == []
    end

    test "handles multiple transfers" do
      t1 = make_transfer(%{amount: 50_000.0, notes: "rate:0.04"})
      t2 = make_transfer(%{amount: 75_000.0, notes: "rate:0.06"})
      entries = InterestAccrual.generate_journal_entries([t1, t2])

      assert length(entries) == 2
    end

    test "filters out zero-rate transfers from a mixed list" do
      t1 = make_transfer(%{amount: 50_000.0, notes: "rate:0.05"})
      t2 = make_transfer(%{amount: 75_000.0, notes: "no rate here"})
      entries = InterestAccrual.generate_journal_entries([t1, t2])

      assert length(entries) == 1
    end
  end

  describe "extract_rate/1" do
    test "extracts rate from notes with rate:X.XX format" do
      transfer = make_transfer(%{notes: "rate:0.05"})
      rate = InterestAccrual.extract_rate(transfer)

      assert Decimal.equal?(rate, Decimal.new("0.05"))
    end

    test "extracts rate with longer decimal" do
      transfer = make_transfer(%{notes: "rate:0.123"})
      rate = InterestAccrual.extract_rate(transfer)

      assert Decimal.equal?(rate, Decimal.new("0.123"))
    end

    test "returns zero for notes without rate pattern" do
      transfer = make_transfer(%{notes: "just a regular note"})
      rate = InterestAccrual.extract_rate(transfer)

      assert Decimal.equal?(rate, Decimal.new(0))
    end

    test "returns zero for nil notes" do
      transfer = make_transfer(%{notes: nil})
      rate = InterestAccrual.extract_rate(transfer)

      assert Decimal.equal?(rate, Decimal.new(0))
    end
  end

  describe "days_outstanding/1" do
    test "calculates days from past date" do
      past = Date.utc_today() |> Date.add(-30) |> Date.to_string()
      assert InterestAccrual.days_outstanding(past) == 30
    end

    test "returns 0 for today" do
      today = Date.utc_today() |> Date.to_string()
      assert InterestAccrual.days_outstanding(today) == 0
    end

    test "returns 0 for future date" do
      future = Date.utc_today() |> Date.add(10) |> Date.to_string()
      assert InterestAccrual.days_outstanding(future) == 0
    end

    test "returns 0 for invalid date string" do
      assert InterestAccrual.days_outstanding("not-a-date") == 0
    end

    test "returns 0 for nil" do
      assert InterestAccrual.days_outstanding(nil) == 0
    end
  end
end
