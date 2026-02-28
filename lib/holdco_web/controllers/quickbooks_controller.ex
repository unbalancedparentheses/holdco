defmodule HoldcoWeb.QuickbooksController do
  use HoldcoWeb, :controller

  alias Holdco.Integrations.Quickbooks

  def connect(conn, %{"company_id" => company_id}) do
    {url, state} = Quickbooks.authorize_url()

    conn
    |> put_session(:qbo_company_id, company_id)
    |> put_session(:qbo_oauth_state, state)
    |> redirect(external: url)
  end

  def connect(conn, _params) do
    conn
    |> put_flash(:error, "Company ID is required to connect QuickBooks")
    |> redirect(to: ~p"/accounts/integrations")
  end

  def callback(conn, %{"code" => code, "realmId" => realm_id} = params) do
    company_id = get_session(conn, :qbo_company_id)
    expected_state = get_session(conn, :qbo_oauth_state)
    received_state = params["state"]

    cond do
      expected_state == nil or received_state != expected_state ->
        conn
        |> delete_session(:qbo_company_id)
        |> delete_session(:qbo_oauth_state)
        |> put_flash(:error, "OAuth state mismatch — possible CSRF attack. Please try again.")
        |> redirect(to: ~p"/accounts/integrations")

      company_id == nil ->
        conn
        |> delete_session(:qbo_oauth_state)
        |> put_flash(:error, "Missing company context for QuickBooks connection")
        |> redirect(to: ~p"/accounts/integrations")

      true ->
        do_callback(conn, code, realm_id, company_id)
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

  defp do_callback(conn, code, realm_id, company_id) do
    company_id = if is_binary(company_id), do: String.to_integer(company_id), else: company_id

    case Quickbooks.exchange_code(code, realm_id, company_id) do
      {:ok, _integration} ->
        conn
        |> delete_session(:qbo_company_id)
        |> delete_session(:qbo_oauth_state)
        |> put_flash(:info, "QuickBooks connected successfully")
        |> redirect(to: ~p"/companies/#{company_id}")

      {:error, reason} ->
        conn
        |> delete_session(:qbo_company_id)
        |> delete_session(:qbo_oauth_state)
        |> put_flash(:error, "Failed to connect QuickBooks: #{inspect(reason)}")
        |> redirect(to: ~p"/companies/#{company_id}")
    end
  end
end
