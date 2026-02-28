defmodule Holdco.Finance.CharitableGiftTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Finance

  describe "charitable_gifts CRUD" do
    test "list_charitable_gifts/0 returns all gifts" do
      gift = charitable_gift_fixture()
      assert Enum.any?(Finance.list_charitable_gifts(), &(&1.id == gift.id))
    end

    test "list_charitable_gifts/1 filters by company_id" do
      company = company_fixture()
      gift = charitable_gift_fixture(%{company: company})
      other = charitable_gift_fixture()

      results = Finance.list_charitable_gifts(company.id)
      assert Enum.any?(results, &(&1.id == gift.id))
      refute Enum.any?(results, &(&1.id == other.id))
    end

    test "get_charitable_gift!/1 returns gift with preloads" do
      gift = charitable_gift_fixture()
      fetched = Finance.get_charitable_gift!(gift.id)
      assert fetched.id == gift.id
      assert fetched.company != nil
    end

    test "get_charitable_gift!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Finance.get_charitable_gift!(0)
      end
    end

    test "create_charitable_gift/1 with valid data" do
      company = company_fixture()

      assert {:ok, gift} =
               Finance.create_charitable_gift(%{
                 company_id: company.id,
                 recipient_name: "Local Food Bank",
                 recipient_type: "501c3",
                 ein_number: "12-3456789",
                 amount: "50000.00",
                 gift_type: "cash",
                 gift_date: "2024-12-15",
                 tax_year: 2024,
                 tax_deductible: true
               })

      assert gift.recipient_name == "Local Food Bank"
      assert gift.recipient_type == "501c3"
      assert Decimal.equal?(gift.amount, Decimal.new("50000.00"))
      assert gift.tax_deductible == true
    end

    test "create_charitable_gift/1 with all recipient types" do
      company = company_fixture()

      for type <- ~w(501c3 daf private_foundation public_charity religious educational other) do
        assert {:ok, gift} =
                 Finance.create_charitable_gift(%{
                   company_id: company.id,
                   recipient_name: "Org #{type}",
                   recipient_type: type,
                   amount: "1000.00",
                   gift_date: "2024-01-01"
                 })

        assert gift.recipient_type == type
      end
    end

    test "create_charitable_gift/1 with all gift types" do
      company = company_fixture()

      for type <- ~w(cash securities property in_kind pledge) do
        assert {:ok, gift} =
                 Finance.create_charitable_gift(%{
                   company_id: company.id,
                   recipient_name: "Charity",
                   gift_type: type,
                   amount: "5000.00",
                   gift_date: "2024-01-01"
                 })

        assert gift.gift_type == type
      end
    end

    test "create_charitable_gift/1 fails without required fields" do
      assert {:error, changeset} = Finance.create_charitable_gift(%{})
      errors = errors_on(changeset)
      assert errors[:company_id]
      assert errors[:recipient_name]
      assert errors[:amount]
      assert errors[:gift_date]
    end

    test "create_charitable_gift/1 fails with invalid recipient type" do
      company = company_fixture()

      assert {:error, changeset} =
               Finance.create_charitable_gift(%{
                 company_id: company.id,
                 recipient_name: "Test",
                 recipient_type: "invalid",
                 amount: "1000.00",
                 gift_date: "2024-01-01"
               })

      assert errors_on(changeset)[:recipient_type]
    end

    test "update_charitable_gift/2 with valid data" do
      gift = charitable_gift_fixture()

      assert {:ok, updated} =
               Finance.update_charitable_gift(gift, %{
                 recipient_name: "Updated Charity",
                 acknowledgment_received: true,
                 acknowledgment_date: "2024-07-01"
               })

      assert updated.recipient_name == "Updated Charity"
      assert updated.acknowledgment_received == true
    end

    test "delete_charitable_gift/1 removes the gift" do
      gift = charitable_gift_fixture()
      assert {:ok, _} = Finance.delete_charitable_gift(gift)

      assert_raise Ecto.NoResultsError, fn ->
        Finance.get_charitable_gift!(gift.id)
      end
    end
  end

  describe "gifts_by_year/2" do
    test "returns gifts for a specific year" do
      company = company_fixture()
      gift_2024 = charitable_gift_fixture(%{company: company, tax_year: 2024})
      _gift_2023 = charitable_gift_fixture(%{company: company, tax_year: 2023})

      results = Finance.gifts_by_year(company.id, 2024)
      assert Enum.any?(results, &(&1.id == gift_2024.id))
      assert length(results) == 1
    end
  end

  describe "total_giving/1" do
    test "sums all giving for a company" do
      company = company_fixture()
      charitable_gift_fixture(%{company: company, amount: "10000.00"})
      charitable_gift_fixture(%{company: company, amount: "25000.00"})

      total = Finance.total_giving(company.id)
      assert Decimal.equal?(total, Decimal.new("35000.00"))
    end

    test "returns zero when no gifts exist" do
      company = company_fixture()
      total = Finance.total_giving(company.id)
      assert Decimal.equal?(total, Decimal.new(0))
    end
  end

  describe "unfulfilled_pledges/1" do
    test "returns only unfulfilled pledges" do
      company = company_fixture()
      pledge = charitable_gift_fixture(%{company: company, gift_type: "pledge", pledge_fulfilled: false})
      _fulfilled = charitable_gift_fixture(%{company: company, gift_type: "pledge", pledge_fulfilled: true})
      _cash = charitable_gift_fixture(%{company: company, gift_type: "cash"})

      results = Finance.unfulfilled_pledges(company.id)
      assert length(results) == 1
      assert Enum.any?(results, &(&1.id == pledge.id))
    end
  end
end
