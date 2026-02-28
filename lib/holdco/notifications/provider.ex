defmodule Holdco.Notifications.Provider do
  @moduledoc """
  Behaviour for notification provider plugins.

  Each provider must implement three callbacks:
  - `send_notification/2` to actually deliver the notification
  - `validate_config/1` to check provider-specific configuration
  - `provider_name/0` to return the provider identifier string
  """

  @callback send_notification(channel :: map(), notification :: map()) ::
              {:ok, map()} | {:error, String.t()}

  @callback validate_config(config :: map()) :: :ok | {:error, String.t()}

  @callback provider_name() :: String.t()
end
