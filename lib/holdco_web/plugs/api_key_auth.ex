defmodule HoldcoWeb.Plugs.ApiKeyAuth do
  @moduledoc """
  Authenticates API requests via the X-API-Key header.
  Looks up the key in the api_keys table and assigns current_scope.
  """
  import Plug.Conn
  alias Holdco.Repo
  alias Holdco.Accounts.{ApiKey, Scope}

  def init(opts), do: opts

  def call(conn, _opts) do
    with [key] <- get_req_header(conn, "x-api-key"),
         %ApiKey{is_active: true, user_id: user_id} = api_key <- Repo.get_by(ApiKey, key: key),
         user when not is_nil(user) <- Holdco.Accounts.get_user!(user_id) do
      # Update last_used_at
      api_key
      |> Ecto.Changeset.change(last_used_at: DateTime.utc_now() |> DateTime.truncate(:second))
      |> Repo.update()

      conn
      |> assign(:current_scope, Scope.for_user(user))
      |> assign(:current_user, user)
      |> assign(:api_key, api_key)
    else
      _ ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(401, Jason.encode!(%{error: "Invalid or missing API key"}))
        |> halt()
    end
  end
end
