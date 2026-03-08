defmodule Holdco.CorporateTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Corporate

  describe "companies" do
    test "list_companies/0 returns all companies" do
      company = company_fixture()
      assert Enum.any?(Corporate.list_companies(), &(&1.id == company.id))
    end

    test "list_companies/1 filters by country" do
      company_fixture(%{country: "US"})
      company_fixture(%{country: "UK"})
      results = Corporate.list_companies(%{country: "UK"})
      assert Enum.all?(results, &(&1.country == "UK"))
    end

    test "get_company!/1 returns the company with preloads" do
      company = company_fixture()
      fetched = Corporate.get_company!(company.id)
      assert fetched.id == company.id
      assert fetched.beneficial_owners == []
    end

    test "create_company/1 with valid data" do
      assert {:ok, company} = Corporate.create_company(%{name: "New Corp", country: "DE"})
      assert company.name == "New Corp"
      assert company.country == "DE"
    end

    test "create_company/1 with invalid data" do
      assert {:error, changeset} = Corporate.create_company(%{})
      assert errors_on(changeset)[:name]
    end

    test "update_company/2" do
      company = company_fixture()
      assert {:ok, updated} = Corporate.update_company(company, %{name: "Updated Corp"})
      assert updated.name == "Updated Corp"
    end

    test "delete_company/1" do
      company = company_fixture()
      assert {:ok, _} = Corporate.delete_company(company)
      assert_raise Ecto.NoResultsError, fn -> Corporate.get_company!(company.id) end
    end

    test "list_subsidiaries/1" do
      parent = company_fixture()
      child = company_fixture(%{parent_id: parent.id})
      subs = Corporate.list_subsidiaries(parent.id)
      assert Enum.any?(subs, &(&1.id == child.id))
    end

    test "company_tree/0 builds tree" do
      parent = company_fixture()
      _child = company_fixture(%{parent_id: parent.id})
      tree = Corporate.company_tree()
      assert is_list(tree)
      root = Enum.find(tree, &(&1.company.id == parent.id))
      assert length(root.children) == 1
    end

    test "change_company/2 returns changeset" do
      company = company_fixture()
      cs = Corporate.change_company(company, %{name: "foo"})
      assert %Ecto.Changeset{} = cs
    end

    test "get_company_with_preloads!/1 loads all associations" do
      company = company_fixture()
      loaded = Corporate.get_company_with_preloads!(company.id)
      assert loaded.id == company.id
      assert is_list(loaded.bank_accounts)
      assert is_list(loaded.documents)
    end
  end

  describe "beneficial_owners" do
    test "CRUD operations" do
      company = company_fixture()
      {:ok, bo} = Corporate.create_beneficial_owner(%{company_id: company.id, name: "Alice"})
      assert bo.name == "Alice"

      assert Enum.any?(Corporate.list_beneficial_owners(company.id), &(&1.id == bo.id))
      assert Corporate.get_beneficial_owner!(bo.id).id == bo.id

      {:ok, updated} = Corporate.update_beneficial_owner(bo, %{name: "Bob"})
      assert updated.name == "Bob"

      {:ok, _} = Corporate.delete_beneficial_owner(updated)
      assert_raise Ecto.NoResultsError, fn -> Corporate.get_beneficial_owner!(bo.id) end
    end
  end

  describe "key_personnel" do
    test "CRUD operations" do
      company = company_fixture()
      {:ok, kp} = Corporate.create_key_personnel(%{company_id: company.id, name: "Jane", title: "CEO"})
      assert kp.title == "CEO"

      assert Enum.any?(Corporate.list_key_personnel(company.id), &(&1.id == kp.id))
      assert Corporate.get_key_personnel!(kp.id).id == kp.id

      {:ok, updated} = Corporate.update_key_personnel(kp, %{title: "CFO"})
      assert updated.title == "CFO"

      {:ok, _} = Corporate.delete_key_personnel(updated)
    end
  end
end
