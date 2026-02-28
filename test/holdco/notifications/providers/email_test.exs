defmodule Holdco.Notifications.Providers.EmailTest do
  use ExUnit.Case, async: true

  alias Holdco.Notifications.Providers.Email

  describe "provider_name/0" do
    test "returns email" do
      assert Email.provider_name() == "email"
    end
  end

  describe "validate_config/1" do
    test "accepts valid email" do
      config = %{"email" => "user@example.com"}
      assert :ok = Email.validate_config(config)
    end

    test "rejects empty config" do
      assert {:error, "Email address is required"} = Email.validate_config(%{})
    end

    test "rejects nil email" do
      config = %{"email" => nil}
      assert {:error, "Email address is required"} = Email.validate_config(config)
    end

    test "rejects empty string email" do
      config = %{"email" => ""}
      assert {:error, "Email address is required"} = Email.validate_config(config)
    end

    test "accepts any non-empty email string" do
      # Email format validation is not the provider's job — just presence
      config = %{"email" => "anything@test.org"}
      assert :ok = Email.validate_config(config)
    end
  end

  describe "send_notification/2" do
    test "creates email with correct fields" do
      # Test that the function builds and attempts to deliver
      # With Swoosh test adapter, this should succeed
      channel = %{config: %{"email" => "test@example.com"}}
      notification = %{title: "Test Subject", body: "Test body content"}

      result = Email.send_notification(channel, notification)
      # With Swoosh test adapter in test env, this should succeed
      assert {:ok, %{provider: "email"}} = result
    end

    test "handles nil body" do
      channel = %{config: %{"email" => "test@example.com"}}
      notification = %{title: "Subject Only", body: nil}

      result = Email.send_notification(channel, notification)
      assert {:ok, %{provider: "email"}} = result
    end
  end
end
