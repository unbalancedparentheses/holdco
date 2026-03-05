defmodule Holdco.MultiBookTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Finance

  # ── Accounting Book CRUD ───────────────────────────────

  describe "list_accounting_books/1" do
    test "returns all books" do
      book = accounting_book_fixture()
      books = Finance.list_accounting_books()
      assert length(books) >= 1
      assert Enum.any?(books, &(&1.id == book.id))
    end

    test "filters by company_id" do
      c1 = company_fixture(%{name: "BookCo1"})
      c2 = company_fixture(%{name: "BookCo2"})
      b1 = accounting_book_fixture(%{company: c1})
      _b2 = accounting_book_fixture(%{company: c2})

      books = Finance.list_accounting_books(c1.id)
      assert length(books) == 1
      assert hd(books).id == b1.id
    end

    test "returns empty list when no books for company" do
      company = company_fixture()
      assert Finance.list_accounting_books(company.id) == []
    end
  end

  describe "get_accounting_book!/1" do
    test "returns the book with given id" do
      book = accounting_book_fixture()
      found = Finance.get_accounting_book!(book.id)
      assert found.id == book.id
      assert found.name == book.name
    end

    test "preloads company and adjustments" do
      book = accounting_book_fixture()
      found = Finance.get_accounting_book!(book.id)
      assert found.company != nil
      assert is_list(found.adjustments)
    end

    test "raises when id does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Finance.get_accounting_book!(0)
      end
    end
  end

  describe "create_accounting_book/1" do
    test "creates a book with valid attrs" do
      company = company_fixture()

      assert {:ok, book} =
               Finance.create_accounting_book(%{
                 company_id: company.id,
                 name: "IFRS Primary",
                 book_type: "ifrs",
                 base_currency: "EUR",
                 is_primary: true
               })

      assert book.name == "IFRS Primary"
      assert book.book_type == "ifrs"
      assert book.base_currency == "EUR"
      assert book.is_primary == true
      assert book.is_active == true
    end

    test "fails without required fields" do
      assert {:error, changeset} = Finance.create_accounting_book(%{})
      errors = errors_on(changeset)
      assert errors[:company_id]
      assert errors[:name]
      assert errors[:book_type]
    end

    test "validates book_type inclusion" do
      company = company_fixture()

      assert {:error, changeset} =
               Finance.create_accounting_book(%{
                 company_id: company.id,
                 name: "Bad Type",
                 book_type: "invalid_type"
               })

      assert %{book_type: _} = errors_on(changeset)
    end

    test "accepts all valid book types" do
      company = company_fixture()

      for type <- ~w(ifrs us_gaap local_gaap tax management) do
        assert {:ok, book} =
                 Finance.create_accounting_book(%{
                   company_id: company.id,
                   name: "#{type} book",
                   book_type: type
                 })

        assert book.book_type == type
      end
    end
  end

  describe "update_accounting_book/2" do
    test "updates a book" do
      book = accounting_book_fixture()
      assert {:ok, updated} = Finance.update_accounting_book(book, %{name: "Updated Name"})
      assert updated.name == "Updated Name"
    end

    test "deactivates a book" do
      book = accounting_book_fixture()
      assert {:ok, updated} = Finance.update_accounting_book(book, %{is_active: false})
      assert updated.is_active == false
    end

    test "rejects invalid book_type update" do
      book = accounting_book_fixture()

      assert {:error, changeset} =
               Finance.update_accounting_book(book, %{book_type: "invalid"})

      assert %{book_type: _} = errors_on(changeset)
    end
  end

  describe "delete_accounting_book/1" do
    test "deletes the book" do
      book = accounting_book_fixture()
      assert {:ok, _} = Finance.delete_accounting_book(book)

      assert_raise Ecto.NoResultsError, fn ->
        Finance.get_accounting_book!(book.id)
      end
    end
  end

  # ── Book Adjustment CRUD ───────────────────────────────

  describe "list_book_adjustments/1" do
    test "returns adjustments for a book" do
      book = accounting_book_fixture()
      adjustment = book_adjustment_fixture(%{book: book})
      adjustments = Finance.list_book_adjustments(book.id)
      assert length(adjustments) >= 1
      assert Enum.any?(adjustments, &(&1.id == adjustment.id))
    end

    test "returns empty list when no adjustments" do
      book = accounting_book_fixture()
      assert Finance.list_book_adjustments(book.id) == []
    end
  end

  describe "get_book_adjustment!/1" do
    test "returns the adjustment with given id" do
      adjustment = book_adjustment_fixture()
      found = Finance.get_book_adjustment!(adjustment.id)
      assert found.id == adjustment.id
    end

    test "raises when id does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Finance.get_book_adjustment!(0)
      end
    end
  end

  describe "create_book_adjustment/1" do
    test "creates an adjustment with valid attrs" do
      book = accounting_book_fixture()

      assert {:ok, adj} =
               Finance.create_book_adjustment(%{
                 book_id: book.id,
                 adjustment_type: "measurement",
                 amount: 5000.0,
                 effective_date: "2026-02-01",
                 description: "Fair value remeasurement"
               })

      assert adj.adjustment_type == "measurement"
      assert Decimal.equal?(adj.amount, Decimal.from_float(5000.0))
    end

    test "creates an adjustment with account references" do
      company = company_fixture()
      book = accounting_book_fixture(%{company: company})
      debit_acct = account_fixture(%{company: company, name: "Debit Account", account_type: "asset", code: "1001-#{System.unique_integer([:positive])}"})
      credit_acct = account_fixture(%{company: company, name: "Credit Account", account_type: "liability", code: "2001-#{System.unique_integer([:positive])}"})

      assert {:ok, adj} =
               Finance.create_book_adjustment(%{
                 book_id: book.id,
                 adjustment_type: "reclassification",
                 debit_account_id: debit_acct.id,
                 credit_account_id: credit_acct.id,
                 amount: 10_000.0,
                 effective_date: "2026-01-31"
               })

      assert adj.debit_account_id == debit_acct.id
      assert adj.credit_account_id == credit_acct.id
    end

    test "fails without required fields" do
      assert {:error, changeset} = Finance.create_book_adjustment(%{})
      errors = errors_on(changeset)
      assert errors[:book_id]
      assert errors[:adjustment_type]
      assert errors[:amount]
      assert errors[:effective_date]
    end

    test "validates adjustment_type inclusion" do
      book = accounting_book_fixture()

      assert {:error, changeset} =
               Finance.create_book_adjustment(%{
                 book_id: book.id,
                 adjustment_type: "invalid_type",
                 amount: 100.0,
                 effective_date: "2026-01-01"
               })

      assert %{adjustment_type: _} = errors_on(changeset)
    end

    test "validates amount is positive" do
      book = accounting_book_fixture()

      assert {:error, changeset} =
               Finance.create_book_adjustment(%{
                 book_id: book.id,
                 adjustment_type: "reclassification",
                 amount: -100.0,
                 effective_date: "2026-01-01"
               })

      assert %{amount: _} = errors_on(changeset)
    end

    test "accepts all valid adjustment types" do
      book = accounting_book_fixture()

      for type <- ~w(reclassification measurement elimination other) do
        assert {:ok, adj} =
                 Finance.create_book_adjustment(%{
                   book_id: book.id,
                   adjustment_type: type,
                   amount: 100.0,
                   effective_date: "2026-01-01"
                 })

        assert adj.adjustment_type == type
      end
    end
  end

  describe "update_book_adjustment/2" do
    test "updates an adjustment" do
      adj = book_adjustment_fixture()

      assert {:ok, updated} =
               Finance.update_book_adjustment(adj, %{description: "Updated description"})

      assert updated.description == "Updated description"
    end

    test "updates amount" do
      adj = book_adjustment_fixture()
      assert {:ok, updated} = Finance.update_book_adjustment(adj, %{amount: 9999.0})
      assert Decimal.equal?(updated.amount, Decimal.from_float(9999.0))
    end
  end

  describe "delete_book_adjustment/1" do
    test "deletes the adjustment" do
      adj = book_adjustment_fixture()
      assert {:ok, _} = Finance.delete_book_adjustment(adj)

      assert_raise Ecto.NoResultsError, fn ->
        Finance.get_book_adjustment!(adj.id)
      end
    end
  end

  # ── Book Trial Balance ─────────────────────────────────

  describe "book_trial_balance/2" do
    test "returns base trial balance when no adjustments" do
      company = company_fixture()
      book = accounting_book_fixture(%{company: company})

      # Create an account and journal entry
      acct = account_fixture(%{company: company, name: "Cash", account_type: "asset", code: "1000-#{System.unique_integer([:positive])}"})
      je = journal_entry_fixture(%{company: company})
      journal_line_fixture(%{entry: je, account: acct, debit: 1000.0, credit: 0.0})

      tb = Finance.book_trial_balance(book.id, ~D[2026-12-31])

      assert is_list(tb)
      cash_entry = Enum.find(tb, &(&1.id == acct.id))
      assert cash_entry != nil
      assert Decimal.equal?(cash_entry.total_debit, Decimal.from_float(1000.0))
    end

    test "applies adjustments to the trial balance" do
      company = company_fixture()
      book = accounting_book_fixture(%{company: company})

      acct = account_fixture(%{company: company, name: "Inventory", account_type: "asset", code: "1100-#{System.unique_integer([:positive])}"})
      je = journal_entry_fixture(%{company: company})
      journal_line_fixture(%{entry: je, account: acct, debit: 5000.0, credit: 0.0})

      # Add an adjustment that debits the inventory account
      Finance.create_book_adjustment(%{
        book_id: book.id,
        adjustment_type: "measurement",
        debit_account_id: acct.id,
        amount: 500.0,
        effective_date: "2026-06-15"
      })

      tb = Finance.book_trial_balance(book.id, ~D[2026-12-31])
      inv_entry = Enum.find(tb, &(&1.id == acct.id))

      # Original 5000 debit + 500 adjustment debit = 5500
      assert Decimal.equal?(inv_entry.total_debit, Decimal.from_float(5500.0))
      assert Decimal.equal?(inv_entry.debit_adjustment, Decimal.from_float(500.0))
    end

    test "only applies adjustments up to the given date" do
      company = company_fixture()
      book = accounting_book_fixture(%{company: company})

      acct = account_fixture(%{company: company, name: "Equipment", account_type: "asset", code: "1200-#{System.unique_integer([:positive])}"})
      je = journal_entry_fixture(%{company: company})
      journal_line_fixture(%{entry: je, account: acct, debit: 10_000.0, credit: 0.0})

      # Adjustment before cutoff date
      Finance.create_book_adjustment(%{
        book_id: book.id,
        adjustment_type: "measurement",
        debit_account_id: acct.id,
        amount: 1000.0,
        effective_date: "2026-03-01"
      })

      # Adjustment after cutoff date
      Finance.create_book_adjustment(%{
        book_id: book.id,
        adjustment_type: "measurement",
        debit_account_id: acct.id,
        amount: 2000.0,
        effective_date: "2026-09-01"
      })

      # Query as of June 30 - should only include March adjustment
      tb = Finance.book_trial_balance(book.id, ~D[2026-06-30])
      equip_entry = Enum.find(tb, &(&1.id == acct.id))

      # Original 10000 + 1000 March adjustment = 11000 (September excluded)
      assert Decimal.equal?(equip_entry.total_debit, Decimal.from_float(11_000.0))
    end

    test "applies credit adjustments correctly" do
      company = company_fixture()
      book = accounting_book_fixture(%{company: company})

      acct = account_fixture(%{company: company, name: "Revenue", account_type: "revenue", code: "4000-#{System.unique_integer([:positive])}"})
      je = journal_entry_fixture(%{company: company})
      journal_line_fixture(%{entry: je, account: acct, debit: 0.0, credit: 3000.0})

      Finance.create_book_adjustment(%{
        book_id: book.id,
        adjustment_type: "reclassification",
        credit_account_id: acct.id,
        amount: 500.0,
        effective_date: "2026-01-15"
      })

      tb = Finance.book_trial_balance(book.id, ~D[2026-12-31])
      rev_entry = Enum.find(tb, &(&1.id == acct.id))

      assert Decimal.equal?(rev_entry.total_credit, Decimal.from_float(3500.0))
      assert Decimal.equal?(rev_entry.credit_adjustment, Decimal.from_float(500.0))
    end
  end
end
