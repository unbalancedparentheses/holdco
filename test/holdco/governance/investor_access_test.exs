defmodule Holdco.Governance.InvestorAccessTest do
  use Holdco.DataCase, async: true

  alias Holdco.Governance.InvestorAccess

  describe "changeset/2" do
    test "valid changeset with required fields" do
      changeset =
        InvestorAccess.changeset(%InvestorAccess{}, %{
          user_id: 1,
          company_id: 1
        })

      assert changeset.valid?
    end

    test "invalid changeset without required fields" do
      changeset = InvestorAccess.changeset(%InvestorAccess{}, %{})
      refute changeset.valid?
      assert %{user_id: ["can't be blank"], company_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid changeset with only user_id" do
      changeset = InvestorAccess.changeset(%InvestorAccess{}, %{user_id: 1})
      refute changeset.valid?
      assert %{company_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid changeset with only company_id" do
      changeset = InvestorAccess.changeset(%InvestorAccess{}, %{company_id: 1})
      refute changeset.valid?
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "accepts all optional fields" do
      expires = DateTime.utc_now() |> DateTime.add(30, :day) |> DateTime.truncate(:second)

      changeset =
        InvestorAccess.changeset(%InvestorAccess{}, %{
          user_id: 1,
          company_id: 1,
          can_view_financials: false,
          can_view_holdings: false,
          can_view_documents: true,
          can_view_cap_table: false,
          expires_at: expires,
          notes: "Quarterly review access"
        })

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :can_view_financials) == false
      assert Ecto.Changeset.get_change(changeset, :can_view_holdings) == false
      assert Ecto.Changeset.get_change(changeset, :can_view_documents) == true
      assert Ecto.Changeset.get_change(changeset, :can_view_cap_table) == false
      assert Ecto.Changeset.get_change(changeset, :expires_at) == expires
      assert Ecto.Changeset.get_change(changeset, :notes) == "Quarterly review access"
    end

    test "ignores unknown fields" do
      changeset =
        InvestorAccess.changeset(%InvestorAccess{}, %{
          user_id: 1,
          company_id: 1,
          unknown_field: "something"
        })

      assert changeset.valid?
    end

    test "casts boolean fields correctly" do
      changeset =
        InvestorAccess.changeset(%InvestorAccess{}, %{
          user_id: 1,
          company_id: 1,
          can_view_financials: true,
          can_view_holdings: true,
          can_view_documents: true,
          can_view_cap_table: true
        })

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :can_view_documents) == true
    end

    test "casts expires_at as utc_datetime" do
      expires = ~U[2025-12-31 23:59:59Z]

      changeset =
        InvestorAccess.changeset(%InvestorAccess{}, %{
          user_id: 1,
          company_id: 1,
          expires_at: expires
        })

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :expires_at) == expires
    end

    test "changeset on existing struct for update" do
      existing = %InvestorAccess{
        id: 1,
        user_id: 1,
        company_id: 1,
        can_view_financials: true,
        can_view_documents: false
      }

      changeset = InvestorAccess.changeset(existing, %{can_view_documents: true, notes: "Updated"})
      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :can_view_documents) == true
      assert Ecto.Changeset.get_change(changeset, :notes) == "Updated"
    end
  end
end
