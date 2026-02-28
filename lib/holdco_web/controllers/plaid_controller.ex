defmodule HoldcoWeb.PlaidController do
  use HoldcoWeb, :controller

  alias Holdco.Integrations.Plaid

  def create_link_token(conn, %{"company_id" => company_id}) do
    user_id = conn.assigns.current_scope.user.id

    case Plaid.create_link_token(user_id, company_id) do
      {:ok, %{link_token: link_token}} ->
        json(conn, %{link_token: link_token})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: inspect(reason)})
    end
  end

  def create_link_token(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "company_id is required"})
  end

  def exchange_token(conn, %{
        "public_token" => public_token,
        "company_id" => company_id,
        "bank_account_id" => bank_account_id
      } = params) do
    opts = %{
      institution_id: Map.get(params, "institution_id", ""),
      institution_name: Map.get(params, "institution_name", "")
    }

    case Plaid.exchange_public_token(public_token, company_id, bank_account_id, opts) do
      {:ok, config} ->
        json(conn, %{
          id: config.id,
          provider: config.provider,
          external_account_id: config.external_account_id
        })

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: inspect(reason)})
    end
  end

  def exchange_token(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "public_token, company_id, and bank_account_id are required"})
  end

  def webhook(conn, params) do
    case Plaid.handle_webhook(params) do
      {:ok, _} ->
        conn
        |> put_status(:ok)
        |> json(%{status: "ok"})

      {:error, reason} ->
        conn
        |> put_status(:ok)
        |> json(%{status: "error", detail: inspect(reason)})
    end
  end
end
