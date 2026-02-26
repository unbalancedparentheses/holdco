defmodule Holdco.Workers.PortfolioSnapshotWorker do
  use Oban.Worker, queue: :snapshots, max_attempts: 3

  alias Holdco.{Assets, Portfolio}

  @impl Oban.Worker
  def perform(_job) do
    nav = Portfolio.calculate_nav()
    today = Date.utc_today() |> Date.to_string()

    Assets.create_portfolio_snapshot(%{
      date: today,
      liquid: nav.liquid,
      marketable: nav.marketable,
      illiquid: nav.illiquid,
      liabilities: nav.liabilities,
      nav: nav.nav,
      currency: "USD"
    })

    :ok
  end
end
