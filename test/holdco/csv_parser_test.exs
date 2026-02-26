defmodule Holdco.CSVParserTest do
  use ExUnit.Case

  # Holdco.CSVParser is defined via NimbleCSV.define in lib/holdco_web/live/import_live.ex
  # It uses comma separator and double-quote escape

  describe "parse_string/2" do
    test "parses basic CSV content" do
      csv = "Name,Country,Type\nAcme Corp,US,LLC\nBeta Inc,UK,Ltd"

      rows = Holdco.CSVParser.parse_string(csv, skip_headers: true)

      assert rows == [
               ["Acme Corp", "US", "LLC"],
               ["Beta Inc", "UK", "Ltd"]
             ]
    end

    test "parses CSV without skipping headers" do
      csv = "Name,Country\nAcme Corp,US"

      rows = Holdco.CSVParser.parse_string(csv, skip_headers: false)

      assert rows == [
               ["Name", "Country"],
               ["Acme Corp", "US"]
             ]
    end

    test "handles quoted fields with commas" do
      csv = "Name,Description\n\"Acme, Corp\",\"A big, important company\""

      rows = Holdco.CSVParser.parse_string(csv, skip_headers: true)

      assert rows == [["Acme, Corp", "A big, important company"]]
    end

    test "handles empty fields" do
      csv = "A,B,C\n1,,3"

      rows = Holdco.CSVParser.parse_string(csv, skip_headers: true)

      assert rows == [["1", "", "3"]]
    end

    test "parses empty CSV with only headers" do
      csv = "Name,Country,Type"

      rows = Holdco.CSVParser.parse_string(csv, skip_headers: true)

      assert rows == []
    end

    test "handles quoted fields with embedded double quotes" do
      csv = "Name,Note\n\"Test\",\"He said \"\"hello\"\"\""

      rows = Holdco.CSVParser.parse_string(csv, skip_headers: true)

      assert rows == [["Test", "He said \"hello\""]]
    end

    test "parses multiple rows" do
      csv = "H1,H2\nA,B\nC,D\nE,F"

      rows = Holdco.CSVParser.parse_string(csv, skip_headers: true)

      assert length(rows) == 3
      assert Enum.at(rows, 0) == ["A", "B"]
      assert Enum.at(rows, 1) == ["C", "D"]
      assert Enum.at(rows, 2) == ["E", "F"]
    end

    test "handles fields with newlines inside quotes" do
      csv = "Name,Bio\n\"Alice\",\"Line1\nLine2\""

      rows = Holdco.CSVParser.parse_string(csv, skip_headers: true)

      assert rows == [["Alice", "Line1\nLine2"]]
    end

    test "handles single column CSV" do
      csv = "Name\nAlice\nBob"

      rows = Holdco.CSVParser.parse_string(csv, skip_headers: true)

      assert rows == [["Alice"], ["Bob"]]
    end

    test "handles trailing newline" do
      csv = "A,B\n1,2\n"

      rows = Holdco.CSVParser.parse_string(csv, skip_headers: true)

      assert rows == [["1", "2"]]
    end

    test "handles whitespace in unquoted fields" do
      csv = "A,B\n hello , world "

      rows = Holdco.CSVParser.parse_string(csv, skip_headers: true)

      assert rows == [[" hello ", " world "]]
    end

    test "handles many columns" do
      csv = "A,B,C,D,E,F\n1,2,3,4,5,6"

      rows = Holdco.CSVParser.parse_string(csv, skip_headers: true)

      assert rows == [["1", "2", "3", "4", "5", "6"]]
    end

    test "handles skip_headers: false with single row" do
      csv = "A,B"

      rows = Holdco.CSVParser.parse_string(csv, skip_headers: false)

      assert rows == [["A", "B"]]
    end
  end

  describe "parse_string/2 edge cases" do
    test "raises on malformed CSV with mismatched quotes" do
      csv = "A,B\n\"unclosed,value"

      assert_raise NimbleCSV.ParseError, fn ->
        Holdco.CSVParser.parse_string(csv, skip_headers: true)
      end
    end
  end

  describe "dump_to_iodata/1" do
    test "dumps rows to iodata" do
      rows = [["Alice", "US"], ["Bob", "UK"]]
      iodata = Holdco.CSVParser.dump_to_iodata(rows)
      result = IO.iodata_to_binary(iodata)

      assert result =~ "Alice"
      assert result =~ "Bob"
      assert result =~ "US"
      assert result =~ "UK"
    end

    test "dumps empty list to empty iodata" do
      iodata = Holdco.CSVParser.dump_to_iodata([])
      result = IO.iodata_to_binary(iodata)
      assert result == ""
    end

    test "dumps single row" do
      iodata = Holdco.CSVParser.dump_to_iodata([["one", "two"]])
      result = IO.iodata_to_binary(iodata)
      assert result =~ "one"
      assert result =~ "two"
    end

    test "handles fields with commas by quoting" do
      iodata = Holdco.CSVParser.dump_to_iodata([["Acme, Corp", "US"]])
      result = IO.iodata_to_binary(iodata)
      assert result =~ "Acme, Corp"
    end
  end

  describe "dump_to_stream/1" do
    test "dumps rows to a stream" do
      rows = [["X", "Y"], ["A", "B"]]
      stream = Holdco.CSVParser.dump_to_stream(rows)
      result = stream |> Enum.to_list() |> IO.iodata_to_binary()

      assert result =~ "X"
      assert result =~ "A"
    end
  end

  describe "parse_string/2 with default options" do
    test "parse_string with defaults skips headers" do
      csv = "H1,H2\nA,B"

      rows = Holdco.CSVParser.parse_string(csv)
      # NimbleCSV defaults to skipping headers
      assert length(rows) == 1
      assert rows == [["A", "B"]]
    end
  end

  describe "parse_enumerable/2" do
    test "parses a list of lines (enumerable)" do
      lines = ["Name,Age\n", "Alice,30\n", "Bob,25\n"]
      rows = Holdco.CSVParser.parse_enumerable(lines, skip_headers: true)
      assert rows == [["Alice", "30"], ["Bob", "25"]]
    end

    test "parses enumerable without skipping headers" do
      lines = ["Name,Age\n", "Alice,30\n"]
      rows = Holdco.CSVParser.parse_enumerable(lines, skip_headers: false)
      assert rows == [["Name", "Age"], ["Alice", "30"]]
    end

    test "parses empty enumerable" do
      rows = Holdco.CSVParser.parse_enumerable([], skip_headers: false)
      assert rows == []
    end
  end

  describe "parse_stream/2" do
    test "parses a stream" do
      lines = ["Name,Age\n", "Alice,30\n", "Bob,25\n"]
      stream = Stream.map(lines, & &1)
      rows = Holdco.CSVParser.parse_stream(stream, skip_headers: true) |> Enum.to_list()
      assert rows == [["Alice", "30"], ["Bob", "25"]]
    end
  end

  describe "round trip: parse then dump" do
    test "data survives a round trip through dump and parse" do
      original = [["Alice", "US", "100"], ["Bob", "UK", "200"]]
      dumped = Holdco.CSVParser.dump_to_iodata(original) |> IO.iodata_to_binary()
      parsed = Holdco.CSVParser.parse_string(dumped, skip_headers: false)
      assert parsed == original
    end
  end
end
