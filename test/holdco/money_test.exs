defmodule Holdco.MoneyTest do
  use ExUnit.Case, async: true

  alias Holdco.Money

  # ── to_decimal/1 ──────────────────────────────────────────

  describe "to_decimal/1" do
    test "nil returns 0" do
      assert Decimal.equal?(Money.to_decimal(nil), Decimal.new(0))
    end

    test "Decimal passthrough" do
      d = Decimal.new("42.5")
      assert Money.to_decimal(d) === d
    end

    test "float conversion" do
      result = Money.to_decimal(3.14)
      assert_in_delta Decimal.to_float(result), 3.14, 0.001
    end

    test "integer conversion" do
      assert Decimal.equal?(Money.to_decimal(42), Decimal.new(42))
    end

    test "string conversion" do
      assert Decimal.equal?(Money.to_decimal("123.45"), Decimal.new("123.45"))
    end

    test "invalid string returns 0" do
      assert Decimal.equal?(Money.to_decimal("not_a_number"), Decimal.new(0))
    end

    test "string with trailing chars still parses" do
      # Decimal.parse("123abc") returns {123, "abc"} — our code accepts it
      result = Money.to_decimal("123abc")
      assert Decimal.equal?(result, Decimal.new(123))
    end

    test "empty string returns 0" do
      assert Decimal.equal?(Money.to_decimal(""), Decimal.new(0))
    end

    test "negative integer" do
      assert Decimal.equal?(Money.to_decimal(-10), Decimal.new(-10))
    end

    test "negative string" do
      assert Decimal.equal?(Money.to_decimal("-99.5"), Decimal.new("-99.5"))
    end
  end

  # ── Arithmetic ────────────────────────────────────────────

  describe "add/2" do
    test "two decimals" do
      assert Decimal.equal?(Money.add(Decimal.new(10), Decimal.new(20)), Decimal.new(30))
    end

    test "mixed types: float and integer" do
      result = Money.add(1.5, 2)
      assert_in_delta Decimal.to_float(result), 3.5, 0.001
    end

    test "nil treated as 0" do
      assert Decimal.equal?(Money.add(nil, Decimal.new(5)), Decimal.new(5))
      assert Decimal.equal?(Money.add(Decimal.new(5), nil), Decimal.new(5))
    end

    test "string and integer" do
      assert Decimal.equal?(Money.add("10", 5), Decimal.new(15))
    end
  end

  describe "sub/2" do
    test "basic subtraction" do
      assert Decimal.equal?(Money.sub(Decimal.new(30), Decimal.new(10)), Decimal.new(20))
    end

    test "result can be negative" do
      assert Money.negative?(Money.sub(5, 10))
    end

    test "nil treated as 0" do
      assert Decimal.equal?(Money.sub(nil, Decimal.new(5)), Decimal.new(-5))
    end
  end

  describe "mult/2" do
    test "basic multiplication" do
      assert Decimal.equal?(Money.mult(Decimal.new(3), Decimal.new(4)), Decimal.new(12))
    end

    test "multiply by nil (0)" do
      assert Decimal.equal?(Money.mult(100, nil), Decimal.new(0))
    end

    test "mixed types" do
      result = Money.mult("5", 3)
      assert Decimal.equal?(result, Decimal.new(15))
    end
  end

  describe "div/2" do
    test "basic division" do
      result = Money.div(Decimal.new(10), Decimal.new(4))
      assert Decimal.equal?(result, Decimal.new("2.5"))
    end

    test "divide by zero returns 0" do
      assert Decimal.equal?(Money.div(100, 0), Decimal.new(0))
    end

    test "divide by nil (treated as 0) returns 0" do
      assert Decimal.equal?(Money.div(100, nil), Decimal.new(0))
    end

    test "divide zero by something" do
      assert Decimal.equal?(Money.div(0, 5), Decimal.new(0))
    end

    test "mixed types" do
      result = Money.div("100", 4)
      assert Decimal.equal?(result, Decimal.new(25))
    end
  end

  # ── Comparisons ───────────────────────────────────────────

  describe "gt?/2" do
    test "greater" do
      assert Money.gt?(10, 5)
    end

    test "not greater" do
      refute Money.gt?(5, 10)
    end

    test "equal values are not greater" do
      refute Money.gt?(5, 5)
    end

    test "mixed types" do
      assert Money.gt?("100", 50)
    end
  end

  describe "lt?/2" do
    test "less" do
      assert Money.lt?(5, 10)
    end

    test "not less" do
      refute Money.lt?(10, 5)
    end

    test "equal values are not less" do
      refute Money.lt?(5, 5)
    end
  end

  describe "gte?/2" do
    test "greater" do
      assert Money.gte?(10, 5)
    end

    test "equal" do
      assert Money.gte?(5, 5)
    end

    test "less returns false" do
      refute Money.gte?(3, 5)
    end
  end

  describe "equal?/2" do
    test "equal decimals" do
      assert Money.equal?(Decimal.new(5), Decimal.new(5))
    end

    test "mixed types that are equal" do
      assert Money.equal?(5, "5")
      assert Money.equal?(5.0, 5)
    end

    test "not equal" do
      refute Money.equal?(5, 6)
    end

    test "nil equals 0" do
      assert Money.equal?(nil, 0)
    end
  end

  # ── Min/Max ───────────────────────────────────────────────

  describe "max/2" do
    test "returns larger" do
      assert Decimal.equal?(Money.max(10, 5), Decimal.new(10))
    end

    test "with equal values returns first" do
      result = Money.max(7, 7)
      assert Decimal.equal?(result, Decimal.new(7))
    end

    test "with negatives" do
      assert Decimal.equal?(Money.max(-5, -10), Decimal.new(-5))
    end

    test "nil treated as 0" do
      assert Decimal.equal?(Money.max(nil, 5), Decimal.new(5))
      assert Decimal.equal?(Money.max(5, nil), Decimal.new(5))
    end
  end

  describe "min/2" do
    test "returns smaller" do
      assert Decimal.equal?(Money.min(10, 5), Decimal.new(5))
    end

    test "with equal values returns first" do
      result = Money.min(7, 7)
      assert Decimal.equal?(result, Decimal.new(7))
    end

    test "with negatives" do
      assert Decimal.equal?(Money.min(-5, -10), Decimal.new(-10))
    end

    test "nil treated as 0" do
      assert Decimal.equal?(Money.min(nil, 5), Decimal.new(0))
    end
  end

  # ── Predicates ────────────────────────────────────────────

  describe "positive?/1" do
    test "positive number" do
      assert Money.positive?(1)
    end

    test "zero is not positive" do
      refute Money.positive?(0)
    end

    test "negative is not positive" do
      refute Money.positive?(-1)
    end

    test "nil (0) is not positive" do
      refute Money.positive?(nil)
    end

    test "small positive decimal" do
      assert Money.positive?(Decimal.new("0.001"))
    end
  end

  describe "negative?/1" do
    test "negative number" do
      assert Money.negative?(-1)
    end

    test "zero is not negative" do
      refute Money.negative?(0)
    end

    test "positive is not negative" do
      refute Money.negative?(1)
    end

    test "nil (0) is not negative" do
      refute Money.negative?(nil)
    end
  end

  describe "zero?/1" do
    test "zero" do
      assert Money.zero?(0)
    end

    test "nil is zero" do
      assert Money.zero?(nil)
    end

    test "Decimal zero" do
      assert Money.zero?(Decimal.new(0))
    end

    test "non-zero" do
      refute Money.zero?(1)
      refute Money.zero?(-1)
    end

    test "string zero" do
      assert Money.zero?("0")
      assert Money.zero?("0.00")
    end
  end

  # ── Utilities ─────────────────────────────────────────────

  describe "abs/1" do
    test "positive stays positive" do
      assert Decimal.equal?(Money.abs(5), Decimal.new(5))
    end

    test "negative becomes positive" do
      assert Decimal.equal?(Money.abs(-5), Decimal.new(5))
    end

    test "zero stays zero" do
      assert Decimal.equal?(Money.abs(0), Decimal.new(0))
    end
  end

  describe "negate/1" do
    test "positive becomes negative" do
      assert Decimal.equal?(Money.negate(5), Decimal.new(-5))
    end

    test "negative becomes positive" do
      assert Decimal.equal?(Money.negate(-5), Decimal.new(5))
    end

    test "zero stays zero" do
      assert Money.zero?(Money.negate(0))
    end
  end

  describe "round/2" do
    test "default 2 decimal places" do
      result = Money.round(Decimal.new("3.14159"))
      assert Decimal.equal?(result, Decimal.new("3.14"))
    end

    test "custom decimal places" do
      result = Money.round(Decimal.new("3.14159"), 4)
      assert Decimal.equal?(result, Decimal.new("3.1416"))
    end

    test "round to 0 places" do
      result = Money.round(Decimal.new("3.7"), 0)
      assert Decimal.equal?(result, Decimal.new(4))
    end
  end

  describe "to_float/1" do
    test "converts decimal to float" do
      assert Money.to_float(Decimal.new("3.14")) == 3.14
    end

    test "nil returns 0.0" do
      assert Money.to_float(nil) == 0.0
    end

    test "integer input" do
      assert Money.to_float(42) == 42.0
    end
  end

  describe "format/2" do
    test "default 2 decimal places" do
      assert Money.format(Decimal.new("3.14159")) == "3.14"
    end

    test "custom decimal places" do
      assert Money.format(Decimal.new("3.14159"), 4) == "3.1416"
    end

    test "nil formats as 0.00" do
      assert Money.format(nil) == "0.00"
    end

    test "integer input" do
      assert Money.format(100) == "100.00"
    end
  end

  describe "sum/1" do
    test "empty list returns 0" do
      assert Decimal.equal?(Money.sum([]), Decimal.new(0))
    end

    test "single element" do
      assert Decimal.equal?(Money.sum([Decimal.new(5)]), Decimal.new(5))
    end

    test "mixed types" do
      result = Money.sum([1, 2.5, "3", Decimal.new(4), nil])
      assert_in_delta Decimal.to_float(result), 10.5, 0.001
    end

    test "all nils sum to 0" do
      assert Decimal.equal?(Money.sum([nil, nil, nil]), Decimal.new(0))
    end
  end

  describe "pow/2" do
    test "basic power" do
      result = Money.pow(2, 3)
      assert_in_delta Decimal.to_float(result), 8.0, 0.001
    end

    test "fractional exponent" do
      result = Money.pow(9, 0.5)
      assert_in_delta Decimal.to_float(result), 3.0, 0.001
    end

    test "power of 0" do
      result = Money.pow(5, 0)
      assert_in_delta Decimal.to_float(result), 1.0, 0.001
    end

    test "base 1 to any power" do
      result = Money.pow(1, 100)
      assert_in_delta Decimal.to_float(result), 1.0, 0.001
    end
  end
end
