defmodule Holdco.ContractLeiRptCoiTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Corporate
  alias Holdco.Governance

  # ══════════════════════════════════════════════════════════
  # Contract Tests
  # ══════════════════════════════════════════════════════════

  describe "contracts CRUD" do
    test "create_contract/1 with valid data" do
      company = company_fixture()

      assert {:ok, contract} =
               Corporate.create_contract(%{
                 company_id: company.id,
                 title: "SaaS Agreement",
                 counterparty: "CloudCo Inc",
                 contract_type: "service",
                 status: "active",
                 start_date: "2024-01-01",
                 end_date: "2025-01-01",
                 value: "120000.00",
                 currency: "USD"
               })

      assert contract.title == "SaaS Agreement"
      assert contract.counterparty == "CloudCo Inc"
      assert contract.contract_type == "service"
      assert contract.status == "active"
    end

    test "create_contract/1 fails without required fields" do
      assert {:error, changeset} = Corporate.create_contract(%{})
      errors = errors_on(changeset)
      assert errors[:company_id]
      assert errors[:title]
      assert errors[:counterparty]
    end

    test "create_contract/1 validates contract_type enum" do
      company = company_fixture()

      assert {:error, changeset} =
               Corporate.create_contract(%{
                 company_id: company.id,
                 title: "Test",
                 counterparty: "Test Co",
                 contract_type: "invalid"
               })

      assert errors_on(changeset)[:contract_type]
    end

    test "create_contract/1 validates status enum" do
      company = company_fixture()

      assert {:error, changeset} =
               Corporate.create_contract(%{
                 company_id: company.id,
                 title: "Test",
                 counterparty: "Test Co",
                 contract_type: "nda",
                 status: "invalid_status"
               })

      assert errors_on(changeset)[:status]
    end

    test "create_contract/1 with all contract types" do
      company = company_fixture()

      for ct <- ~w(nda service license lease employment consulting vendor partnership loan other) do
        assert {:ok, c} =
                 Corporate.create_contract(%{
                   company_id: company.id,
                   title: "#{ct} contract",
                   counterparty: "Party",
                   contract_type: ct
                 })

        assert c.contract_type == ct
      end
    end

    test "create_contract/1 with tags array" do
      company = company_fixture()

      assert {:ok, c} =
               Corporate.create_contract(%{
                 company_id: company.id,
                 title: "Tagged Contract",
                 counterparty: "TagCo",
                 contract_type: "service",
                 tags: ["priority", "renewal-due"]
               })

      assert c.tags == ["priority", "renewal-due"]
    end

    test "create_contract/1 validates renewal_notice_days non-negative" do
      company = company_fixture()

      assert {:error, changeset} =
               Corporate.create_contract(%{
                 company_id: company.id,
                 title: "Test",
                 counterparty: "Test Co",
                 contract_type: "nda",
                 renewal_notice_days: -5
               })

      assert errors_on(changeset)[:renewal_notice_days]
    end

    test "list_contracts/0 returns all contracts" do
      contract = contract_fixture()
      results = Corporate.list_contracts()
      assert Enum.any?(results, &(&1.id == contract.id))
    end

    test "list_contracts/1 filters by company" do
      company = company_fixture()
      c = contract_fixture(%{company: company})
      _other = contract_fixture()

      results = Corporate.list_contracts(company.id)
      assert length(results) == 1
      assert hd(results).id == c.id
    end

    test "get_contract!/1 returns the contract with preloads" do
      contract = contract_fixture()
      fetched = Corporate.get_contract!(contract.id)
      assert fetched.id == contract.id
      assert fetched.company != nil
    end

    test "get_contract!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Corporate.get_contract!(0)
      end
    end

    test "update_contract/2 updates fields" do
      contract = contract_fixture()

      assert {:ok, updated} =
               Corporate.update_contract(contract, %{
                 status: "terminated",
                 termination_reason: "Breach of terms",
                 termination_date: "2024-12-01"
               })

      assert updated.status == "terminated"
      assert updated.termination_reason == "Breach of terms"
    end

    test "delete_contract/1 removes the contract" do
      contract = contract_fixture()
      assert {:ok, _} = Corporate.delete_contract(contract)

      assert_raise Ecto.NoResultsError, fn ->
        Corporate.get_contract!(contract.id)
      end
    end
  end

  describe "expiring_contracts/1" do
    test "returns contracts expiring within N days" do
      company = company_fixture()
      soon = Date.add(Date.utc_today(), 15)
      far = Date.add(Date.utc_today(), 90)

      {:ok, expiring_soon} =
        Corporate.create_contract(%{
          company_id: company.id,
          title: "Expiring Soon",
          counterparty: "SoonCo",
          contract_type: "service",
          status: "active",
          end_date: soon
        })

      {:ok, _far_away} =
        Corporate.create_contract(%{
          company_id: company.id,
          title: "Far Away",
          counterparty: "FarCo",
          contract_type: "service",
          status: "active",
          end_date: far
        })

      results = Corporate.expiring_contracts(30)
      assert Enum.any?(results, &(&1.id == expiring_soon.id))
      refute Enum.any?(results, &(&1.title == "Far Away"))
    end

    test "excludes already expired contracts" do
      company = company_fixture()
      past = Date.add(Date.utc_today(), -10)

      {:ok, _expired} =
        Corporate.create_contract(%{
          company_id: company.id,
          title: "Already Expired",
          counterparty: "OldCo",
          contract_type: "nda",
          status: "active",
          end_date: past
        })

      results = Corporate.expiring_contracts(30)
      refute Enum.any?(results, &(&1.title == "Already Expired"))
    end

    test "excludes terminated and draft contracts" do
      company = company_fixture()
      soon = Date.add(Date.utc_today(), 15)

      {:ok, _terminated} =
        Corporate.create_contract(%{
          company_id: company.id,
          title: "Terminated",
          counterparty: "TermCo",
          contract_type: "service",
          status: "terminated",
          end_date: soon
        })

      results = Corporate.expiring_contracts(30)
      refute Enum.any?(results, &(&1.title == "Terminated"))
    end
  end

  describe "contracts_by_counterparty/0" do
    test "groups contracts by counterparty with counts and totals" do
      company = company_fixture()

      Corporate.create_contract(%{
        company_id: company.id, title: "C1", counterparty: "Acme", contract_type: "nda", value: "10000"
      })

      Corporate.create_contract(%{
        company_id: company.id, title: "C2", counterparty: "Acme", contract_type: "service", value: "20000"
      })

      Corporate.create_contract(%{
        company_id: company.id, title: "C3", counterparty: "Globex", contract_type: "lease", value: "5000"
      })

      results = Corporate.contracts_by_counterparty()
      acme = Enum.find(results, &(&1.counterparty == "Acme"))
      assert acme.count == 2
      assert Decimal.equal?(acme.total_value, Decimal.new("30000"))
    end
  end

  describe "contract_summary/0" do
    test "returns summary by status and type with total value" do
      company = company_fixture()

      Corporate.create_contract(%{
        company_id: company.id, title: "A", counterparty: "X", contract_type: "nda", status: "active", value: "10000"
      })

      Corporate.create_contract(%{
        company_id: company.id, title: "B", counterparty: "Y", contract_type: "service", status: "active", value: "20000"
      })

      summary = Corporate.contract_summary()
      assert is_list(summary.by_status)
      assert is_list(summary.by_type)
      assert Enum.any?(summary.by_status, &(&1.status == "active"))
    end
  end

  # ══════════════════════════════════════════════════════════
  # LEI Record Tests
  # ══════════════════════════════════════════════════════════

  describe "lei_records CRUD" do
    test "create_lei_record/1 with valid data" do
      company = company_fixture()

      assert {:ok, lei} =
               Corporate.create_lei_record(%{
                 company_id: company.id,
                 lei_code: "529900T8BM49AURSDO55",
                 registration_status: "issued",
                 entity_status: "active",
                 legal_name: "Test Corp Ltd",
                 jurisdiction: "GB",
                 managing_lou: "Bloomberg Finance LP"
               })

      assert lei.lei_code == "529900T8BM49AURSDO55"
      assert lei.registration_status == "issued"
      assert lei.legal_name == "Test Corp Ltd"
    end

    test "create_lei_record/1 fails without required fields" do
      assert {:error, changeset} = Corporate.create_lei_record(%{})
      errors = errors_on(changeset)
      assert errors[:company_id]
      assert errors[:lei_code]
    end

    test "create_lei_record/1 validates lei_code length (must be 20)" do
      company = company_fixture()

      assert {:error, changeset} =
               Corporate.create_lei_record(%{
                 company_id: company.id,
                 lei_code: "SHORT"
               })

      assert errors_on(changeset)[:lei_code]
    end

    test "create_lei_record/1 validates registration_status enum" do
      company = company_fixture()

      assert {:error, changeset} =
               Corporate.create_lei_record(%{
                 company_id: company.id,
                 lei_code: "529900T8BM49AURSDO55",
                 registration_status: "invalid"
               })

      assert errors_on(changeset)[:registration_status]
    end

    test "create_lei_record/1 validates entity_status enum" do
      company = company_fixture()

      assert {:error, changeset} =
               Corporate.create_lei_record(%{
                 company_id: company.id,
                 lei_code: "529900T8BM49AURSDO55",
                 entity_status: "invalid"
               })

      assert errors_on(changeset)[:entity_status]
    end

    test "create_lei_record/1 enforces unique lei_code" do
      company = company_fixture()
      lei_code = "529900T8BM49AURSDO55"

      assert {:ok, _} =
               Corporate.create_lei_record(%{company_id: company.id, lei_code: lei_code})

      assert {:error, changeset} =
               Corporate.create_lei_record(%{company_id: company.id, lei_code: lei_code})

      assert errors_on(changeset)[:lei_code]
    end

    test "create_lei_record/1 with all registration statuses" do
      company = company_fixture()

      for {status, i} <- Enum.with_index(~w(pending issued lapsed retired)) do
        code = String.pad_trailing("LEI#{i}STATUS", 20, "0")

        assert {:ok, lei} =
                 Corporate.create_lei_record(%{
                   company_id: company.id,
                   lei_code: code,
                   registration_status: status
                 })

        assert lei.registration_status == status
      end
    end

    test "list_lei_records/0 returns all records" do
      lei = lei_record_fixture()
      results = Corporate.list_lei_records()
      assert Enum.any?(results, &(&1.id == lei.id))
    end

    test "list_lei_records/1 filters by company" do
      company = company_fixture()
      lei = lei_record_fixture(%{company: company})
      _other = lei_record_fixture()

      results = Corporate.list_lei_records(company.id)
      assert length(results) == 1
      assert hd(results).id == lei.id
    end

    test "get_lei_record!/1 returns the record with preloads" do
      lei = lei_record_fixture()
      fetched = Corporate.get_lei_record!(lei.id)
      assert fetched.id == lei.id
      assert fetched.company != nil
    end

    test "get_lei_record!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Corporate.get_lei_record!(0)
      end
    end

    test "update_lei_record/2 updates fields" do
      lei = lei_record_fixture()

      assert {:ok, updated} =
               Corporate.update_lei_record(lei, %{
                 registration_status: "lapsed",
                 notes: "Renewal missed"
               })

      assert updated.registration_status == "lapsed"
      assert updated.notes == "Renewal missed"
    end

    test "delete_lei_record/1 removes the record" do
      lei = lei_record_fixture()
      assert {:ok, _} = Corporate.delete_lei_record(lei)

      assert_raise Ecto.NoResultsError, fn ->
        Corporate.get_lei_record!(lei.id)
      end
    end
  end

  describe "lei_due_for_renewal/0" do
    test "returns LEI records due for renewal within 30 days" do
      company = company_fixture()
      soon = Date.add(Date.utc_today(), 15)
      far = Date.add(Date.utc_today(), 60)

      {:ok, due_soon} =
        Corporate.create_lei_record(%{
          company_id: company.id,
          lei_code: "DUESOON0000000000000",
          registration_status: "issued",
          next_renewal_date: soon
        })

      {:ok, _far_away} =
        Corporate.create_lei_record(%{
          company_id: company.id,
          lei_code: "FARAWAY0000000000000",
          registration_status: "issued",
          next_renewal_date: far
        })

      results = Corporate.lei_due_for_renewal()
      assert Enum.any?(results, &(&1.id == due_soon.id))
      refute Enum.any?(results, &(&1.lei_code == "FARAWAY0000000000000"))
    end

    test "excludes lapsed and retired records" do
      company = company_fixture()
      soon = Date.add(Date.utc_today(), 15)

      {:ok, _lapsed} =
        Corporate.create_lei_record(%{
          company_id: company.id,
          lei_code: "LAPSED00000000000000",
          registration_status: "lapsed",
          next_renewal_date: soon
        })

      results = Corporate.lei_due_for_renewal()
      refute Enum.any?(results, &(&1.lei_code == "LAPSED00000000000000"))
    end
  end

  # ══════════════════════════════════════════════════════════
  # Related Party Transaction Tests
  # ══════════════════════════════════════════════════════════

  describe "related_party_transactions CRUD" do
    test "create_related_party_transaction/1 with valid data" do
      company = company_fixture()

      assert {:ok, rpt} =
               Corporate.create_related_party_transaction(%{
                 company_id: company.id,
                 related_party_name: "SubCo Ltd",
                 relationship: "subsidiary",
                 transaction_type: "service",
                 transaction_date: "2024-06-15",
                 amount: "75000.00",
                 currency: "GBP",
                 arm_length_confirmation: true
               })

      assert rpt.related_party_name == "SubCo Ltd"
      assert rpt.relationship == "subsidiary"
      assert rpt.arm_length_confirmation == true
    end

    test "create_related_party_transaction/1 fails without required fields" do
      assert {:error, changeset} = Corporate.create_related_party_transaction(%{})
      errors = errors_on(changeset)
      assert errors[:company_id]
      assert errors[:related_party_name]
      assert errors[:relationship]
      assert errors[:transaction_type]
      assert errors[:transaction_date]
      assert errors[:amount]
    end

    test "create_related_party_transaction/1 validates relationship enum" do
      company = company_fixture()

      assert {:error, changeset} =
               Corporate.create_related_party_transaction(%{
                 company_id: company.id,
                 related_party_name: "Test",
                 relationship: "invalid",
                 transaction_type: "sale",
                 transaction_date: "2024-01-01",
                 amount: "1000"
               })

      assert errors_on(changeset)[:relationship]
    end

    test "create_related_party_transaction/1 validates transaction_type enum" do
      company = company_fixture()

      assert {:error, changeset} =
               Corporate.create_related_party_transaction(%{
                 company_id: company.id,
                 related_party_name: "Test",
                 relationship: "parent",
                 transaction_type: "invalid",
                 transaction_date: "2024-01-01",
                 amount: "1000"
               })

      assert errors_on(changeset)[:transaction_type]
    end

    test "create_related_party_transaction/1 validates disclosure_status enum" do
      company = company_fixture()

      assert {:error, changeset} =
               Corporate.create_related_party_transaction(%{
                 company_id: company.id,
                 related_party_name: "Test",
                 relationship: "parent",
                 transaction_type: "sale",
                 transaction_date: "2024-01-01",
                 amount: "1000",
                 disclosure_status: "invalid"
               })

      assert errors_on(changeset)[:disclosure_status]
    end

    test "create_related_party_transaction/1 validates amount > 0" do
      company = company_fixture()

      assert {:error, changeset} =
               Corporate.create_related_party_transaction(%{
                 company_id: company.id,
                 related_party_name: "Test",
                 relationship: "parent",
                 transaction_type: "sale",
                 transaction_date: "2024-01-01",
                 amount: "0"
               })

      assert errors_on(changeset)[:amount]
    end

    test "create_related_party_transaction/1 with all relationship types" do
      company = company_fixture()

      for rel <- ~w(parent subsidiary affiliate director officer shareholder family_member) do
        assert {:ok, rpt} =
                 Corporate.create_related_party_transaction(%{
                   company_id: company.id,
                   related_party_name: "Party #{rel}",
                   relationship: rel,
                   transaction_type: "sale",
                   transaction_date: "2024-01-01",
                   amount: "1000"
                 })

        assert rpt.relationship == rel
      end
    end

    test "list_related_party_transactions/0 returns all transactions" do
      rpt = related_party_transaction_fixture()
      results = Corporate.list_related_party_transactions()
      assert Enum.any?(results, &(&1.id == rpt.id))
    end

    test "list_related_party_transactions/1 filters by company" do
      company = company_fixture()
      rpt = related_party_transaction_fixture(%{company: company})
      _other = related_party_transaction_fixture()

      results = Corporate.list_related_party_transactions(company.id)
      assert length(results) == 1
      assert hd(results).id == rpt.id
    end

    test "get_related_party_transaction!/1 returns the transaction with preloads" do
      rpt = related_party_transaction_fixture()
      fetched = Corporate.get_related_party_transaction!(rpt.id)
      assert fetched.id == rpt.id
      assert fetched.company != nil
    end

    test "get_related_party_transaction!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Corporate.get_related_party_transaction!(0)
      end
    end

    test "update_related_party_transaction/2 updates fields" do
      rpt = related_party_transaction_fixture()

      assert {:ok, updated} =
               Corporate.update_related_party_transaction(rpt, %{
                 disclosure_status: "disclosed",
                 board_approval_reference: "BR-2024-001"
               })

      assert updated.disclosure_status == "disclosed"
      assert updated.board_approval_reference == "BR-2024-001"
    end

    test "delete_related_party_transaction/1 removes the transaction" do
      rpt = related_party_transaction_fixture()
      assert {:ok, _} = Corporate.delete_related_party_transaction(rpt)

      assert_raise Ecto.NoResultsError, fn ->
        Corporate.get_related_party_transaction!(rpt.id)
      end
    end
  end

  describe "related_party_summary/0" do
    test "returns summary by relationship type and transaction type" do
      company = company_fixture()

      Corporate.create_related_party_transaction(%{
        company_id: company.id, related_party_name: "A",
        relationship: "subsidiary", transaction_type: "sale",
        transaction_date: "2024-01-01", amount: "10000"
      })

      Corporate.create_related_party_transaction(%{
        company_id: company.id, related_party_name: "B",
        relationship: "subsidiary", transaction_type: "service",
        transaction_date: "2024-02-01", amount: "20000"
      })

      Corporate.create_related_party_transaction(%{
        company_id: company.id, related_party_name: "C",
        relationship: "director", transaction_type: "loan",
        transaction_date: "2024-03-01", amount: "5000"
      })

      summary = Corporate.related_party_summary()
      assert is_list(summary.by_relationship)
      assert is_list(summary.by_type)
      sub = Enum.find(summary.by_relationship, &(&1.relationship == "subsidiary"))
      assert sub.count == 2
      assert Decimal.equal?(sub.total_amount, Decimal.new("30000"))
    end

    test "related_party_summary/1 filters by company" do
      c1 = company_fixture()
      c2 = company_fixture()

      Corporate.create_related_party_transaction(%{
        company_id: c1.id, related_party_name: "A",
        relationship: "parent", transaction_type: "sale",
        transaction_date: "2024-01-01", amount: "10000"
      })

      Corporate.create_related_party_transaction(%{
        company_id: c2.id, related_party_name: "B",
        relationship: "parent", transaction_type: "sale",
        transaction_date: "2024-01-01", amount: "50000"
      })

      summary = Corporate.related_party_summary(c1.id)
      assert Decimal.equal?(summary.total_amount, Decimal.new("10000"))
    end
  end

  # ══════════════════════════════════════════════════════════
  # Conflict of Interest Tests
  # ══════════════════════════════════════════════════════════

  describe "conflicts_of_interest CRUD" do
    test "create_conflict_of_interest/1 with valid data" do
      company = company_fixture()

      assert {:ok, coi} =
               Governance.create_conflict_of_interest(%{
                 company_id: company.id,
                 declarant_name: "Jane Smith",
                 declarant_role: "director",
                 conflict_type: "financial",
                 description: "Owns 10% stake in competing firm",
                 declared_date: "2024-06-01",
                 parties_involved: "Competing Corp",
                 potential_impact: "Could influence procurement decisions"
               })

      assert coi.declarant_name == "Jane Smith"
      assert coi.conflict_type == "financial"
      assert coi.status == "declared"
    end

    test "create_conflict_of_interest/1 fails without required fields" do
      assert {:error, changeset} = Governance.create_conflict_of_interest(%{})
      errors = errors_on(changeset)
      assert errors[:company_id]
      assert errors[:declarant_name]
      assert errors[:declarant_role]
      assert errors[:conflict_type]
      assert errors[:description]
      assert errors[:declared_date]
    end

    test "create_conflict_of_interest/1 validates declarant_role enum" do
      company = company_fixture()

      assert {:error, changeset} =
               Governance.create_conflict_of_interest(%{
                 company_id: company.id,
                 declarant_name: "Test",
                 declarant_role: "invalid",
                 conflict_type: "financial",
                 description: "Test",
                 declared_date: "2024-01-01"
               })

      assert errors_on(changeset)[:declarant_role]
    end

    test "create_conflict_of_interest/1 validates conflict_type enum" do
      company = company_fixture()

      assert {:error, changeset} =
               Governance.create_conflict_of_interest(%{
                 company_id: company.id,
                 declarant_name: "Test",
                 declarant_role: "director",
                 conflict_type: "invalid",
                 description: "Test",
                 declared_date: "2024-01-01"
               })

      assert errors_on(changeset)[:conflict_type]
    end

    test "create_conflict_of_interest/1 validates status enum" do
      company = company_fixture()

      assert {:error, changeset} =
               Governance.create_conflict_of_interest(%{
                 company_id: company.id,
                 declarant_name: "Test",
                 declarant_role: "director",
                 conflict_type: "financial",
                 description: "Test",
                 declared_date: "2024-01-01",
                 status: "invalid"
               })

      assert errors_on(changeset)[:status]
    end

    test "create_conflict_of_interest/1 with all declarant roles" do
      company = company_fixture()

      for role <- ~w(director officer employee advisor) do
        assert {:ok, coi} =
                 Governance.create_conflict_of_interest(%{
                   company_id: company.id,
                   declarant_name: "Person #{role}",
                   declarant_role: role,
                   conflict_type: "financial",
                   description: "Test conflict for #{role}",
                   declared_date: "2024-01-01"
                 })

        assert coi.declarant_role == role
      end
    end

    test "create_conflict_of_interest/1 with all conflict types" do
      company = company_fixture()

      for ct <- ~w(financial personal professional organizational) do
        assert {:ok, coi} =
                 Governance.create_conflict_of_interest(%{
                   company_id: company.id,
                   declarant_name: "Person #{ct}",
                   declarant_role: "director",
                   conflict_type: ct,
                   description: "Test #{ct} conflict",
                   declared_date: "2024-01-01"
                 })

        assert coi.conflict_type == ct
      end
    end

    test "list_conflicts_of_interest/0 returns all conflicts" do
      coi = conflict_of_interest_fixture()
      results = Governance.list_conflicts_of_interest()
      assert Enum.any?(results, &(&1.id == coi.id))
    end

    test "list_conflicts_of_interest/1 filters by company" do
      company = company_fixture()
      coi = conflict_of_interest_fixture(%{company: company})
      _other = conflict_of_interest_fixture()

      results = Governance.list_conflicts_of_interest(company.id)
      assert length(results) == 1
      assert hd(results).id == coi.id
    end

    test "get_conflict_of_interest!/1 returns the conflict with preloads" do
      coi = conflict_of_interest_fixture()
      fetched = Governance.get_conflict_of_interest!(coi.id)
      assert fetched.id == coi.id
      assert fetched.company != nil
    end

    test "get_conflict_of_interest!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Governance.get_conflict_of_interest!(0)
      end
    end

    test "update_conflict_of_interest/2 updates fields" do
      coi = conflict_of_interest_fixture()

      assert {:ok, updated} =
               Governance.update_conflict_of_interest(coi, %{
                 status: "mitigated",
                 mitigation_plan: "Recused from procurement committee",
                 reviewer_name: "Board Secretary",
                 review_date: "2024-07-01"
               })

      assert updated.status == "mitigated"
      assert updated.mitigation_plan == "Recused from procurement committee"
      assert updated.reviewer_name == "Board Secretary"
    end

    test "delete_conflict_of_interest/1 removes the conflict" do
      coi = conflict_of_interest_fixture()
      assert {:ok, _} = Governance.delete_conflict_of_interest(coi)

      assert_raise Ecto.NoResultsError, fn ->
        Governance.get_conflict_of_interest!(coi.id)
      end
    end
  end

  describe "active_conflicts/0" do
    test "returns only active conflicts (declared, under_review, ongoing)" do
      company = company_fixture()

      {:ok, _declared} =
        Governance.create_conflict_of_interest(%{
          company_id: company.id, declarant_name: "A", declarant_role: "director",
          conflict_type: "financial", description: "Test", declared_date: "2024-01-01",
          status: "declared"
        })

      {:ok, _under_review} =
        Governance.create_conflict_of_interest(%{
          company_id: company.id, declarant_name: "B", declarant_role: "officer",
          conflict_type: "personal", description: "Test", declared_date: "2024-02-01",
          status: "under_review"
        })

      {:ok, _ongoing} =
        Governance.create_conflict_of_interest(%{
          company_id: company.id, declarant_name: "C", declarant_role: "employee",
          conflict_type: "professional", description: "Test", declared_date: "2024-03-01",
          status: "ongoing"
        })

      {:ok, _resolved} =
        Governance.create_conflict_of_interest(%{
          company_id: company.id, declarant_name: "D", declarant_role: "advisor",
          conflict_type: "organizational", description: "Test", declared_date: "2024-04-01",
          status: "resolved"
        })

      {:ok, _mitigated} =
        Governance.create_conflict_of_interest(%{
          company_id: company.id, declarant_name: "E", declarant_role: "director",
          conflict_type: "financial", description: "Test", declared_date: "2024-05-01",
          status: "mitigated"
        })

      results = Governance.active_conflicts(company.id)
      statuses = Enum.map(results, & &1.status)
      assert length(results) == 3
      assert "resolved" not in statuses
      assert "mitigated" not in statuses
    end

    test "active_conflicts/0 returns empty when all resolved" do
      company = company_fixture()

      {:ok, _resolved} =
        Governance.create_conflict_of_interest(%{
          company_id: company.id, declarant_name: "A", declarant_role: "director",
          conflict_type: "financial", description: "Test", declared_date: "2024-01-01",
          status: "resolved"
        })

      assert Governance.active_conflicts(company.id) == []
    end
  end

  describe "conflict_summary/0" do
    test "returns summary by status, type, and role" do
      company = company_fixture()

      Governance.create_conflict_of_interest(%{
        company_id: company.id, declarant_name: "A", declarant_role: "director",
        conflict_type: "financial", description: "Test A", declared_date: "2024-01-01"
      })

      Governance.create_conflict_of_interest(%{
        company_id: company.id, declarant_name: "B", declarant_role: "officer",
        conflict_type: "financial", description: "Test B", declared_date: "2024-02-01"
      })

      Governance.create_conflict_of_interest(%{
        company_id: company.id, declarant_name: "C", declarant_role: "director",
        conflict_type: "personal", description: "Test C", declared_date: "2024-03-01"
      })

      summary = Governance.conflict_summary(company.id)
      assert is_list(summary.by_status)
      assert is_list(summary.by_type)
      assert is_list(summary.by_role)

      financial = Enum.find(summary.by_type, &(&1.conflict_type == "financial"))
      assert financial.count == 2

      directors = Enum.find(summary.by_role, &(&1.declarant_role == "director"))
      assert directors.count == 2
    end
  end
end
