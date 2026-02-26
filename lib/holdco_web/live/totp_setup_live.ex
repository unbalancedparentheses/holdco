defmodule HoldcoWeb.TotpSetupLive do
  use HoldcoWeb, :live_view

  alias Holdco.Accounts

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    if user.totp_enabled do
      {:ok,
       assign(socket,
         page_title: "Two-Factor Authentication",
         totp_enabled: true,
         secret: nil,
         qr_svg: nil,
         error: nil
       )}
    else
      secret = Accounts.generate_totp_secret()
      qr_svg = Accounts.totp_qr_svg(user, secret)

      {:ok,
       assign(socket,
         page_title: "Set Up Two-Factor Authentication",
         totp_enabled: false,
         secret: secret,
         qr_svg: qr_svg,
         error: nil
       )}
    end
  end

  @impl true
  def handle_event("verify_and_enable", %{"totp" => %{"code" => code}}, socket) do
    user = socket.assigns.current_scope.user
    secret = socket.assigns.secret

    if NimbleTOTP.valid?(secret, code) do
      case Accounts.enable_totp(user, secret) do
        {:ok, _user} ->
          {:noreply,
           socket
           |> put_flash(:info, "Two-factor authentication has been enabled successfully.")
           |> push_navigate(to: ~p"/users/settings/2fa")}

        {:error, _changeset} ->
          {:noreply, assign(socket, error: "Failed to enable 2FA. Please try again.")}
      end
    else
      {:noreply,
       assign(socket, error: "Invalid code. Please check your authenticator app and try again.")}
    end
  end

  @impl true
  def handle_event("disable_totp", _params, socket) do
    user = socket.assigns.current_scope.user

    case Accounts.disable_totp(user) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Two-factor authentication has been disabled.")
         |> push_navigate(to: ~p"/users/settings/2fa")}

      {:error, _changeset} ->
        {:noreply, assign(socket, error: "Failed to disable 2FA. Please try again.")}
    end
  end

  @impl true
  def handle_event("regenerate_secret", _params, socket) do
    user = socket.assigns.current_scope.user
    secret = Accounts.generate_totp_secret()
    qr_svg = Accounts.totp_qr_svg(user, secret)

    {:noreply, assign(socket, secret: secret, qr_svg: qr_svg, error: nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <h1>Two-Factor Authentication</h1>
      <p class="deck">Add an extra layer of security to your account</p>
      <hr class="page-title-rule" />
    </div>

    <div style="max-width: 480px; margin: 0 auto;">
      <%= if @totp_enabled do %>
        <div class="panel" style="padding: 1.5rem;">
          <div style="display: flex; align-items: center; gap: 0.75rem; margin-bottom: 1rem;">
            <span style="display: inline-block; width: 12px; height: 12px; border-radius: 50%; background: #00994d;">
            </span>
            <strong style="font-size: 1.1rem;">Two-factor authentication is enabled</strong>
          </div>

          <p style="color: #666; margin-bottom: 1.5rem;">
            Your account is protected with TOTP-based two-factor authentication.
            You will need your authenticator app each time you log in.
          </p>

          <div
            :if={@error}
            style="color: #cc0000; margin-bottom: 1rem; padding: 0.5rem; background: #fff0f0; border-radius: 4px;"
          >
            {@error}
          </div>

          <button
            phx-click="disable_totp"
            data-confirm="Are you sure you want to disable two-factor authentication? This will make your account less secure."
            style="background: #cc0000; color: white; border: none; padding: 0.5rem 1rem; border-radius: 4px; cursor: pointer; font-size: 0.9rem;"
          >
            Disable Two-Factor Authentication
          </button>
        </div>
      <% else %>
        <div class="panel" style="padding: 1.5rem;">
          <h2 style="margin-bottom: 0.5rem; font-size: 1.1rem;">Step 1: Scan QR Code</h2>
          <p style="color: #666; margin-bottom: 1rem;">
            Scan this QR code with your authenticator app (Google Authenticator,
            Authy, 1Password, etc.).
          </p>

          <div style="display: flex; justify-content: center; margin-bottom: 1rem; padding: 1rem; background: white; border: 1px solid #eee; border-radius: 4px;">
            {Phoenix.HTML.raw(@qr_svg)}
          </div>

          <details style="margin-bottom: 1.5rem;">
            <summary style="cursor: pointer; font-size: 0.875rem; color: #666;">
              Can't scan? Use this secret key instead
            </summary>
            <code style="display: block; margin-top: 0.5rem; padding: 0.5rem; background: #f5f5f5; border-radius: 4px; font-size: 0.8rem; word-break: break-all;">
              {Base.encode32(@secret, padding: false)}
            </code>
          </details>

          <button
            phx-click="regenerate_secret"
            style="background: none; border: 1px solid #ccc; padding: 0.35rem 0.75rem; border-radius: 4px; cursor: pointer; font-size: 0.8rem; color: #666; margin-bottom: 1.5rem;"
          >
            Generate new secret
          </button>
        </div>

        <div class="panel" style="padding: 1.5rem; margin-top: 1rem;">
          <h2 style="margin-bottom: 0.5rem; font-size: 1.1rem;">Step 2: Verify Code</h2>
          <p style="color: #666; margin-bottom: 1rem;">
            Enter the 6-digit code shown in your authenticator app to confirm setup.
          </p>

          <div
            :if={@error}
            style="color: #cc0000; margin-bottom: 1rem; padding: 0.5rem; background: #fff0f0; border-radius: 4px;"
          >
            {@error}
          </div>

          <form phx-submit="verify_and_enable">
            <div style="margin-bottom: 1rem;">
              <label for="totp_code" style="display: block; font-weight: 500; margin-bottom: 0.25rem;">
                Authentication Code
              </label>
              <input
                type="text"
                id="totp_code"
                name="totp[code]"
                inputmode="numeric"
                pattern="[0-9]{6}"
                maxlength="6"
                autocomplete="one-time-code"
                autofocus
                required
                placeholder="000000"
                style="width: 100%; padding: 0.5rem; font-size: 1.25rem; letter-spacing: 0.5em; text-align: center; font-family: monospace; border: 1px solid #ccc; border-radius: 4px;"
              />
            </div>
            <button
              type="submit"
              style="background: #0d7680; color: white; border: none; padding: 0.5rem 1rem; border-radius: 4px; cursor: pointer; font-size: 0.9rem; width: 100%;"
            >
              Verify and Enable 2FA
            </button>
          </form>
        </div>
      <% end %>

      <div style="margin-top: 1.5rem; text-align: center;">
        <.link navigate={~p"/users/settings"} style="font-size: 0.875rem; color: #666;">
          &larr; Back to Account Settings
        </.link>
      </div>
    </div>
    """
  end
end
