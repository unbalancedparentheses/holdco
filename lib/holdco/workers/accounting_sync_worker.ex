defmodule Holdco.Workers.AccountingSyncWorker do
  @moduledoc """
  Oban worker that syncs accounting data from Xero and QuickBooks.
  Runs every 6 hours, processes all active AccountingSyncConfig records.
  """
  use Oban.Worker, queue: :default, max_attempts: 3

  alias Holdco.Integrations
  alias Holdco.Integrations.{Xero, Quickbooks}

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    configs = Integrations.list_accounting_sync_configs()

    for config <- configs, config.is_active do
      sync_config(config)
    end

    :ok
  end

  defp sync_config(config) do
    {:ok, log} =
      Integrations.create_accounting_sync_log(%{
        config_id: config.id,
        status: "running"
      })

    case do_sync(config) do
      {:ok, results} ->
        records = count_records(results)

        Integrations.update_accounting_sync_log(log, %{
          status: "completed",
          records_synced: records,
          completed_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

        Integrations.update_accounting_sync_config(config, %{
          last_sync_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      {:error, reason} ->
        Integrations.update_accounting_sync_log(log, %{
          status: "failed",
          error_message: inspect(reason),
          completed_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })
    end
  rescue
    e ->
      Logger.error("AccountingSyncWorker error for config #{config.id}: #{Exception.message(e)}")
  end

  defp do_sync(%{provider: "xero", company_id: company_id}), do: Xero.sync_all(company_id)
  defp do_sync(%{provider: "quickbooks", company_id: company_id}), do: Quickbooks.sync_all(company_id)
  defp do_sync(%{provider: provider}), do: {:error, "Unknown provider: #{provider}"}

  defp count_records(%{accounts: {:ok, a}, journal_entries: {:ok, j}}), do: a + j
  defp count_records(%{accounts: {:ok, a}}), do: a
  defp count_records(%{journal_entries: {:ok, j}}), do: j
  defp count_records(_), do: 0
end
