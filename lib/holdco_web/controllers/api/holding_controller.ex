defmodule HoldcoWeb.Api.HoldingController do
  use HoldcoWeb, :controller

  alias Holdco.Assets

  def index(conn, _params) do
    holdings =
      Assets.list_holdings()
      |> Enum.map(&holding_json/1)

    json(conn, %{holdings: holdings})
  end

  defp holding_json(h) do
    %{
      id: h.id,
      asset: h.asset,
      ticker: h.ticker,
      asset_type: h.asset_type,
      quantity: h.quantity,
      currency: h.currency,
      company_id: h.company_id,
      company_name: if(h.company, do: h.company.name),
      inserted_at: h.inserted_at,
      updated_at: h.updated_at
    }
  end
end
