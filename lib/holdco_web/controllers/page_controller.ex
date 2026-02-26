defmodule HoldcoWeb.PageController do
  use HoldcoWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
