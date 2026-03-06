defmodule Holdco.Notifications.Providers.Email do
  @behaviour Holdco.Notifications.Provider
  import Swoosh.Email

  @impl true
  def provider_name, do: "email"

  @impl true
  def validate_config(config) do
    if is_binary(config["email"]) && config["email"] != "" do
      :ok
    else
      {:error, "Email address is required"}
    end
  end

  @impl true
  def send_notification(channel, notification) do
    email =
      new()
      |> to(channel.config["email"])
      |> from(Holdco.Config.mail_from())
      |> subject(notification.title)
      |> text_body(notification.body || "")

    case Holdco.Mailer.deliver(email) do
      {:ok, _} -> {:ok, %{provider: "email"}}
      {:error, err} -> {:error, "Email delivery failed: #{inspect(err)}"}
    end
  end
end
