defmodule Holdco.Integrations.ReconciliationTest do
  use Holdco.DataCase, async: false

  import Holdco.HoldcoFixtures

  alias Holdco.Integrations
  alias Holdco.Integrations.Reconciliation

  # ── Helpers ────────────────────────────────────────────

  defp create_feed_config do
    company = company_fixture()
    ba = bank_account_fixture(%{company: company})

    {:ok, bfc} =
      Integrations.create_bank_feed_config(%{
        company_id: company.id,
        bank_account_id: ba.id,
        provider: "csv_import"
      })

    {company, bfc}
  end

  defp create_feed_transaction(feed_config_id, attrs) do
    base = %{
      feed_config_id: feed_config_id,
      external_id: "ext-#{System.unique_integer([:positive])}",
      date: "2024-06-15",
      description: "Feed transaction",
      amount: Decimal.new("100.00")
    }

    {:ok, bft} = Integrations.create_bank_feed_transaction(Map.merge(base, attrs))
    bft
  end

  defp create_book_transaction(company, attrs) do
    base = %{
      company_id: company.id,
      transaction_type: "credit",
      description: "Book transaction",
      amount: 100.0,
      date: "2024-06-15"
    }

    transaction_fixture(Map.merge(base, attrs))
  end

  # ── reconciliation_summary/1 ───────────────────────────

  describe "reconciliation_summary/1" do
    test "returns zero counts when no feed transactions exist" do
      {_company, bfc} = create_feed_config()

      summary = Reconciliation.reconciliation_summary(bfc.id)
      assert summary == %{total: 0, matched: 0, unmatched: 0}
    end

    test "returns correct counts with all unmatched transactions" do
      {_company, bfc} = create_feed_config()
      create_feed_transaction(bfc.id, %{description: "Unmatched 1"})
      create_feed_transaction(bfc.id, %{description: "Unmatched 2"})
      create_feed_transaction(bfc.id, %{description: "Unmatched 3"})

      summary = Reconciliation.reconciliation_summary(bfc.id)
      assert summary.total == 3
      assert summary.matched == 0
      assert summary.unmatched == 3
    end

    test "returns correct counts with some matched transactions" do
      {company, bfc} = create_feed_config()
      feed_txn = create_feed_transaction(bfc.id, %{description: "To match"})
      _unmatched = create_feed_transaction(bfc.id, %{description: "Unmatched"})
      book_txn = create_book_transaction(company, %{description: "To match"})

      Reconciliation.manual_match(feed_txn.id, book_txn.id)

      summary = Reconciliation.reconciliation_summary(bfc.id)
      assert summary.total == 2
      assert summary.matched == 1
      assert summary.unmatched == 1
    end

    test "returns correct counts with all matched transactions" do
      {company, bfc} = create_feed_config()
      feed1 = create_feed_transaction(bfc.id, %{description: "Match 1"})
      feed2 = create_feed_transaction(bfc.id, %{description: "Match 2"})
      book1 = create_book_transaction(company, %{description: "Match 1"})
      book2 = create_book_transaction(company, %{description: "Match 2"})

      Reconciliation.manual_match(feed1.id, book1.id)
      Reconciliation.manual_match(feed2.id, book2.id)

      summary = Reconciliation.reconciliation_summary(bfc.id)
      assert summary.total == 2
      assert summary.matched == 2
      assert summary.unmatched == 0
    end

    test "scopes counts to the given feed_config_id" do
      {_company1, bfc1} = create_feed_config()
      {_company2, bfc2} = create_feed_config()

      create_feed_transaction(bfc1.id, %{description: "Config 1 txn"})
      create_feed_transaction(bfc1.id, %{description: "Config 1 txn 2"})
      create_feed_transaction(bfc2.id, %{description: "Config 2 txn"})

      summary1 = Reconciliation.reconciliation_summary(bfc1.id)
      summary2 = Reconciliation.reconciliation_summary(bfc2.id)

      assert summary1.total == 2
      assert summary2.total == 1
    end
  end

  # ── manual_match/2 ─────────────────────────────────────

  describe "manual_match/2" do
    test "marks a feed transaction as matched with a book transaction" do
      {company, bfc} = create_feed_config()
      feed_txn = create_feed_transaction(bfc.id, %{description: "Manual match"})
      book_txn = create_book_transaction(company, %{description: "Manual match"})

      assert {:ok, matched} = Reconciliation.manual_match(feed_txn.id, book_txn.id)
      assert matched.is_matched == true
      assert matched.matched_transaction_id == book_txn.id
    end

    test "updates the reconciliation summary after matching" do
      {company, bfc} = create_feed_config()
      feed_txn = create_feed_transaction(bfc.id, %{description: "Summary test"})
      book_txn = create_book_transaction(company, %{description: "Summary test"})

      assert %{matched: 0} = Reconciliation.reconciliation_summary(bfc.id)
      Reconciliation.manual_match(feed_txn.id, book_txn.id)
      assert %{matched: 1} = Reconciliation.reconciliation_summary(bfc.id)
    end

    test "can match different feed transactions to different book transactions" do
      {company, bfc} = create_feed_config()
      feed1 = create_feed_transaction(bfc.id, %{description: "Feed 1", amount: Decimal.new("100.00")})
      feed2 = create_feed_transaction(bfc.id, %{description: "Feed 2", amount: Decimal.new("200.00")})
      book1 = create_book_transaction(company, %{description: "Book 1", amount: 100.0})
      book2 = create_book_transaction(company, %{description: "Book 2", amount: 200.0})

      assert {:ok, m1} = Reconciliation.manual_match(feed1.id, book1.id)
      assert {:ok, m2} = Reconciliation.manual_match(feed2.id, book2.id)

      assert m1.matched_transaction_id == book1.id
      assert m2.matched_transaction_id == book2.id
    end
  end

  # ── unmatch/1 ──────────────────────────────────────────

  describe "unmatch/1" do
    test "removes the match from a feed transaction" do
      {company, bfc} = create_feed_config()
      feed_txn = create_feed_transaction(bfc.id, %{description: "To unmatch"})
      book_txn = create_book_transaction(company, %{description: "To unmatch"})

      Reconciliation.manual_match(feed_txn.id, book_txn.id)
      assert {:ok, unmatched} = Reconciliation.unmatch(feed_txn.id)

      assert unmatched.is_matched == false
      assert unmatched.matched_transaction_id == nil
    end

    test "updates reconciliation summary after unmatching" do
      {company, bfc} = create_feed_config()
      feed_txn = create_feed_transaction(bfc.id, %{description: "Unmatch summary"})
      book_txn = create_book_transaction(company, %{description: "Unmatch summary"})

      Reconciliation.manual_match(feed_txn.id, book_txn.id)
      assert %{matched: 1, unmatched: 0} = Reconciliation.reconciliation_summary(bfc.id)

      Reconciliation.unmatch(feed_txn.id)
      assert %{matched: 0, unmatched: 1} = Reconciliation.reconciliation_summary(bfc.id)
    end

    test "allows re-matching after unmatching" do
      {company, bfc} = create_feed_config()
      feed_txn = create_feed_transaction(bfc.id, %{description: "Rematch"})
      book1 = create_book_transaction(company, %{description: "Book first", amount: 100.0})
      book2 = create_book_transaction(company, %{description: "Book second", amount: 100.0})

      Reconciliation.manual_match(feed_txn.id, book1.id)
      Reconciliation.unmatch(feed_txn.id)

      assert {:ok, rematched} = Reconciliation.manual_match(feed_txn.id, book2.id)
      assert rematched.matched_transaction_id == book2.id
      assert rematched.is_matched == true
    end
  end

  # ── candidates/1 ───────────────────────────────────────

  describe "candidates/1" do
    test "returns scored candidates sorted by score descending" do
      {company, bfc} = create_feed_config()

      feed_txn =
        create_feed_transaction(bfc.id, %{
          description: "Office Supplies Purchase",
          amount: Decimal.new("250.00"),
          date: "2024-06-15"
        })

      # Exact match: same amount, same date, similar description
      _exact = create_book_transaction(company, %{
        description: "Office Supplies Purchase",
        amount: 250.0,
        date: "2024-06-15"
      })

      # Partial match: same amount, different date
      _partial = create_book_transaction(company, %{
        description: "Something else",
        amount: 250.0,
        date: "2024-07-01"
      })

      # Poor match: different amount, different date
      _poor = create_book_transaction(company, %{
        description: "Completely unrelated",
        amount: 9999.0,
        date: "2023-01-01"
      })

      results = Reconciliation.candidates(feed_txn.id)

      assert length(results) >= 1
      # First result should have the highest score
      [{_best_txn, best_score} | _] = results
      assert best_score == 100

      # All results should be in descending score order
      scores = Enum.map(results, fn {_txn, score} -> score end)
      assert scores == Enum.sort(scores, :desc)
    end

    test "returns at most 10 candidates" do
      {company, bfc} = create_feed_config()

      feed_txn =
        create_feed_transaction(bfc.id, %{
          description: "Test",
          amount: Decimal.new("100.00"),
          date: "2024-06-15"
        })

      # Create 15 book transactions with matching amounts
      for i <- 1..15 do
        create_book_transaction(company, %{
          description: "Book #{i}",
          amount: 100.0,
          date: "2024-06-15"
        })
      end

      results = Reconciliation.candidates(feed_txn.id)
      assert length(results) <= 10
    end

    test "filters out candidates with zero score" do
      {company, bfc} = create_feed_config()

      feed_txn =
        create_feed_transaction(bfc.id, %{
          description: "Unique feed description",
          amount: Decimal.new("12345.67"),
          date: "2024-06-15"
        })

      # Create a book transaction that should score 0: completely different amount,
      # far apart date, different description
      _no_match = create_book_transaction(company, %{
        description: "X",
        amount: 1.0,
        date: "2020-01-01"
      })

      results = Reconciliation.candidates(feed_txn.id)
      # All returned candidates should have score > 0
      Enum.each(results, fn {_txn, score} -> assert score > 0 end)
    end

    test "returns empty list when no book transactions exist for company" do
      {_company, bfc} = create_feed_config()

      feed_txn = create_feed_transaction(bfc.id, %{description: "Lonely feed txn"})
      results = Reconciliation.candidates(feed_txn.id)
      assert results == []
    end

    test "scopes book transactions to the same company" do
      {company1, bfc1} = create_feed_config()
      {company2, _bfc2} = create_feed_config()

      feed_txn =
        create_feed_transaction(bfc1.id, %{
          description: "Cross company test",
          amount: Decimal.new("500.00"),
          date: "2024-06-15"
        })

      # Book transaction for a different company
      _other_company_txn = create_book_transaction(company2, %{
        description: "Cross company test",
        amount: 500.0,
        date: "2024-06-15"
      })

      # Book transaction for the same company
      same_company_txn = create_book_transaction(company1, %{
        description: "Cross company test",
        amount: 500.0,
        date: "2024-06-15"
      })

      results = Reconciliation.candidates(feed_txn.id)
      matched_ids = Enum.map(results, fn {txn, _score} -> txn.id end)

      assert same_company_txn.id in matched_ids
      refute Enum.any?(results, fn {txn, _} -> txn.company_id == company2.id end)
    end
  end

  # ── Scoring (tested indirectly through candidates) ─────

  describe "scoring logic via candidates" do
    test "exact amount match scores 50 points" do
      {company, bfc} = create_feed_config()

      feed_txn =
        create_feed_transaction(bfc.id, %{
          description: "",
          amount: Decimal.new("500.00"),
          date: "2020-01-01"
        })

      # Exact amount, distant date (0 date score), empty descriptions (0 desc score)
      _book = create_book_transaction(company, %{
        description: "X",
        amount: 500.0,
        date: "2010-01-01"
      })

      [{_txn, score}] = Reconciliation.candidates(feed_txn.id)
      assert score == 50
    end

    test "same-day date match scores 30 points" do
      {company, bfc} = create_feed_config()

      feed_txn =
        create_feed_transaction(bfc.id, %{
          description: "",
          amount: Decimal.new("999999.00"),
          date: "2024-06-15"
        })

      # Wildly different amount (0 amount score), same date, no description match
      _book = create_book_transaction(company, %{
        description: "X",
        amount: 1.0,
        date: "2024-06-15"
      })

      [{_txn, score}] = Reconciliation.candidates(feed_txn.id)
      assert score == 30
    end

    test "date within 1 day scores 25 points" do
      {company, bfc} = create_feed_config()

      feed_txn =
        create_feed_transaction(bfc.id, %{
          description: "",
          amount: Decimal.new("999999.00"),
          date: "2024-06-15"
        })

      _book = create_book_transaction(company, %{
        description: "X",
        amount: 1.0,
        date: "2024-06-16"
      })

      [{_txn, score}] = Reconciliation.candidates(feed_txn.id)
      assert score == 25
    end

    test "date within 3 days scores 20 points" do
      {company, bfc} = create_feed_config()

      feed_txn =
        create_feed_transaction(bfc.id, %{
          description: "",
          amount: Decimal.new("999999.00"),
          date: "2024-06-15"
        })

      _book = create_book_transaction(company, %{
        description: "X",
        amount: 1.0,
        date: "2024-06-18"
      })

      [{_txn, score}] = Reconciliation.candidates(feed_txn.id)
      assert score == 20
    end

    test "exact description match scores 20 points" do
      {company, bfc} = create_feed_config()

      feed_txn =
        create_feed_transaction(bfc.id, %{
          description: "Office Rent Payment",
          amount: Decimal.new("999999.00"),
          date: "2010-01-01"
        })

      # Different amount (0 pts), distant date (0 pts), same description (20 pts)
      _book = create_book_transaction(company, %{
        description: "Office Rent Payment",
        amount: 1.0,
        date: "2000-01-01"
      })

      [{_txn, score}] = Reconciliation.candidates(feed_txn.id)
      assert score == 20
    end

    test "perfect match scores 100 points (50 + 30 + 20)" do
      {company, bfc} = create_feed_config()

      feed_txn =
        create_feed_transaction(bfc.id, %{
          description: "Exact Match Test",
          amount: Decimal.new("750.00"),
          date: "2024-06-15"
        })

      _book = create_book_transaction(company, %{
        description: "Exact Match Test",
        amount: 750.0,
        date: "2024-06-15"
      })

      [{_txn, score}] = Reconciliation.candidates(feed_txn.id)
      assert score == 100
    end

    test "close amount (within 1%) scores 40 points" do
      {company, bfc} = create_feed_config()

      feed_txn =
        create_feed_transaction(bfc.id, %{
          description: "",
          amount: Decimal.new("1000.00"),
          date: "2010-01-01"
        })

      # 1005 is within 0.5% of 1000
      _book = create_book_transaction(company, %{
        description: "X",
        amount: 1005.0,
        date: "2000-01-01"
      })

      [{_txn, score}] = Reconciliation.candidates(feed_txn.id)
      assert score == 40
    end

    test "amount within 5% scores 25 points" do
      {company, bfc} = create_feed_config()

      feed_txn =
        create_feed_transaction(bfc.id, %{
          description: "",
          amount: Decimal.new("1000.00"),
          date: "2010-01-01"
        })

      # 1040 is 4% different from 1000
      _book = create_book_transaction(company, %{
        description: "X",
        amount: 1040.0,
        date: "2000-01-01"
      })

      [{_txn, score}] = Reconciliation.candidates(feed_txn.id)
      assert score == 25
    end

    test "amount within 10% scores 10 points" do
      {company, bfc} = create_feed_config()

      feed_txn =
        create_feed_transaction(bfc.id, %{
          description: "",
          amount: Decimal.new("1000.00"),
          date: "2010-01-01"
        })

      # 1080 is 8% different from 1000
      _book = create_book_transaction(company, %{
        description: "X",
        amount: 1080.0,
        date: "2000-01-01"
      })

      [{_txn, score}] = Reconciliation.candidates(feed_txn.id)
      assert score == 10
    end
  end

  # ── auto_match/1 ───────────────────────────────────────

  describe "auto_match/1" do
    test "auto-matches feed transactions above threshold" do
      {company, bfc} = create_feed_config()

      feed_txn =
        create_feed_transaction(bfc.id, %{
          description: "Monthly Rent",
          amount: Decimal.new("2000.00"),
          date: "2024-06-15"
        })

      book_txn = create_book_transaction(company, %{
        description: "Monthly Rent",
        amount: 2000.0,
        date: "2024-06-15"
      })

      matches = Reconciliation.auto_match(bfc.id)

      assert length(matches) == 1
      [{matched_feed, matched_book, score}] = matches
      assert matched_feed.id == feed_txn.id
      assert matched_book.id == book_txn.id
      assert score == 100
    end

    test "does not match feed transactions below threshold" do
      {company, bfc} = create_feed_config()

      _feed_txn =
        create_feed_transaction(bfc.id, %{
          description: "Very Specific Feed Description",
          amount: Decimal.new("12345.00"),
          date: "2024-06-15"
        })

      # Wildly different book transaction
      _book_txn = create_book_transaction(company, %{
        description: "Completely Different",
        amount: 1.0,
        date: "2020-01-01"
      })

      matches = Reconciliation.auto_match(bfc.id)
      assert matches == []
    end

    test "returns empty list when no feed transactions exist" do
      {_company, bfc} = create_feed_config()
      matches = Reconciliation.auto_match(bfc.id)
      assert matches == []
    end

    test "returns empty list when no book transactions exist" do
      {_company, bfc} = create_feed_config()
      create_feed_transaction(bfc.id, %{description: "No books to match"})

      matches = Reconciliation.auto_match(bfc.id)
      assert matches == []
    end

    test "does not re-match already matched feed transactions" do
      {company, bfc} = create_feed_config()

      _feed_txn =
        create_feed_transaction(bfc.id, %{
          description: "Already matched",
          amount: Decimal.new("500.00"),
          date: "2024-06-15"
        })

      _book_txn = create_book_transaction(company, %{
        description: "Already matched",
        amount: 500.0,
        date: "2024-06-15"
      })

      # First auto-match
      matches1 = Reconciliation.auto_match(bfc.id)
      assert length(matches1) == 1

      # Second auto-match should find nothing new
      matches2 = Reconciliation.auto_match(bfc.id)
      assert matches2 == []
    end

    test "does not double-match book transactions" do
      {company, bfc} = create_feed_config()

      # Two identical feed transactions
      _feed1 =
        create_feed_transaction(bfc.id, %{
          description: "Duplicate Payment",
          amount: Decimal.new("300.00"),
          date: "2024-06-15"
        })

      _feed2 =
        create_feed_transaction(bfc.id, %{
          description: "Duplicate Payment",
          amount: Decimal.new("300.00"),
          date: "2024-06-15"
        })

      # Only one matching book transaction
      book_txn = create_book_transaction(company, %{
        description: "Duplicate Payment",
        amount: 300.0,
        date: "2024-06-15"
      })

      matches = Reconciliation.auto_match(bfc.id)
      # Only one should be matched since there's only one book transaction
      assert length(matches) == 1

      matched_book_ids = Enum.map(matches, fn {_f, b, _s} -> b.id end)
      assert book_txn.id in matched_book_ids
    end

    test "matches multiple feed transactions to different book transactions" do
      {company, bfc} = create_feed_config()

      feed1 =
        create_feed_transaction(bfc.id, %{
          description: "Payment A",
          amount: Decimal.new("100.00"),
          date: "2024-06-01"
        })

      feed2 =
        create_feed_transaction(bfc.id, %{
          description: "Payment B",
          amount: Decimal.new("200.00"),
          date: "2024-06-10"
        })

      book1 = create_book_transaction(company, %{
        description: "Payment A",
        amount: 100.0,
        date: "2024-06-01"
      })

      book2 = create_book_transaction(company, %{
        description: "Payment B",
        amount: 200.0,
        date: "2024-06-10"
      })

      matches = Reconciliation.auto_match(bfc.id)
      assert length(matches) == 2

      matched_feed_ids = Enum.map(matches, fn {f, _b, _s} -> f.id end)
      matched_book_ids = Enum.map(matches, fn {_f, b, _s} -> b.id end)

      assert feed1.id in matched_feed_ids
      assert feed2.id in matched_feed_ids
      assert book1.id in matched_book_ids
      assert book2.id in matched_book_ids
    end

    test "updates reconciliation summary after auto-matching" do
      {company, bfc} = create_feed_config()

      create_feed_transaction(bfc.id, %{
        description: "Auto summary test",
        amount: Decimal.new("800.00"),
        date: "2024-06-15"
      })

      create_book_transaction(company, %{
        description: "Auto summary test",
        amount: 800.0,
        date: "2024-06-15"
      })

      assert %{total: 1, matched: 0, unmatched: 1} = Reconciliation.reconciliation_summary(bfc.id)

      Reconciliation.auto_match(bfc.id)

      assert %{total: 1, matched: 1, unmatched: 0} = Reconciliation.reconciliation_summary(bfc.id)
    end

    test "auto-match respects threshold of 60 points" do
      {company, bfc} = create_feed_config()

      # This feed txn should match with score of 50 (exact amount) + 5 (date within 7 days) = 55
      # That's below 60, so no match
      create_feed_transaction(bfc.id, %{
        description: "",
        amount: Decimal.new("1000.00"),
        date: "2024-06-15"
      })

      create_book_transaction(company, %{
        description: "X",
        amount: 1000.0,
        date: "2024-06-22"
      })

      matches = Reconciliation.auto_match(bfc.id)
      assert matches == []
    end

    test "auto-match succeeds at threshold boundary (exact amount + same day = 80)" do
      {company, bfc} = create_feed_config()

      create_feed_transaction(bfc.id, %{
        description: "",
        amount: Decimal.new("1000.00"),
        date: "2024-06-15"
      })

      create_book_transaction(company, %{
        description: "X",
        amount: 1000.0,
        date: "2024-06-15"
      })

      matches = Reconciliation.auto_match(bfc.id)
      assert length(matches) == 1
      [{_feed, _book, score}] = matches
      assert score >= 60
    end
  end
end
