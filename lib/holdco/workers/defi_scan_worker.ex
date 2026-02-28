defmodule Holdco.Workers.DefiScanWorker do
  @moduledoc """
  Oban worker that periodically scans all active DeFi positions,
  refreshing on-chain balances and token prices.

  Scheduled hourly via Oban cron; can also be enqueued on-demand
  from the DeFi Positions LiveView.
  """

  use Oban.Worker, queue: :default, max_attempts: 3

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    result = Holdco.Integrations.DefiScanner.scan_all_positions()

    {:ok, summary} = result
    Logger.info("DeFi scan complete: #{summary.updated} updated, #{summary.errors} errors")
    :ok
  end
end
