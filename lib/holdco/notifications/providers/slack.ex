defmodule Holdco.Notifications.Providers.Slack do
  @behaviour Holdco.Notifications.Provider

  @impl true
  def provider_name, do: "slack"

  @impl true
  def validate_config(config) do
    if is_binary(config["webhook_url"]) &&
         String.starts_with?(config["webhook_url"], "https://hooks.slack.com/") do
      :ok
    else
      {:error, "Invalid Slack webhook URL"}
    end
  end

  @impl true
  def send_notification(channel, notification) do
    webhook_url = channel.config["webhook_url"]

    body =
      Jason.encode!(%{
        text: notification.title,
        blocks: [
          %{type: "header", text: %{type: "plain_text", text: notification.title}},
          %{type: "section", text: %{type: "mrkdwn", text: notification.body || ""}}
        ]
      })

    case Req.post(webhook_url, body: body, headers: [{"content-type", "application/json"}]) do
      {:ok, %{status: 200}} -> {:ok, %{provider: "slack"}}
      {:ok, resp} -> {:error, "Slack returned status #{resp.status}"}
      {:error, err} -> {:error, "Slack request failed: #{inspect(err)}"}
    end
  end
end
