defmodule Holdco.Integrations.Xero do
  @moduledoc """
  Xero OAuth2 client, API wrapper, and sync engine.

  Configuration (runtime, via application env):
    config :holdco, Holdco.Integrations.Xero,
      client_id: "your_client_id",
      client_secret: "your_client_secret",
      redirect_uri: "http://localhost:4000/auth/xero/callback"
  """

  alias Holdco.{Finance, Integrations}

  @auth_base "https://login.xero.com/identity/connect/authorize"
  @token_url "https://identity.xero.com/connect/token"
  @api_base "https://api.xero.com/api.xro/2.0"
  @scopes "openid profile email accounting.transactions accounting.contacts accounting.settings offline_access"

  # OAuth2

  def authorize_url do
    config = config()
    state = generate_state()

    params =
      URI.encode_query(%{
        client_id: config[:client_id],
        redirect_uri: config[:redirect_uri],
        response_type: "code",
        scope: @scopes,
        state: state
      })

    {"#{@auth_base}?#{params}", state}
  end

  def exchange_code(code, tenant_id, company_id) do
    config = config()

    body =
      URI.encode_query(%{
        grant_type: "authorization_code",
        code: code,
        redirect_uri: config[:redirect_uri]
      })

    case Req.post(@token_url,
           body: body,
           headers: [
             {"content-type", "application/x-www-form-urlencoded"},
             {"authorization", "Basic #{basic_auth(config)}"},
             {"accept", "application/json"}
           ]
         ) do
      {:ok, %{status: 200, body: body}} ->
        expires_at =
          DateTime.utc_now()
          |> DateTime.add(body["expires_in"] || 1800, :second)
          |> DateTime.truncate(:second)

        Integrations.upsert_integration("xero", company_id, %{
          "access_token" => body["access_token"],
          "refresh_token" => body["refresh_token"],
          "token_expires_at" => expires_at,
          "realm_id" => tenant_id,
          "status" => "connected"
        })

      {:ok, resp} ->
        {:error, {:token_exchange_failed, resp.status, resp.body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def refresh_token(%{refresh_token: refresh_token, company_id: company_id} = _integration) do
    config = config()

    body =
      URI.encode_query(%{
        grant_type: "refresh_token",
        refresh_token: refresh_token
      })

    case Req.post(@token_url,
           body: body,
           headers: [
             {"content-type", "application/x-www-form-urlencoded"},
             {"authorization", "Basic #{basic_auth(config)}"},
             {"accept", "application/json"}
           ]
         ) do
      {:ok, %{status: 200, body: body}} ->
        expires_at =
          DateTime.utc_now()
          |> DateTime.add(body["expires_in"] || 1800, :second)
          |> DateTime.truncate(:second)

        Integrations.upsert_integration("xero", company_id, %{
          "access_token" => body["access_token"],
          "refresh_token" => body["refresh_token"],
          "token_expires_at" => expires_at,
          "status" => "connected"
        })

      {:ok, resp} ->
        {:error, {:refresh_failed, resp.status, resp.body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # API

  def api_get(integration, path) do
    integration = ensure_fresh_token!(integration)
    url = "#{@api_base}#{path}"

    case Req.get(url,
           headers: [
             {"authorization", "Bearer #{integration.access_token}"},
             {"xero-tenant-id", integration.realm_id},
             {"accept", "application/json"}
           ]
         ) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, resp} -> {:error, {:api_error, resp.status, resp.body}}
      {:error, reason} -> {:error, reason}
    end
  end

  def api_post(integration, path, payload) do
    integration = ensure_fresh_token!(integration)
    url = "#{@api_base}#{path}"

    case Req.post(url,
           json: payload,
           headers: [
             {"authorization", "Bearer #{integration.access_token}"},
             {"xero-tenant-id", integration.realm_id},
             {"accept", "application/json"},
             {"content-type", "application/json"}
           ]
         ) do
      {:ok, %{status: status, body: body}} when status in [200, 201] -> {:ok, body}
      {:ok, resp} -> {:error, {:api_error, resp.status, resp.body}}
      {:error, reason} -> {:error, reason}
    end
  end

  # Sync

  def sync_all(company_id) do
    case Integrations.get_integration("xero", company_id) do
      nil ->
        {:error, :not_connected}

      %{status: "disconnected"} ->
        {:error, :not_connected}

      integration ->
        results = %{
          accounts: sync_accounts(integration, company_id),
          journal_entries: sync_journal_entries(integration, company_id)
        }

        Integrations.update_last_synced("xero", company_id)
        Integrations.broadcast({:xero_synced, results})
        {:ok, results}
    end
  end

  def sync_accounts(integration, company_id) do
    case api_get(integration, "/Accounts") do
      {:ok, %{"Accounts" => accounts}} ->
        synced =
          Enum.map(accounts, fn xero_account ->
            attrs = %{
              "name" => xero_account["Name"],
              "code" => xero_account["Code"] || "XERO-#{xero_account["AccountID"]}",
              "account_type" => map_account_type(xero_account["Type"]),
              "currency" => xero_account["CurrencyCode"] || "USD",
              "external_id" => xero_account["AccountID"],
              "company_id" => company_id
            }

            upsert_by_external_id(:account, attrs)
          end)

        {:ok, length(synced)}

      {:ok, _} ->
        {:ok, 0}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def sync_journal_entries(integration, company_id) do
    case api_get(integration, "/ManualJournals") do
      {:ok, %{"ManualJournals" => journals}} ->
        synced =
          Enum.map(journals, fn xero_journal ->
            entry_attrs = %{
              "date" => parse_xero_date(xero_journal["Date"]),
              "description" =>
                xero_journal["Narration"] || "Xero Journal ##{xero_journal["ManualJournalID"]}",
              "reference" => "XERO-#{xero_journal["ManualJournalID"]}",
              "external_id" => xero_journal["ManualJournalID"],
              "company_id" => company_id
            }

            case upsert_by_external_id(:journal_entry, entry_attrs) do
              {:ok, entry} ->
                sync_journal_lines(entry, xero_journal["JournalLines"] || [])
                {:ok, entry}

              error ->
                error
            end
          end)

        {:ok, length(synced)}

      {:ok, _} ->
        {:ok, 0}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private

  defp sync_journal_lines(entry, xero_lines) do
    existing_lines = Finance.list_journal_lines(entry.id)
    Enum.each(existing_lines, &Finance.delete_journal_line/1)

    accounts = Finance.list_accounts()
    account_by_ext = Map.new(accounts, fn a -> {a.external_id, a.id} end)

    Enum.each(xero_lines, fn line ->
      ext_account_id = line["AccountID"]
      account_id = Map.get(account_by_ext, ext_account_id)

      if account_id do
        line_amount = parse_decimal(line["LineAmount"])
        is_debit = Decimal.compare(line_amount, Decimal.new(0)) != :lt

        Finance.create_journal_line(%{
          "entry_id" => entry.id,
          "account_id" => account_id,
          "debit" => if(is_debit, do: Decimal.abs(line_amount), else: Decimal.new(0)),
          "credit" => if(!is_debit, do: Decimal.abs(line_amount), else: Decimal.new(0))
        })
      end
    end)
  end

  defp parse_decimal(nil), do: Decimal.new(0)
  defp parse_decimal(val) when is_binary(val), do: Decimal.new(val)
  defp parse_decimal(val) when is_float(val), do: Decimal.from_float(val)
  defp parse_decimal(val) when is_integer(val), do: Decimal.new(val)

  defp parse_xero_date(nil), do: Date.to_iso8601(Date.utc_today())

  defp parse_xero_date(date_string) when is_binary(date_string) do
    # Xero sometimes returns dates as "/Date(1234567890000+0000)/" or as ISO strings
    case Regex.run(~r"/Date\((\d+)([+-]\d+)?\)/", date_string) do
      [_, ms_string | _] ->
        ms = String.to_integer(ms_string)
        unix_seconds = div(ms, 1000)

        DateTime.from_unix!(unix_seconds)
        |> DateTime.to_date()
        |> Date.to_iso8601()

      _ ->
        # Assume ISO 8601 format
        date_string
    end
  end

  defp upsert_by_external_id(:account, %{"external_id" => ext_id} = attrs) do
    import Ecto.Query
    alias Holdco.Finance.Account

    case Holdco.Repo.one(from(a in Account, where: a.external_id == ^ext_id)) do
      nil -> Finance.create_account(attrs)
      existing -> Finance.update_account(existing, attrs)
    end
  end

  defp upsert_by_external_id(:journal_entry, %{"external_id" => ext_id} = attrs) do
    import Ecto.Query
    alias Holdco.Finance.JournalEntry

    case Holdco.Repo.one(from(je in JournalEntry, where: je.external_id == ^ext_id)) do
      nil -> Finance.create_journal_entry(attrs)
      existing -> Finance.update_journal_entry(existing, attrs)
    end
  end

  # Xero account type mapping
  # See: https://developer.xero.com/documentation/api/accounting/types#account-types
  def map_account_type("BANK"), do: "asset"
  def map_account_type("CURRENT"), do: "asset"
  def map_account_type("CURRLIAB"), do: "liability"
  def map_account_type("DEPRECIATN"), do: "expense"
  def map_account_type("DIRECTCOSTS"), do: "expense"
  def map_account_type("EQUITY"), do: "equity"
  def map_account_type("EXPENSE"), do: "expense"
  def map_account_type("FIXED"), do: "asset"
  def map_account_type("INVENTORY"), do: "asset"
  def map_account_type("LIABILITY"), do: "liability"
  def map_account_type("NONCURRENT"), do: "asset"
  def map_account_type("OTHERINCOME"), do: "revenue"
  def map_account_type("OVERHEADS"), do: "expense"
  def map_account_type("PREPAYMENT"), do: "asset"
  def map_account_type("REVENUE"), do: "revenue"
  def map_account_type("SALES"), do: "revenue"
  def map_account_type("TERMLIAB"), do: "liability"
  def map_account_type("PAYGLIABILITY"), do: "liability"
  def map_account_type("SUPERANNUATIONEXPENSE"), do: "expense"
  def map_account_type("SUPERANNUATIONLIABILITY"), do: "liability"
  def map_account_type("WAGESEXPENSE"), do: "expense"
  def map_account_type(_), do: "asset"

  defp ensure_fresh_token!(integration) do
    if integration.token_expires_at &&
         DateTime.compare(integration.token_expires_at, DateTime.utc_now()) == :lt do
      case refresh_token(integration) do
        {:ok, refreshed} -> refreshed
        {:error, _} -> integration
      end
    else
      integration
    end
  end

  defp config do
    Application.get_env(:holdco, __MODULE__, [])
  end

  defp basic_auth(config) do
    Base.encode64("#{config[:client_id]}:#{config[:client_secret]}")
  end

  defp generate_state do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end
end
