defmodule Holdco.Import.XlsxParser do
  @moduledoc """
  Lightweight XLSX parser using Erlang :zip and :xmerl.

  XLSX files are ZIP archives containing XML files. This module:
  - Opens the .xlsx ZIP archive in memory
  - Reads `xl/sharedStrings.xml` for the shared string table
  - Reads `xl/worksheets/sheet1.xml` for cell data
  - Returns rows as list of lists (same format as NimbleCSV output)
  """

  @doc """
  Parses an XLSX file and returns rows as a list of lists of strings.

  ## Options

    * `:skip_headers` - When `true` (default), skips the first row (header row).
      Set to `false` to include the header row.

  ## Examples

      iex> Holdco.Import.XlsxParser.parse_file("data.xlsx")
      {:ok, [["Alice", "US", "LLC", "Operating", "100"], ...]}

      iex> Holdco.Import.XlsxParser.parse_file("data.xlsx", skip_headers: false)
      {:ok, [["Name", "Country", ...], ["Alice", "US", ...], ...]}
  """
  def parse_file(path, opts \\ []) do
    skip_headers = Keyword.get(opts, :skip_headers, true)

    with {:ok, files} <- unzip_file(path),
         shared_strings <- parse_shared_strings(files),
         {:ok, rows} <- parse_sheet(files, shared_strings) do
      result =
        if skip_headers and length(rows) > 0 do
          tl(rows)
        else
          rows
        end

      {:ok, result}
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp unzip_file(path) do
    charlist_path = String.to_charlist(path)

    case :zip.unzip(charlist_path, [:memory]) do
      {:ok, files} -> {:ok, files}
      {:error, reason} -> {:error, "Failed to open XLSX file: #{inspect(reason)}"}
    end
  end

  defp parse_shared_strings(files) do
    case find_file(files, ~c"xl/sharedStrings.xml") do
      nil ->
        # No shared strings file means all values are inline
        %{}

      content ->
        parse_shared_strings_xml(content)
    end
  end

  defp parse_shared_strings_xml(xml_content) do
    {doc, _} = :xmerl_scan.string(String.to_charlist(xml_content), quiet: true)

    # Extract all <si> elements which contain shared strings
    si_elements = xpath(doc, ~c"//si")

    si_elements
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {si_elem, idx}, acc ->
      text = extract_text_from_si(si_elem)
      Map.put(acc, idx, text)
    end)
  end

  defp extract_text_from_si(si_elem) do
    # Each <si> can contain:
    # - A single <t> element with text
    # - Multiple <r> (rich text run) elements, each with a <t> element
    t_elements = xpath(si_elem, ~c".//t")

    t_elements
    |> Enum.map(&extract_text/1)
    |> Enum.join("")
  end

  defp parse_sheet(files, shared_strings) do
    case find_file(files, ~c"xl/worksheets/sheet1.xml") do
      nil ->
        {:error, "No worksheet found in XLSX file"}

      content ->
        {:ok, parse_sheet_xml(content, shared_strings)}
    end
  end

  defp parse_sheet_xml(xml_content, shared_strings) do
    {doc, _} = :xmerl_scan.string(String.to_charlist(xml_content), quiet: true)

    # Extract all <row> elements
    row_elements = xpath(doc, ~c"//row")

    row_elements
    |> Enum.map(fn row_elem -> parse_row(row_elem, shared_strings) end)
    |> normalize_rows()
  end

  defp parse_row(row_elem, shared_strings) do
    # Extract all <c> (cell) elements within this row
    cell_elements = xpath(row_elem, ~c"./c")

    cell_elements
    |> Enum.map(fn cell_elem ->
      {col_ref(cell_elem), cell_value(cell_elem, shared_strings)}
    end)
  end

  defp col_ref(cell_elem) do
    # Get the "r" attribute (cell reference like "A1", "B1", etc.)
    case get_attribute(cell_elem, :r) do
      nil -> 0
      ref -> col_index_from_ref(to_string(ref))
    end
  end

  defp cell_value(cell_elem, shared_strings) do
    type = get_attribute(cell_elem, :t)
    value_elements = xpath(cell_elem, ~c"./v")

    raw_value =
      case value_elements do
        [] ->
          # Check for inline string
          inline_elements = xpath(cell_elem, ~c"./is//t")

          case inline_elements do
            [] -> ""
            elems -> Enum.map(elems, &extract_text/1) |> Enum.join("")
          end

        [v_elem | _] ->
          extract_text(v_elem)
      end

    resolve_value(type, raw_value, shared_strings)
  end

  defp resolve_value(~c"s", raw_value, shared_strings) do
    # Shared string reference
    case Integer.parse(raw_value) do
      {idx, _} -> Map.get(shared_strings, idx, "")
      :error -> raw_value
    end
  end

  defp resolve_value(~c"b", raw_value, _shared_strings) do
    # Boolean
    if raw_value == "1", do: "TRUE", else: "FALSE"
  end

  defp resolve_value(~c"inlineStr", _raw_value, _shared_strings) do
    # Already handled in cell_value
    ""
  end

  defp resolve_value(_type, raw_value, _shared_strings) do
    # Number, date, or untyped - return as string
    clean_numeric_string(raw_value)
  end

  defp clean_numeric_string(value) do
    # If it looks like a float that's actually an integer (e.g., "100.0"), clean it
    case Float.parse(value) do
      {float_val, ""} ->
        if float_val == Float.floor(float_val) and not String.contains?(value, "E") do
          # It's a whole number represented as float
          float_val |> trunc() |> Integer.to_string()
        else
          value
        end

      _ ->
        value
    end
  end

  defp normalize_rows(parsed_rows) do
    # Each parsed_row is a list of {col_index, value} tuples
    # We need to fill in gaps and produce uniform row lengths
    if parsed_rows == [] do
      []
    else
      max_col =
        parsed_rows
        |> Enum.flat_map(fn cells -> Enum.map(cells, fn {col, _} -> col end) end)
        |> Enum.max(fn -> 0 end)

      Enum.map(parsed_rows, fn cells ->
        cell_map = Map.new(cells)

        for col <- 0..max_col do
          Map.get(cell_map, col, "")
        end
      end)
    end
  end

  # Column reference parsing: "A1" -> 0, "B1" -> 1, "AA1" -> 26, etc.
  defp col_index_from_ref(ref) do
    letters =
      ref
      |> String.graphemes()
      |> Enum.take_while(fn char -> char >= "A" and char <= "Z" end)

    letters
    |> Enum.reduce(0, fn letter, acc ->
      <<code>> = letter
      acc * 26 + (code - ?A + 1)
    end)
    |> Kernel.-(1)
  end

  # XPath helper using :xmerl_xpath
  defp xpath(node, path) do
    :xmerl_xpath.string(path, node)
  rescue
    _ -> []
  end

  # Extract text content from an XML element
  defp extract_text(element) do
    element
    |> xpath(~c"./text()")
    |> Enum.map(fn text_node ->
      case text_node do
        {:xmlText, _, _, _, value, _} -> to_string(value)
        _ -> ""
      end
    end)
    |> Enum.join("")
  end

  # Get an attribute value from an XML element
  defp get_attribute(element, attr_name) do
    case element do
      {:xmlElement, _, _, _, _, _, _, attributes, _, _, _, _} ->
        Enum.find_value(attributes, fn
          {:xmlAttribute, ^attr_name, _, _, _, _, _, _, value, _} -> value
          _ -> nil
        end)

      _ ->
        nil
    end
  end

  # Find a file in the zip entries by name
  defp find_file(files, name) do
    Enum.find_value(files, fn
      {entry_name, content} when entry_name == name -> content
      _ -> nil
    end)
  end
end
