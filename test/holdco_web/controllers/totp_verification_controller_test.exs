defmodule HoldcoWeb.TotpVerificationControllerTest do
  use HoldcoWeb.ConnCase

  import Holdco.AccountsFixtures
  alias Holdco.Accounts

  describe "GET /users/totp-verify" do
    test "redirects to login when no totp_pending_user_id in session", %{conn: conn} do
      conn = get(conn, ~p"/users/totp-verify")
      assert redirected_to(conn) == ~p"/users/log-in"
    end

    test "renders TOTP verification page when totp_pending_user_id is in session", %{conn: conn} do
      user = user_fixture()

      conn =
        conn
        |> init_test_session(%{totp_pending_user_id: user.id})
        |> get(~p"/users/totp-verify")

      response = html_response(conn, 200)
      assert response =~ "Two-Factor Authentication"
      assert response =~ "Authentication Code"
      assert response =~ "totp_verify_form"
    end
  end

  describe "POST /users/totp-verify" do
    test "redirects to login when session expired (no totp_pending_user_id)", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> post(~p"/users/totp-verify", %{"totp" => %{"code" => "123456"}})

      assert redirected_to(conn) == ~p"/users/log-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Session expired"
    end

    test "shows error for invalid TOTP code", %{conn: conn} do
      user = user_fixture()
      secret = Accounts.generate_totp_secret()
      {:ok, user} = Accounts.enable_totp(user, secret)

      conn =
        conn
        |> init_test_session(%{totp_pending_user_id: user.id})
        |> post(~p"/users/totp-verify", %{"totp" => %{"code" => "000000"}})

      response = html_response(conn, 200)
      assert response =~ "Invalid two-factor authentication code"
    end

    test "logs in user with valid TOTP code", %{conn: conn} do
      user = user_fixture()
      secret = Accounts.generate_totp_secret()
      {:ok, user} = Accounts.enable_totp(user, secret)

      # Generate a valid TOTP code
      valid_code = NimbleTOTP.verification_code(secret)

      conn =
        conn
        |> init_test_session(%{totp_pending_user_id: user.id})
        |> post(~p"/users/totp-verify", %{"totp" => %{"code" => valid_code}})

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/"
    end

    test "logs in user with valid TOTP code and remember_me", %{conn: conn} do
      user = user_fixture()
      secret = Accounts.generate_totp_secret()
      {:ok, user} = Accounts.enable_totp(user, secret)

      valid_code = NimbleTOTP.verification_code(secret)

      conn =
        conn
        |> init_test_session(%{
          totp_pending_user_id: user.id,
          totp_pending_remember_me: "true"
        })
        |> post(~p"/users/totp-verify", %{"totp" => %{"code" => valid_code}})

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/"
    end

    test "clears pending session keys after successful TOTP verification", %{conn: conn} do
      user = user_fixture()
      secret = Accounts.generate_totp_secret()
      {:ok, user} = Accounts.enable_totp(user, secret)

      valid_code = NimbleTOTP.verification_code(secret)

      conn =
        conn
        |> init_test_session(%{
          totp_pending_user_id: user.id,
          totp_pending_remember_me: "true"
        })
        |> post(~p"/users/totp-verify", %{"totp" => %{"code" => valid_code}})

      refute get_session(conn, :totp_pending_user_id)
      refute get_session(conn, :totp_pending_remember_me)
    end
  end
end
