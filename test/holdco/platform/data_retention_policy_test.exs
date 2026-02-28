defmodule Holdco.Platform.DataRetentionPolicyTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Platform

  describe "data_retention_policies CRUD" do
    test "list_data_retention_policies/0 returns all policies" do
      policy = data_retention_policy_fixture()
      assert Enum.any?(Platform.list_data_retention_policies(), &(&1.id == policy.id))
    end

    test "get_data_retention_policy!/1 returns the policy" do
      policy = data_retention_policy_fixture()
      fetched = Platform.get_data_retention_policy!(policy.id)
      assert fetched.id == policy.id
    end

    test "get_data_retention_policy!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Platform.get_data_retention_policy!(0)
      end
    end

    test "create_data_retention_policy/1 with valid data" do
      assert {:ok, policy} =
               Platform.create_data_retention_policy(%{
                 name: "GDPR Personal Data",
                 description: "Retain personal data for compliance",
                 data_category: "personal_data",
                 retention_period_days: 730,
                 legal_basis: "legal_obligation",
                 action_on_expiry: "anonymize",
                 affected_tables: ["users", "contacts"]
               })

      assert policy.name == "GDPR Personal Data"
      assert policy.data_category == "personal_data"
      assert policy.retention_period_days == 730
      assert policy.legal_basis == "legal_obligation"
      assert policy.action_on_expiry == "anonymize"
      assert policy.affected_tables == ["users", "contacts"]
      assert policy.is_active == true
    end

    test "create_data_retention_policy/1 with all data categories" do
      for category <- ~w(personal_data financial_records audit_logs communications documents analytics) do
        assert {:ok, policy} =
                 Platform.create_data_retention_policy(%{
                   name: "Policy #{category}",
                   data_category: category,
                   retention_period_days: 365,
                   legal_basis: "consent",
                   action_on_expiry: "delete"
                 })

        assert policy.data_category == category
      end
    end

    test "create_data_retention_policy/1 with all legal bases" do
      for basis <- ~w(consent contract legal_obligation legitimate_interest public_interest) do
        assert {:ok, policy} =
                 Platform.create_data_retention_policy(%{
                   name: "Policy #{basis}",
                   data_category: "personal_data",
                   retention_period_days: 365,
                   legal_basis: basis,
                   action_on_expiry: "delete"
                 })

        assert policy.legal_basis == basis
      end
    end

    test "create_data_retention_policy/1 with all actions" do
      for action <- ~w(delete anonymize archive) do
        assert {:ok, policy} =
                 Platform.create_data_retention_policy(%{
                   name: "Policy #{action}",
                   data_category: "personal_data",
                   retention_period_days: 365,
                   legal_basis: "consent",
                   action_on_expiry: action
                 })

        assert policy.action_on_expiry == action
      end
    end

    test "create_data_retention_policy/1 fails without required fields" do
      assert {:error, changeset} = Platform.create_data_retention_policy(%{})
      errors = errors_on(changeset)
      assert errors[:name]
      assert errors[:data_category]
      assert errors[:retention_period_days]
      assert errors[:legal_basis]
      assert errors[:action_on_expiry]
    end

    test "create_data_retention_policy/1 fails with invalid data_category" do
      assert {:error, changeset} =
               Platform.create_data_retention_policy(%{
                 name: "Bad",
                 data_category: "invalid",
                 retention_period_days: 365,
                 legal_basis: "consent",
                 action_on_expiry: "delete"
               })

      assert errors_on(changeset)[:data_category]
    end

    test "create_data_retention_policy/1 fails with invalid legal_basis" do
      assert {:error, changeset} =
               Platform.create_data_retention_policy(%{
                 name: "Bad",
                 data_category: "personal_data",
                 retention_period_days: 365,
                 legal_basis: "invalid",
                 action_on_expiry: "delete"
               })

      assert errors_on(changeset)[:legal_basis]
    end

    test "create_data_retention_policy/1 fails with zero retention days" do
      assert {:error, changeset} =
               Platform.create_data_retention_policy(%{
                 name: "Zero",
                 data_category: "personal_data",
                 retention_period_days: 0,
                 legal_basis: "consent",
                 action_on_expiry: "delete"
               })

      assert errors_on(changeset)[:retention_period_days]
    end

    test "update_data_retention_policy/2 with valid data" do
      policy = data_retention_policy_fixture()

      assert {:ok, updated} =
               Platform.update_data_retention_policy(policy, %{
                 name: "Updated Policy",
                 retention_period_days: 1095,
                 is_active: false
               })

      assert updated.name == "Updated Policy"
      assert updated.retention_period_days == 1095
      assert updated.is_active == false
    end

    test "delete_data_retention_policy/1 removes the policy" do
      policy = data_retention_policy_fixture()
      assert {:ok, _} = Platform.delete_data_retention_policy(policy)

      assert_raise Ecto.NoResultsError, fn ->
        Platform.get_data_retention_policy!(policy.id)
      end
    end

    test "active_policies/0 returns only active policies" do
      active = data_retention_policy_fixture(%{is_active: true, name: "Active"})
      _inactive = data_retention_policy_fixture(%{is_active: false, name: "Inactive"})

      results = Platform.active_policies()
      assert Enum.any?(results, &(&1.id == active.id))
      refute Enum.any?(results, &(&1.is_active == false))
    end
  end

  describe "data_deletion_requests CRUD" do
    test "list_data_deletion_requests/0 returns all requests" do
      request = data_deletion_request_fixture()
      assert Enum.any?(Platform.list_data_deletion_requests(), &(&1.id == request.id))
    end

    test "get_data_deletion_request!/1 returns the request" do
      request = data_deletion_request_fixture()
      fetched = Platform.get_data_deletion_request!(request.id)
      assert fetched.id == request.id
    end

    test "create_data_deletion_request/1 with valid data" do
      assert {:ok, request} =
               Platform.create_data_deletion_request(%{
                 requested_by_email: "john@example.com",
                 request_type: "erasure",
                 reason: "User requested account deletion",
                 data_categories: ["personal_data", "communications"]
               })

      assert request.requested_by_email == "john@example.com"
      assert request.request_type == "erasure"
      assert request.status == "pending"
      assert request.data_categories == ["personal_data", "communications"]
    end

    test "create_data_deletion_request/1 with all request types" do
      for type <- ~w(erasure portability access rectification) do
        assert {:ok, req} =
                 Platform.create_data_deletion_request(%{
                   requested_by_email: "test_#{type}@example.com",
                   request_type: type
                 })

        assert req.request_type == type
      end
    end

    test "create_data_deletion_request/1 fails without required fields" do
      assert {:error, changeset} = Platform.create_data_deletion_request(%{})
      errors = errors_on(changeset)
      assert errors[:requested_by_email]
      assert errors[:request_type]
    end

    test "create_data_deletion_request/1 fails with invalid email" do
      assert {:error, changeset} =
               Platform.create_data_deletion_request(%{
                 requested_by_email: "not-an-email",
                 request_type: "erasure"
               })

      assert errors_on(changeset)[:requested_by_email]
    end

    test "update_data_deletion_request/2 changes status" do
      request = data_deletion_request_fixture()

      assert {:ok, updated} =
               Platform.update_data_deletion_request(request, %{status: "in_progress"})

      assert updated.status == "in_progress"
    end

    test "process_deletion_request/2 sets processed_at" do
      request = data_deletion_request_fixture()

      assert {:ok, processed} =
               Platform.process_deletion_request(request, %{
                 status: "completed",
                 processed_by_id: 1
               })

      assert processed.status == "completed"
      assert processed.processed_at != nil
      assert processed.processed_by_id == 1
    end

    test "process_deletion_request/2 can deny request" do
      request = data_deletion_request_fixture()

      assert {:ok, denied} =
               Platform.process_deletion_request(request, %{
                 status: "denied",
                 denial_reason: "Exemption applies"
               })

      assert denied.status == "denied"
      assert denied.denial_reason == "Exemption applies"
    end
  end
end
