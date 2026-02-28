defmodule Holdco.ServiceAgreementTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Finance

  defp d(val) when is_struct(val, Decimal), do: Decimal.to_float(val)
  defp d(val) when is_number(val), do: val / 1
  defp d(nil), do: 0.0

  describe "service_agreements CRUD" do
    test "create_service_agreement/1 with valid data" do
      provider = company_fixture(%{name: "Provider Co"})
      recipient = company_fixture(%{name: "Recipient Co"})

      attrs = %{
        provider_company_id: provider.id,
        recipient_company_id: recipient.id,
        agreement_type: "management_fee",
        amount: 10_000.0,
        currency: "USD",
        frequency: "monthly",
        start_date: "2024-01-01",
        end_date: "2024-12-31",
        status: "active",
        transfer_pricing_method: "cost_plus",
        markup_pct: 5.0,
        description: "Monthly management services",
        arm_length_basis: "Comparable market rates",
        notes: "Test agreement"
      }

      assert {:ok, sa} = Finance.create_service_agreement(attrs)
      assert sa.provider_company_id == provider.id
      assert sa.recipient_company_id == recipient.id
      assert sa.agreement_type == "management_fee"
      assert d(sa.amount) == 10_000.0
      assert sa.currency == "USD"
      assert sa.frequency == "monthly"
      assert sa.status == "active"
      assert sa.transfer_pricing_method == "cost_plus"
    end

    test "create_service_agreement/1 with invalid data" do
      assert {:error, cs} = Finance.create_service_agreement(%{})
      assert errors_on(cs)[:provider_company_id]
      assert errors_on(cs)[:recipient_company_id]
      assert errors_on(cs)[:agreement_type]
      assert errors_on(cs)[:amount]
    end

    test "create_service_agreement/1 rejects same provider and recipient" do
      company = company_fixture()

      attrs = %{
        provider_company_id: company.id,
        recipient_company_id: company.id,
        agreement_type: "management_fee",
        amount: 10_000.0
      }

      assert {:error, cs} = Finance.create_service_agreement(attrs)
      assert errors_on(cs)[:recipient_company_id]
    end

    test "create_service_agreement/1 rejects invalid agreement_type" do
      provider = company_fixture()
      recipient = company_fixture()

      attrs = %{
        provider_company_id: provider.id,
        recipient_company_id: recipient.id,
        agreement_type: "invalid_type",
        amount: 10_000.0
      }

      assert {:error, cs} = Finance.create_service_agreement(attrs)
      assert errors_on(cs)[:agreement_type]
    end

    test "create_service_agreement/1 rejects negative amount" do
      provider = company_fixture()
      recipient = company_fixture()

      attrs = %{
        provider_company_id: provider.id,
        recipient_company_id: recipient.id,
        agreement_type: "licensing",
        amount: -100.0
      }

      assert {:error, cs} = Finance.create_service_agreement(attrs)
      assert errors_on(cs)[:amount]
    end

    test "list_service_agreements/0 returns all agreements" do
      sa = service_agreement_fixture()
      agreements = Finance.list_service_agreements()
      assert Enum.any?(agreements, &(&1.id == sa.id))
    end

    test "list_service_agreements/1 filters by company_id (as provider)" do
      provider = company_fixture()
      recipient = company_fixture()
      sa = service_agreement_fixture(%{provider_company: provider, recipient_company: recipient})
      _other = service_agreement_fixture()

      agreements = Finance.list_service_agreements(provider.id)
      assert Enum.any?(agreements, &(&1.id == sa.id))
    end

    test "list_service_agreements/1 filters by company_id (as recipient)" do
      provider = company_fixture()
      recipient = company_fixture()
      sa = service_agreement_fixture(%{provider_company: provider, recipient_company: recipient})

      agreements = Finance.list_service_agreements(recipient.id)
      assert Enum.any?(agreements, &(&1.id == sa.id))
    end

    test "get_service_agreement!/1 returns the agreement" do
      sa = service_agreement_fixture()
      fetched = Finance.get_service_agreement!(sa.id)
      assert fetched.id == sa.id
      assert fetched.provider_company != nil
      assert fetched.recipient_company != nil
    end

    test "update_service_agreement/2 with valid data" do
      sa = service_agreement_fixture()
      {:ok, updated} = Finance.update_service_agreement(sa, %{status: "terminated", amount: 20_000.0})
      assert updated.status == "terminated"
      assert d(updated.amount) == 20_000.0
    end

    test "update_service_agreement/2 with invalid data" do
      sa = service_agreement_fixture()
      assert {:error, _cs} = Finance.update_service_agreement(sa, %{agreement_type: "invalid"})
    end

    test "delete_service_agreement/1 removes the record" do
      sa = service_agreement_fixture()
      {:ok, _} = Finance.delete_service_agreement(sa)
      assert_raise Ecto.NoResultsError, fn -> Finance.get_service_agreement!(sa.id) end
    end
  end

  describe "service_agreement_summary/1" do
    test "returns summary with inflows, outflows, and breakdown by type" do
      provider = company_fixture(%{name: "Provider"})
      recipient = company_fixture(%{name: "Recipient"})

      # Provider provides services to recipient (outflow from provider's perspective)
      service_agreement_fixture(%{
        provider_company: provider,
        recipient_company: recipient,
        agreement_type: "management_fee",
        amount: 5_000.0
      })

      service_agreement_fixture(%{
        provider_company: provider,
        recipient_company: recipient,
        agreement_type: "licensing",
        amount: 3_000.0
      })

      # Provider receives services from another company (inflow)
      other = company_fixture(%{name: "Other"})

      service_agreement_fixture(%{
        provider_company: other,
        recipient_company: provider,
        agreement_type: "shared_services",
        amount: 2_000.0
      })

      summary = Finance.service_agreement_summary(provider.id)

      assert summary.total_agreements == 3
      assert d(summary.total_inflows) == 2_000.0
      assert d(summary.total_outflows) == 8_000.0
      assert d(summary.net) == -6_000.0
      assert length(summary.by_type) == 3
    end

    test "returns empty summary for company with no agreements" do
      company = company_fixture()
      summary = Finance.service_agreement_summary(company.id)

      assert summary.total_agreements == 0
      assert d(summary.total_inflows) == 0.0
      assert d(summary.total_outflows) == 0.0
      assert summary.by_type == []
    end
  end

  describe "service agreement types and statuses" do
    test "accepts all valid agreement types" do
      provider = company_fixture()
      recipient = company_fixture()

      for type <- ~w(management_fee shared_services licensing royalty cost_sharing other) do
        assert {:ok, _} =
          Finance.create_service_agreement(%{
            provider_company_id: provider.id,
            recipient_company_id: recipient.id,
            agreement_type: type,
            amount: 1_000.0
          })
      end
    end

    test "accepts all valid transfer pricing methods" do
      provider = company_fixture()
      recipient = company_fixture()

      for method <- ~w(comparable_uncontrolled resale_price cost_plus profit_split tnmm) do
        assert {:ok, _} =
          Finance.create_service_agreement(%{
            provider_company_id: provider.id,
            recipient_company_id: recipient.id,
            agreement_type: "management_fee",
            amount: 1_000.0,
            transfer_pricing_method: method
          })
      end
    end

    test "accepts all valid frequencies" do
      provider = company_fixture()
      recipient = company_fixture()

      for freq <- ~w(monthly quarterly annually) do
        assert {:ok, _} =
          Finance.create_service_agreement(%{
            provider_company_id: provider.id,
            recipient_company_id: recipient.id,
            agreement_type: "management_fee",
            amount: 1_000.0,
            frequency: freq
          })
      end
    end
  end
end
