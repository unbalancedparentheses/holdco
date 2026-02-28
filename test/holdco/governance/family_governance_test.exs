defmodule Holdco.Governance.FamilyGovernanceTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Governance

  describe "family_charters CRUD" do
    test "list_family_charters/0 returns all charters" do
      charter = family_charter_fixture()
      assert Enum.any?(Governance.list_family_charters(), &(&1.id == charter.id))
    end

    test "get_family_charter!/1 returns charter with preloads" do
      charter = family_charter_fixture()
      fetched = Governance.get_family_charter!(charter.id)
      assert fetched.id == charter.id
      assert is_list(fetched.family_members)
    end

    test "get_family_charter!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Governance.get_family_charter!(0)
      end
    end

    test "create_family_charter/1 with valid data" do
      assert {:ok, charter} =
               Governance.create_family_charter(%{
                 family_name: "Smith Family",
                 version: "2.0",
                 status: "active",
                 mission_statement: "To preserve our legacy",
                 values: ["integrity", "education", "philanthropy"],
                 meeting_schedule: "Monthly"
               })

      assert charter.family_name == "Smith Family"
      assert charter.version == "2.0"
      assert charter.status == "active"
      assert charter.values == ["integrity", "education", "philanthropy"]
    end

    test "create_family_charter/1 with all statuses" do
      for status <- ~w(draft active under_review archived) do
        assert {:ok, charter} =
                 Governance.create_family_charter(%{
                   family_name: "Family #{status}",
                   version: "1.0",
                   status: status
                 })

        assert charter.status == status
      end
    end

    test "create_family_charter/1 fails without required fields" do
      assert {:error, changeset} = Governance.create_family_charter(%{})
      errors = errors_on(changeset)
      assert errors[:family_name]
      assert errors[:version]
    end

    test "create_family_charter/1 fails with invalid status" do
      assert {:error, changeset} =
               Governance.create_family_charter(%{
                 family_name: "Test",
                 version: "1.0",
                 status: "invalid"
               })

      assert errors_on(changeset)[:status]
    end

    test "update_family_charter/2 with valid data" do
      charter = family_charter_fixture()

      assert {:ok, updated} =
               Governance.update_family_charter(charter, %{
                 family_name: "Updated Family",
                 status: "active"
               })

      assert updated.family_name == "Updated Family"
      assert updated.status == "active"
    end
  end

  describe "family_members CRUD" do
    test "list_family_members/1 returns members for charter" do
      charter = family_charter_fixture()
      member = family_member_fixture(%{family_charter: charter})

      results = Governance.list_family_members(charter.id)
      assert Enum.any?(results, &(&1.id == member.id))
    end

    test "get_family_member!/1 returns member with preloads" do
      member = family_member_fixture()
      fetched = Governance.get_family_member!(member.id)
      assert fetched.id == member.id
      assert fetched.family_charter != nil
    end

    test "create_family_member/1 with valid data" do
      charter = family_charter_fixture()

      assert {:ok, member} =
               Governance.create_family_member(%{
                 family_charter_id: charter.id,
                 full_name: "Alice Smith",
                 relationship: "Daughter",
                 generation: 2,
                 role_in_family_office: "director",
                 voting_rights: true,
                 board_eligible: true,
                 employment_status: "employed"
               })

      assert member.full_name == "Alice Smith"
      assert member.voting_rights == true
      assert member.board_eligible == true
      assert member.generation == 2
    end

    test "create_family_member/1 fails without required fields" do
      assert {:error, changeset} = Governance.create_family_member(%{})
      errors = errors_on(changeset)
      assert errors[:family_charter_id]
      assert errors[:full_name]
      assert errors[:relationship]
    end

    test "update_family_member/2 with valid data" do
      member = family_member_fixture()

      assert {:ok, updated} =
               Governance.update_family_member(member, %{
                 voting_rights: true,
                 role_in_family_office: "trustee"
               })

      assert updated.voting_rights == true
      assert updated.role_in_family_office == "trustee"
    end

    test "delete_family_member/1 removes the member" do
      member = family_member_fixture()
      assert {:ok, _} = Governance.delete_family_member(member)

      assert_raise Ecto.NoResultsError, fn ->
        Governance.get_family_member!(member.id)
      end
    end
  end

  describe "voting_members/1" do
    test "returns only members with voting rights" do
      charter = family_charter_fixture()
      voter = family_member_fixture(%{family_charter: charter, voting_rights: true})
      _non_voter = family_member_fixture(%{family_charter: charter, voting_rights: false})

      results = Governance.voting_members(charter.id)
      assert length(results) == 1
      assert Enum.any?(results, &(&1.id == voter.id))
    end
  end

  describe "members_by_generation/1" do
    test "groups members by generation" do
      charter = family_charter_fixture()
      family_member_fixture(%{family_charter: charter, generation: 1, full_name: "Patriarch"})
      family_member_fixture(%{family_charter: charter, generation: 2, full_name: "Child A"})
      family_member_fixture(%{family_charter: charter, generation: 2, full_name: "Child B"})
      family_member_fixture(%{family_charter: charter, generation: 3, full_name: "Grandchild"})

      result = Governance.members_by_generation(charter.id)
      assert map_size(result) == 3
      assert length(result[1]) == 1
      assert length(result[2]) == 2
      assert length(result[3]) == 1
    end
  end
end
