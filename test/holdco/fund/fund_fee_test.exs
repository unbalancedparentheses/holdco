defmodule Holdco.Fund.FundFeeTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Fund

  describe "list_fund_fees/1" do
    test "returns all fund fees" do
      fee = fund_fee_fixture()
      fees = Fund.list_fund_fees()
      assert length(fees) >= 1
      assert Enum.any?(fees, &(&1.id == fee.id))
    end

    test "filters by company_id" do
      c1 = company_fixture(%{name: "Fee Co1"})
      c2 = company_fixture(%{name: "Fee Co2"})
      fee1 = fund_fee_fixture(%{company: c1})
      _fee2 = fund_fee_fixture(%{company: c2})

      fees = Fund.list_fund_fees(c1.id)
      assert length(fees) == 1
      assert hd(fees).id == fee1.id
    end

    test "returns empty list when no fees for company" do
      company = company_fixture()
      assert Fund.list_fund_fees(company.id) == []
    end
  end

  describe "get_fund_fee!/1" do
    test "returns the fund fee with given id" do
      fee = fund_fee_fixture()
      found = Fund.get_fund_fee!(fee.id)
      assert found.id == fee.id
    end

    test "raises when id does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Fund.get_fund_fee!(0)
      end
    end
  end

  describe "create_fund_fee/1" do
    test "creates a fund fee with valid attrs" do
      company = company_fixture()

      assert {:ok, fee} =
               Fund.create_fund_fee(%{
                 company_id: company.id,
                 fee_type: "management",
                 description: "Q1 management fee",
                 amount: 25_000.0,
                 period_start: ~D[2024-01-01],
                 period_end: ~D[2024-03-31],
                 basis: "nav",
                 rate_pct: 2.0,
                 status: "accrued"
               })

      assert fee.fee_type == "management"
      assert Decimal.equal?(fee.amount, Decimal.from_float(25_000.0))
    end

    test "fails without required fields" do
      assert {:error, changeset} = Fund.create_fund_fee(%{})
      errors = errors_on(changeset)
      assert errors[:company_id]
      assert errors[:fee_type]
      assert errors[:amount]
    end

    test "validates fee_type values" do
      company = company_fixture()

      assert {:error, changeset} =
               Fund.create_fund_fee(%{
                 company_id: company.id,
                 fee_type: "invalid_type",
                 amount: 1000.0
               })

      assert errors_on(changeset)[:fee_type]
    end

    test "validates status values" do
      company = company_fixture()

      assert {:error, changeset} =
               Fund.create_fund_fee(%{
                 company_id: company.id,
                 fee_type: "management",
                 amount: 1000.0,
                 status: "invalid_status"
               })

      assert errors_on(changeset)[:status]
    end

    test "validates amount is non-negative" do
      company = company_fixture()

      assert {:error, changeset} =
               Fund.create_fund_fee(%{
                 company_id: company.id,
                 fee_type: "management",
                 amount: -100.0
               })

      assert errors_on(changeset)[:amount]
    end
  end

  describe "update_fund_fee/2" do
    test "updates a fund fee" do
      fee = fund_fee_fixture()

      assert {:ok, updated} =
               Fund.update_fund_fee(fee, %{status: "paid", paid_date: ~D[2024-04-01]})

      assert updated.status == "paid"
      assert updated.paid_date == ~D[2024-04-01]
    end

    test "fee status transitions" do
      fee = fund_fee_fixture(%{status: "accrued"})

      assert {:ok, fee} = Fund.update_fund_fee(fee, %{status: "invoiced"})
      assert fee.status == "invoiced"

      assert {:ok, fee} = Fund.update_fund_fee(fee, %{status: "paid"})
      assert fee.status == "paid"
    end

    test "fee can be waived" do
      fee = fund_fee_fixture(%{status: "accrued"})

      assert {:ok, fee} = Fund.update_fund_fee(fee, %{status: "waived"})
      assert fee.status == "waived"
    end
  end

  describe "delete_fund_fee/1" do
    test "deletes the fund fee" do
      fee = fund_fee_fixture()
      assert {:ok, _} = Fund.delete_fund_fee(fee)

      assert_raise Ecto.NoResultsError, fn ->
        Fund.get_fund_fee!(fee.id)
      end
    end
  end

  describe "calculate_management_fee/5" do
    test "calculates fee with NAV basis" do
      company = company_fixture()
      # Add some bank balance so NAV is not zero
      bank_account_fixture(%{company: company, balance: 1_000_000.0})

      result =
        Fund.calculate_management_fee(
          company.id,
          2.0,
          "nav",
          ~D[2024-01-01],
          ~D[2024-12-31]
        )

      assert result.fee_type == "management"
      assert result.basis == "nav"
      assert Decimal.compare(result.rate_pct, Decimal.new(0)) == :gt
      # Amount should be positive since we have bank balance
      assert Decimal.compare(result.amount, Decimal.new(0)) == :gt
    end

    test "calculates fee with committed capital basis" do
      company = company_fixture()
      fund_investment_fixture(%{company: company, commitment: 500_000.0})

      result =
        Fund.calculate_management_fee(
          company.id,
          1.5,
          "committed_capital",
          ~D[2024-01-01],
          ~D[2024-06-30]
        )

      assert result.fee_type == "management"
      assert result.basis == "committed_capital"
      assert Decimal.compare(result.amount, Decimal.new(0)) == :gt
    end

    test "returns zero amount for unknown basis" do
      company = company_fixture()

      result =
        Fund.calculate_management_fee(
          company.id,
          2.0,
          "fixed",
          ~D[2024-01-01],
          ~D[2024-12-31]
        )

      assert Decimal.equal?(result.amount, Decimal.new(0))
    end
  end

  describe "fee_summary/1" do
    test "groups fees by type" do
      company = company_fixture()
      fund_fee_fixture(%{company: company, fee_type: "management", amount: 20_000.0})
      fund_fee_fixture(%{company: company, fee_type: "performance", amount: 50_000.0})
      fund_fee_fixture(%{company: company, fee_type: "management", amount: 10_000.0})

      summary = Fund.fee_summary(company.id)

      assert summary.count == 3
      assert Map.has_key?(summary.by_type, "management")
      assert Map.has_key?(summary.by_type, "performance")
      # management total should be 30_000
      assert Decimal.compare(summary.by_type["management"], Decimal.new(0)) == :gt
    end

    test "groups fees by status" do
      company = company_fixture()
      fund_fee_fixture(%{company: company, status: "accrued", amount: 10_000.0})
      fund_fee_fixture(%{company: company, status: "paid", amount: 15_000.0})

      summary = Fund.fee_summary(company.id)

      assert Map.has_key?(summary.by_status, "accrued")
      assert Map.has_key?(summary.by_status, "paid")
    end

    test "returns zero totals for company with no fees" do
      company = company_fixture()

      summary = Fund.fee_summary(company.id)

      assert summary.count == 0
      assert Decimal.equal?(summary.total, Decimal.new(0))
    end
  end
end
