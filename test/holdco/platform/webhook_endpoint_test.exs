defmodule Holdco.Platform.WebhookEndpointTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Platform

  describe "webhook_endpoints CRUD" do
    test "list_webhook_endpoints/0 returns all endpoints" do
      endpoint = webhook_endpoint_fixture()
      assert Enum.any?(Platform.list_webhook_endpoints(), &(&1.id == endpoint.id))
    end

    test "get_webhook_endpoint!/1 returns the endpoint" do
      endpoint = webhook_endpoint_fixture()
      fetched = Platform.get_webhook_endpoint!(endpoint.id)
      assert fetched.id == endpoint.id
      assert fetched.url == endpoint.url
    end

    test "get_webhook_endpoint!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Platform.get_webhook_endpoint!(0)
      end
    end

    test "create_webhook_endpoint/1 with valid data" do
      assert {:ok, endpoint} =
               Platform.create_webhook_endpoint(%{
                 name: "My Webhook",
                 url: "https://example.com/hook",
                 secret_key: "mysecret",
                 events: ["create", "delete"],
                 max_retries: 5
               })

      assert endpoint.name == "My Webhook"
      assert endpoint.url == "https://example.com/hook"
      assert endpoint.events == ["create", "delete"]
      assert endpoint.max_retries == 5
      assert endpoint.is_active == true
      assert endpoint.failure_count == 0
    end

    test "create_webhook_endpoint/1 fails without required fields" do
      assert {:error, changeset} = Platform.create_webhook_endpoint(%{})
      errors = errors_on(changeset)
      assert errors[:url]
      assert errors[:name]
    end

    test "update_webhook_endpoint/2 with valid data" do
      endpoint = webhook_endpoint_fixture()

      assert {:ok, updated} =
               Platform.update_webhook_endpoint(endpoint, %{
                 name: "Updated Endpoint",
                 events: ["update"],
                 is_active: false,
                 last_response_code: 200
               })

      assert updated.name == "Updated Endpoint"
      assert updated.events == ["update"]
      assert updated.is_active == false
      assert updated.last_response_code == 200
    end

    test "delete_webhook_endpoint/1 removes the endpoint" do
      endpoint = webhook_endpoint_fixture()
      assert {:ok, _} = Platform.delete_webhook_endpoint(endpoint)

      assert_raise Ecto.NoResultsError, fn ->
        Platform.get_webhook_endpoint!(endpoint.id)
      end
    end

    test "active_endpoints_for_event/1 returns matching active endpoints" do
      _all = webhook_endpoint_fixture(%{events: [], is_active: true, name: "All Events", url: "https://all.com/hook"})
      create_only = webhook_endpoint_fixture(%{events: ["create"], is_active: true, name: "Create Only", url: "https://create.com/hook"})
      _inactive = webhook_endpoint_fixture(%{events: ["create"], is_active: false, name: "Inactive", url: "https://inactive.com/hook"})

      results = Platform.active_endpoints_for_event("create")
      assert Enum.any?(results, &(&1.id == create_only.id))
      refute Enum.any?(results, &(&1.is_active == false))
    end

    test "active_endpoints_for_event/1 includes endpoints with empty events list" do
      all_events = webhook_endpoint_fixture(%{events: [], is_active: true, name: "All", url: "https://all2.com/hook"})
      results = Platform.active_endpoints_for_event("anything")
      assert Enum.any?(results, &(&1.id == all_events.id))
    end
  end

  describe "webhook_deliveries" do
    test "list_webhook_deliveries/1 returns deliveries for endpoint" do
      endpoint = webhook_endpoint_fixture()
      delivery = webhook_delivery_fixture(%{endpoint: endpoint})
      deliveries = Platform.list_webhook_deliveries(endpoint.id)
      assert Enum.any?(deliveries, &(&1.id == delivery.id))
    end

    test "create_webhook_delivery/1 with valid data" do
      endpoint = webhook_endpoint_fixture()

      assert {:ok, delivery} =
               Platform.create_webhook_delivery(%{
                 endpoint_id: endpoint.id,
                 event_type: "update",
                 payload: %{"entity" => "company", "id" => 1},
                 status: "pending"
               })

      assert delivery.event_type == "update"
      assert delivery.payload == %{"entity" => "company", "id" => 1}
      assert delivery.status == "pending"
      assert delivery.attempts == 0
    end

    test "create_webhook_delivery/1 fails with invalid status" do
      endpoint = webhook_endpoint_fixture()

      assert {:error, changeset} =
               Platform.create_webhook_delivery(%{
                 endpoint_id: endpoint.id,
                 event_type: "test",
                 status: "invalid_status"
               })

      assert errors_on(changeset)[:status]
    end

    test "update_webhook_delivery/2 transitions status" do
      delivery = webhook_delivery_fixture()
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      assert {:ok, updated} =
               Platform.update_webhook_delivery(delivery, %{
                 status: "delivered",
                 attempts: 1,
                 response_code: 200,
                 delivered_at: now
               })

      assert updated.status == "delivered"
      assert updated.attempts == 1
      assert updated.response_code == 200
    end

    test "pending_deliveries/0 returns pending and retrying deliveries" do
      _delivered = webhook_delivery_fixture(%{status: "delivered"})
      pending = webhook_delivery_fixture(%{status: "pending"})
      retrying = webhook_delivery_fixture(%{status: "retrying"})

      results = Platform.pending_deliveries()
      result_ids = Enum.map(results, & &1.id)
      assert pending.id in result_ids
      assert retrying.id in result_ids
    end
  end
end
