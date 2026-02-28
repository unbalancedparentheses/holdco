defmodule Holdco.ComplianceTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Compliance

  # Helper: convert Decimal to float for test assertions
  defp d(val) when is_struct(val, Decimal), do: Decimal.to_float(val)
  defp d(val) when is_number(val), do: val / 1
  defp d(nil), do: 0.0

  describe "tax_deadlines" do
    test "CRUD operations" do
      company = company_fixture()
      {:ok, td} = Compliance.create_tax_deadline(%{company_id: company.id, jurisdiction: "US", description: "Q1 Filing", due_date: "2024-04-15"})

      assert Enum.any?(Compliance.list_tax_deadlines(company.id), &(&1.id == td.id))
      assert Enum.any?(Compliance.list_tax_deadlines(), &(&1.id == td.id))
      assert Compliance.get_tax_deadline!(td.id).id == td.id

      {:ok, updated} = Compliance.update_tax_deadline(td, %{description: "Updated"})
      assert updated.description == "Updated"

      {:ok, _} = Compliance.delete_tax_deadline(updated)
    end
  end

  describe "annual_filings" do
    test "CRUD operations" do
      company = company_fixture()
      {:ok, af} = Compliance.create_annual_filing(%{company_id: company.id, jurisdiction: "UK", filing_type: "annual_return", due_date: "2024-12-31"})

      assert Enum.any?(Compliance.list_annual_filings(company.id), &(&1.id == af.id))
      assert Enum.any?(Compliance.list_annual_filings(), &(&1.id == af.id))
      assert Compliance.get_annual_filing!(af.id).id == af.id

      {:ok, updated} = Compliance.update_annual_filing(af, %{status: "filed"})
      assert updated.status == "filed"

      {:ok, _} = Compliance.delete_annual_filing(updated)
    end
  end

  describe "regulatory_filings" do
    test "CRUD operations" do
      company = company_fixture()
      {:ok, rf} = Compliance.create_regulatory_filing(%{company_id: company.id, jurisdiction: "US", filing_type: "10-Q", due_date: "2024-05-15"})

      assert Enum.any?(Compliance.list_regulatory_filings(company.id), &(&1.id == rf.id))
      assert Compliance.get_regulatory_filing!(rf.id).id == rf.id

      {:ok, updated} = Compliance.update_regulatory_filing(rf, %{filing_type: "10-K"})
      assert updated.filing_type == "10-K"

      {:ok, _} = Compliance.delete_regulatory_filing(updated)
    end
  end

  describe "regulatory_licenses" do
    test "CRUD operations" do
      company = company_fixture()
      {:ok, rl} = Compliance.create_regulatory_license(%{company_id: company.id, license_type: "banking", issuing_authority: "OCC"})

      assert Enum.any?(Compliance.list_regulatory_licenses(company.id), &(&1.id == rl.id))
      assert Compliance.get_regulatory_license!(rl.id).id == rl.id

      {:ok, updated} = Compliance.update_regulatory_license(rl, %{license_type: "broker"})
      assert updated.license_type == "broker"

      {:ok, _} = Compliance.delete_regulatory_license(updated)
    end
  end

  describe "compliance_checklists" do
    test "CRUD operations" do
      company = company_fixture()
      {:ok, cc} = Compliance.create_compliance_checklist(%{company_id: company.id, jurisdiction: "US", item: "AML check"})

      assert Enum.any?(Compliance.list_compliance_checklists(company.id), &(&1.id == cc.id))
      assert Compliance.get_compliance_checklist!(cc.id).id == cc.id

      {:ok, updated} = Compliance.update_compliance_checklist(cc, %{completed: true})
      assert updated.completed == true

      {:ok, _} = Compliance.delete_compliance_checklist(updated)
    end
  end

  describe "insurance_policies" do
    test "CRUD operations" do
      company = company_fixture()
      {:ok, ip} = Compliance.create_insurance_policy(%{company_id: company.id, policy_type: "liability", provider: "Zurich"})

      assert Enum.any?(Compliance.list_insurance_policies(company.id), &(&1.id == ip.id))
      assert Compliance.get_insurance_policy!(ip.id).id == ip.id

      {:ok, updated} = Compliance.update_insurance_policy(ip, %{provider: "AIG"})
      assert updated.provider == "AIG"

      {:ok, _} = Compliance.delete_insurance_policy(updated)
    end
  end

  describe "transfer_pricing_docs" do
    test "CRUD operations" do
      c1 = company_fixture()
      c2 = company_fixture()
      {:ok, tp} = Compliance.create_transfer_pricing_doc(%{from_company_id: c1.id, to_company_id: c2.id, description: "Mgmt fees"})

      assert Enum.any?(Compliance.list_transfer_pricing_docs(), &(&1.id == tp.id))
      assert Compliance.get_transfer_pricing_doc!(tp.id).id == tp.id

      {:ok, updated} = Compliance.update_transfer_pricing_doc(tp, %{description: "Royalties"})
      assert updated.description == "Royalties"

      {:ok, _} = Compliance.delete_transfer_pricing_doc(updated)
    end
  end

  describe "withholding_taxes" do
    test "CRUD operations" do
      company = company_fixture()
      {:ok, wt} = Compliance.create_withholding_tax(%{
        company_id: company.id, payment_type: "dividend", country_from: "US", country_to: "DE",
        gross_amount: 10000.0, rate: 0.15, tax_amount: 1500.0, date: "2024-01-01"
      })

      assert Enum.any?(Compliance.list_withholding_taxes(company.id), &(&1.id == wt.id))
      assert Compliance.get_withholding_tax!(wt.id).id == wt.id

      {:ok, updated} = Compliance.update_withholding_tax(wt, %{rate: 0.10})
      assert d(updated.rate) == 0.10

      {:ok, _} = Compliance.delete_withholding_tax(updated)
    end
  end

  describe "fatca_reports" do
    test "CRUD operations" do
      company = company_fixture()
      {:ok, fr} = Compliance.create_fatca_report(%{company_id: company.id, reporting_year: 2024, jurisdiction: "US"})

      assert Enum.any?(Compliance.list_fatca_reports(company.id), &(&1.id == fr.id))
      assert Compliance.get_fatca_report!(fr.id).id == fr.id

      {:ok, updated} = Compliance.update_fatca_report(fr, %{status: "filed"})
      assert updated.status == "filed"

      {:ok, _} = Compliance.delete_fatca_report(updated)
    end
  end

  describe "esg_scores" do
    test "CRUD operations" do
      company = company_fixture()
      {:ok, es} = Compliance.create_esg_score(%{company_id: company.id, period: "2024", overall_score: 85.0})

      assert Enum.any?(Compliance.list_esg_scores(company.id), &(&1.id == es.id))
      assert Compliance.get_esg_score!(es.id).id == es.id

      {:ok, updated} = Compliance.update_esg_score(es, %{overall_score: 90.0})
      assert d(updated.overall_score) == 90.0

      {:ok, _} = Compliance.delete_esg_score(updated)
    end
  end

  describe "list functions without company filter" do
    test "list_regulatory_filings/0 returns all" do
      company = company_fixture()
      {:ok, rf} = Compliance.create_regulatory_filing(%{company_id: company.id, jurisdiction: "DE", filing_type: "Annual", due_date: "2025-03-01"})
      assert Enum.any?(Compliance.list_regulatory_filings(), &(&1.id == rf.id))
    end

    test "list_regulatory_licenses/0 returns all" do
      company = company_fixture()
      {:ok, rl} = Compliance.create_regulatory_license(%{company_id: company.id, license_type: "money_services", issuing_authority: "FinCEN"})
      assert Enum.any?(Compliance.list_regulatory_licenses(), &(&1.id == rl.id))
    end

    test "list_compliance_checklists/0 returns all" do
      company = company_fixture()
      {:ok, cc} = Compliance.create_compliance_checklist(%{company_id: company.id, jurisdiction: "EU", item: "GDPR check"})
      assert Enum.any?(Compliance.list_compliance_checklists(), &(&1.id == cc.id))
    end

    test "list_insurance_policies/0 returns all" do
      company = company_fixture()
      {:ok, ip} = Compliance.create_insurance_policy(%{company_id: company.id, policy_type: "D&O", provider: "Lloyd's"})
      assert Enum.any?(Compliance.list_insurance_policies(), &(&1.id == ip.id))
    end

    test "list_withholding_taxes/0 returns all" do
      company = company_fixture()
      {:ok, wt} = Compliance.create_withholding_tax(%{
        company_id: company.id, payment_type: "interest", country_from: "US", country_to: "UK",
        gross_amount: 5000.0, rate: 0.10, tax_amount: 500.0, date: "2024-06-01"
      })
      assert Enum.any?(Compliance.list_withholding_taxes(), &(&1.id == wt.id))
    end

    test "list_fatca_reports/0 returns all" do
      company = company_fixture()
      {:ok, fr} = Compliance.create_fatca_report(%{company_id: company.id, reporting_year: 2025, jurisdiction: "UK"})
      assert Enum.any?(Compliance.list_fatca_reports(), &(&1.id == fr.id))
    end

    test "list_esg_scores/0 returns all" do
      company = company_fixture()
      {:ok, es} = Compliance.create_esg_score(%{company_id: company.id, period: "2025", overall_score: 75.0})
      assert Enum.any?(Compliance.list_esg_scores(), &(&1.id == es.id))
    end

    test "list_sanctions_checks/0 returns all" do
      company = company_fixture()
      {:ok, sc} = Compliance.create_sanctions_check(%{company_id: company.id, checked_name: "AllCheck Corp"})
      assert Enum.any?(Compliance.list_sanctions_checks(), &(&1.id == sc.id))
    end
  end

  describe "subscribe/0" do
    test "subscribes to compliance PubSub topic" do
      assert :ok = Compliance.subscribe()
    end
  end

  describe "sanctions" do
    test "sanctions lists CRUD" do
      {:ok, sl} = Compliance.create_sanctions_list(%{name: "OFAC SDN", list_type: "SDN"})

      assert Enum.any?(Compliance.list_sanctions_lists(), &(&1.id == sl.id))
      assert Compliance.get_sanctions_list!(sl.id).id == sl.id

      {:ok, updated} = Compliance.update_sanctions_list(sl, %{name: "EU List"})
      assert updated.name == "EU List"

      {:ok, _} = Compliance.delete_sanctions_list(updated)
    end

    test "sanctions entries CRUD" do
      list = sanctions_list_fixture()
      {:ok, se} = Compliance.create_sanctions_entry(%{sanctions_list_id: list.id, name: "Bad Actor"})

      assert Enum.any?(Compliance.list_sanctions_entries(list.id), &(&1.id == se.id))
      assert Compliance.get_sanctions_entry!(se.id).id == se.id

      {:ok, updated} = Compliance.update_sanctions_entry(se, %{name: "Updated"})
      assert updated.name == "Updated"

      {:ok, _} = Compliance.delete_sanctions_entry(updated)
    end

    test "sanctions checks CRUD" do
      company = company_fixture()
      {:ok, sc} = Compliance.create_sanctions_check(%{company_id: company.id, checked_name: "Test Corp"})

      assert Enum.any?(Compliance.list_sanctions_checks(company.id), &(&1.id == sc.id))
      assert Compliance.get_sanctions_check!(sc.id).id == sc.id

      {:ok, updated} = Compliance.update_sanctions_check(sc, %{status: "clear"})
      assert updated.status == "clear"

      {:ok, _} = Compliance.delete_sanctions_check(updated)
    end
  end
end
