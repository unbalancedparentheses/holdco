defmodule Holdco.SearchTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Search

  describe "search/1" do
    test "finds a company by name" do
      company = company_fixture(%{name: "UniqueSearchCorp"})
      results = Search.search("UniqueSearchCorp")

      assert results.total >= 1
      assert Enum.any?(results.companies, fn c -> c.id == company.id end)

      match = Enum.find(results.companies, fn c -> c.id == company.id end)
      assert match.name == "UniqueSearchCorp"
      assert match.type == :company
    end

    test "finds a company by country" do
      company = company_fixture(%{name: "SwissHolding", country: "CH"})
      results = Search.search("CH")

      assert Enum.any?(results.companies, fn c -> c.id == company.id end)
      match = Enum.find(results.companies, fn c -> c.id == company.id end)
      assert match.detail == "CH"
    end

    test "finds a holding by asset name" do
      company = company_fixture()
      holding = holding_fixture(%{company: company, asset: "ZetaCoin", ticker: "ZTC"})
      results = Search.search("ZetaCoin")

      assert results.total >= 1
      assert Enum.any?(results.holdings, fn h -> h.id == holding.id end)

      match = Enum.find(results.holdings, fn h -> h.id == holding.id end)
      assert match.name == "ZetaCoin"
      assert match.type == :holding
      assert match.detail == "ZTC"
    end

    test "finds a holding by ticker" do
      company = company_fixture()
      holding = holding_fixture(%{company: company, asset: "Zeta Protocol", ticker: "ZTCXQ"})
      results = Search.search("ZTCXQ")

      assert Enum.any?(results.holdings, fn h -> h.id == holding.id end)
    end

    test "finds a transaction by description" do
      company = company_fixture()

      txn =
        transaction_fixture(%{
          company: company,
          description: "WireToAcmeLabs",
          counterparty: "Acme Labs Inc"
        })

      results = Search.search("WireToAcmeLabs")

      assert results.total >= 1
      assert Enum.any?(results.transactions, fn t -> t.id == txn.id end)

      match = Enum.find(results.transactions, fn t -> t.id == txn.id end)
      assert match.name == "WireToAcmeLabs"
      assert match.type == :transaction
    end

    test "finds a transaction by counterparty" do
      company = company_fixture()

      txn =
        transaction_fixture(%{
          company: company,
          description: "Payment",
          counterparty: "XylophoneVentures"
        })

      results = Search.search("XylophoneVentures")
      assert Enum.any?(results.transactions, fn t -> t.id == txn.id end)
    end

    test "finds a document by name" do
      company = company_fixture()
      doc = document_fixture(%{company: company, name: "BoardMinutesQ3", doc_type: "minutes"})
      results = Search.search("BoardMinutesQ3")

      assert results.total >= 1
      assert Enum.any?(results.documents, fn d -> d.id == doc.id end)

      match = Enum.find(results.documents, fn d -> d.id == doc.id end)
      assert match.name == "BoardMinutesQ3"
      assert match.type == :document
      assert match.detail == "minutes"
    end

    test "finds a document by doc_type" do
      company = company_fixture()
      doc = document_fixture(%{company: company, name: "SomeDoc", doc_type: "xyzUniqueType"})
      results = Search.search("xyzUniqueType")

      assert Enum.any?(results.documents, fn d -> d.id == doc.id end)
    end

    test "returns results across multiple tables" do
      company = company_fixture(%{name: "OmniSearch"})
      holding_fixture(%{company: company, asset: "OmniSearch Token", ticker: "OST"})

      results = Search.search("OmniSearch")

      assert results.total >= 2
      assert length(results.companies) >= 1
      assert length(results.holdings) >= 1
    end

    test "returns empty lists when nothing matches" do
      results = Search.search("xyznonexistent99999")

      assert results.companies == []
      assert results.holdings == []
      assert results.transactions == []
      assert results.documents == []
      assert results.total == 0
    end

    test "blank query returns empty results" do
      results = Search.search("")

      assert results.companies == []
      assert results.holdings == []
      assert results.transactions == []
      assert results.documents == []
      assert results.total == 0
    end

    test "nil query returns empty results" do
      results = Search.search(nil)

      assert results.companies == []
      assert results.holdings == []
      assert results.transactions == []
      assert results.documents == []
      assert results.total == 0
    end
  end
end
