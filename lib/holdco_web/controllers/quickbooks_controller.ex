defmodule HoldcoWeb.QuickbooksController do
  use HoldcoWeb, :controller

  alias Holdco.Integrations.Quickbooks

  def connect(conn, _params) do
    redirect(conn, external: Quickbooks.authorize_url())
  end

  def callback(conn, %{"code" => code, "realmId" => realm_id}) do
    case Quickbooks.exchange_code(code, realm_id) do
      {:ok, _integration} ->
        conn
        |> put_flash(:info, "QuickBooks connected successfully")
        |> redirect(to: ~p"/accounts/integrations")

      {:error, reason} ->
        conn
        |> put_flash(:error, "Failed to connect QuickBooks: #{inspect(reason)}")
        |> redirect(to: ~p"/accounts/integrations")
    end
  end

  def callback(conn, %{"error" => error}) do
    conn
    |> put_flash(:error, "QuickBooks authorization failed: #{error}")
    |> redirect(to: ~p"/accounts/integrations")
  end
end
