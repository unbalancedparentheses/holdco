defmodule HoldcoWeb.QuickbooksController do
  use HoldcoWeb, :controller

  alias Holdco.Integrations.Quickbooks

  def connect(conn, %{"company_id" => company_id}) do
    conn
    |> put_session(:qbo_company_id, company_id)
    |> redirect(external: Quickbooks.authorize_url())
  end

  def connect(conn, _params) do
    conn
    |> put_flash(:error, "Company ID is required to connect QuickBooks")
    |> redirect(to: ~p"/accounts/integrations")
  end

  def callback(conn, %{"code" => code, "realmId" => realm_id}) do
    company_id = get_session(conn, :qbo_company_id)

    if company_id do
      company_id = if is_binary(company_id), do: String.to_integer(company_id), else: company_id

      case Quickbooks.exchange_code(code, realm_id, company_id) do
        {:ok, _integration} ->
          conn
          |> delete_session(:qbo_company_id)
          |> put_flash(:info, "QuickBooks connected successfully")
          |> redirect(to: ~p"/companies/#{company_id}")

        {:error, reason} ->
          conn
          |> delete_session(:qbo_company_id)
          |> put_flash(:error, "Failed to connect QuickBooks: #{inspect(reason)}")
          |> redirect(to: ~p"/companies/#{company_id}")
      end
    else
      conn
      |> put_flash(:error, "Missing company context for QuickBooks connection")
      |> redirect(to: ~p"/accounts/integrations")
    end
  end

  def callback(conn, %{"error" => error}) do
    company_id = get_session(conn, :qbo_company_id)
    conn = delete_session(conn, :qbo_company_id)

    redirect_path =
      if company_id, do: ~p"/companies/#{company_id}", else: ~p"/accounts/integrations"

    conn
    |> put_flash(:error, "QuickBooks authorization failed: #{error}")
    |> redirect(to: redirect_path)
  end
end
