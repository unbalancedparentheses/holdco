defmodule Holdco.BankGuaranteeTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Finance

  describe "bank_guarantees" do
    test "list_bank_guarantees/0 returns all guarantees" do
      bg = bank_guarantee_fixture()
      results = Finance.list_bank_guarantees()
      assert Enum.any?(results, &(&1.id == bg.id))
    end

    test "list_bank_guarantees/1 filters by company" do
      company = company_fixture()
      bg = bank_guarantee_fixture(%{company: company})
      _other = bank_guarantee_fixture()
      results = Finance.list_bank_guarantees(company.id)
      assert Enum.all?(results, &(&1.company_id == company.id))
      assert Enum.any?(results, &(&1.id == bg.id))
    end

    test "get_bank_guarantee!/1 returns the guarantee" do
      bg = bank_guarantee_fixture()
      found = Finance.get_bank_guarantee!(bg.id)
      assert found.id == bg.id
      assert found.company != nil
    end

    test "get_bank_guarantee!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Finance.get_bank_guarantee!(0)
      end
    end

    test "create_bank_guarantee/1 with valid data" do
      company = company_fixture()

      assert {:ok, bg} =
               Finance.create_bank_guarantee(%{
                 company_id: company.id,
                 guarantee_type: "loc",
                 issuing_bank: "Chase",
                 beneficiary: "Vendor Inc",
                 reference_number: "LOC-001",
                 amount: "5000000.00",
                 issue_date: "2024-01-15",
                 expiry_date: "2025-01-15",
                 annual_fee_pct: "1.5"
               })

      assert bg.guarantee_type == "loc"
      assert bg.issuing_bank == "Chase"
      assert Decimal.equal?(bg.amount, Decimal.new("5000000.00"))
    end

    test "create_bank_guarantee/1 fails without required fields" do
      assert {:error, changeset} = Finance.create_bank_guarantee(%{})
      errors = errors_on(changeset)
      assert errors[:company_id]
      assert errors[:issuing_bank]
      assert errors[:beneficiary]
      assert errors[:amount]
    end

    test "create_bank_guarantee/1 validates guarantee_type" do
      company = company_fixture()

      assert {:error, changeset} =
               Finance.create_bank_guarantee(%{
                 company_id: company.id,
                 guarantee_type: "invalid",
                 issuing_bank: "Bank",
                 beneficiary: "Corp",
                 amount: "100"
               })

      assert errors_on(changeset)[:guarantee_type]
    end

    test "create_bank_guarantee/1 validates status" do
      company = company_fixture()

      assert {:error, changeset} =
               Finance.create_bank_guarantee(%{
                 company_id: company.id,
                 guarantee_type: "performance",
                 issuing_bank: "Bank",
                 beneficiary: "Corp",
                 amount: "100",
                 status: "invalid"
               })

      assert errors_on(changeset)[:status]
    end

    test "create_bank_guarantee/1 validates amount > 0" do
      company = company_fixture()

      assert {:error, changeset} =
               Finance.create_bank_guarantee(%{
                 company_id: company.id,
                 guarantee_type: "performance",
                 issuing_bank: "Bank",
                 beneficiary: "Corp",
                 amount: "0"
               })

      assert errors_on(changeset)[:amount]
    end

    test "create_bank_guarantee/1 with all guarantee types" do
      company = company_fixture()

      for gt <- ~w(performance financial bid advance_payment loc standby_loc) do
        assert {:ok, bg} =
                 Finance.create_bank_guarantee(%{
                   company_id: company.id,
                   guarantee_type: gt,
                   issuing_bank: "Bank #{gt}",
                   beneficiary: "Beneficiary #{gt}",
                   amount: "100000"
                 })

        assert bg.guarantee_type == gt
      end
    end

    test "update_bank_guarantee/2 updates attributes" do
      bg = bank_guarantee_fixture()

      assert {:ok, updated} =
               Finance.update_bank_guarantee(bg, %{status: "expired", notes: "Expired naturally"})

      assert updated.status == "expired"
      assert updated.notes == "Expired naturally"
    end

    test "delete_bank_guarantee/1 deletes the guarantee" do
      bg = bank_guarantee_fixture()
      assert {:ok, _} = Finance.delete_bank_guarantee(bg)
      assert_raise Ecto.NoResultsError, fn -> Finance.get_bank_guarantee!(bg.id) end
    end
  end

  describe "active_guarantees/1" do
    test "returns only active guarantees" do
      company = company_fixture()
      active = bank_guarantee_fixture(%{company: company, status: "active"})
      _expired = bank_guarantee_fixture(%{company: company, status: "expired"})
      _called = bank_guarantee_fixture(%{company: company, status: "called"})

      results = Finance.active_guarantees(company.id)
      assert Enum.any?(results, &(&1.id == active.id))
      assert Enum.all?(results, &(&1.status == "active"))
    end
  end

  describe "guarantee_summary/1" do
    test "returns summary with by_type, by_status, and totals" do
      company = company_fixture()
      bank_guarantee_fixture(%{company: company, guarantee_type: "performance", amount: "1000000", status: "active"})
      bank_guarantee_fixture(%{company: company, guarantee_type: "loc", amount: "500000", status: "active"})
      bank_guarantee_fixture(%{company: company, guarantee_type: "performance", amount: "200000", status: "expired"})

      summary = Finance.guarantee_summary(company.id)
      assert is_list(summary.by_type)
      assert is_list(summary.by_status)
      assert Decimal.equal?(summary.total_amount, Decimal.new("1700000"))
      assert Decimal.equal?(summary.active_amount, Decimal.new("1500000"))
    end

    test "returns zero totals for company with no guarantees" do
      company = company_fixture()
      summary = Finance.guarantee_summary(company.id)
      assert Decimal.equal?(summary.total_amount, Decimal.new(0))
      assert Decimal.equal?(summary.active_amount, Decimal.new(0))
    end
  end
end
