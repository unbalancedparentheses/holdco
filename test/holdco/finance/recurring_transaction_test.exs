defmodule Holdco.Finance.RecurringTransactionTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Finance

  describe "recurring transaction CRUD" do
    test "create_recurring_transaction/1 creates a recurring transaction" do
      company = company_fixture()

      {:ok, rt} =
        Finance.create_recurring_transaction(%{
          company_id: company.id,
          description: "Monthly rent",
          amount: 5000.0,
          frequency: "monthly",
          start_date: "2024-01-01",
          next_run_date: "2024-01-01"
        })

      assert rt.description == "Monthly rent"
      assert Decimal.equal?(rt.amount, Decimal.new("5000.0"))
      assert rt.frequency == "monthly"
      assert rt.is_active == true
    end

    test "create_recurring_transaction/1 with invalid data returns error" do
      assert {:error, cs} = Finance.create_recurring_transaction(%{})
      assert errors_on(cs)[:company_id]
      assert errors_on(cs)[:description]
      assert errors_on(cs)[:amount]
    end

    test "list_recurring_transactions/0 returns all" do
      company = company_fixture()

      {:ok, rt} =
        Finance.create_recurring_transaction(%{
          company_id: company.id,
          description: "Weekly payroll",
          amount: 10000.0,
          frequency: "weekly",
          start_date: "2024-01-01",
          next_run_date: "2024-01-01"
        })

      transactions = Finance.list_recurring_transactions()
      assert Enum.any?(transactions, &(&1.id == rt.id))
    end

    test "list_recurring_transactions/1 filters by company" do
      c1 = company_fixture()
      c2 = company_fixture()

      {:ok, rt1} =
        Finance.create_recurring_transaction(%{
          company_id: c1.id,
          description: "Rent C1",
          amount: 3000.0,
          frequency: "monthly",
          start_date: "2024-01-01",
          next_run_date: "2024-01-01"
        })

      {:ok, rt2} =
        Finance.create_recurring_transaction(%{
          company_id: c2.id,
          description: "Rent C2",
          amount: 4000.0,
          frequency: "monthly",
          start_date: "2024-01-01",
          next_run_date: "2024-01-01"
        })

      results = Finance.list_recurring_transactions(c1.id)
      assert Enum.any?(results, &(&1.id == rt1.id))
      refute Enum.any?(results, &(&1.id == rt2.id))
    end

    test "get_recurring_transaction!/1 returns the transaction" do
      company = company_fixture()

      {:ok, rt} =
        Finance.create_recurring_transaction(%{
          company_id: company.id,
          description: "Test get",
          amount: 100.0,
          frequency: "daily",
          start_date: "2024-01-01",
          next_run_date: "2024-01-01"
        })

      fetched = Finance.get_recurring_transaction!(rt.id)
      assert fetched.id == rt.id
      assert fetched.description == "Test get"
    end

    test "update_recurring_transaction/2 updates the transaction" do
      company = company_fixture()

      {:ok, rt} =
        Finance.create_recurring_transaction(%{
          company_id: company.id,
          description: "Original",
          amount: 100.0,
          frequency: "daily",
          start_date: "2024-01-01",
          next_run_date: "2024-01-01"
        })

      {:ok, updated} = Finance.update_recurring_transaction(rt, %{description: "Updated"})
      assert updated.description == "Updated"
    end

    test "delete_recurring_transaction/1 removes the transaction" do
      company = company_fixture()

      {:ok, rt} =
        Finance.create_recurring_transaction(%{
          company_id: company.id,
          description: "To delete",
          amount: 100.0,
          frequency: "daily",
          start_date: "2024-01-01",
          next_run_date: "2024-01-01"
        })

      {:ok, _} = Finance.delete_recurring_transaction(rt)

      assert_raise Ecto.NoResultsError, fn ->
        Finance.get_recurring_transaction!(rt.id)
      end
    end
  end

  describe "list_due_recurring_transactions/0" do
    test "returns transactions due today or earlier" do
      company = company_fixture()
      today = Date.utc_today() |> Date.to_iso8601()

      {:ok, rt} =
        Finance.create_recurring_transaction(%{
          company_id: company.id,
          description: "Due today",
          amount: 100.0,
          frequency: "monthly",
          start_date: "2024-01-01",
          next_run_date: today,
          is_active: true
        })

      due = Finance.list_due_recurring_transactions()
      assert Enum.any?(due, &(&1.id == rt.id))
    end

    test "does not return future transactions" do
      company = company_fixture()
      future = Date.utc_today() |> Date.add(30) |> Date.to_iso8601()

      {:ok, rt} =
        Finance.create_recurring_transaction(%{
          company_id: company.id,
          description: "Future",
          amount: 100.0,
          frequency: "monthly",
          start_date: "2024-01-01",
          next_run_date: future,
          is_active: true
        })

      due = Finance.list_due_recurring_transactions()
      refute Enum.any?(due, &(&1.id == rt.id))
    end

    test "does not return inactive transactions" do
      company = company_fixture()
      today = Date.utc_today() |> Date.to_iso8601()

      {:ok, rt} =
        Finance.create_recurring_transaction(%{
          company_id: company.id,
          description: "Inactive",
          amount: 100.0,
          frequency: "monthly",
          start_date: "2024-01-01",
          next_run_date: today,
          is_active: false
        })

      due = Finance.list_due_recurring_transactions()
      refute Enum.any?(due, &(&1.id == rt.id))
    end
  end

  describe "advance_next_run_date/1" do
    test "advances daily frequency by 1 day" do
      company = company_fixture()

      {:ok, rt} =
        Finance.create_recurring_transaction(%{
          company_id: company.id,
          description: "Daily",
          amount: 10.0,
          frequency: "daily",
          start_date: "2024-01-01",
          next_run_date: "2024-01-15"
        })

      {:ok, updated} = Finance.advance_next_run_date(rt)
      assert updated.next_run_date == "2024-01-16"
      assert updated.last_run_date == "2024-01-15"
    end

    test "advances weekly frequency by 7 days" do
      company = company_fixture()

      {:ok, rt} =
        Finance.create_recurring_transaction(%{
          company_id: company.id,
          description: "Weekly",
          amount: 10.0,
          frequency: "weekly",
          start_date: "2024-01-01",
          next_run_date: "2024-01-15"
        })

      {:ok, updated} = Finance.advance_next_run_date(rt)
      assert updated.next_run_date == "2024-01-22"
    end

    test "advances monthly frequency by 30 days" do
      company = company_fixture()

      {:ok, rt} =
        Finance.create_recurring_transaction(%{
          company_id: company.id,
          description: "Monthly",
          amount: 10.0,
          frequency: "monthly",
          start_date: "2024-01-01",
          next_run_date: "2024-01-01"
        })

      {:ok, updated} = Finance.advance_next_run_date(rt)
      assert updated.next_run_date == "2024-01-31"
    end

    test "deactivates when next date exceeds end_date" do
      company = company_fixture()

      {:ok, rt} =
        Finance.create_recurring_transaction(%{
          company_id: company.id,
          description: "Ending soon",
          amount: 10.0,
          frequency: "monthly",
          start_date: "2024-01-01",
          end_date: "2024-02-15",
          next_run_date: "2024-01-20"
        })

      {:ok, updated} = Finance.advance_next_run_date(rt)
      assert updated.is_active == false
    end

    test "stays active when next date is within end_date" do
      company = company_fixture()

      {:ok, rt} =
        Finance.create_recurring_transaction(%{
          company_id: company.id,
          description: "Ongoing",
          amount: 10.0,
          frequency: "daily",
          start_date: "2024-01-01",
          end_date: "2024-12-31",
          next_run_date: "2024-01-15"
        })

      {:ok, updated} = Finance.advance_next_run_date(rt)
      assert updated.is_active == true
    end
  end
end
