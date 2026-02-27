defmodule Holdco.Integrations.Quickbooks do
  @moduledoc """
  QuickBooks Online OAuth2 client, API wrapper, and sync engine.

  Configuration (runtime, via application env):
    config :holdco, Holdco.Integrations.Quickbooks,
      client_id: "your_client_id",
      client_secret: "your_client_secret",
      redirect_uri: "http://localhost:4000/auth/quickbooks/callback",
      environment: :sandbox  # or :production
  """

  alias Holdco.{Finance, Integrations}

  @sandbox_base "https://sandbox-quickbooks.api.intuit.com"
  @production_base "https://quickbooks.api.intuit.com"
  @auth_base "https://appcenter.intuit.com/connect/oauth2"
  @token_url "https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer"

  # OAuth2

  def authorize_url do
    config = config()

    params =
      URI.encode_query(%{
        client_id: config[:client_id],
        redirect_uri: config[:redirect_uri],
        response_type: "code",
        scope: "com.intuit.quickbooks.accounting",
        state: generate_state()
      })

    "#{@auth_base}?#{params}"
  end

  def exchange_code(code, realm_id, company_id) do
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
          |> DateTime.add(body["expires_in"] || 3600, :second)
          |> DateTime.truncate(:second)

        Integrations.upsert_integration("quickbooks", company_id, %{
          "access_token" => body["access_token"],
          "refresh_token" => body["refresh_token"],
          "token_expires_at" => expires_at,
          "realm_id" => realm_id,
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
          |> DateTime.add(body["expires_in"] || 3600, :second)
          |> DateTime.truncate(:second)

        Integrations.upsert_integration("quickbooks", company_id, %{
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
    url = "#{api_base()}/v3/company/#{integration.realm_id}#{path}"

    case Req.get(url,
           headers: [
             {"authorization", "Bearer #{integration.access_token}"},
             {"accept", "application/json"}
           ]
         ) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, resp} -> {:error, {:api_error, resp.status, resp.body}}
      {:error, reason} -> {:error, reason}
    end
  end

  # Sync

  def sync_all(company_id) do
    case Integrations.get_integration("quickbooks", company_id) do
      nil ->
        {:error, :not_connected}

      %{status: "disconnected"} ->
        {:error, :not_connected}

      integration ->
        results = %{
          accounts: sync_accounts(integration, company_id),
          journal_entries: sync_journal_entries(integration, company_id)
        }

        Integrations.update_last_synced("quickbooks", company_id)
        Integrations.broadcast({:quickbooks_synced, results})
        {:ok, results}
    end
  end

  def sync_accounts(integration, company_id) do
    case api_get(integration, "/query?query=SELECT * FROM Account MAXRESULTS 1000") do
      {:ok, %{"QueryResponse" => %{"Account" => accounts}}} ->
        synced =
          Enum.map(accounts, fn qbo_account ->
            attrs = %{
              "name" => qbo_account["Name"],
              "code" => qbo_account["AcctNum"] || "QBO-#{qbo_account["Id"]}",
              "account_type" => map_account_type(qbo_account["AccountType"]),
              "currency" => qbo_account["CurrencyRef"]["value"] || "USD",
              "external_id" => to_string(qbo_account["Id"]),
              "company_id" => company_id
            }

            upsert_by_external_id(:account, attrs)
          end)

        {:ok, length(synced)}

      {:ok, %{"QueryResponse" => _}} ->
        {:ok, 0}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def sync_journal_entries(integration, company_id) do
    case api_get(integration, "/query?query=SELECT * FROM JournalEntry MAXRESULTS 1000") do
      {:ok, %{"QueryResponse" => %{"JournalEntry" => entries}}} ->
        synced =
          Enum.map(entries, fn qbo_entry ->
            entry_attrs = %{
              "date" => qbo_entry["TxnDate"],
              "description" =>
                qbo_entry["PrivateNote"] || "QBO Journal Entry ##{qbo_entry["Id"]}",
              "reference" => "QBO-#{qbo_entry["DocNumber"] || qbo_entry["Id"]}",
              "external_id" => to_string(qbo_entry["Id"]),
              "company_id" => company_id
            }

            case upsert_by_external_id(:journal_entry, entry_attrs) do
              {:ok, entry} ->
                sync_journal_lines(entry, qbo_entry["Line"] || [])
                {:ok, entry}

              error ->
                error
            end
          end)

        {:ok, length(synced)}

      {:ok, %{"QueryResponse" => _}} ->
        {:ok, 0}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private

  defp sync_journal_lines(entry, qbo_lines) do
    existing_lines = Finance.list_journal_lines(entry.id)
    Enum.each(existing_lines, &Finance.delete_journal_line/1)

    accounts = Finance.list_accounts()
    account_by_ext = Map.new(accounts, fn a -> {a.external_id, a.id} end)

    Enum.each(qbo_lines, fn line ->
      detail = line["JournalEntryLineDetail"]

      if detail do
        ext_account_id = to_string(detail["AccountRef"]["value"])
        account_id = Map.get(account_by_ext, ext_account_id)

        if account_id do
          is_debit = detail["PostingType"] == "Debit"

          Finance.create_journal_line(%{
            "entry_id" => entry.id,
            "account_id" => account_id,
            "debit" => if(is_debit, do: line["Amount"] || 0.0, else: 0.0),
            "credit" => if(!is_debit, do: line["Amount"] || 0.0, else: 0.0)
          })
        end
      end
    end)
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

  defp map_account_type("Bank"), do: "asset"
  defp map_account_type("Accounts Receivable"), do: "asset"
  defp map_account_type("Other Current Asset"), do: "asset"
  defp map_account_type("Fixed Asset"), do: "asset"
  defp map_account_type("Other Asset"), do: "asset"
  defp map_account_type("Accounts Payable"), do: "liability"
  defp map_account_type("Credit Card"), do: "liability"
  defp map_account_type("Other Current Liability"), do: "liability"
  defp map_account_type("Long Term Liability"), do: "liability"
  defp map_account_type("Equity"), do: "equity"
  defp map_account_type("Income"), do: "revenue"
  defp map_account_type("Other Income"), do: "revenue"
  defp map_account_type("Expense"), do: "expense"
  defp map_account_type("Other Expense"), do: "expense"
  defp map_account_type("Cost of Goods Sold"), do: "expense"
  defp map_account_type(_), do: "asset"

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

  defp api_base do
    if config()[:environment] == :production, do: @production_base, else: @sandbox_base
  end

  defp basic_auth(config) do
    Base.encode64("#{config[:client_id]}:#{config[:client_secret]}")
  end

  defp generate_state do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end
end
