defmodule Holdco.ShareClassTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Corporate

  describe "share_classes" do
    test "list_share_classes/0 returns all share classes" do
      sc = share_class_fixture()
      results = Corporate.list_share_classes()
      assert Enum.any?(results, &(&1.id == sc.id))
    end

    test "list_share_classes/1 filters by company" do
      company = company_fixture()
      sc = share_class_fixture(%{company: company})
      _other = share_class_fixture()
      results = Corporate.list_share_classes(company.id)
      assert Enum.all?(results, &(&1.company_id == company.id))
      assert Enum.any?(results, &(&1.id == sc.id))
    end

    test "list_share_classes/1 returns empty for company with no share classes" do
      company = company_fixture()
      assert Corporate.list_share_classes(company.id) == []
    end

    test "get_share_class!/1 returns the share class with preloads" do
      sc = share_class_fixture()
      found = Corporate.get_share_class!(sc.id)
      assert found.id == sc.id
      assert found.company != nil
    end

    test "get_share_class!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Corporate.get_share_class!(0)
      end
    end

    test "create_share_class/1 with valid data" do
      company = company_fixture()

      assert {:ok, sc} =
               Corporate.create_share_class(%{
                 company_id: company.id,
                 name: "Common Stock",
                 class_code: "COM",
                 shares_authorized: "1000000",
                 shares_issued: "500000",
                 shares_outstanding: "450000",
                 par_value: "0.001"
               })

      assert sc.name == "Common Stock"
      assert sc.class_code == "COM"
      assert Decimal.equal?(sc.shares_authorized, Decimal.new("1000000"))
    end

    test "create_share_class/1 fails without required fields" do
      assert {:error, changeset} = Corporate.create_share_class(%{})
      errors = errors_on(changeset)
      assert errors[:company_id]
      assert errors[:name]
      assert errors[:class_code]
    end

    test "create_share_class/1 validates dividend_preference" do
      company = company_fixture()

      assert {:error, changeset} =
               Corporate.create_share_class(%{
                 company_id: company.id,
                 name: "Test",
                 class_code: "T1",
                 dividend_preference: "invalid"
               })

      assert errors_on(changeset)[:dividend_preference]
    end

    test "create_share_class/1 validates status" do
      company = company_fixture()

      assert {:error, changeset} =
               Corporate.create_share_class(%{
                 company_id: company.id,
                 name: "Test",
                 class_code: "T2",
                 status: "invalid"
               })

      assert errors_on(changeset)[:status]
    end

    test "create_share_class/1 validates unique company_id + class_code" do
      company = company_fixture()
      share_class_fixture(%{company: company, class_code: "DUP"})

      assert {:error, changeset} =
               Corporate.create_share_class(%{
                 company_id: company.id,
                 name: "Duplicate",
                 class_code: "DUP"
               })

      assert errors_on(changeset)[:company_id]
    end

    test "create_share_class/1 with all dividend preferences" do
      company = company_fixture()

      for {dp, i} <- Enum.with_index(~w(none cumulative non_cumulative participating)) do
        assert {:ok, sc} =
                 Corporate.create_share_class(%{
                   company_id: company.id,
                   name: "DP #{i}",
                   class_code: "DP#{i}",
                   dividend_preference: dp
                 })

        assert sc.dividend_preference == dp
      end
    end

    test "create_share_class/1 with convertible and redeemable flags" do
      company = company_fixture()

      assert {:ok, sc} =
               Corporate.create_share_class(%{
                 company_id: company.id,
                 name: "Preferred",
                 class_code: "PREF",
                 is_convertible: true,
                 is_redeemable: true,
                 conversion_ratio: "2.5"
               })

      assert sc.is_convertible == true
      assert sc.is_redeemable == true
      assert Decimal.equal?(sc.conversion_ratio, Decimal.new("2.5"))
    end

    test "update_share_class/2 updates attributes" do
      sc = share_class_fixture()

      assert {:ok, updated} =
               Corporate.update_share_class(sc, %{name: "Updated Class", status: "retired"})

      assert updated.name == "Updated Class"
      assert updated.status == "retired"
    end

    test "delete_share_class/1 deletes the share class" do
      sc = share_class_fixture()
      assert {:ok, _} = Corporate.delete_share_class(sc)
      assert_raise Ecto.NoResultsError, fn -> Corporate.get_share_class!(sc.id) end
    end
  end

  describe "cap_table/1" do
    test "returns share classes with ownership percentages" do
      company = company_fixture()
      share_class_fixture(%{company: company, class_code: "A", shares_outstanding: "6000"})
      share_class_fixture(%{company: company, class_code: "B", shares_outstanding: "4000"})

      cap_table = Corporate.cap_table(company.id)
      assert length(cap_table) == 2

      a_entry = Enum.find(cap_table, &(&1.share_class.class_code == "A"))
      b_entry = Enum.find(cap_table, &(&1.share_class.class_code == "B"))

      assert Decimal.equal?(a_entry.ownership_pct, Decimal.new("60.00"))
      assert Decimal.equal?(b_entry.ownership_pct, Decimal.new("40.00"))
    end

    test "returns empty list for company with no share classes" do
      company = company_fixture()
      assert Corporate.cap_table(company.id) == []
    end

    test "handles zero outstanding shares" do
      company = company_fixture()
      share_class_fixture(%{company: company, class_code: "Z", shares_outstanding: "0"})

      cap_table = Corporate.cap_table(company.id)
      assert length(cap_table) == 1
      assert Decimal.equal?(hd(cap_table).ownership_pct, Decimal.new(0))
    end
  end
end
