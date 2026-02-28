defmodule Holdco.Integrations.Reconciliation do
  @moduledoc """
  Bank reconciliation matching engine.
  Matches bank feed transactions against book transactions (Banking.Transaction).

  Scoring:
    - Amount match: 50 points (exact match)
    - Date proximity: 30 points (same day), decaying by 5 pts per day offset
    - Description similarity: 20 points (Jaro-Winkler similarity)

  Threshold: 60 points minimum for auto-match.
  """

  import Ecto.Query

  alias Holdco.Repo
  alias Holdco.Integrations
  alias Holdco.Integrations.BankFeedTransaction
  alias Holdco.Banking.Transaction

  @match_threshold 60

  @doc """
  Auto-matches unmatched feed transactions against book transactions.
  Returns a list of {feed_txn, matched_book_txn, score} tuples for
  matches that exceed the threshold.
  """
  def auto_match(feed_config_id) do
    feed_config = Integrations.get_bank_feed_config!(feed_config_id)
    company_id = feed_config.company_id

    unmatched_feed_txns = Integrations.list_unmatched_bank_feed_transactions(feed_config_id)

    # Get all unmatched book transactions for this company
    book_txns =
      from(t in Transaction,
        where: t.company_id == ^company_id,
        order_by: [desc: t.date]
      )
      |> Repo.all()

    # Already matched book transaction IDs (to avoid double-matching)
    already_matched_ids =
      from(bft in BankFeedTransaction,
        where: bft.feed_config_id == ^feed_config_id and bft.is_matched == true,
        select: bft.matched_transaction_id
      )
      |> Repo.all()
      |> Enum.reject(&is_nil/1)
      |> MapSet.new()

    available_book_txns = Enum.reject(book_txns, &MapSet.member?(already_matched_ids, &1.id))

    {matches, _used_ids} =
      Enum.reduce(unmatched_feed_txns, {[], MapSet.new()}, fn feed_txn, {acc, used} ->
        candidates =
          available_book_txns
          |> Enum.reject(&MapSet.member?(used, &1.id))
          |> Enum.map(fn book_txn ->
            score = score_match(feed_txn, book_txn)
            {book_txn, score}
          end)
          |> Enum.filter(fn {_book_txn, score} -> score >= @match_threshold end)
          |> Enum.sort_by(fn {_book_txn, score} -> -score end)

        case candidates do
          [{best_book_txn, best_score} | _] ->
            Integrations.match_bank_feed_transaction(feed_txn.id, best_book_txn.id)
            {[{feed_txn, best_book_txn, best_score} | acc], MapSet.put(used, best_book_txn.id)}

          [] ->
            {acc, used}
        end
      end)

    Enum.reverse(matches)
  end

  @doc """
  Manually matches a feed transaction to a book transaction.
  """
  def manual_match(feed_transaction_id, book_transaction_id) do
    Integrations.match_bank_feed_transaction(feed_transaction_id, book_transaction_id)
  end

  @doc """
  Removes a match from a feed transaction.
  """
  def unmatch(feed_transaction_id) do
    Integrations.unmatch_bank_feed_transaction(feed_transaction_id)
  end

  @doc """
  Returns a reconciliation summary for a given feed config.
  """
  def reconciliation_summary(feed_config_id) do
    total =
      Repo.one(
        from(bft in BankFeedTransaction,
          where: bft.feed_config_id == ^feed_config_id,
          select: count(bft.id)
        )
      ) || 0

    matched =
      Repo.one(
        from(bft in BankFeedTransaction,
          where: bft.feed_config_id == ^feed_config_id and bft.is_matched == true,
          select: count(bft.id)
        )
      ) || 0

    %{total: total, matched: matched, unmatched: total - matched}
  end

  @doc """
  Returns scored candidates for a single feed transaction against book transactions.
  Useful for the UI to show match suggestions.
  """
  def candidates(feed_transaction_id) do
    feed_txn = Integrations.get_bank_feed_transaction!(feed_transaction_id)
    feed_config = Integrations.get_bank_feed_config!(feed_txn.feed_config_id)
    company_id = feed_config.company_id

    book_txns =
      from(t in Transaction,
        where: t.company_id == ^company_id,
        order_by: [desc: t.date]
      )
      |> Repo.all()

    book_txns
    |> Enum.map(fn book_txn ->
      score = score_match(feed_txn, book_txn)
      {book_txn, score}
    end)
    |> Enum.filter(fn {_book_txn, score} -> score > 0 end)
    |> Enum.sort_by(fn {_book_txn, score} -> -score end)
    |> Enum.take(10)
  end

  # Scoring

  defp score_match(feed_txn, book_txn) do
    amount_score(feed_txn, book_txn) +
      date_score(feed_txn, book_txn) +
      description_score(feed_txn, book_txn)
  end

  defp amount_score(feed_txn, book_txn) do
    feed_amount = Decimal.abs(feed_txn.amount || Decimal.new(0))
    book_amount = Decimal.abs(book_txn.amount || Decimal.new(0))

    if Decimal.equal?(feed_amount, book_amount) do
      50
    else
      # Partial credit for close amounts (within 5%)
      diff = Decimal.abs(Decimal.sub(feed_amount, book_amount))
      max_val = Decimal.max(feed_amount, book_amount)

      if Decimal.gt?(max_val, 0) do
        pct_diff = Decimal.to_float(Decimal.div(diff, max_val))

        cond do
          pct_diff <= 0.01 -> 40
          pct_diff <= 0.05 -> 25
          pct_diff <= 0.10 -> 10
          true -> 0
        end
      else
        # Both zero
        50
      end
    end
  end

  defp date_score(feed_txn, book_txn) do
    case {parse_date(feed_txn.date), parse_date(book_txn.date)} do
      {{:ok, feed_date}, {:ok, book_date}} ->
        diff = abs(Date.diff(feed_date, book_date))

        cond do
          diff == 0 -> 30
          diff <= 1 -> 25
          diff <= 3 -> 20
          diff <= 5 -> 10
          diff <= 7 -> 5
          true -> 0
        end

      _ ->
        0
    end
  end

  defp description_score(feed_txn, book_txn) do
    feed_desc = normalize_string(feed_txn.description || "")
    book_desc = normalize_string(book_txn.description || "")

    cond do
      feed_desc == "" or book_desc == "" ->
        0

      feed_desc == book_desc ->
        20

      true ->
        jaro = String.jaro_distance(feed_desc, book_desc)
        substring_bonus = if String.contains?(feed_desc, book_desc) or String.contains?(book_desc, feed_desc), do: 5, else: 0

        base_score = round(jaro * 15)
        min(base_score + substring_bonus, 20)
    end
  end

  defp normalize_string(str) do
    str
    |> String.downcase()
    |> String.trim()
    |> String.replace(~r/[^a-z0-9\s]/, "")
    |> String.replace(~r/\s+/, " ")
  end

  defp parse_date(nil), do: :error
  defp parse_date(""), do: :error

  defp parse_date(date_str) when is_binary(date_str) do
    Date.from_iso8601(date_str)
  end

  defp parse_date(%Date{} = date), do: {:ok, date}
  defp parse_date(_), do: :error
end
