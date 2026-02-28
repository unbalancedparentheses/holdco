defmodule HoldcoWeb.XeroController do
  use HoldcoWeb, :controller

  alias Holdco.Integrations.Xero

  def connect(conn, %{"company_id" => company_id}) do
    {url, state} = Xero.authorize_url()

    conn
    |> put_session(:xero_company_id, company_id)
    |> put_session(:xero_oauth_state, state)
    |> redirect(external: url)
  end

  def connect(conn, _params) do
    conn
    |> put_flash(:error, "Company ID is required to connect Xero")
    |> redirect(to: ~p"/accounts/integrations")
  end

  def callback(conn, %{"code" => code} = params) do
    company_id = get_session(conn, :xero_company_id)
    expected_state = get_session(conn, :xero_oauth_state)
    received_state = params["state"]

    cond do
      expected_state == nil or received_state != expected_state ->
        conn
        |> delete_session(:xero_company_id)
        |> delete_session(:xero_oauth_state)
        |> put_flash(:error, "OAuth state mismatch -- possible CSRF attack. Please try again.")
        |> redirect(to: ~p"/accounts/integrations")

      company_id == nil ->
        conn
        |> delete_session(:xero_oauth_state)
        |> put_flash(:error, "Missing company context for Xero connection")
        |> redirect(to: ~p"/accounts/integrations")

      true ->
        # Xero provides tenant_id via the connections endpoint after auth.
        # For the OAuth flow, the tenant_id can come as a query param from our
        # org selection step, or we fetch it from the /connections API.
        # Here we accept it from params or use a placeholder that gets updated
        # when the user selects their org.
        tenant_id = params["tenantId"] || params["tenant_id"] || "pending"
        do_callback(conn, code, tenant_id, company_id)
    end
  end

  def callback(conn, %{"error" => error}) do
    company_id = get_session(conn, :xero_company_id)
    conn = delete_session(conn, :xero_company_id)

    redirect_path =
      if company_id, do: ~p"/companies/#{company_id}", else: ~p"/accounts/integrations"

    conn
    |> put_flash(:error, "Xero authorization failed: #{error}")
    |> redirect(to: redirect_path)
  end

  defp do_callback(conn, code, tenant_id, company_id) do
    company_id = if is_binary(company_id), do: String.to_integer(company_id), else: company_id

    case Xero.exchange_code(code, tenant_id, company_id) do
      {:ok, _integration} ->
        conn
        |> delete_session(:xero_company_id)
        |> delete_session(:xero_oauth_state)
        |> put_flash(:info, "Xero connected successfully")
        |> redirect(to: ~p"/companies/#{company_id}")

      {:error, reason} ->
        conn
        |> delete_session(:xero_company_id)
        |> delete_session(:xero_oauth_state)
        |> put_flash(:error, "Failed to connect Xero: #{inspect(reason)}")
        |> redirect(to: ~p"/companies/#{company_id}")
    end
  end
end
