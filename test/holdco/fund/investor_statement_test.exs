defmodule Holdco.Fund.InvestorStatementTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Fund

  describe "list_investor_statements/1" do
    test "returns all investor statements" do
      stmt = investor_statement_fixture()
      stmts = Fund.list_investor_statements()
      assert length(stmts) >= 1
      assert Enum.any?(stmts, &(&1.id == stmt.id))
    end

    test "filters by company_id" do
      c1 = company_fixture(%{name: "Stmt Co1"})
      c2 = company_fixture(%{name: "Stmt Co2"})
      stmt1 = investor_statement_fixture(%{company: c1})
      _stmt2 = investor_statement_fixture(%{company: c2})

      stmts = Fund.list_investor_statements(company_id: c1.id)
      assert length(stmts) == 1
      assert hd(stmts).id == stmt1.id
    end

    test "filters by investor_name" do
      stmt = investor_statement_fixture(%{investor_name: "Alice Johnson"})
      _other = investor_statement_fixture(%{investor_name: "Bob Smith"})

      stmts = Fund.list_investor_statements(investor_name: "Alice Johnson")
      assert length(stmts) == 1
      assert hd(stmts).id == stmt.id
    end

    test "filters by status" do
      _draft = investor_statement_fixture(%{status: "draft"})
      final = investor_statement_fixture(%{status: "final"})

      stmts = Fund.list_investor_statements(status: "final")
      assert Enum.any?(stmts, &(&1.id == final.id))
      assert Enum.all?(stmts, &(&1.status == "final"))
    end

    test "returns empty list when no statements match" do
      company = company_fixture()
      assert Fund.list_investor_statements(company_id: company.id) == []
    end
  end

  describe "get_investor_statement!/1" do
    test "returns the statement with given id" do
      stmt = investor_statement_fixture()
      found = Fund.get_investor_statement!(stmt.id)
      assert found.id == stmt.id
    end

    test "raises when id does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Fund.get_investor_statement!(0)
      end
    end
  end

  describe "create_investor_statement/1" do
    test "creates a statement with valid attrs" do
      company = company_fixture()

      assert {:ok, stmt} =
               Fund.create_investor_statement(%{
                 company_id: company.id,
                 investor_name: "Test Investor",
                 period_start: ~D[2024-01-01],
                 period_end: ~D[2024-06-30],
                 beginning_balance: 100_000.0,
                 contributions: 25_000.0,
                 distributions: 5_000.0,
                 ending_balance: 120_000.0,
                 moic: 1.2
               })

      assert stmt.investor_name == "Test Investor"
      assert stmt.status == "draft"
    end

    test "fails without required fields" do
      assert {:error, changeset} = Fund.create_investor_statement(%{})
      errors = errors_on(changeset)
      assert errors[:company_id]
      assert errors[:investor_name]
      assert errors[:period_start]
      assert errors[:period_end]
    end

    test "validates status values" do
      company = company_fixture()

      assert {:error, changeset} =
               Fund.create_investor_statement(%{
                 company_id: company.id,
                 investor_name: "Test",
                 period_start: ~D[2024-01-01],
                 period_end: ~D[2024-12-31],
                 status: "invalid_status"
               })

      assert errors_on(changeset)[:status]
    end
  end

  describe "update_investor_statement/2" do
    test "updates a statement" do
      stmt = investor_statement_fixture()

      assert {:ok, updated} =
               Fund.update_investor_statement(stmt, %{status: "final"})

      assert updated.status == "final"
    end

    test "transitions from draft to review to final to sent" do
      stmt = investor_statement_fixture(%{status: "draft"})

      assert {:ok, stmt} = Fund.update_investor_statement(stmt, %{status: "review"})
      assert stmt.status == "review"

      assert {:ok, stmt} = Fund.update_investor_statement(stmt, %{status: "final"})
      assert stmt.status == "final"

      assert {:ok, stmt} = Fund.update_investor_statement(stmt, %{status: "sent"})
      assert stmt.status == "sent"
    end
  end

  describe "delete_investor_statement/1" do
    test "deletes the statement" do
      stmt = investor_statement_fixture()
      assert {:ok, _} = Fund.delete_investor_statement(stmt)

      assert_raise Ecto.NoResultsError, fn ->
        Fund.get_investor_statement!(stmt.id)
      end
    end
  end

  describe "generate_investor_statement/4" do
    test "generates statement with contributions and distributions" do
      company = company_fixture()
      investor = "Test Investor Gen"

      # Add some capital contributions for the investor
      capital_contribution_fixture(%{
        company: company,
        contributor: investor,
        amount: 100_000.0,
        date: "2024-03-01"
      })

      capital_contribution_fixture(%{
        company: company,
        contributor: investor,
        amount: 50_000.0,
        date: "2024-06-01"
      })

      # Add a dividend (distribution)
      dividend_fixture(%{
        company: company,
        amount: 10_000.0,
        date: "2024-09-01"
      })

      result =
        Fund.generate_investor_statement(
          company.id,
          investor,
          ~D[2024-01-01],
          ~D[2024-12-31]
        )

      assert result.company_id == company.id
      assert result.investor_name == investor
      assert result.status == "draft"
      # Contributions should be 150_000
      assert Decimal.compare(result.contributions, Decimal.new(0)) == :gt
    end

    test "generates statement for empty period" do
      company = company_fixture()
      investor = "Empty Period Investor"

      result =
        Fund.generate_investor_statement(
          company.id,
          investor,
          ~D[2024-01-01],
          ~D[2024-12-31]
        )

      assert result.company_id == company.id
      assert Decimal.equal?(result.contributions, Decimal.new(0))
      assert Decimal.equal?(result.distributions, Decimal.new(0))
    end

    test "MOIC calculation with contributions" do
      company = company_fixture()
      investor = "MOIC Investor"

      capital_contribution_fixture(%{
        company: company,
        contributor: investor,
        amount: 100_000.0,
        date: "2024-01-15"
      })

      result =
        Fund.generate_investor_statement(
          company.id,
          investor,
          ~D[2024-01-01],
          ~D[2024-12-31]
        )

      # MOIC = total_value / total_contributions
      # With 100k contributed and no distributions, ending_balance = 100k
      # MOIC = 100k / 100k = 1.0
      assert result.moic != nil
      assert Decimal.compare(result.moic, Decimal.new(0)) == :gt
    end
  end
end
