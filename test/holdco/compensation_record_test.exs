defmodule Holdco.CompensationRecordTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Finance

  describe "compensation_records" do
    test "list_compensation_records/0 returns all records" do
      cr = compensation_record_fixture()
      results = Finance.list_compensation_records()
      assert Enum.any?(results, &(&1.id == cr.id))
    end

    test "list_compensation_records/1 filters by company" do
      company = company_fixture()
      cr = compensation_record_fixture(%{company: company})
      _other = compensation_record_fixture()
      results = Finance.list_compensation_records(company.id)
      assert Enum.all?(results, &(&1.company_id == company.id))
      assert Enum.any?(results, &(&1.id == cr.id))
    end

    test "get_compensation_record!/1 returns the record" do
      cr = compensation_record_fixture()
      found = Finance.get_compensation_record!(cr.id)
      assert found.id == cr.id
      assert found.company != nil
    end

    test "get_compensation_record!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Finance.get_compensation_record!(0)
      end
    end

    test "create_compensation_record/1 with valid data" do
      company = company_fixture()

      assert {:ok, cr} =
               Finance.create_compensation_record(%{
                 company_id: company.id,
                 employee_name: "Jane Doe",
                 role: "CTO",
                 department: "Engineering",
                 compensation_type: "salary",
                 amount: "200000.00",
                 frequency: "annual",
                 effective_date: "2024-01-01"
               })

      assert cr.employee_name == "Jane Doe"
      assert cr.compensation_type == "salary"
      assert Decimal.equal?(cr.amount, Decimal.new("200000.00"))
    end

    test "create_compensation_record/1 fails without required fields" do
      assert {:error, changeset} = Finance.create_compensation_record(%{})
      errors = errors_on(changeset)
      assert errors[:company_id]
      assert errors[:employee_name]
      assert errors[:amount]
    end

    test "create_compensation_record/1 validates compensation_type" do
      company = company_fixture()

      assert {:error, changeset} =
               Finance.create_compensation_record(%{
                 company_id: company.id,
                 employee_name: "Test",
                 amount: "100",
                 compensation_type: "invalid",
                 frequency: "annual"
               })

      assert errors_on(changeset)[:compensation_type]
    end

    test "create_compensation_record/1 validates frequency" do
      company = company_fixture()

      assert {:error, changeset} =
               Finance.create_compensation_record(%{
                 company_id: company.id,
                 employee_name: "Test",
                 amount: "100",
                 compensation_type: "salary",
                 frequency: "invalid"
               })

      assert errors_on(changeset)[:frequency]
    end

    test "create_compensation_record/1 validates amount > 0" do
      company = company_fixture()

      assert {:error, changeset} =
               Finance.create_compensation_record(%{
                 company_id: company.id,
                 employee_name: "Test",
                 amount: "0",
                 compensation_type: "salary",
                 frequency: "annual"
               })

      assert errors_on(changeset)[:amount]
    end

    test "create_compensation_record/1 with all compensation types" do
      company = company_fixture()

      for ct <- ~w(salary bonus equity commission benefit severance) do
        assert {:ok, cr} =
                 Finance.create_compensation_record(%{
                   company_id: company.id,
                   employee_name: "Test #{ct}",
                   amount: "50000",
                   compensation_type: ct,
                   frequency: "annual"
                 })

        assert cr.compensation_type == ct
      end
    end

    test "update_compensation_record/2 updates attributes" do
      cr = compensation_record_fixture()

      assert {:ok, updated} =
               Finance.update_compensation_record(cr, %{status: "terminated", end_date: "2024-12-31"})

      assert updated.status == "terminated"
    end

    test "delete_compensation_record/1 deletes the record" do
      cr = compensation_record_fixture()
      assert {:ok, _} = Finance.delete_compensation_record(cr)
      assert_raise Ecto.NoResultsError, fn -> Finance.get_compensation_record!(cr.id) end
    end
  end

  describe "total_compensation/1" do
    test "returns total active compensation for a company" do
      company = company_fixture()
      compensation_record_fixture(%{company: company, amount: "100000", status: "active"})
      compensation_record_fixture(%{company: company, amount: "80000", status: "active"})
      compensation_record_fixture(%{company: company, amount: "50000", status: "terminated"})

      total = Finance.total_compensation(company.id)
      assert Decimal.equal?(total, Decimal.new("180000"))
    end

    test "returns zero for company with no records" do
      company = company_fixture()
      assert Decimal.equal?(Finance.total_compensation(company.id), Decimal.new(0))
    end
  end

  describe "compensation_by_department/1" do
    test "groups compensation by department" do
      company = company_fixture()
      compensation_record_fixture(%{company: company, department: "Engineering", amount: "120000"})
      compensation_record_fixture(%{company: company, department: "Engineering", amount: "130000"})
      compensation_record_fixture(%{company: company, department: "Sales", amount: "90000"})

      by_dept = Finance.compensation_by_department(company.id)
      eng = Enum.find(by_dept, &(&1.department == "Engineering"))
      sales = Enum.find(by_dept, &(&1.department == "Sales"))

      assert eng.count == 2
      assert Decimal.equal?(eng.total_amount, Decimal.new("250000"))
      assert sales.count == 1
    end
  end
end
