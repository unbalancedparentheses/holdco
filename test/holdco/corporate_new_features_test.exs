defmodule Holdco.CorporateNewFeaturesTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Corporate

  # ── Entity Lifecycle Tests ─────────────────────────────

  describe "entity_lifecycles" do
    test "list_entity_lifecycles/1 returns events for a company" do
      company = company_fixture()
      el = entity_lifecycle_fixture(%{company: company})
      results = Corporate.list_entity_lifecycles(company.id)
      assert Enum.any?(results, &(&1.id == el.id))
    end

    test "list_entity_lifecycles/1 returns empty for company with no events" do
      company = company_fixture()
      assert Corporate.list_entity_lifecycles(company.id) == []
    end

    test "list_entity_lifecycles/1 does not return events from other companies" do
      c1 = company_fixture()
      c2 = company_fixture()
      _el = entity_lifecycle_fixture(%{company: c1})
      assert Corporate.list_entity_lifecycles(c2.id) == []
    end

    test "get_entity_lifecycle!/1 returns the event" do
      el = entity_lifecycle_fixture()
      found = Corporate.get_entity_lifecycle!(el.id)
      assert found.id == el.id
      assert found.event_type == "incorporation"
    end

    test "get_entity_lifecycle!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Corporate.get_entity_lifecycle!(0)
      end
    end

    test "create_entity_lifecycle/1 with valid data" do
      company = company_fixture()

      assert {:ok, el} =
               Corporate.create_entity_lifecycle(%{
                 company_id: company.id,
                 event_type: "incorporation",
                 event_date: "2024-01-15",
                 jurisdiction: "Delaware",
                 status: "completed"
               })

      assert el.event_type == "incorporation"
      assert el.jurisdiction == "Delaware"
      assert el.status == "completed"
    end

    test "create_entity_lifecycle/1 with all event types" do
      company = company_fixture()

      for event_type <- ~w(incorporation registration amendment redomiciliation merger spin_off dissolution reinstatement name_change other) do
        assert {:ok, el} =
                 Corporate.create_entity_lifecycle(%{
                   company_id: company.id,
                   event_type: event_type,
                   event_date: "2024-01-15"
                 })

        assert el.event_type == event_type
      end
    end

    test "create_entity_lifecycle/1 fails without required fields" do
      assert {:error, changeset} = Corporate.create_entity_lifecycle(%{})
      errors = errors_on(changeset)
      assert errors[:company_id]
      assert errors[:event_type]
      assert errors[:event_date]
    end

    test "create_entity_lifecycle/1 fails with invalid event_type" do
      company = company_fixture()

      assert {:error, changeset} =
               Corporate.create_entity_lifecycle(%{
                 company_id: company.id,
                 event_type: "invalid_type",
                 event_date: "2024-01-15"
               })

      assert errors_on(changeset)[:event_type]
    end

    test "create_entity_lifecycle/1 fails with invalid status" do
      company = company_fixture()

      assert {:error, changeset} =
               Corporate.create_entity_lifecycle(%{
                 company_id: company.id,
                 event_type: "incorporation",
                 event_date: "2024-01-15",
                 status: "invalid_status"
               })

      assert errors_on(changeset)[:status]
    end

    test "create_entity_lifecycle/1 fails with invalid date format" do
      company = company_fixture()

      assert {:error, changeset} =
               Corporate.create_entity_lifecycle(%{
                 company_id: company.id,
                 event_type: "incorporation",
                 event_date: "not-a-date"
               })

      assert errors_on(changeset)[:event_date]
    end

    test "update_entity_lifecycle/2 updates fields" do
      el = entity_lifecycle_fixture()
      assert {:ok, updated} = Corporate.update_entity_lifecycle(el, %{status: "rejected", description: "Updated desc"})
      assert updated.status == "rejected"
      assert updated.description == "Updated desc"
    end

    test "delete_entity_lifecycle/1 removes the event" do
      el = entity_lifecycle_fixture()
      assert {:ok, _} = Corporate.delete_entity_lifecycle(el)

      assert_raise Ecto.NoResultsError, fn ->
        Corporate.get_entity_lifecycle!(el.id)
      end
    end

    test "entity_timeline/1 returns events in chronological order" do
      company = company_fixture()
      _el1 = entity_lifecycle_fixture(%{company: company, event_date: "2024-06-01", event_type: "amendment"})
      _el2 = entity_lifecycle_fixture(%{company: company, event_date: "2024-01-01", event_type: "incorporation"})
      _el3 = entity_lifecycle_fixture(%{company: company, event_date: "2024-12-01", event_type: "name_change"})

      timeline = Corporate.entity_timeline(company.id)
      dates = Enum.map(timeline, & &1.event_date)
      assert dates == Enum.sort(dates)
    end

    test "entity_timeline/1 returns empty for company with no events" do
      company = company_fixture()
      assert Corporate.entity_timeline(company.id) == []
    end

    test "create_entity_lifecycle/1 stores documents array" do
      company = company_fixture()

      assert {:ok, el} =
               Corporate.create_entity_lifecycle(%{
                 company_id: company.id,
                 event_type: "incorporation",
                 event_date: "2024-01-15",
                 documents: ["/docs/cert.pdf", "/docs/articles.pdf"]
               })

      assert el.documents == ["/docs/cert.pdf", "/docs/articles.pdf"]
    end
  end

  # ── Register Entry Tests ───────────────────────────────

  describe "register_entries" do
    test "list_register_entries/1 returns entries for a company" do
      company = company_fixture()
      re = register_entry_fixture(%{company: company})
      results = Corporate.list_register_entries(company.id)
      assert Enum.any?(results, &(&1.id == re.id))
    end

    test "list_register_entries/1 returns empty for company with no entries" do
      company = company_fixture()
      assert Corporate.list_register_entries(company.id) == []
    end

    test "get_register_entry!/1 returns the entry" do
      re = register_entry_fixture()
      found = Corporate.get_register_entry!(re.id)
      assert found.id == re.id
      assert found.register_type == "directors"
    end

    test "get_register_entry!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Corporate.get_register_entry!(0)
      end
    end

    test "create_register_entry/1 with valid data" do
      company = company_fixture()

      assert {:ok, re} =
               Corporate.create_register_entry(%{
                 company_id: company.id,
                 register_type: "directors",
                 entry_date: "2024-01-15",
                 person_name: "John Smith",
                 role_or_description: "Executive Director",
                 appointment_date: "2024-01-15"
               })

      assert re.person_name == "John Smith"
      assert re.register_type == "directors"
    end

    test "create_register_entry/1 with all register types" do
      company = company_fixture()

      for register_type <- ~w(directors shareholders charges mortgages debentures beneficial_owners secretary auditors registered_office) do
        assert {:ok, re} =
                 Corporate.create_register_entry(%{
                   company_id: company.id,
                   register_type: register_type,
                   entry_date: "2024-01-15"
                 })

        assert re.register_type == register_type
      end
    end

    test "create_register_entry/1 fails without required fields" do
      assert {:error, changeset} = Corporate.create_register_entry(%{})
      errors = errors_on(changeset)
      assert errors[:company_id]
      assert errors[:register_type]
      assert errors[:entry_date]
    end

    test "create_register_entry/1 fails with invalid register_type" do
      company = company_fixture()

      assert {:error, changeset} =
               Corporate.create_register_entry(%{
                 company_id: company.id,
                 register_type: "invalid_type",
                 entry_date: "2024-01-15"
               })

      assert errors_on(changeset)[:register_type]
    end

    test "create_register_entry/1 fails with invalid date format" do
      company = company_fixture()

      assert {:error, changeset} =
               Corporate.create_register_entry(%{
                 company_id: company.id,
                 register_type: "directors",
                 entry_date: "bad-date"
               })

      assert errors_on(changeset)[:entry_date]
    end

    test "create_register_entry/1 with shareholder fields" do
      company = company_fixture()

      assert {:ok, re} =
               Corporate.create_register_entry(%{
                 company_id: company.id,
                 register_type: "shareholders",
                 entry_date: "2024-01-15",
                 person_name: "Investor A",
                 shares_held: 10_000,
                 share_class: "Common"
               })

      assert Decimal.equal?(re.shares_held, Decimal.new(10_000))
      assert re.share_class == "Common"
    end

    test "create_register_entry/1 rejects negative shares" do
      company = company_fixture()

      assert {:error, changeset} =
               Corporate.create_register_entry(%{
                 company_id: company.id,
                 register_type: "shareholders",
                 entry_date: "2024-01-15",
                 shares_held: -100
               })

      assert errors_on(changeset)[:shares_held]
    end

    test "update_register_entry/2 updates fields" do
      re = register_entry_fixture()

      assert {:ok, updated} =
               Corporate.update_register_entry(re, %{
                 person_name: "Jane Doe",
                 role_or_description: "Non-Executive Director"
               })

      assert updated.person_name == "Jane Doe"
      assert updated.role_or_description == "Non-Executive Director"
    end

    test "delete_register_entry/1 removes the entry" do
      re = register_entry_fixture()
      assert {:ok, _} = Corporate.delete_register_entry(re)

      assert_raise Ecto.NoResultsError, fn ->
        Corporate.get_register_entry!(re.id)
      end
    end

    test "current_register/2 returns only current entries for a type" do
      company = company_fixture()

      _current =
        register_entry_fixture(%{
          company: company,
          register_type: "directors",
          status: "current",
          person_name: "Active Director"
        })

      _historical =
        register_entry_fixture(%{
          company: company,
          register_type: "directors",
          status: "historical",
          person_name: "Former Director"
        })

      results = Corporate.current_register(company.id, "directors")
      assert length(results) == 1
      assert hd(results).person_name == "Active Director"
    end

    test "current_register/2 returns empty for a type with no current entries" do
      company = company_fixture()

      _historical =
        register_entry_fixture(%{
          company: company,
          register_type: "secretary",
          status: "historical"
        })

      assert Corporate.current_register(company.id, "secretary") == []
    end

    test "register_summary/1 returns counts per register type" do
      company = company_fixture()
      register_entry_fixture(%{company: company, register_type: "directors"})
      register_entry_fixture(%{company: company, register_type: "directors"})
      register_entry_fixture(%{company: company, register_type: "shareholders"})

      summary = Corporate.register_summary(company.id)
      assert summary["directors"] == 2
      assert summary["shareholders"] == 1
    end

    test "register_summary/1 returns empty map for company with no entries" do
      company = company_fixture()
      assert Corporate.register_summary(company.id) == %{}
    end
  end

  # ── Corporate Action Tests ─────────────────────────────

  describe "corporate_actions" do
    test "list_corporate_actions/1 returns actions for a company" do
      company = company_fixture()
      ca = corporate_action_fixture(%{company: company})
      results = Corporate.list_corporate_actions(company.id)
      assert Enum.any?(results, &(&1.id == ca.id))
    end

    test "list_corporate_actions/1 returns empty for company with no actions" do
      company = company_fixture()
      assert Corporate.list_corporate_actions(company.id) == []
    end

    test "get_corporate_action!/1 returns the action" do
      ca = corporate_action_fixture()
      found = Corporate.get_corporate_action!(ca.id)
      assert found.id == ca.id
      assert found.action_type == "stock_split"
    end

    test "get_corporate_action!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Corporate.get_corporate_action!(0)
      end
    end

    test "create_corporate_action/1 with valid data" do
      company = company_fixture()

      assert {:ok, ca} =
               Corporate.create_corporate_action(%{
                 company_id: company.id,
                 action_type: "stock_split",
                 announcement_date: "2024-01-01",
                 record_date: "2024-01-15",
                 effective_date: "2024-02-01",
                 description: "2-for-1 split",
                 ratio_numerator: 2,
                 ratio_denominator: 1,
                 status: "announced"
               })

      assert ca.action_type == "stock_split"
      assert ca.ratio_numerator == 2
      assert ca.ratio_denominator == 1
    end

    test "create_corporate_action/1 with all action types" do
      company = company_fixture()

      for action_type <- ~w(stock_split reverse_split merger acquisition spin_off tender_offer rights_issue buyback dividend_reinvestment delisting) do
        assert {:ok, ca} =
                 Corporate.create_corporate_action(%{
                   company_id: company.id,
                   action_type: action_type
                 })

        assert ca.action_type == action_type
      end
    end

    test "create_corporate_action/1 fails without required fields" do
      assert {:error, changeset} = Corporate.create_corporate_action(%{})
      errors = errors_on(changeset)
      assert errors[:company_id]
      assert errors[:action_type]
    end

    test "create_corporate_action/1 fails with invalid action_type" do
      company = company_fixture()

      assert {:error, changeset} =
               Corporate.create_corporate_action(%{
                 company_id: company.id,
                 action_type: "invalid_type"
               })

      assert errors_on(changeset)[:action_type]
    end

    test "create_corporate_action/1 fails with invalid status" do
      company = company_fixture()

      assert {:error, changeset} =
               Corporate.create_corporate_action(%{
                 company_id: company.id,
                 action_type: "merger",
                 status: "bad_status"
               })

      assert errors_on(changeset)[:status]
    end

    test "create_corporate_action/1 with monetary values" do
      company = company_fixture()

      assert {:ok, ca} =
               Corporate.create_corporate_action(%{
                 company_id: company.id,
                 action_type: "tender_offer",
                 price_per_share: "45.50",
                 total_value: "1000000.00",
                 currency: "EUR"
               })

      assert Decimal.equal?(ca.price_per_share, Decimal.new("45.50"))
      assert Decimal.equal?(ca.total_value, Decimal.new("1000000.00"))
      assert ca.currency == "EUR"
    end

    test "create_corporate_action/1 fails with invalid date format" do
      company = company_fixture()

      assert {:error, changeset} =
               Corporate.create_corporate_action(%{
                 company_id: company.id,
                 action_type: "merger",
                 announcement_date: "not-valid"
               })

      assert errors_on(changeset)[:announcement_date]
    end

    test "update_corporate_action/2 updates fields" do
      ca = corporate_action_fixture()

      assert {:ok, updated} =
               Corporate.update_corporate_action(ca, %{
                 status: "completed",
                 completion_date: "2024-03-01",
                 description: "Completed split"
               })

      assert updated.status == "completed"
      assert updated.completion_date == "2024-03-01"
      assert updated.description == "Completed split"
    end

    test "delete_corporate_action/1 removes the action" do
      ca = corporate_action_fixture()
      assert {:ok, _} = Corporate.delete_corporate_action(ca)

      assert_raise Ecto.NoResultsError, fn ->
        Corporate.get_corporate_action!(ca.id)
      end
    end

    test "pending_actions/1 returns actions not completed or cancelled" do
      company = company_fixture()
      _announced = corporate_action_fixture(%{company: company, status: "announced"})
      _approved = corporate_action_fixture(%{company: company, status: "approved", action_type: "merger"})
      _in_progress = corporate_action_fixture(%{company: company, status: "in_progress", action_type: "acquisition"})
      _completed = corporate_action_fixture(%{company: company, status: "completed", action_type: "buyback"})
      _cancelled = corporate_action_fixture(%{company: company, status: "cancelled", action_type: "delisting"})

      pending = Corporate.pending_actions(company.id)
      statuses = Enum.map(pending, & &1.status)
      assert length(pending) == 3
      assert "completed" not in statuses
      assert "cancelled" not in statuses
    end

    test "pending_actions/1 returns empty when all completed" do
      company = company_fixture()
      _completed = corporate_action_fixture(%{company: company, status: "completed"})

      assert Corporate.pending_actions(company.id) == []
    end

    test "pending_actions/1 returns empty for company with no actions" do
      company = company_fixture()
      assert Corporate.pending_actions(company.id) == []
    end
  end
end
