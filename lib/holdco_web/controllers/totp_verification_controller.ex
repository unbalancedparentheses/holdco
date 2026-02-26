defmodule HoldcoWeb.TotpVerificationController do
  use HoldcoWeb, :controller

  alias Holdco.Accounts
  alias HoldcoWeb.UserAuth

  def new(conn, _params) do
    if get_session(conn, :totp_pending_user_id) do
      render(conn, :new)
    else
      conn
      |> redirect(to: ~p"/users/log-in")
      |> halt()
    end
  end

  def create(conn, %{"totp" => %{"code" => code}}) do
    user_id = get_session(conn, :totp_pending_user_id)
    remember_me = get_session(conn, :totp_pending_remember_me)

    if is_nil(user_id) do
      conn
      |> put_flash(:error, "Session expired. Please log in again.")
      |> redirect(to: ~p"/users/log-in")
    else
      user = Accounts.get_user!(user_id)

      if Accounts.valid_totp?(user, code) do
        params = if remember_me, do: %{"remember_me" => remember_me}, else: %{}

        conn
        |> delete_session(:totp_pending_user_id)
        |> delete_session(:totp_pending_remember_me)
        |> put_flash(:info, "Welcome back!")
        |> UserAuth.log_in_user(user, params)
      else
        conn
        |> put_flash(:error, "Invalid two-factor authentication code. Please try again.")
        |> render(:new)
      end
    end
  end
end
