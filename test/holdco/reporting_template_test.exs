defmodule Holdco.ReportingTemplateTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Compliance

  describe "reporting_templates CRUD" do
    test "create_reporting_template/1 with valid data" do
      assert {:ok, template} =
               Compliance.create_reporting_template(%{
                 name: "CRS Annual Report",
                 template_type: "crs",
                 jurisdiction: "US",
                 frequency: "annual"
               })

      assert template.name == "CRS Annual Report"
      assert template.template_type == "crs"
      assert template.is_active == true
    end

    test "create_reporting_template/1 with invalid data" do
      assert {:error, changeset} = Compliance.create_reporting_template(%{})
      assert errors_on(changeset)[:name]
    end

    test "create_reporting_template/1 validates template_type enum" do
      assert {:error, changeset} =
               Compliance.create_reporting_template(%{
                 name: "Test",
                 template_type: "invalid",
                 frequency: "annual"
               })

      assert errors_on(changeset)[:template_type]
    end

    test "create_reporting_template/1 validates frequency enum" do
      assert {:error, changeset} =
               Compliance.create_reporting_template(%{
                 name: "Test",
                 template_type: "crs",
                 frequency: "invalid"
               })

      assert errors_on(changeset)[:frequency]
    end

    test "list_reporting_templates/0 returns all templates" do
      template = reporting_template_fixture()
      assert Enum.any?(Compliance.list_reporting_templates(), &(&1.id == template.id))
    end

    test "get_reporting_template!/1 returns the template" do
      template = reporting_template_fixture()
      fetched = Compliance.get_reporting_template!(template.id)
      assert fetched.id == template.id
    end

    test "update_reporting_template/2 updates the template" do
      template = reporting_template_fixture()

      assert {:ok, updated} =
               Compliance.update_reporting_template(template, %{
                 name: "Updated Template",
                 is_active: false
               })

      assert updated.name == "Updated Template"
      assert updated.is_active == false
    end

    test "delete_reporting_template/1 deletes the template" do
      template = reporting_template_fixture()
      assert {:ok, _} = Compliance.delete_reporting_template(template)
      assert_raise Ecto.NoResultsError, fn -> Compliance.get_reporting_template!(template.id) end
    end

    test "create with all template types" do
      for type <- ~w(crs fatca bo_register aml_report regulatory_return tax_return) do
        assert {:ok, t} =
                 Compliance.create_reporting_template(%{
                   name: "#{type} template",
                   template_type: type,
                   frequency: "annual"
                 })

        assert t.template_type == type
      end
    end

    test "create with all frequencies" do
      for freq <- ~w(annual semi_annual quarterly monthly ad_hoc) do
        assert {:ok, t} =
                 Compliance.create_reporting_template(%{
                   name: "#{freq} template",
                   template_type: "crs",
                   frequency: freq
                 })

        assert t.frequency == freq
      end
    end

    test "create with fields map" do
      assert {:ok, template} =
               Compliance.create_reporting_template(%{
                 name: "With Fields",
                 template_type: "crs",
                 frequency: "annual",
                 fields: %{"name" => "string", "amount" => "decimal"}
               })

      assert template.fields == %{"name" => "string", "amount" => "decimal"}
    end
  end

  describe "generate_report/2" do
    test "generates CRS report" do
      template = reporting_template_fixture(%{template_type: "crs"})
      assert {:ok, report} = Compliance.generate_report(template.id)
      assert report.type == "crs"
      assert report.template.id == template.id
      assert is_list(report.records)
    end

    test "generates FATCA report" do
      template = reporting_template_fixture(%{template_type: "fatca"})
      assert {:ok, report} = Compliance.generate_report(template.id)
      assert report.type == "fatca"
    end

    test "generates BO register report" do
      template = reporting_template_fixture(%{template_type: "bo_register"})
      assert {:ok, report} = Compliance.generate_report(template.id)
      assert report.type == "bo_register"
    end

    test "generates AML report" do
      template = reporting_template_fixture(%{template_type: "aml_report"})
      assert {:ok, report} = Compliance.generate_report(template.id)
      assert report.type == "aml_report"
    end

    test "generates report with unknown type" do
      template = reporting_template_fixture(%{template_type: "tax_return"})
      assert {:ok, report} = Compliance.generate_report(template.id)
      assert report.type == "tax_return"
      assert report.records == []
    end
  end
end
