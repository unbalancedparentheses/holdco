defmodule Holdco.Treasury do
  import Ecto.Query
  alias Holdco.Repo
  alias Holdco.Treasury.{CashPool, CashPoolEntry}

  # Cash Pools
  def list_cash_pools do
    from(cp in CashPool, order_by: cp.name, preload: [:entries])
    |> Repo.all()
  end

  def get_cash_pool!(id) do
    Repo.get!(CashPool, id) |> Repo.preload(entries: [:company, :bank_account])
  end

  def create_cash_pool(attrs) do
    %CashPool{}
    |> CashPool.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("cash_pools", "create")
  end

  def update_cash_pool(%CashPool{} = cp, attrs) do
    cp
    |> CashPool.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("cash_pools", "update")
  end

  def delete_cash_pool(%CashPool{} = cp) do
    Repo.delete(cp)
    |> audit_and_broadcast("cash_pools", "delete")
  end

  # Cash Pool Entries
  def list_cash_pool_entries(pool_id) do
    from(cpe in CashPoolEntry, where: cpe.pool_id == ^pool_id,
         preload: [:company, :bank_account])
    |> Repo.all()
  end

  def get_cash_pool_entry!(id), do: Repo.get!(CashPoolEntry, id) |> Repo.preload([:pool, :company, :bank_account])

  def create_cash_pool_entry(attrs) do
    %CashPoolEntry{}
    |> CashPoolEntry.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("cash_pool_entries", "create")
  end

  def update_cash_pool_entry(%CashPoolEntry{} = cpe, attrs) do
    cpe
    |> CashPoolEntry.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("cash_pool_entries", "update")
  end

  def delete_cash_pool_entry(%CashPoolEntry{} = cpe) do
    Repo.delete(cpe)
    |> audit_and_broadcast("cash_pool_entries", "delete")
  end

  # PubSub
  def subscribe, do: Phoenix.PubSub.subscribe(Holdco.PubSub, "treasury")
  defp broadcast(message), do: Phoenix.PubSub.broadcast(Holdco.PubSub, "treasury", message)

  defp audit_and_broadcast(result, table, action) do
    case result do
      {:ok, record} ->
        Holdco.Platform.log_action(action, table, record.id)
        broadcast({String.to_atom("#{table}_#{action}d"), record})
        {:ok, record}
      error -> error
    end
  end
end
