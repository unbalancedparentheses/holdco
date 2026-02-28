defmodule Holdco.IpAssetTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Corporate

  describe "ip_assets CRUD" do
    test "create_ip_asset/1 with valid data" do
      company = company_fixture()

      assert {:ok, ip} =
               Corporate.create_ip_asset(%{
                 company_id: company.id,
                 name: "Widget Patent",
                 asset_type: "patent",
                 status: "active",
                 jurisdiction: "US"
               })

      assert ip.name == "Widget Patent"
      assert ip.asset_type == "patent"
      assert ip.status == "active"
    end

    test "create_ip_asset/1 with invalid data" do
      assert {:error, changeset} = Corporate.create_ip_asset(%{})
      assert errors_on(changeset)[:company_id]
      assert errors_on(changeset)[:name]
    end

    test "create_ip_asset/1 validates asset_type enum" do
      company = company_fixture()

      assert {:error, changeset} =
               Corporate.create_ip_asset(%{
                 company_id: company.id,
                 name: "Test",
                 asset_type: "invalid"
               })

      assert errors_on(changeset)[:asset_type]
    end

    test "create_ip_asset/1 validates status enum" do
      company = company_fixture()

      assert {:error, changeset} =
               Corporate.create_ip_asset(%{
                 company_id: company.id,
                 name: "Test",
                 asset_type: "patent",
                 status: "invalid"
               })

      assert errors_on(changeset)[:status]
    end

    test "list_ip_assets/0 returns all assets" do
      ip = ip_asset_fixture()
      assert Enum.any?(Corporate.list_ip_assets(), &(&1.id == ip.id))
    end

    test "list_ip_assets/1 filters by company" do
      company = company_fixture()
      ip = ip_asset_fixture(%{company: company})
      _other = ip_asset_fixture()

      results = Corporate.list_ip_assets(company.id)
      assert Enum.any?(results, &(&1.id == ip.id))
      assert length(results) == 1
    end

    test "get_ip_asset!/1 returns the asset with preloads" do
      ip = ip_asset_fixture()
      fetched = Corporate.get_ip_asset!(ip.id)
      assert fetched.id == ip.id
      assert fetched.company != nil
    end

    test "update_ip_asset/2 updates the asset" do
      ip = ip_asset_fixture()

      assert {:ok, updated} =
               Corporate.update_ip_asset(ip, %{
                 name: "Updated Patent",
                 status: "expired",
                 valuation: 200_000
               })

      assert updated.name == "Updated Patent"
      assert updated.status == "expired"
    end

    test "delete_ip_asset/1 deletes the asset" do
      ip = ip_asset_fixture()
      assert {:ok, _} = Corporate.delete_ip_asset(ip)
      assert_raise Ecto.NoResultsError, fn -> Corporate.get_ip_asset!(ip.id) end
    end

    test "create with all asset types" do
      company = company_fixture()

      for type <- ~w(patent trademark copyright trade_secret domain software_license) do
        assert {:ok, ip} =
                 Corporate.create_ip_asset(%{
                   company_id: company.id,
                   name: "#{type} asset",
                   asset_type: type
                 })

        assert ip.asset_type == type
      end
    end

    test "create with licensees array" do
      company = company_fixture()

      assert {:ok, ip} =
               Corporate.create_ip_asset(%{
                 company_id: company.id,
                 name: "Licensed Patent",
                 asset_type: "patent",
                 licensees: ["Company A", "Company B"]
               })

      assert ip.licensees == ["Company A", "Company B"]
    end

    test "create with all optional fields" do
      company = company_fixture()

      assert {:ok, ip} =
               Corporate.create_ip_asset(%{
                 company_id: company.id,
                 name: "Full Patent",
                 asset_type: "patent",
                 registration_number: "US-12345",
                 jurisdiction: "US",
                 filing_date: "2020-01-01",
                 grant_date: "2021-06-15",
                 expiry_date: "2040-01-01",
                 status: "active",
                 owner_entity: "HoldCo Inc",
                 licensees: ["Sub A"],
                 annual_cost: 10_000,
                 currency: "EUR",
                 valuation: 500_000,
                 notes: "Core patent"
               })

      assert ip.registration_number == "US-12345"
      assert ip.owner_entity == "HoldCo Inc"
      assert ip.currency == "EUR"
    end
  end

  describe "expiring_ip_assets/1" do
    test "returns assets expiring within N days" do
      company = company_fixture()
      soon = Date.add(Date.utc_today(), 30)
      far = Date.add(Date.utc_today(), 180)

      {:ok, expiring_soon} =
        Corporate.create_ip_asset(%{
          company_id: company.id,
          name: "Expiring Soon",
          asset_type: "domain",
          status: "active",
          expiry_date: soon
        })

      {:ok, _far_away} =
        Corporate.create_ip_asset(%{
          company_id: company.id,
          name: "Far Away",
          asset_type: "domain",
          status: "active",
          expiry_date: far
        })

      results = Corporate.expiring_ip_assets(90)
      assert Enum.any?(results, &(&1.id == expiring_soon.id))
      refute Enum.any?(results, &(&1.name == "Far Away"))
    end

    test "excludes already expired assets" do
      company = company_fixture()
      past = Date.add(Date.utc_today(), -10)

      {:ok, _expired} =
        Corporate.create_ip_asset(%{
          company_id: company.id,
          name: "Already Expired",
          asset_type: "patent",
          status: "active",
          expiry_date: past
        })

      results = Corporate.expiring_ip_assets(90)
      refute Enum.any?(results, &(&1.name == "Already Expired"))
    end

    test "excludes abandoned and transferred assets" do
      company = company_fixture()
      soon = Date.add(Date.utc_today(), 30)

      {:ok, _abandoned} =
        Corporate.create_ip_asset(%{
          company_id: company.id,
          name: "Abandoned",
          asset_type: "patent",
          status: "abandoned",
          expiry_date: soon
        })

      results = Corporate.expiring_ip_assets(90)
      refute Enum.any?(results, &(&1.name == "Abandoned"))
    end
  end

  describe "ip_portfolio_summary/0" do
    test "returns summary by type, status, costs, and valuations" do
      company = company_fixture()

      Corporate.create_ip_asset(%{
        company_id: company.id,
        name: "Patent A",
        asset_type: "patent",
        status: "active",
        valuation: 100_000,
        annual_cost: 5_000
      })

      Corporate.create_ip_asset(%{
        company_id: company.id,
        name: "Domain A",
        asset_type: "domain",
        status: "active",
        valuation: 50_000,
        annual_cost: 1_000
      })

      summary = Corporate.ip_portfolio_summary()
      assert is_list(summary.by_type)
      assert is_list(summary.by_status)
      assert Enum.any?(summary.by_type, &(&1.asset_type == "patent"))
      assert Enum.any?(summary.by_type, &(&1.asset_type == "domain"))
    end

    test "ip_portfolio_summary/1 filters by company" do
      company1 = company_fixture()
      company2 = company_fixture()

      Corporate.create_ip_asset(%{
        company_id: company1.id,
        name: "C1 Patent",
        asset_type: "patent",
        valuation: 100_000,
        annual_cost: 5_000
      })

      Corporate.create_ip_asset(%{
        company_id: company2.id,
        name: "C2 Patent",
        asset_type: "patent",
        valuation: 200_000,
        annual_cost: 10_000
      })

      summary = Corporate.ip_portfolio_summary(company1.id)
      assert is_list(summary.by_type)
      # Should only include company1's assets
      patent_type = Enum.find(summary.by_type, &(&1.asset_type == "patent"))
      assert patent_type.count == 1
    end
  end
end
