defmodule Holdco.Banking.StatementParserTest do
  use Holdco.DataCase, async: true

  alias Holdco.Banking.StatementParser

  describe "parse/2" do
    test "parses CSV with standard headers" do
      csv = """
      Date,Description,Amount,Currency
      2024-01-15,Coffee shop,-4.50,USD
      2024-01-16,Salary deposit,3500.00,USD
      2024-01-17,Rent payment,-1200.00,USD
      """

      assert {:ok, txns} = StatementParser.parse(csv, "statement.csv")
      assert length(txns) == 3

      [t1, t2, t3] = txns
      assert t1.date == "2024-01-15"
      assert t1.description == "Coffee shop"
      assert Decimal.equal?(t1.amount, Decimal.new("-4.50"))
      assert t1.currency == "USD"

      assert Decimal.equal?(t2.amount, Decimal.new("3500.00"))
      assert Decimal.equal?(t3.amount, Decimal.new("-1200.00"))
    end

    test "parses CSV with debit/credit columns" do
      csv = """
      Date,Memo,Debit,Credit
      2024-02-01,Wire transfer,,5000.00
      2024-02-02,Office supplies,150.00,
      """

      assert {:ok, txns} = StatementParser.parse(csv, "bank.csv")
      assert length(txns) == 2

      [credit, debit] = txns
      assert Decimal.equal?(credit.amount, Decimal.new("5000.00"))
      assert Decimal.equal?(debit.amount, Decimal.new("-150.00"))
    end

    test "normalizes date formats" do
      csv = """
      Date,Description,Amount
      01/15/2024,Payment 1,-100
      2024-02-20,Payment 2,-200
      """

      assert {:ok, txns} = StatementParser.parse(csv, "dates.csv")

      [t1, t2] = txns
      assert t1.date == "2024-01-15"
      assert t2.date == "2024-02-20"
    end

    test "defaults currency to USD when not present" do
      csv = """
      Date,Description,Amount
      2024-01-01,Test,-10
      """

      assert {:ok, [txn]} = StatementParser.parse(csv, "no_currency.csv")
      assert txn.currency == "USD"
    end

    test "returns error for unsupported file format" do
      assert {:error, "Unsupported file format" <> _} = StatementParser.parse("content", "file.pdf")
    end

    test "returns error when date column not found" do
      csv = """
      Foo,Bar,Baz
      1,2,3
      """

      assert {:error, "Could not detect date column" <> _} = StatementParser.parse(csv, "bad.csv")
    end

    test "returns error when amount column not found" do
      csv = """
      Date,Foo,Bar
      2024-01-01,test,value
      """

      assert {:error, "Could not detect amount column" <> _} = StatementParser.parse(csv, "no_amount.csv")
    end

    test "handles empty CSV" do
      assert {:error, _} = StatementParser.parse("", "empty.csv")
    end

    test "skips blank lines" do
      csv = """
      Date,Description,Amount
      2024-01-01,First,-10

      2024-01-02,Second,-20

      """

      assert {:ok, txns} = StatementParser.parse(csv, "blanks.csv")
      assert length(txns) == 2
    end

    test "handles quoted CSV fields with commas" do
      csv = """
      Date,Description,Amount
      2024-01-01,"Coffee, tea, and snacks",-25.50
      """

      assert {:ok, [txn]} = StatementParser.parse(csv, "quoted.csv")
      assert txn.description == "Coffee, tea, and snacks"
    end
  end

  describe "parse_csv_fallback/1" do
    test "handles various header name variations" do
      csv = """
      Transaction Date,Narrative,Value
      2024-03-01,Invoice payment,500
      """

      assert {:ok, [txn]} = StatementParser.parse_csv_fallback(csv)
      assert txn.date == "2024-03-01"
      assert txn.description == "Invoice payment"
      assert Decimal.equal?(txn.amount, Decimal.new("500"))
    end
  end

  describe "parse_with_ai/1" do
    test "returns error when AI is not configured" do
      # AI is not configured in test env, so this tests the fallback path
      assert {:error, _} = StatementParser.parse_with_ai("some csv content")
    end
  end
end
