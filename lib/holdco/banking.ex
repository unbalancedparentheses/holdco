defmodule Holdco.Banking do
  import Ecto.Query
  alias Holdco.Repo
  alias Holdco.Banking.{BankAccount, Transaction}

  # Bank Accounts
  def list_bank_accounts(filters \\ %{}) do
    BankAccount
    |> Holdco.QueryHelpers.apply_filters(filters)
    |> order_by([ba], asc: ba.bank_name)
    |> preload(:company)
    |> Repo.all()
  end

  def get_bank_account!(id), do: Repo.get!(BankAccount, id) |> Repo.preload(:company)

  def create_bank_account(attrs) do
    %BankAccount{}
    |> BankAccount.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("bank_accounts", "create")
  end

  def update_bank_account(%BankAccount{} = ba, attrs) do
    ba
    |> BankAccount.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("bank_accounts", "update")
  end

  def delete_bank_account(%BankAccount{} = ba) do
    Repo.delete(ba)
    |> audit_and_broadcast("bank_accounts", "delete")
  end

  # Transactions
  def list_transactions(filters \\ %{}) do
    Transaction
    |> Holdco.QueryHelpers.apply_filters(filters)
    |> order_by([t], desc: t.date)
    |> preload(:company)
    |> Repo.all()
  end

  def get_transaction!(id), do: Repo.get!(Transaction, id) |> Repo.preload(:company)

  def create_transaction(attrs) do
    %Transaction{}
    |> Transaction.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("transactions", "create")
  end

  def update_transaction(%Transaction{} = t, attrs) do
    t
    |> Transaction.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("transactions", "update")
  end

  def delete_transaction(%Transaction{} = t) do
    Repo.delete(t)
    |> audit_and_broadcast("transactions", "delete")
  end

  # Bulk Operations
  def bulk_update_transactions(ids, attrs) when is_list(ids) do
    results =
      Enum.map(ids, fn id ->
        transaction = get_transaction!(id)
        update_transaction(transaction, attrs)
      end)

    {Enum.count(results, &match?({:ok, _}, &1)),
     Enum.count(results, &match?({:error, _}, &1))}
  end

  def bulk_delete_transactions(ids) when is_list(ids) do
    results =
      Enum.map(ids, fn id ->
        transaction = get_transaction!(id)
        delete_transaction(transaction)
      end)

    {Enum.count(results, &match?({:ok, _}, &1)),
     Enum.count(results, &match?({:error, _}, &1))}
  end

  def bulk_update_bank_accounts(ids, attrs) when is_list(ids) do
    results =
      Enum.map(ids, fn id ->
        bank_account = get_bank_account!(id)
        update_bank_account(bank_account, attrs)
      end)

    {Enum.count(results, &match?({:ok, _}, &1)),
     Enum.count(results, &match?({:error, _}, &1))}
  end

  def bulk_delete_bank_accounts(ids) when is_list(ids) do
    results =
      Enum.map(ids, fn id ->
        bank_account = get_bank_account!(id)
        delete_bank_account(bank_account)
      end)

    {Enum.count(results, &match?({:ok, _}, &1)),
     Enum.count(results, &match?({:error, _}, &1))}
  end

  # Aggregations
  def total_balance do
    Repo.one(from ba in BankAccount, select: sum(ba.balance)) || 0.0
  end

  # PubSub
  def subscribe, do: Phoenix.PubSub.subscribe(Holdco.PubSub, "banking")
  defp broadcast(message), do: Phoenix.PubSub.broadcast(Holdco.PubSub, "banking", message)

  defp audit_and_broadcast(result, table, action) do
    case result do
      {:ok, record} ->
        Holdco.Platform.log_action(action, table, record.id)
        broadcast({String.to_atom("#{table}_#{action}d"), record})
        {:ok, record}

      error ->
        error
    end
  end
end
