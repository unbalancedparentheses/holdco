defmodule Holdco.ValidatorsTest do
  use ExUnit.Case, async: true

  alias Holdco.Validators

  # Minimal schema and changeset for testing the validator
  defmodule TestSchema do
    use Ecto.Schema
    import Ecto.Changeset

    embedded_schema do
      field :date, :string
    end

    def changeset(schema, attrs) do
      schema
      |> cast(attrs, [:date])
    end
  end

  defp changeset_with_date(date) do
    TestSchema.changeset(%TestSchema{}, %{date: date})
  end

  describe "validate_date_format/2" do
    test "valid ISO 8601 date passes" do
      cs = changeset_with_date("2024-06-15") |> Validators.validate_date_format(:date)
      assert cs.valid?
    end

    test "invalid format 'not-a-date' rejected" do
      cs = changeset_with_date("not-a-date") |> Validators.validate_date_format(:date)
      refute cs.valid?
      assert {"must be a valid date (YYYY-MM-DD)", []} in errors_on(cs, :date)
    end

    test "invalid format with slashes rejected" do
      cs = changeset_with_date("2024/01/01") |> Validators.validate_date_format(:date)
      refute cs.valid?
    end

    test "invalid format MM-DD-YYYY rejected" do
      cs = changeset_with_date("01-01-2024") |> Validators.validate_date_format(:date)
      refute cs.valid?
    end

    test "nil value passes (validator only fires on changes)" do
      cs = TestSchema.changeset(%TestSchema{}, %{}) |> Validators.validate_date_format(:date)
      assert cs.valid?
    end

    test "leap year date 2024-02-29 passes" do
      cs = changeset_with_date("2024-02-29") |> Validators.validate_date_format(:date)
      assert cs.valid?
    end

    test "invalid day for month 2024-02-30 rejected" do
      cs = changeset_with_date("2024-02-30") |> Validators.validate_date_format(:date)
      refute cs.valid?
    end

    test "non-leap year 2023-02-29 rejected" do
      cs = changeset_with_date("2023-02-29") |> Validators.validate_date_format(:date)
      refute cs.valid?
    end
  end

  # Helper to extract errors from changeset
  defp errors_on(changeset, field) do
    changeset.errors
    |> Enum.filter(fn {f, _} -> f == field end)
    |> Enum.map(fn {_, v} -> v end)
  end
end
