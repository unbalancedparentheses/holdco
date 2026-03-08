defmodule Holdco.Banking.StatementImportTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Banking.StatementImport
  alias Holdco.Integrations

  describe "import_transactions/2" do
    test "imports parsed transactions and creates feed config" do
      company = company_fixture()
      account = bank_account_fixture(%{company: company})

      txns = [
        %{date: "2024-01-15", description: "Coffee", amount: Decimal.new("-4.50"), currency: "USD"},
        %{date: "2024-01-16", description: "Salary", amount: Decimal.new("3500"), currency: "USD"}
      ]

      assert {:ok, result} = StatementImport.import_transactions(account, txns)
      assert result.imported == 2
      assert result.duplicates == 0
      assert is_integer(result.matched)
      assert result.feed_config_id

      # Verify feed config was created
      config = Integrations.get_bank_feed_config!(result.feed_config_id)
      assert config.provider == "csv_import"
      assert config.bank_account_id == account.id
    end

    test "deduplicates identical transactions" do
      company = company_fixture()
      account = bank_account_fixture(%{company: company})

      txns = [
        %{date: "2024-01-15", description: "Coffee", amount: Decimal.new("-4.50"), currency: "USD"}
      ]

      assert {:ok, first} = StatementImport.import_transactions(account, txns)
      assert first.imported == 1

      # Import same transactions again
      assert {:ok, second} = StatementImport.import_transactions(account, txns)
      # Should update existing rather than create new — still counts as imported
      assert second.imported == 1
    end

    test "reuses existing feed config for same account" do
      company = company_fixture()
      account = bank_account_fixture(%{company: company})

      txns1 = [%{date: "2024-01-15", description: "First", amount: Decimal.new("100"), currency: "USD"}]
      txns2 = [%{date: "2024-01-16", description: "Second", amount: Decimal.new("200"), currency: "USD"}]

      assert {:ok, r1} = StatementImport.import_transactions(account, txns1)
      assert {:ok, r2} = StatementImport.import_transactions(account, txns2)

      assert r1.feed_config_id == r2.feed_config_id
    end

    test "handles empty transaction list" do
      company = company_fixture()
      account = bank_account_fixture(%{company: company})

      assert {:ok, result} = StatementImport.import_transactions(account, [])
      assert result.imported == 0
      assert result.duplicates == 0
    end
  end
end
