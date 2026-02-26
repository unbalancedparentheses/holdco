defmodule HoldcoWeb.Api.PortfolioController do
  use HoldcoWeb, :controller

  alias Holdco.Portfolio

  def index(conn, _params) do
    json(conn, Portfolio.calculate_nav())
  end

  def allocation(conn, _params) do
    json(conn, Portfolio.asset_allocation())
  end

  def fx_exposure(conn, _params) do
    json(conn, Portfolio.fx_exposure())
  end
end
