defmodule Holdco.Assets do
  import Ecto.Query
  alias Holdco.Repo

  alias Holdco.Assets.{
    AssetHolding,
    CustodianAccount,
    CostBasisLot,
    CryptoWallet,
    RealEstateProperty,
    FundInvestment,
    PortfolioSnapshot
  }

  # Asset Holdings
  def list_holdings(filters \\ %{}) do
    AssetHolding
    |> Holdco.QueryHelpers.apply_filters(filters)
    |> order_by([h], asc: h.asset)
    |> preload([:company, :custodian, :cost_basis_lots])
    |> Repo.all()
  end

  def get_holding!(id) do
    Repo.get!(AssetHolding, id)
    |> Repo.preload([:company, :custodian, :cost_basis_lots, :crypto_wallets])
  end

  def create_holding(attrs) do
    %AssetHolding{}
    |> AssetHolding.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("asset_holdings", "create")
  end

  def update_holding(%AssetHolding{} = holding, attrs) do
    holding
    |> AssetHolding.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("asset_holdings", "update")
  end

  def delete_holding(%AssetHolding{} = holding) do
    Repo.delete(holding)
    |> audit_and_broadcast("asset_holdings", "delete")
  end

  # Bulk Operations
  def bulk_update_holdings(ids, attrs) when is_list(ids) do
    results =
      Enum.map(ids, fn id ->
        holding = get_holding!(id)
        update_holding(holding, attrs)
      end)

    {Enum.count(results, &match?({:ok, _}, &1)),
     Enum.count(results, &match?({:error, _}, &1))}
  end

  def bulk_delete_holdings(ids) when is_list(ids) do
    results =
      Enum.map(ids, fn id ->
        holding = get_holding!(id)
        delete_holding(holding)
      end)

    {Enum.count(results, &match?({:ok, _}, &1)),
     Enum.count(results, &match?({:error, _}, &1))}
  end

  # Custodian Accounts
  def list_custodian_accounts do
    from(ca in CustodianAccount, preload: [:asset_holding])
    |> Repo.all()
  end

  def get_custodian_account!(id),
    do: Repo.get!(CustodianAccount, id) |> Repo.preload(:asset_holding)

  def create_custodian_account(attrs) do
    %CustodianAccount{}
    |> CustodianAccount.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("custodian_accounts", "create")
  end

  def update_custodian_account(%CustodianAccount{} = ca, attrs) do
    ca
    |> CustodianAccount.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("custodian_accounts", "update")
  end

  def delete_custodian_account(%CustodianAccount{} = ca) do
    Repo.delete(ca)
    |> audit_and_broadcast("custodian_accounts", "delete")
  end

  # Cost Basis Lots
  def list_cost_basis_lots(holding_id) do
    from(cbl in CostBasisLot, where: cbl.holding_id == ^holding_id, order_by: cbl.purchase_date)
    |> Repo.all()
  end

  def get_cost_basis_lot!(id), do: Repo.get!(CostBasisLot, id)

  def create_cost_basis_lot(attrs) do
    %CostBasisLot{}
    |> CostBasisLot.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("cost_basis_lots", "create")
  end

  def update_cost_basis_lot(%CostBasisLot{} = cbl, attrs) do
    cbl
    |> CostBasisLot.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("cost_basis_lots", "update")
  end

  def delete_cost_basis_lot(%CostBasisLot{} = cbl) do
    Repo.delete(cbl)
    |> audit_and_broadcast("cost_basis_lots", "delete")
  end

  # Crypto Wallets
  def list_crypto_wallets(holding_id \\ nil) do
    query = from(cw in CryptoWallet, order_by: cw.blockchain, preload: [:holding])
    query = if holding_id, do: where(query, [cw], cw.holding_id == ^holding_id), else: query
    Repo.all(query)
  end

  def get_crypto_wallet!(id), do: Repo.get!(CryptoWallet, id) |> Repo.preload(:holding)

  def create_crypto_wallet(attrs) do
    %CryptoWallet{}
    |> CryptoWallet.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("crypto_wallets", "create")
  end

  def update_crypto_wallet(%CryptoWallet{} = cw, attrs) do
    cw
    |> CryptoWallet.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("crypto_wallets", "update")
  end

  def delete_crypto_wallet(%CryptoWallet{} = cw) do
    Repo.delete(cw)
    |> audit_and_broadcast("crypto_wallets", "delete")
  end

  # Real Estate Properties
  def list_real_estate_properties(company_id \\ nil) do
    query = from(re in RealEstateProperty, order_by: re.name, preload: [:company])
    query = if company_id, do: where(query, [re], re.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_real_estate_property!(id),
    do: Repo.get!(RealEstateProperty, id) |> Repo.preload(:company)

  def create_real_estate_property(attrs) do
    %RealEstateProperty{}
    |> RealEstateProperty.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("real_estate_properties", "create")
  end

  def update_real_estate_property(%RealEstateProperty{} = re, attrs) do
    re
    |> RealEstateProperty.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("real_estate_properties", "update")
  end

  def delete_real_estate_property(%RealEstateProperty{} = re) do
    Repo.delete(re)
    |> audit_and_broadcast("real_estate_properties", "delete")
  end

  # Fund Investments
  def list_fund_investments(company_id \\ nil) do
    query = from(fi in FundInvestment, order_by: fi.fund_name, preload: [:company])
    query = if company_id, do: where(query, [fi], fi.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_fund_investment!(id), do: Repo.get!(FundInvestment, id) |> Repo.preload(:company)

  def create_fund_investment(attrs) do
    %FundInvestment{}
    |> FundInvestment.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("fund_investments", "create")
  end

  def update_fund_investment(%FundInvestment{} = fi, attrs) do
    fi
    |> FundInvestment.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("fund_investments", "update")
  end

  def delete_fund_investment(%FundInvestment{} = fi) do
    Repo.delete(fi)
    |> audit_and_broadcast("fund_investments", "delete")
  end

  # Portfolio Snapshots
  def list_portfolio_snapshots do
    from(ps in PortfolioSnapshot, order_by: [desc: ps.date])
    |> Repo.all()
  end

  def get_portfolio_snapshot!(id), do: Repo.get!(PortfolioSnapshot, id)

  def create_portfolio_snapshot(attrs) do
    %PortfolioSnapshot{}
    |> PortfolioSnapshot.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("portfolio_snapshots", "create")
  end

  def update_portfolio_snapshot(%PortfolioSnapshot{} = ps, attrs) do
    ps
    |> PortfolioSnapshot.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("portfolio_snapshots", "update")
  end

  def delete_portfolio_snapshot(%PortfolioSnapshot{} = ps) do
    Repo.delete(ps)
    |> audit_and_broadcast("portfolio_snapshots", "delete")
  end

  # PubSub

  defp broadcast(message), do: Phoenix.PubSub.broadcast(Holdco.PubSub, "portfolio", message)

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
