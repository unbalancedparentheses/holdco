defmodule Holdco.Money do
  @moduledoc """
  Helpers for working with Decimal monetary values throughout the application.
  Provides arithmetic wrappers that accept Decimal, float, integer, string, or nil inputs.
  """

  @doc "Add two values, treating nil as 0."
  def add(a, b), do: Decimal.add(to_decimal(a), to_decimal(b))

  @doc "Subtract b from a, treating nil as 0."
  def sub(a, b), do: Decimal.sub(to_decimal(a), to_decimal(b))

  @doc "Multiply two values, treating nil as 0."
  def mult(a, b), do: Decimal.mult(to_decimal(a), to_decimal(b))

  @doc "Divide a by b. Returns Decimal.new(0) if b is zero."
  def div(a, b) do
    b_dec = to_decimal(b)

    if Decimal.equal?(b_dec, Decimal.new(0)) do
      Decimal.new(0)
    else
      Decimal.div(to_decimal(a), b_dec)
    end
  end

  @doc "Absolute value."
  def abs(a), do: Decimal.abs(to_decimal(a))

  @doc "Negate a value."
  def negate(a), do: Decimal.negate(to_decimal(a))

  @doc "Returns true if a > b."
  def gt?(a, b), do: Decimal.compare(to_decimal(a), to_decimal(b)) == :gt

  @doc "Returns true if a < b."
  def lt?(a, b), do: Decimal.compare(to_decimal(a), to_decimal(b)) == :lt

  @doc "Returns true if a >= b."
  def gte?(a, b), do: Decimal.compare(to_decimal(a), to_decimal(b)) in [:gt, :eq]

  @doc "Returns true if a == b."
  def equal?(a, b), do: Decimal.equal?(to_decimal(a), to_decimal(b))

  @doc "Returns the larger of two values."
  def max(a, b) do
    a_dec = to_decimal(a)
    b_dec = to_decimal(b)
    if Decimal.compare(a_dec, b_dec) in [:gt, :eq], do: a_dec, else: b_dec
  end

  @doc "Returns the smaller of two values."
  def min(a, b) do
    a_dec = to_decimal(a)
    b_dec = to_decimal(b)
    if Decimal.compare(a_dec, b_dec) in [:lt, :eq], do: a_dec, else: b_dec
  end

  @doc "Round to N decimal places (default 2)."
  def round(a, places \\ 2), do: Decimal.round(to_decimal(a), places)

  @doc "Convert to float for display or Chart.js data."
  def to_float(a), do: to_decimal(a) |> Decimal.to_float()

  @doc "Format as string with N decimal places."
  def format(a, places \\ 2) do
    to_decimal(a) |> Decimal.round(places) |> Decimal.to_string()
  end

  @doc "Sum a list of values."
  def sum(values) do
    Enum.reduce(values, Decimal.new(0), fn v, acc -> Decimal.add(acc, to_decimal(v)) end)
  end

  @doc "Check if value is positive (> 0)."
  def positive?(a), do: Decimal.compare(to_decimal(a), Decimal.new(0)) == :gt

  @doc "Check if value is negative (< 0)."
  def negative?(a), do: Decimal.compare(to_decimal(a), Decimal.new(0)) == :lt

  @doc "Check if value is zero."
  def zero?(a), do: Decimal.equal?(to_decimal(a), Decimal.new(0))

  @doc "Convert any numeric input to Decimal."
  def to_decimal(nil), do: Decimal.new(0)
  def to_decimal(%Decimal{} = d), do: d
  def to_decimal(n) when is_float(n), do: Decimal.from_float(n)
  def to_decimal(n) when is_integer(n), do: Decimal.new(n)
  def to_decimal(n) when is_binary(n) do
    case Decimal.parse(n) do
      {d, ""} -> d
      {d, _} -> d
      :error -> Decimal.new(0)
    end
  end

  @doc "Power function using floats internally (for compound growth)."
  def pow(base, exp) do
    result = :math.pow(to_float(base), to_float(exp))
    Decimal.from_float(result)
  end
end
