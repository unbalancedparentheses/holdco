defmodule Holdco.Workers.BankFeedSyncWorker do
  use Oban.Worker, queue: :bank_feeds, max_attempts: 3

  alias Holdco.Integrations
  alias Holdco.Integrations.Plaid

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    configs =
      Integrations.list_active_bank_feed_configs()
      |> Enum.filter(&(&1.provider == "plaid"))

    Enum.each(configs, fn config ->
      case Plaid.sync_transactions(config) do
        {:ok, %{synced: count}} ->
          Logger.info("BankFeedSyncWorker: synced #{count} transactions for config #{config.id}")

        {:error, reason} ->
          Logger.warning(
            "BankFeedSyncWorker: failed to sync config #{config.id}: #{inspect(reason)}"
          )
      end
    end)

    :ok
  end
end
