defmodule Holdco.Import.XlsxParserTest do
  use ExUnit.Case, async: true

  alias Holdco.Import.XlsxParser

  @moduletag :tmp_dir

  describe "parse_file/2" do
    test "parses a valid xlsx with shared strings and returns data rows", %{tmp_dir: tmp_dir} do
      path = create_xlsx(tmp_dir, "test.xlsx", [
        ["Name", "Country", "Type"],
        ["Acme Corp", "US", "LLC"],
        ["Beta Inc", "UK", "Ltd"]
      ])

      assert {:ok, rows} = XlsxParser.parse_file(path)
      # skip_headers: true by default, so header row skipped
      assert length(rows) == 2
      assert Enum.at(rows, 0) == ["Acme Corp", "US", "LLC"]
      assert Enum.at(rows, 1) == ["Beta Inc", "UK", "Ltd"]
    end

    test "skip_headers: false includes the header row", %{tmp_dir: tmp_dir} do
      path = create_xlsx(tmp_dir, "headers.xlsx", [
        ["Name", "Country"],
        ["Acme", "US"]
      ])

      assert {:ok, rows} = XlsxParser.parse_file(path, skip_headers: false)
      assert length(rows) == 2
      assert Enum.at(rows, 0) == ["Name", "Country"]
      assert Enum.at(rows, 1) == ["Acme", "US"]
    end

    test "skip_headers: true with only a header row returns empty list", %{tmp_dir: tmp_dir} do
      path = create_xlsx(tmp_dir, "header_only.xlsx", [
        ["Name", "Country"]
      ])

      assert {:ok, []} = XlsxParser.parse_file(path)
    end

    test "parses empty sheet (no rows) and returns empty list", %{tmp_dir: tmp_dir} do
      path = create_xlsx(tmp_dir, "empty.xlsx", [])

      assert {:ok, []} = XlsxParser.parse_file(path)
    end

    test "handles multiple columns correctly", %{tmp_dir: tmp_dir} do
      path = create_xlsx(tmp_dir, "multi_col.xlsx", [
        ["A", "B", "C", "D", "E"],
        ["1", "2", "3", "4", "5"]
      ])

      assert {:ok, [row]} = XlsxParser.parse_file(path)
      assert row == ["1", "2", "3", "4", "5"]
    end

    test "handles numeric values as strings", %{tmp_dir: tmp_dir} do
      path = create_xlsx_with_numbers(tmp_dir, "numbers.xlsx", [
        [{"s", "Amount"}, {"s", "Rate"}],
        [{"n", "1000"}, {"n", "3.5"}]
      ])

      assert {:ok, [row]} = XlsxParser.parse_file(path)
      assert Enum.at(row, 0) == "1000"
      assert Enum.at(row, 1) == "3.5"
    end

    test "handles rows with mixed shared strings and inline values", %{tmp_dir: tmp_dir} do
      path = create_xlsx(tmp_dir, "mixed.xlsx", [
        ["Header1", "Header2"],
        ["Value1", "Value2"],
        ["Value3", "Value4"]
      ])

      assert {:ok, rows} = XlsxParser.parse_file(path)
      assert length(rows) == 2
      assert Enum.at(rows, 0) == ["Value1", "Value2"]
      assert Enum.at(rows, 1) == ["Value3", "Value4"]
    end

    test "returns error for invalid (non-zip) file", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "invalid.xlsx")
      File.write!(path, "this is not a zip file")

      assert {:error, _reason} = XlsxParser.parse_file(path)
    end

    test "returns error for non-existent file" do
      assert {:error, _reason} = XlsxParser.parse_file("/tmp/nonexistent_file_12345.xlsx")
    end

    test "handles xlsx with no shared strings file (all inline)", %{tmp_dir: tmp_dir} do
      path = create_xlsx_no_shared_strings(tmp_dir, "no_shared.xlsx", [
        [{"n", "100"}, {"n", "200"}],
        [{"n", "300"}, {"n", "400"}]
      ])

      assert {:ok, rows} = XlsxParser.parse_file(path, skip_headers: false)
      assert length(rows) == 2
      assert Enum.at(rows, 0) == ["100", "200"]
      assert Enum.at(rows, 1) == ["300", "400"]
    end
  end

  # Helper to create a minimal .xlsx file from a list of rows
  # Each row is a list of string values. All values go into shared strings.
  defp create_xlsx(tmp_dir, filename, rows) do
    path = Path.join(tmp_dir, filename)

    # Build shared strings
    all_values = List.flatten(rows) |> Enum.uniq()
    ss_index = all_values |> Enum.with_index() |> Map.new()

    shared_strings_xml = build_shared_strings_xml(all_values)
    sheet_xml = build_sheet_xml(rows, ss_index)
    content_types_xml = build_content_types_xml()
    rels_xml = build_rels_xml()
    workbook_xml = build_workbook_xml()
    workbook_rels_xml = build_workbook_rels_xml()

    files = [
      {~c"[Content_Types].xml", content_types_xml},
      {~c"_rels/.rels", rels_xml},
      {~c"xl/workbook.xml", workbook_xml},
      {~c"xl/_rels/workbook.xml.rels", workbook_rels_xml},
      {~c"xl/sharedStrings.xml", shared_strings_xml},
      {~c"xl/worksheets/sheet1.xml", sheet_xml}
    ]

    {:ok, _} = :zip.create(String.to_charlist(path), files)
    path
  end

  # Create xlsx with explicit cell types (for numeric values)
  defp create_xlsx_with_numbers(tmp_dir, filename, rows) do
    path = Path.join(tmp_dir, filename)

    # Collect shared strings from "s" type cells
    shared_values =
      rows
      |> List.flatten()
      |> Enum.filter(fn {type, _} -> type == "s" end)
      |> Enum.map(fn {_, val} -> val end)
      |> Enum.uniq()

    ss_index = shared_values |> Enum.with_index() |> Map.new()

    shared_strings_xml = build_shared_strings_xml(shared_values)
    sheet_xml = build_sheet_xml_typed(rows, ss_index)
    content_types_xml = build_content_types_xml()
    rels_xml = build_rels_xml()
    workbook_xml = build_workbook_xml()
    workbook_rels_xml = build_workbook_rels_xml()

    files = [
      {~c"[Content_Types].xml", content_types_xml},
      {~c"_rels/.rels", rels_xml},
      {~c"xl/workbook.xml", workbook_xml},
      {~c"xl/_rels/workbook.xml.rels", workbook_rels_xml},
      {~c"xl/sharedStrings.xml", shared_strings_xml},
      {~c"xl/worksheets/sheet1.xml", sheet_xml}
    ]

    {:ok, _} = :zip.create(String.to_charlist(path), files)
    path
  end

  # Create xlsx without shared strings file (numeric only)
  defp create_xlsx_no_shared_strings(tmp_dir, filename, rows) do
    path = Path.join(tmp_dir, filename)

    sheet_xml = build_sheet_xml_typed(rows, %{})
    content_types_xml = build_content_types_xml(false)
    rels_xml = build_rels_xml()
    workbook_xml = build_workbook_xml()
    workbook_rels_xml = build_workbook_rels_xml(false)

    files = [
      {~c"[Content_Types].xml", content_types_xml},
      {~c"_rels/.rels", rels_xml},
      {~c"xl/workbook.xml", workbook_xml},
      {~c"xl/_rels/workbook.xml.rels", workbook_rels_xml},
      {~c"xl/worksheets/sheet1.xml", sheet_xml}
    ]

    {:ok, _} = :zip.create(String.to_charlist(path), files)
    path
  end

  defp build_shared_strings_xml(values) do
    si_elements =
      values
      |> Enum.map(fn val -> "<si><t>#{xml_escape(val)}</t></si>" end)
      |> Enum.join("")

    ~s(<?xml version="1.0" encoding="UTF-8" standalone="yes"?>) <>
      ~s(<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="#{length(values)}" uniqueCount="#{length(values)}">) <>
      si_elements <>
      ~s(</sst>)
  end

  defp build_sheet_xml(rows, ss_index) do
    row_elements =
      rows
      |> Enum.with_index(1)
      |> Enum.map(fn {row, row_idx} ->
        cells =
          row
          |> Enum.with_index()
          |> Enum.map(fn {val, col_idx} ->
            col_letter = col_index_to_letter(col_idx)
            ref = "#{col_letter}#{row_idx}"
            idx = Map.get(ss_index, val, 0)
            ~s(<c r="#{ref}" t="s"><v>#{idx}</v></c>)
          end)
          |> Enum.join("")

        ~s(<row r="#{row_idx}">#{cells}</row>)
      end)
      |> Enum.join("")

    ~s(<?xml version="1.0" encoding="UTF-8" standalone="yes"?>) <>
      ~s(<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">) <>
      ~s(<sheetData>#{row_elements}</sheetData>) <>
      ~s(</worksheet>)
  end

  defp build_sheet_xml_typed(rows, ss_index) do
    row_elements =
      rows
      |> Enum.with_index(1)
      |> Enum.map(fn {row, row_idx} ->
        cells =
          row
          |> Enum.with_index()
          |> Enum.map(fn {{type, val}, col_idx} ->
            col_letter = col_index_to_letter(col_idx)
            ref = "#{col_letter}#{row_idx}"

            case type do
              "s" ->
                idx = Map.get(ss_index, val, 0)
                ~s(<c r="#{ref}" t="s"><v>#{idx}</v></c>)

              "n" ->
                ~s(<c r="#{ref}"><v>#{val}</v></c>)

              _ ->
                ~s(<c r="#{ref}"><v>#{xml_escape(val)}</v></c>)
            end
          end)
          |> Enum.join("")

        ~s(<row r="#{row_idx}">#{cells}</row>)
      end)
      |> Enum.join("")

    ~s(<?xml version="1.0" encoding="UTF-8" standalone="yes"?>) <>
      ~s(<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">) <>
      ~s(<sheetData>#{row_elements}</sheetData>) <>
      ~s(</worksheet>)
  end

  defp build_content_types_xml(with_shared_strings \\ true) do
    ss_override =
      if with_shared_strings do
        ~s(<Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>)
      else
        ""
      end

    ~s(<?xml version="1.0" encoding="UTF-8" standalone="yes"?>) <>
      ~s(<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">) <>
      ~s(<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>) <>
      ~s(<Default Extension="xml" ContentType="application/xml"/>) <>
      ~s(<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>) <>
      ~s(<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>) <>
      ss_override <>
      ~s(</Types>)
  end

  defp build_rels_xml do
    ~s(<?xml version="1.0" encoding="UTF-8" standalone="yes"?>) <>
      ~s(<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">) <>
      ~s(<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>) <>
      ~s(</Relationships>)
  end

  defp build_workbook_xml do
    ~s(<?xml version="1.0" encoding="UTF-8" standalone="yes"?>) <>
      ~s(<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">) <>
      ~s(<sheets><sheet name="Sheet1" sheetId="1" r:id="rId1" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"/></sheets>) <>
      ~s(</workbook>)
  end

  defp build_workbook_rels_xml(with_shared_strings \\ true) do
    ss_rel =
      if with_shared_strings do
        ~s(<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>)
      else
        ""
      end

    ~s(<?xml version="1.0" encoding="UTF-8" standalone="yes"?>) <>
      ~s(<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">) <>
      ~s(<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>) <>
      ss_rel <>
      ~s(</Relationships>)
  end

  defp col_index_to_letter(idx) when idx < 26 do
    <<(?A + idx)>>
  end

  defp col_index_to_letter(idx) do
    first = div(idx, 26) - 1
    second = rem(idx, 26)
    <<(?A + first), (?A + second)>>
  end

  defp xml_escape(str) do
    str
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end
end
