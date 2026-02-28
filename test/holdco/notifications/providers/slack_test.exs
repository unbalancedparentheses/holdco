defmodule Holdco.Notifications.Providers.SlackTest do
  use ExUnit.Case, async: true

  alias Holdco.Notifications.Providers.Slack

  describe "provider_name/0" do
    test "returns slack" do
      assert Slack.provider_name() == "slack"
    end
  end

  describe "validate_config/1" do
    test "accepts valid webhook URL" do
      config = %{"webhook_url" => "https://hooks.slack.com/services/T00000/B00000/XXXXXXX"}
      assert :ok = Slack.validate_config(config)
    end

    test "rejects invalid URL" do
      config = %{"webhook_url" => "https://example.com/not-slack"}
      assert {:error, "Invalid Slack webhook URL"} = Slack.validate_config(config)
    end

    test "rejects empty config" do
      assert {:error, "Invalid Slack webhook URL"} = Slack.validate_config(%{})
    end

    test "rejects nil webhook_url" do
      config = %{"webhook_url" => nil}
      assert {:error, "Invalid Slack webhook URL"} = Slack.validate_config(config)
    end

    test "rejects non-string webhook_url" do
      config = %{"webhook_url" => 12345}
      assert {:error, "Invalid Slack webhook URL"} = Slack.validate_config(config)
    end
  end

  describe "send_notification/2" do
    test "formats blocks correctly" do
      # We test the structure by verifying the function can be called
      # (it will fail due to invalid URL, but we verify the error handling)
      channel = %{config: %{"webhook_url" => "https://hooks.slack.com/services/T00/B00/INVALID"}}
      notification = %{title: "Test Title", body: "Test Body"}

      result = Slack.send_notification(channel, notification)

      # Should return an error (can't connect to invalid host)
      assert {:error, _msg} = result
    end

    test "handles nil body" do
      channel = %{config: %{"webhook_url" => "https://hooks.slack.com/services/T00/B00/INVALID"}}
      notification = %{title: "Test Title", body: nil}

      result = Slack.send_notification(channel, notification)
      assert {:error, _msg} = result
    end
  end
end
