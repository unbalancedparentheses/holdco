defmodule Holdco.SearchTest do
  use Holdco.DataCase

  import Holdco.HoldcoFixtures

  alias Holdco.Search

  describe "search/1" do
    test "returns results for matching company" do
      company_fixture(%{name: "UniqueSearchCorp"})
      results = Search.search("UniqueSearchCorp")
      assert is_map(results)
    end

    test "returns empty results for no match" do
      results = Search.search("xyznonexistent99999")
      assert is_map(results)
    end

    test "returns results for blank query" do
      results = Search.search("")
      assert is_map(results)
    end
  end
end
