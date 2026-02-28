defmodule Holdco.Workers.RecurringTransactionWorkerTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Workers.RecurringTransactionWorker
  alias Holdco.Finance

  describe "perform/1" do
    test "returns :ok with no recurring transactions" do
      assert :ok == RecurringTransactionWorker.perform(%Oban.Job{args: %{}})
    end

    test "returns :ok with no due recurring transactions" do
      company = company_fixture()
      future = Date.utc_today() |> Date.add(30) |> Date.to_iso8601()

      {:ok, _rt} =
        Finance.create_recurring_transaction(%{
          company_id: company.id,
          description: "Future transaction",
          amount: 1000.0,
          frequency: "monthly",
          start_date: "2024-01-01",
          next_run_date: future,
          is_active: true
        })

      assert :ok == RecurringTransactionWorker.perform(%Oban.Job{args: %{}})
    end

    test "processes due transactions with configured accounts" do
      company = company_fixture()
      today = Date.utc_today() |> Date.to_iso8601()

      {:ok, debit_acct} =
        Finance.create_account(%{
          company_id: company.id,
          name: "Rent Expense",
          account_type: "expense",
          code: "#{System.unique_integer([:positive])}"
        })

      {:ok, credit_acct} =
        Finance.create_account(%{
          company_id: company.id,
          name: "Cash",
          account_type: "asset",
          code: "#{System.unique_integer([:positive])}"
        })

      {:ok, rt} =
        Finance.create_recurring_transaction(%{
          company_id: company.id,
          description: "Monthly rent",
          amount: 5000.0,
          frequency: "monthly",
          start_date: "2024-01-01",
          next_run_date: today,
          is_active: true,
          debit_account_id: debit_acct.id,
          credit_account_id: credit_acct.id
        })

      assert :ok == RecurringTransactionWorker.perform(%Oban.Job{args: %{}})

      # Verify the next_run_date was advanced
      updated_rt = Finance.get_recurring_transaction!(rt.id)
      assert updated_rt.next_run_date != today
      assert updated_rt.last_run_date == today
    end

    test "advances date even without accounts configured" do
      company = company_fixture()
      today = Date.utc_today() |> Date.to_iso8601()

      {:ok, rt} =
        Finance.create_recurring_transaction(%{
          company_id: company.id,
          description: "No accounts",
          amount: 100.0,
          frequency: "daily",
          start_date: "2024-01-01",
          next_run_date: today,
          is_active: true
        })

      assert :ok == RecurringTransactionWorker.perform(%Oban.Job{args: %{}})

      updated_rt = Finance.get_recurring_transaction!(rt.id)
      assert updated_rt.next_run_date != today
      assert updated_rt.last_run_date == today
    end

    test "skips inactive transactions" do
      company = company_fixture()
      today = Date.utc_today() |> Date.to_iso8601()

      {:ok, rt} =
        Finance.create_recurring_transaction(%{
          company_id: company.id,
          description: "Inactive",
          amount: 100.0,
          frequency: "daily",
          start_date: "2024-01-01",
          next_run_date: today,
          is_active: false
        })

      assert :ok == RecurringTransactionWorker.perform(%Oban.Job{args: %{}})

      # next_run_date should not have changed
      unchanged_rt = Finance.get_recurring_transaction!(rt.id)
      assert unchanged_rt.next_run_date == today
    end
  end
end
