defmodule Holdco.Finance.InterestAccrual do
  @moduledoc """
  Calculates interest on intercompany loan transfers using simple interest.
  Formula: principal * rate * (days / 365)
  """

  alias Holdco.Money
  alias Holdco.Finance.InterCompanyTransfer

  @doc """
  Calculate accrued interest for a single intercompany transfer.
  Returns a map with :principal, :rate, :days, :interest.

  The transfer must have:
    - amount (principal)
    - date (loan origination, YYYY-MM-DD string)

  The rate is extracted from the transfer's notes field as a decimal
  (e.g., "rate:0.05" for 5%) or defaults to 0.

  Interest is calculated from the transfer date to today using simple interest.
  """
  def calculate_interest(%InterCompanyTransfer{} = transfer) do
    principal = Money.to_decimal(transfer.amount)
    rate = extract_rate(transfer)
    days = days_outstanding(transfer.date)

    interest =
      principal
      |> Decimal.mult(rate)
      |> Decimal.mult(Decimal.new(days))
      |> Decimal.div(Decimal.new(365))
      |> Decimal.round(2)

    %{
      transfer_id: transfer.id,
      principal: principal,
      rate: rate,
      days: days,
      interest: interest,
      from_company_id: transfer.from_company_id,
      to_company_id: transfer.to_company_id,
      currency: transfer.currency || "USD"
    }
  end

  @doc """
  Alias for calculate_interest/1 for single transfer convenience.
  """
  def accrued_interest_for_transfer(%InterCompanyTransfer{} = transfer) do
    calculate_interest(transfer)
  end

  @doc """
  For a list of transfers, generate interest accrual journal entry attribute maps.
  Each entry debits interest expense and credits interest payable.

  Returns a list of {entry_attrs, lines_attrs} tuples suitable for
  Finance.create_journal_entry_with_lines/2.
  """
  def generate_journal_entries(transfers) when is_list(transfers) do
    today = Date.utc_today() |> Date.to_string()

    transfers
    |> Enum.map(&calculate_interest/1)
    |> Enum.reject(fn accrual -> Money.equal?(accrual.interest, 0) end)
    |> Enum.map(fn accrual ->
      entry_attrs = %{
        "date" => today,
        "description" => "Interest accrual on intercompany loan ##{accrual.transfer_id}",
        "reference" => "INT-ACC-#{accrual.transfer_id}"
      }

      lines_attrs = [
        %{
          "debit" => accrual.interest,
          "credit" => Decimal.new(0),
          "notes" => "Interest expense - loan ##{accrual.transfer_id}"
        },
        %{
          "credit" => accrual.interest,
          "debit" => Decimal.new(0),
          "notes" => "Interest payable - loan ##{accrual.transfer_id}"
        }
      ]

      {entry_attrs, lines_attrs}
    end)
  end

  @doc """
  Extract the interest rate from a transfer.
  Looks for "rate:X.XX" in the notes field. Defaults to 0.
  """
  def extract_rate(%InterCompanyTransfer{notes: notes}) when is_binary(notes) do
    case Regex.run(~r/rate:([\d.]+)/, notes) do
      [_, rate_str] -> Money.to_decimal(rate_str)
      _ -> Decimal.new(0)
    end
  end

  def extract_rate(_), do: Decimal.new(0)

  @doc """
  Calculate the number of days between the transfer date and today.
  Returns 0 if the date is in the future or invalid.
  """
  def days_outstanding(date_str) when is_binary(date_str) do
    case Date.from_iso8601(date_str) do
      {:ok, date} ->
        diff = Date.diff(Date.utc_today(), date)
        max(diff, 0)

      {:error, _} ->
        0
    end
  end

  def days_outstanding(_), do: 0
end
