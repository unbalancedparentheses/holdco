defmodule Holdco.Finance.PeriodLockTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures
  import Holdco.AccountsFixtures

  alias Holdco.Finance

  describe "period lock CRUD" do
    test "lock_period/5 creates a locked period" do
      company = company_fixture()
      user = user_fixture()

      {:ok, lock} =
        Finance.lock_period(
          company.id,
          ~D[2024-01-01],
          ~D[2024-01-31],
          "month",
          user.id
        )

      assert lock.company_id == company.id
      assert lock.period_start == ~D[2024-01-01]
      assert lock.period_end == ~D[2024-01-31]
      assert lock.period_type == "month"
      assert lock.status == "locked"
      assert lock.locked_by_id == user.id
      assert lock.locked_at != nil
    end

    test "list_period_locks/0 returns all period locks" do
      company = company_fixture()
      user = user_fixture()
      {:ok, lock} = Finance.lock_period(company.id, ~D[2024-01-01], ~D[2024-01-31], "month", user.id)

      locks = Finance.list_period_locks()
      assert Enum.any?(locks, &(&1.id == lock.id))
    end

    test "list_period_locks/1 filters by company" do
      c1 = company_fixture()
      c2 = company_fixture()
      user = user_fixture()
      {:ok, lock1} = Finance.lock_period(c1.id, ~D[2024-01-01], ~D[2024-01-31], "month", user.id)
      {:ok, lock2} = Finance.lock_period(c2.id, ~D[2024-01-01], ~D[2024-01-31], "month", user.id)

      locks = Finance.list_period_locks(c1.id)
      assert Enum.any?(locks, &(&1.id == lock1.id))
      refute Enum.any?(locks, &(&1.id == lock2.id))
    end

    test "get_period_lock!/1 returns the period lock" do
      company = company_fixture()
      user = user_fixture()
      {:ok, lock} = Finance.lock_period(company.id, ~D[2024-01-01], ~D[2024-01-31], "month", user.id)

      fetched = Finance.get_period_lock!(lock.id)
      assert fetched.id == lock.id
    end

    test "unlock_period/3 sets status to unlocked with reason" do
      company = company_fixture()
      user = user_fixture()
      {:ok, lock} = Finance.lock_period(company.id, ~D[2024-01-01], ~D[2024-01-31], "month", user.id)

      {:ok, unlocked} = Finance.unlock_period(lock.id, user.id, "Correction needed")

      assert unlocked.status == "unlocked"
      assert unlocked.unlocked_by_id == user.id
      assert unlocked.unlock_reason == "Correction needed"
      assert unlocked.unlocked_at != nil
    end

    test "delete_period_lock/1 removes the lock" do
      company = company_fixture()
      user = user_fixture()
      {:ok, lock} = Finance.lock_period(company.id, ~D[2024-01-01], ~D[2024-01-31], "month", user.id)

      {:ok, _} = Finance.delete_period_lock(lock)

      assert_raise Ecto.NoResultsError, fn ->
        Finance.get_period_lock!(lock.id)
      end
    end
  end

  describe "is_period_locked?/2" do
    test "returns true for a date within a locked period" do
      company = company_fixture()
      user = user_fixture()
      {:ok, _lock} = Finance.lock_period(company.id, ~D[2024-01-01], ~D[2024-01-31], "month", user.id)

      assert Finance.is_period_locked?(company.id, ~D[2024-01-15])
    end

    test "returns true for a date on the period boundary" do
      company = company_fixture()
      user = user_fixture()
      {:ok, _lock} = Finance.lock_period(company.id, ~D[2024-01-01], ~D[2024-01-31], "month", user.id)

      assert Finance.is_period_locked?(company.id, ~D[2024-01-01])
      assert Finance.is_period_locked?(company.id, ~D[2024-01-31])
    end

    test "returns false for a date outside a locked period" do
      company = company_fixture()
      user = user_fixture()
      {:ok, _lock} = Finance.lock_period(company.id, ~D[2024-01-01], ~D[2024-01-31], "month", user.id)

      refute Finance.is_period_locked?(company.id, ~D[2024-02-01])
    end

    test "returns false when period is unlocked" do
      company = company_fixture()
      user = user_fixture()
      {:ok, lock} = Finance.lock_period(company.id, ~D[2024-01-01], ~D[2024-01-31], "month", user.id)
      {:ok, _} = Finance.unlock_period(lock.id, user.id, "Need to edit")

      refute Finance.is_period_locked?(company.id, ~D[2024-01-15])
    end

    test "returns false for a different company" do
      c1 = company_fixture()
      c2 = company_fixture()
      user = user_fixture()
      {:ok, _lock} = Finance.lock_period(c1.id, ~D[2024-01-01], ~D[2024-01-31], "month", user.id)

      refute Finance.is_period_locked?(c2.id, ~D[2024-01-15])
    end

    test "accepts string dates" do
      company = company_fixture()
      user = user_fixture()
      {:ok, _lock} = Finance.lock_period(company.id, ~D[2024-01-01], ~D[2024-01-31], "month", user.id)

      assert Finance.is_period_locked?(company.id, "2024-01-15")
    end
  end

  describe "period lock enforcement on journal entries" do
    setup do
      company = company_fixture()
      user = user_fixture()

      {:ok, cash_acct} =
        Finance.create_account(%{
          company_id: company.id,
          name: "Cash",
          account_type: "asset",
          code: "#{System.unique_integer([:positive])}"
        })

      {:ok, revenue_acct} =
        Finance.create_account(%{
          company_id: company.id,
          name: "Revenue",
          account_type: "revenue",
          code: "#{System.unique_integer([:positive])}"
        })

      {:ok, _lock} =
        Finance.lock_period(company.id, ~D[2024-01-01], ~D[2024-01-31], "month", user.id)

      %{company: company, cash_acct: cash_acct, revenue_acct: revenue_acct}
    end

    test "create_journal_entry/1 rejects entries in locked periods", ctx do
      result =
        Finance.create_journal_entry(%{
          company_id: ctx.company.id,
          date: "2024-01-15",
          description: "Should fail"
        })

      assert result == {:error, :period_locked}
    end

    test "create_journal_entry_with_lines/2 rejects entries in locked periods", ctx do
      entry_attrs = %{
        "company_id" => ctx.company.id,
        "date" => "2024-01-15",
        "description" => "Should fail"
      }

      lines_attrs = [
        %{"account_id" => ctx.cash_acct.id, "debit" => 1000.0, "credit" => 0.0},
        %{"account_id" => ctx.revenue_acct.id, "debit" => 0.0, "credit" => 1000.0}
      ]

      assert {:error, :period_locked} =
               Finance.create_journal_entry_with_lines(entry_attrs, lines_attrs)
    end

    test "entries in unlocked periods are allowed", ctx do
      entry_attrs = %{
        "company_id" => ctx.company.id,
        "date" => "2024-02-15",
        "description" => "Should succeed"
      }

      lines_attrs = [
        %{"account_id" => ctx.cash_acct.id, "debit" => 1000.0, "credit" => 0.0},
        %{"account_id" => ctx.revenue_acct.id, "debit" => 0.0, "credit" => 1000.0}
      ]

      assert {:ok, _entry} =
               Finance.create_journal_entry_with_lines(entry_attrs, lines_attrs)
    end
  end
end
