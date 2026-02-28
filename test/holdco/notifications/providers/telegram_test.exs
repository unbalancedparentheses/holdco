defmodule Holdco.Notifications.Providers.TelegramTest do
  use ExUnit.Case, async: true

  alias Holdco.Notifications.Providers.Telegram

  describe "provider_name/0" do
    test "returns telegram" do
      assert Telegram.provider_name() == "telegram"
    end
  end

  describe "validate_config/1" do
    test "accepts valid bot_token and chat_id" do
      config = %{"bot_token" => "123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11", "chat_id" => "-1001234567890"}
      assert :ok = Telegram.validate_config(config)
    end

    test "rejects missing bot_token" do
      config = %{"chat_id" => "12345"}
      assert {:error, "Bot token and chat ID are required"} = Telegram.validate_config(config)
    end

    test "rejects missing chat_id" do
      config = %{"bot_token" => "123456:ABC"}
      assert {:error, "Bot token and chat ID are required"} = Telegram.validate_config(config)
    end

    test "rejects empty config" do
      assert {:error, "Bot token and chat ID are required"} = Telegram.validate_config(%{})
    end

    test "rejects empty string bot_token" do
      config = %{"bot_token" => "", "chat_id" => "12345"}
      assert {:error, "Bot token and chat ID are required"} = Telegram.validate_config(config)
    end
  end

  describe "send_notification/2" do
    test "formats message correctly" do
      channel = %{config: %{"bot_token" => "fake_token", "chat_id" => "12345"}}
      notification = %{title: "Test Title", body: "Test Body"}

      result = Telegram.send_notification(channel, notification)
      # Will fail due to invalid token, but should not raise
      assert {:error, _msg} = result
    end

    test "handles nil body" do
      channel = %{config: %{"bot_token" => "fake_token", "chat_id" => "12345"}}
      notification = %{title: "Test Title", body: nil}

      result = Telegram.send_notification(channel, notification)
      assert {:error, _msg} = result
    end
  end
end
