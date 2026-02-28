defmodule Holdco.Governance.InvestorPortalTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures
  import Holdco.AccountsFixtures

  alias Holdco.Governance

  describe "list_investor_accesses_for_user/1" do
    test "returns accesses for the given user" do
      user = user_fixture()
      company = company_fixture()

      {:ok, ia} =
        Governance.create_investor_access(%{
          user_id: user.id,
          company_id: company.id,
          can_view_financials: true
        })

      accesses = Governance.list_investor_accesses_for_user(user.id)
      assert length(accesses) == 1
      assert hd(accesses).id == ia.id
    end

    test "returns empty list for user with no accesses" do
      user = user_fixture()
      assert Governance.list_investor_accesses_for_user(user.id) == []
    end

    test "excludes expired accesses" do
      user = user_fixture()
      company = company_fixture()

      past = DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)

      {:ok, _ia} =
        Governance.create_investor_access(%{
          user_id: user.id,
          company_id: company.id,
          expires_at: past
        })

      assert Governance.list_investor_accesses_for_user(user.id) == []
    end

    test "includes accesses with nil expires_at" do
      user = user_fixture()
      company = company_fixture()

      {:ok, ia} =
        Governance.create_investor_access(%{
          user_id: user.id,
          company_id: company.id,
          expires_at: nil
        })

      accesses = Governance.list_investor_accesses_for_user(user.id)
      assert length(accesses) == 1
      assert hd(accesses).id == ia.id
    end

    test "includes accesses with future expires_at" do
      user = user_fixture()
      company = company_fixture()

      future = DateTime.utc_now() |> DateTime.add(86400, :second) |> DateTime.truncate(:second)

      {:ok, ia} =
        Governance.create_investor_access(%{
          user_id: user.id,
          company_id: company.id,
          expires_at: future
        })

      accesses = Governance.list_investor_accesses_for_user(user.id)
      assert length(accesses) == 1
      assert hd(accesses).id == ia.id
    end

    test "preloads company and user" do
      user = user_fixture()
      company = company_fixture()

      {:ok, _ia} =
        Governance.create_investor_access(%{
          user_id: user.id,
          company_id: company.id
        })

      [access] = Governance.list_investor_accesses_for_user(user.id)
      assert access.company.id == company.id
      assert access.user.id == user.id
    end

    test "returns multiple accesses for user with access to multiple companies" do
      user = user_fixture()
      company1 = company_fixture()
      company2 = company_fixture()

      {:ok, _} = Governance.create_investor_access(%{user_id: user.id, company_id: company1.id})
      {:ok, _} = Governance.create_investor_access(%{user_id: user.id, company_id: company2.id})

      accesses = Governance.list_investor_accesses_for_user(user.id)
      assert length(accesses) == 2

      company_ids = Enum.map(accesses, & &1.company_id) |> Enum.sort()
      assert company_ids == Enum.sort([company1.id, company2.id])
    end

    test "does not return accesses for other users" do
      user1 = user_fixture()
      user2 = user_fixture()
      company = company_fixture()

      {:ok, _} = Governance.create_investor_access(%{user_id: user1.id, company_id: company.id})

      assert Governance.list_investor_accesses_for_user(user2.id) == []
    end
  end

  describe "get_investor_access_for_user_and_company/2" do
    test "returns the access for given user and company" do
      user = user_fixture()
      company = company_fixture()

      {:ok, ia} =
        Governance.create_investor_access(%{
          user_id: user.id,
          company_id: company.id,
          can_view_financials: true,
          can_view_holdings: false
        })

      access = Governance.get_investor_access_for_user_and_company(user.id, company.id)
      assert access.id == ia.id
      assert access.can_view_financials == true
      assert access.can_view_holdings == false
    end

    test "returns nil when no access exists" do
      user = user_fixture()
      company = company_fixture()

      assert is_nil(Governance.get_investor_access_for_user_and_company(user.id, company.id))
    end

    test "returns nil for expired access" do
      user = user_fixture()
      company = company_fixture()

      past = DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)

      {:ok, _} =
        Governance.create_investor_access(%{
          user_id: user.id,
          company_id: company.id,
          expires_at: past
        })

      assert is_nil(Governance.get_investor_access_for_user_and_company(user.id, company.id))
    end

    test "returns access with future expires_at" do
      user = user_fixture()
      company = company_fixture()

      future = DateTime.utc_now() |> DateTime.add(86400, :second) |> DateTime.truncate(:second)

      {:ok, ia} =
        Governance.create_investor_access(%{
          user_id: user.id,
          company_id: company.id,
          expires_at: future
        })

      access = Governance.get_investor_access_for_user_and_company(user.id, company.id)
      assert access.id == ia.id
    end

    test "preloads company and user" do
      user = user_fixture()
      company = company_fixture()

      {:ok, _} =
        Governance.create_investor_access(%{
          user_id: user.id,
          company_id: company.id
        })

      access = Governance.get_investor_access_for_user_and_company(user.id, company.id)
      assert access.company.id == company.id
      assert access.user.id == user.id
    end

    test "returns nil for wrong company" do
      user = user_fixture()
      company1 = company_fixture()
      company2 = company_fixture()

      {:ok, _} = Governance.create_investor_access(%{user_id: user.id, company_id: company1.id})

      assert is_nil(Governance.get_investor_access_for_user_and_company(user.id, company2.id))
    end

    test "returns nil for wrong user" do
      user1 = user_fixture()
      user2 = user_fixture()
      company = company_fixture()

      {:ok, _} = Governance.create_investor_access(%{user_id: user1.id, company_id: company.id})

      assert is_nil(Governance.get_investor_access_for_user_and_company(user2.id, company.id))
    end
  end
end
