defmodule Holdco.Notifications.Providers.Telegram do
  @behaviour Holdco.Notifications.Provider

  @impl true
  def provider_name, do: "telegram"

  @impl true
  def validate_config(config) do
    if is_binary(config["bot_token"]) && config["bot_token"] != "" &&
         config["chat_id"] != nil && to_string(config["chat_id"]) != "" do
      :ok
    else
      {:error, "Bot token and chat ID are required"}
    end
  end

  @impl true
  def send_notification(channel, notification) do
    bot_token = channel.config["bot_token"]
    chat_id = channel.config["chat_id"]
    url = "https://api.telegram.org/bot#{bot_token}/sendMessage"
    text = "*#{notification.title}*\n#{notification.body || ""}"

    case Req.post(url, json: %{chat_id: chat_id, text: text, parse_mode: "Markdown"}) do
      {:ok, %{status: 200}} -> {:ok, %{provider: "telegram"}}
      {:ok, resp} -> {:error, "Telegram returned status #{resp.status}"}
      {:error, err} -> {:error, "Telegram request failed: #{inspect(err)}"}
    end
  end
end
