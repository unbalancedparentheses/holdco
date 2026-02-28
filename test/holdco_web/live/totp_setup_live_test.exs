defmodule HoldcoWeb.TotpSetupLiveTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "mount" do
    test "renders setup page when TOTP is not enabled", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/users/settings/2fa")
      assert html =~ "Two-Factor Authentication"
      assert html =~ "Scan QR Code"
      assert html =~ "Verify Code"
      assert html =~ "Authentication Code"
    end

    test "renders enabled page when TOTP is already enabled", %{conn: conn, user: user} do
      # Enable TOTP for the user
      secret = Holdco.Accounts.generate_totp_secret()
      {:ok, _user} = Holdco.Accounts.enable_totp(user, secret)

      {:ok, _view, html} = live(conn, ~p"/users/settings/2fa")
      assert html =~ "Two-Factor Authentication"
      assert html =~ "authentication is enabled"
      assert html =~ "Disable Two-Factor Authentication"
    end

    test "displays QR code SVG when TOTP is not enabled", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/users/settings/2fa")
      # QR code should be rendered as an SVG
      assert html =~ "<svg"
    end

    test "displays secret key in details section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/users/settings/2fa")
      assert html =~ "secret key instead"
    end

    test "has a back link to account settings", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/users/settings/2fa")
      assert html =~ "Back to Account Settings"
      assert html =~ "/users/settings"
    end

    test "shows page title for setup", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/users/settings/2fa")
      assert html =~ "Two-Factor Authentication"
    end

    test "shows TOTP protection message when enabled", %{conn: conn, user: user} do
      secret = Holdco.Accounts.generate_totp_secret()
      {:ok, _user} = Holdco.Accounts.enable_totp(user, secret)

      {:ok, _view, html} = live(conn, ~p"/users/settings/2fa")
      assert html =~ "protected with TOTP"
      assert html =~ "authenticator app"
    end
  end

  describe "regenerate_secret" do
    test "regenerates QR code on regenerate_secret event", %{conn: conn} do
      {:ok, view, html1} = live(conn, ~p"/users/settings/2fa")
      assert html1 =~ "<svg"

      html2 = view |> element("button", "Generate new secret") |> render_click()
      assert html2 =~ "<svg"
    end

    test "clears any previous error on regenerate", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users/settings/2fa")

      # Submit an invalid code first to create an error state
      view
      |> form("form[phx-submit=\"verify_and_enable\"]", totp: %{code: "000000"})
      |> render_submit()

      # Regenerate should clear the error
      html = view |> element("button", "Generate new secret") |> render_click()
      refute html =~ "Invalid code"
    end
  end

  describe "verify_and_enable" do
    test "shows error for invalid TOTP code", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users/settings/2fa")

      html =
        view
        |> form("form[phx-submit=\"verify_and_enable\"]", totp: %{code: "000000"})
        |> render_submit()

      assert html =~ "Invalid code"
    end

    test "shows error for empty TOTP code", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users/settings/2fa")

      html =
        view
        |> form("form[phx-submit=\"verify_and_enable\"]", totp: %{code: ""})
        |> render_submit()

      assert html =~ "Invalid code"
    end

    test "enables TOTP with valid code and redirects", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/users/settings/2fa")

      # Extract the Base32-encoded secret from the rendered HTML
      # The secret is rendered inside a <code> tag within a <details> section
      [_, base32_secret] = Regex.run(~r/<code[^>]*>\s*([A-Z2-7]+)\s*<\/code>/, html)
      secret = Base.decode32!(base32_secret, padding: false)

      # Generate a valid TOTP code from the secret
      valid_code = NimbleTOTP.verification_code(secret)

      view
      |> form("form[phx-submit=\"verify_and_enable\"]", totp: %{code: valid_code})
      |> render_submit()

      # Should redirect after successful enable
      flash = assert_redirect(view, ~p"/users/settings/2fa")
      assert flash["info"] =~ "enabled"
    end
  end

  describe "disable_totp" do
    test "disables TOTP when clicking disable button", %{conn: conn, user: user} do
      secret = Holdco.Accounts.generate_totp_secret()
      {:ok, _user} = Holdco.Accounts.enable_totp(user, secret)

      {:ok, view, _html} = live(conn, ~p"/users/settings/2fa")

      view |> element("button", "Disable Two-Factor Authentication") |> render_click()

      # Should redirect after disabling
      flash = assert_redirect(view, ~p"/users/settings/2fa")
      assert flash["info"] =~ "disabled"
    end

    test "user can re-enable after disabling", %{conn: conn, user: user} do
      secret = Holdco.Accounts.generate_totp_secret()
      {:ok, _user} = Holdco.Accounts.enable_totp(user, secret)

      {:ok, view, _html} = live(conn, ~p"/users/settings/2fa")
      view |> element("button", "Disable Two-Factor Authentication") |> render_click()
      assert_redirect(view, ~p"/users/settings/2fa")

      # Navigate back - should show the setup page again
      {:ok, _view, html} = live(conn, ~p"/users/settings/2fa")
      assert html =~ "Scan QR Code"
    end
  end
end
