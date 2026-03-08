defmodule Holdco.Config do
  @moduledoc """
  Reads service configuration from the DB settings table.
  Falls back to Application.get_env for values not yet stored in DB.
  """

  alias Holdco.Platform

  # ── Email ────────────────────────────────────────────────

  def mail_from do
    name = get("mail_from_name", "Holdco")
    address = get("mail_from_address", "noreply@holdco.local")
    {name, address}
  end

  def mailer_config do
    case get("email_provider") do
      "postmark" ->
        [adapter: Swoosh.Adapters.Postmark, api_key: get("postmark_api_key")]

      "resend" ->
        [adapter: Swoosh.Adapters.Resend, api_key: get("resend_api_key")]

      "smtp" ->
        [
          adapter: Swoosh.Adapters.SMTP,
          relay: get("smtp_relay", "smtp.gmail.com"),
          port: String.to_integer(get("smtp_port", "587")),
          username: get("smtp_username"),
          password: get("smtp_password"),
          tls: :if_available,
          ssl: false,
          auth: :always
        ]

      _ ->
        Application.get_env(:holdco, Holdco.Mailer, [])
    end
  end

  @doc """
  Syncs mailer config from DB into Application env so Swoosh picks it up.
  Call on app startup and when settings change.
  """
  def sync_mailer! do
    config = mailer_config()

    if Keyword.has_key?(config, :adapter) do
      Application.put_env(:holdco, Holdco.Mailer, config)
    end
  end

  # ── Xero ────────────────────────────────────────────────

  def xero do
    if db_has_any?(~w(xero_client_id xero_client_secret)) do
      [
        client_id: get("xero_client_id"),
        client_secret: get("xero_client_secret"),
        redirect_uri: get("xero_redirect_uri", "http://localhost:4000/auth/xero/callback")
      ]
    else
      Application.get_env(:holdco, Holdco.Integrations.Xero, [])
    end
  end

  # ── QuickBooks ──────────────────────────────────────────

  def quickbooks do
    if db_has_any?(~w(quickbooks_client_id quickbooks_client_secret)) do
      env = get("quickbooks_environment", "sandbox")

      [
        client_id: get("quickbooks_client_id"),
        client_secret: get("quickbooks_client_secret"),
        redirect_uri: get("quickbooks_redirect_uri", "http://localhost:4000/auth/quickbooks/callback"),
        environment: if(env == "production", do: :production, else: :sandbox)
      ]
    else
      Application.get_env(:holdco, Holdco.Integrations.Quickbooks, [])
    end
  end

  # ── S3 / R2 ─────────────────────────────────────────────

  def s3 do
    if db_has_any?(~w(s3_bucket s3_access_key_id)) do
      [
        bucket: get("s3_bucket"),
        endpoint: get("s3_endpoint", "s3.amazonaws.com"),
        region: get("s3_region", "us-east-1"),
        access_key_id: get("s3_access_key_id"),
        secret_access_key: get("s3_secret_access_key")
      ]
    else
      Application.get_env(:holdco, Holdco.Workers.S3Upload, [])
    end
  end

  # ── Helpers ─────────────────────────────────────────────

  defp get(key, default \\ nil) do
    Platform.get_setting_value(key, default)
  rescue
    _ -> default
  end

  defp db_has_any?(keys) do
    Enum.any?(keys, fn key -> get(key) != nil end)
  end
end
