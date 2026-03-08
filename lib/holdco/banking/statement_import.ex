defmodule Holdco.Banking.StatementImport do
  @moduledoc """
  Imports parsed bank statement transactions into the system.
  Creates BankFeedTransaction records and runs auto-reconciliation.
  """

  import Ecto.Query

  alias Holdco.Repo
  alias Holdco.Integrations
  alias Holdco.Integrations.{BankFeedConfig, Reconciliation}

  @doc """
  Imports parsed transactions for a bank account.
  Finds or creates a BankFeedConfig (provider: "csv_import"), upserts
  BankFeedTransaction records, and runs auto-reconciliation.

  Returns `{:ok, %{imported: count, duplicates: count, matched: count, feed_config_id: id}}`
  or `{:error, reason}`.
  """
  def import_transactions(bank_account, parsed_transactions) do
    feed_config = find_or_create_feed_config(bank_account)

    {imported, duplicates} =
      Enum.reduce(parsed_transactions, {0, 0}, fn txn, {imp, dup} ->
        external_id = generate_external_id(txn)

        attrs = %{
          "date" => txn.date,
          "description" => txn.description,
          "amount" => txn.amount,
          "currency" => txn.currency
        }

        case Integrations.upsert_bank_feed_transaction(feed_config.id, external_id, attrs) do
          {:ok, %{id: _}} -> {imp + 1, dup}
          _ -> {imp, dup + 1}
        end
      end)

    # Run auto-reconciliation
    matches = Reconciliation.auto_match(feed_config.id)

    {:ok,
     %{
       imported: imported,
       duplicates: duplicates,
       matched: length(matches),
       feed_config_id: feed_config.id
     }}
  end

  defp find_or_create_feed_config(bank_account) do
    case Repo.one(
           from(bfc in BankFeedConfig,
             where:
               bfc.bank_account_id == ^bank_account.id and
                 bfc.provider == "csv_import"
           )
         ) do
      nil ->
        {:ok, config} =
          Integrations.create_bank_feed_config(%{
            "company_id" => bank_account.company_id,
            "bank_account_id" => bank_account.id,
            "provider" => "csv_import",
            "is_active" => true
          })

        config

      existing ->
        existing
    end
  end

  defp generate_external_id(txn) do
    data = "#{txn.date}|#{txn.description}|#{Decimal.to_string(txn.amount)}"
    :crypto.hash(:sha256, data) |> Base.encode16(case: :lower) |> String.slice(0, 32)
  end
end
