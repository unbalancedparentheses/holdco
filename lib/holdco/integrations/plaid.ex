defmodule Holdco.Integrations.Plaid do
  @moduledoc """
  Plaid API client for bank feed integration.

  Configuration (runtime, via application env):
    config :holdco, Holdco.Integrations.Plaid,
      client_id: "your_client_id",
      secret: "your_secret",
      environment: :sandbox  # or :production
  """

  alias Holdco.Integrations
  alias Holdco.Integrations.BankFeedConfig

  @sandbox_base "https://sandbox.plaid.com"
  @production_base "https://production.plaid.com"

  @doc """
  Creates a Plaid Link token for the given user and company.
  POST /link/token/create
  """
  def create_link_token(user_id, company_id) do
    body = %{
      client_id: client_id(),
      secret: secret(),
      user: %{client_user_id: to_string(user_id)},
      client_name: "Holdco",
      products: ["transactions"],
      country_codes: ["US"],
      language: "en",
      metadata: %{company_id: to_string(company_id)}
    }

    case api_post("/link/token/create", body) do
      {:ok, %{status: 200, body: %{"link_token" => link_token} = resp_body}} ->
        {:ok, %{link_token: link_token, expiration: resp_body["expiration"]}}

      {:ok, %{status: status, body: resp_body}} ->
        {:error, {:plaid_error, status, resp_body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Exchanges a Plaid public token for an access token and stores it in a BankFeedConfig.
  POST /item/public_token/exchange
  """
  def exchange_public_token(public_token, company_id, bank_account_id, opts \\ %{}) do
    body = %{
      client_id: client_id(),
      secret: secret(),
      public_token: public_token
    }

    case api_post("/item/public_token/exchange", body) do
      {:ok, %{status: 200, body: %{"access_token" => access_token, "item_id" => item_id}}} ->
        institution_id = Map.get(opts, :institution_id, "")
        institution_name = Map.get(opts, :institution_name, "")

        Integrations.create_bank_feed_config(%{
          "company_id" => company_id,
          "bank_account_id" => bank_account_id,
          "provider" => "plaid",
          "access_token" => access_token,
          "external_account_id" => item_id,
          "institution_id" => institution_id,
          "institution_name" => institution_name,
          "is_active" => true
        })

      {:ok, %{status: status, body: resp_body}} ->
        {:error, {:plaid_error, status, resp_body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Syncs transactions for a given BankFeedConfig using Plaid's /transactions/sync endpoint.
  Uses cursor-based pagination to fetch incremental updates.
  """
  def sync_transactions(%BankFeedConfig{} = config) do
    sync_transactions_loop(config, config.sync_cursor, [])
  end

  defp sync_transactions_loop(config, cursor, acc) do
    body =
      %{
        client_id: client_id(),
        secret: secret(),
        access_token: config.access_token
      }
      |> maybe_put_cursor(cursor)

    case api_post("/transactions/sync", body) do
      {:ok, %{status: 200, body: resp_body}} ->
        added = Map.get(resp_body, "added", [])
        modified = Map.get(resp_body, "modified", [])
        removed = Map.get(resp_body, "removed", [])
        next_cursor = Map.get(resp_body, "next_cursor")
        has_more = Map.get(resp_body, "has_more", false)

        upserted = upsert_plaid_transactions(config.id, added ++ modified)
        remove_plaid_transactions(config.id, removed)

        new_acc = acc ++ upserted

        # Update cursor on the config
        Integrations.update_bank_feed_config(config, %{
          sync_cursor: next_cursor,
          last_sync_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

        if has_more do
          sync_transactions_loop(config, next_cursor, new_acc)
        else
          {:ok, %{synced: length(new_acc), cursor: next_cursor}}
        end

      {:ok, %{status: status, body: resp_body}} ->
        {:error, {:plaid_error, status, resp_body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp maybe_put_cursor(body, nil), do: body
  defp maybe_put_cursor(body, ""), do: body
  defp maybe_put_cursor(body, cursor), do: Map.put(body, :cursor, cursor)

  defp upsert_plaid_transactions(feed_config_id, transactions) do
    Enum.map(transactions, fn txn ->
      attrs = %{
        "date" => txn["date"],
        "description" => txn["name"] || txn["merchant_name"] || "",
        "amount" => parse_plaid_amount(txn["amount"]),
        "currency" => get_in(txn, ["iso_currency_code"]) || "USD",
        "category" =>
          case txn["personal_finance_category"] do
            %{"primary" => primary} -> primary
            _ -> Enum.join(txn["category"] || [], ", ")
          end
      }

      external_id = txn["transaction_id"]
      Integrations.upsert_bank_feed_transaction(feed_config_id, external_id, attrs)
    end)
  end

  defp remove_plaid_transactions(feed_config_id, removed) do
    Enum.each(removed, fn txn ->
      external_id = txn["transaction_id"]

      import Ecto.Query

      case Holdco.Repo.one(
             from(bft in Holdco.Integrations.BankFeedTransaction,
               where:
                 bft.feed_config_id == ^feed_config_id and bft.external_id == ^external_id
             )
           ) do
        nil -> :ok
        existing -> Integrations.delete_bank_feed_transaction(existing)
      end
    end)
  end

  # Plaid amounts: positive = money leaving account (debit), negative = money entering (credit).
  # We negate to match typical accounting convention where deposits are positive.
  defp parse_plaid_amount(nil), do: Decimal.new(0)

  defp parse_plaid_amount(amount) when is_float(amount),
    do: Decimal.from_float(amount) |> Decimal.negate()

  defp parse_plaid_amount(amount) when is_integer(amount),
    do: Decimal.new(amount) |> Decimal.negate()

  defp parse_plaid_amount(amount) when is_binary(amount),
    do: Decimal.new(amount) |> Decimal.negate()

  @doc """
  Retrieves accounts associated with a Plaid Item.
  POST /accounts/get
  """
  def get_accounts(%BankFeedConfig{} = config) do
    body = %{
      client_id: client_id(),
      secret: secret(),
      access_token: config.access_token
    }

    case api_post("/accounts/get", body) do
      {:ok, %{status: 200, body: %{"accounts" => accounts}}} ->
        {:ok, accounts}

      {:ok, %{status: status, body: resp_body}} ->
        {:error, {:plaid_error, status, resp_body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Handles incoming Plaid webhook events.
  Triggers a transaction sync when SYNC_UPDATES_AVAILABLE is received.
  """
  def handle_webhook(%{"webhook_type" => "TRANSACTIONS", "webhook_code" => "SYNC_UPDATES_AVAILABLE", "item_id" => item_id}) do
    import Ecto.Query

    configs =
      Holdco.Repo.all(
        from(bfc in BankFeedConfig,
          where: bfc.external_account_id == ^item_id and bfc.is_active == true
        )
      )

    results =
      Enum.map(configs, fn config ->
        sync_transactions(config)
      end)

    {:ok, results}
  end

  def handle_webhook(%{"webhook_type" => "TRANSACTIONS", "webhook_code" => "DEFAULT_UPDATE", "item_id" => item_id}) do
    # Legacy webhook code, trigger sync the same way
    handle_webhook(%{
      "webhook_type" => "TRANSACTIONS",
      "webhook_code" => "SYNC_UPDATES_AVAILABLE",
      "item_id" => item_id
    })
  end

  def handle_webhook(%{"webhook_type" => "ITEM", "webhook_code" => "ERROR", "item_id" => item_id, "error" => error}) do
    import Ecto.Query

    configs =
      Holdco.Repo.all(
        from(bfc in BankFeedConfig,
          where: bfc.external_account_id == ^item_id
        )
      )

    Enum.each(configs, fn config ->
      Integrations.update_bank_feed_config(config, %{
        notes: "Plaid error: #{inspect(error["error_code"])} - #{error["error_message"]}"
      })
    end)

    {:ok, :error_logged}
  end

  def handle_webhook(_payload) do
    {:ok, :ignored}
  end

  # HTTP helpers

  defp api_post(path, body) do
    url = "#{api_base()}#{path}"

    Req.post(url,
      json: body,
      headers: [
        {"PLAID-CLIENT-ID", client_id()},
        {"PLAID-SECRET", secret()},
        {"Content-Type", "application/json"}
      ]
    )
  end

  defp api_base do
    if config()[:environment] == :production, do: @production_base, else: @sandbox_base
  end

  defp config do
    Application.get_env(:holdco, __MODULE__, [])
  end

  defp client_id, do: config()[:client_id] || ""
  defp secret, do: config()[:secret] || ""
end
