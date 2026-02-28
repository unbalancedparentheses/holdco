defmodule Holdco.Workers.InterestAccrualWorkerTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Workers.InterestAccrualWorker

  test "perform/1 returns :ok with no transfers" do
    assert :ok == InterestAccrualWorker.perform(%Oban.Job{args: %{}})
  end

  test "perform/1 returns :ok with no active/loan transfers" do
    inter_company_transfer_fixture(%{
      description: "Regular payment",
      status: "completed",
      notes: "rate:0.05"
    })

    assert :ok == InterestAccrualWorker.perform(%Oban.Job{args: %{}})
  end

  test "perform/1 processes active transfers" do
    inter_company_transfer_fixture(%{
      description: "Working capital",
      status: "active",
      notes: "rate:0.05",
      date: "2025-01-01"
    })

    assert :ok == InterestAccrualWorker.perform(%Oban.Job{args: %{}})
  end

  test "perform/1 processes loan transfers by description" do
    inter_company_transfer_fixture(%{
      description: "Intercompany loan for operations",
      status: "completed",
      notes: "rate:0.03",
      date: "2025-06-01"
    })

    assert :ok == InterestAccrualWorker.perform(%Oban.Job{args: %{}})
  end

  test "perform/1 processes multiple transfers" do
    inter_company_transfer_fixture(%{
      description: "Loan A",
      status: "active",
      notes: "rate:0.04",
      date: "2025-01-01"
    })

    inter_company_transfer_fixture(%{
      description: "Loan B",
      status: "active",
      notes: "rate:0.06",
      date: "2025-03-01"
    })

    assert :ok == InterestAccrualWorker.perform(%Oban.Job{args: %{}})
  end

  test "perform/1 handles transfers with zero rate gracefully" do
    inter_company_transfer_fixture(%{
      description: "Zero interest loan",
      status: "active",
      notes: "rate:0.00",
      date: "2025-01-01"
    })

    assert :ok == InterestAccrualWorker.perform(%Oban.Job{args: %{}})
  end

  test "perform/1 creates journal entries when interest accounts exist" do
    company = company_fixture()

    # Create interest expense and payable accounts
    account_fixture(%{
      company: company,
      name: "Interest Expense",
      account_type: "expense",
      code: "6100"
    })

    account_fixture(%{
      company: company,
      name: "Interest Payable",
      account_type: "liability",
      code: "2200"
    })

    inter_company_transfer_fixture(%{
      description: "Loan with accounts",
      status: "active",
      notes: "rate:0.05",
      date: "2025-01-01"
    })

    assert :ok == InterestAccrualWorker.perform(%Oban.Job{args: %{}})

    # Verify journal entries were created
    entries = Holdco.Finance.list_journal_entries()
    interest_entries = Enum.filter(entries, fn e -> String.contains?(e.description, "Interest accrual") end)
    assert length(interest_entries) > 0
  end
end
