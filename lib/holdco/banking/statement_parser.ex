defmodule Holdco.Banking.StatementParser do
  @moduledoc """
  Parses bank statement files (CSV) into a list of transaction maps.
  Uses AI when configured, falls back to basic CSV header detection.
  """

  alias Holdco.AI

  @type parsed_transaction :: %{
          date: String.t(),
          description: String.t(),
          amount: Decimal.t(),
          currency: String.t()
        }

  @doc """
  Parses a bank statement file into a list of transaction maps.
  Returns `{:ok, [%{date, description, amount, currency}]}` or `{:error, reason}`.
  """
  def parse(file_content, file_name) do
    cond do
      csv_file?(file_name) and AI.configured?() ->
        case parse_with_ai(file_content) do
          {:ok, txns} -> {:ok, txns}
          {:error, _} -> parse_csv_fallback(file_content)
        end

      csv_file?(file_name) ->
        parse_csv_fallback(file_content)

      true ->
        {:error, "Unsupported file format. Please upload a CSV file."}
    end
  end

  @doc """
  Parses bank statement content using the configured LLM.
  """
  def parse_with_ai(content) do
    # Truncate to avoid blowing token limits (~50KB of CSV is plenty)
    truncated = String.slice(content, 0, 50_000)

    messages = [
      %{
        "role" => "user",
        "content" => """
        Parse this bank statement into a JSON array of transactions. Each transaction must have:
        - "date" (YYYY-MM-DD format)
        - "description" (string)
        - "amount" (number: negative for debits/withdrawals, positive for credits/deposits)
        - "currency" (3-letter ISO code, default "USD" if not apparent)

        Return ONLY a valid JSON array, no markdown, no explanation.

        Bank statement:
        #{truncated}
        """
      }
    ]

    case AI.chat(messages, system_prompt: "You are a bank statement parser. Return only valid JSON arrays.") do
      {:ok, response} ->
        parse_ai_response(response)

      {:error, reason} ->
        {:error, "AI parsing failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Basic CSV parsing fallback when AI is not configured.
  Detects columns by header names.
  """
  def parse_csv_fallback(content) do
    lines =
      content
      |> String.trim()
      |> String.split(~r/\r?\n/)

    case lines do
      [header_line | data_lines] when data_lines != [] ->
        headers =
          header_line
          |> String.split(",")
          |> Enum.map(&normalize_header/1)

        date_idx = find_column(headers, ~w(date transaction_date posting_date value_date trans_date))
        desc_idx = find_column(headers, ~w(description memo narrative details reference payee name))
        amount_idx = find_column(headers, ~w(amount value total))
        debit_idx = find_column(headers, ~w(debit withdrawal withdrawals debit_amount))
        credit_idx = find_column(headers, ~w(credit deposit deposits credit_amount))
        currency_idx = find_column(headers, ~w(currency ccy))

        cond do
          is_nil(date_idx) ->
            {:error, "Could not detect date column. Headers: #{Enum.join(headers, ", ")}"}

          is_nil(amount_idx) and is_nil(debit_idx) and is_nil(credit_idx) ->
            {:error, "Could not detect amount column. Headers: #{Enum.join(headers, ", ")}"}

          true ->
            txns =
              data_lines
              |> Enum.reject(&(String.trim(&1) == ""))
              |> Enum.map(fn line ->
                cols = parse_csv_line(line)

                amount = resolve_amount(cols, amount_idx, debit_idx, credit_idx)
                currency = if currency_idx, do: Enum.at(cols, currency_idx, "USD"), else: "USD"

                %{
                  date: normalize_date(Enum.at(cols, date_idx, "")),
                  description: if(desc_idx, do: Enum.at(cols, desc_idx, ""), else: ""),
                  amount: amount,
                  currency: String.trim(currency) |> String.upcase()
                }
              end)
              |> Enum.filter(&(&1.date != ""))

            {:ok, txns}
        end

      _ ->
        {:error, "CSV file appears empty or has no data rows"}
    end
  end

  # Private helpers

  defp csv_file?(name) do
    ext = name |> String.downcase() |> Path.extname()
    ext in [".csv"]
  end

  defp parse_ai_response(response) do
    # Strip markdown code fences if present
    cleaned =
      response
      |> String.trim()
      |> String.replace(~r/^```(?:json)?\s*/, "")
      |> String.replace(~r/\s*```$/, "")
      |> String.trim()

    case Jason.decode(cleaned) do
      {:ok, list} when is_list(list) ->
        txns =
          list
          |> Enum.filter(&valid_transaction?/1)
          |> Enum.map(fn txn ->
            %{
              date: Map.get(txn, "date", ""),
              description: Map.get(txn, "description", ""),
              amount: parse_amount(Map.get(txn, "amount", 0)),
              currency: Map.get(txn, "currency", "USD")
            }
          end)

        if txns == [] do
          {:error, "AI returned no valid transactions"}
        else
          {:ok, txns}
        end

      {:ok, _} ->
        {:error, "AI response was not a JSON array"}

      {:error, _} ->
        {:error, "Could not parse AI response as JSON"}
    end
  end

  defp valid_transaction?(txn) when is_map(txn) do
    Map.has_key?(txn, "date") and Map.has_key?(txn, "amount")
  end

  defp valid_transaction?(_), do: false

  defp parse_amount(amount) when is_float(amount), do: Decimal.from_float(amount)
  defp parse_amount(amount) when is_integer(amount), do: Decimal.new(amount)

  defp parse_amount(amount) when is_binary(amount) do
    cleaned = String.replace(amount, ~r/[,$\s]/, "")

    case Decimal.parse(cleaned) do
      {decimal, _} -> decimal
      :error -> Decimal.new(0)
    end
  end

  defp parse_amount(_), do: Decimal.new(0)

  defp normalize_header(header) do
    header
    |> String.trim()
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]/, "_")
    |> String.replace(~r/_+/, "_")
    |> String.trim("_")
  end

  defp find_column(headers, candidates) do
    Enum.find_index(headers, fn h ->
      Enum.any?(candidates, &(&1 == h))
    end)
  end

  defp resolve_amount(cols, amount_idx, debit_idx, credit_idx) do
    cond do
      amount_idx ->
        parse_amount(Enum.at(cols, amount_idx, "0"))

      debit_idx && credit_idx ->
        debit = parse_amount(Enum.at(cols, debit_idx, ""))
        credit = parse_amount(Enum.at(cols, credit_idx, ""))

        cond do
          Decimal.gt?(debit, 0) -> Decimal.negate(debit)
          Decimal.gt?(credit, 0) -> credit
          true -> Decimal.new(0)
        end

      debit_idx ->
        Decimal.negate(parse_amount(Enum.at(cols, debit_idx, "0")))

      credit_idx ->
        parse_amount(Enum.at(cols, credit_idx, "0"))

      true ->
        Decimal.new(0)
    end
  end

  defp normalize_date(date_str) do
    trimmed = String.trim(date_str)

    cond do
      # Already YYYY-MM-DD
      Regex.match?(~r/^\d{4}-\d{2}-\d{2}$/, trimmed) ->
        trimmed

      # MM/DD/YYYY
      match = Regex.run(~r/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/, trimmed) ->
        [_, m, d, y] = match
        "#{y}-#{String.pad_leading(m, 2, "0")}-#{String.pad_leading(d, 2, "0")}"

      # DD/MM/YYYY (ambiguous, but try)
      match = Regex.run(~r/^(\d{1,2})\.(\d{1,2})\.(\d{4})$/, trimmed) ->
        [_, d, m, y] = match
        "#{y}-#{String.pad_leading(m, 2, "0")}-#{String.pad_leading(d, 2, "0")}"

      # YYYY/MM/DD
      match = Regex.run(~r/^(\d{4})\/(\d{2})\/(\d{2})$/, trimmed) ->
        [_, y, m, d] = match
        "#{y}-#{m}-#{d}"

      true ->
        trimmed
    end
  end

  defp parse_csv_line(line) do
    # Simple CSV split that handles quoted fields
    line
    |> String.split(~r/,(?=(?:[^"]*"[^"]*")*[^"]*$)/)
    |> Enum.map(fn field ->
      field |> String.trim() |> String.trim("\"") |> String.replace("\"\"", "\"")
    end)
  end
end
