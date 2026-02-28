defmodule Holdco.Fund do
  @moduledoc """
  Context for fund/partnership management, including partnership basis tracking.
  """

  import Ecto.Query
  alias Holdco.Repo
  alias Holdco.Money
  alias Holdco.Fund.PartnershipBasis

  # Partnership Bases
  def list_partnership_bases(company_id \\ nil) do
    query = from(pb in PartnershipBasis, order_by: [desc: pb.tax_year, asc: pb.partner_name], preload: [:company])
    query = if company_id, do: where(query, [pb], pb.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_partnership_basis!(id), do: Repo.get!(PartnershipBasis, id) |> Repo.preload(:company)

  def create_partnership_basis(attrs) do
    %PartnershipBasis{}
    |> PartnershipBasis.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("partnership_bases", "create")
  end

  def update_partnership_basis(%PartnershipBasis{} = pb, attrs) do
    pb
    |> PartnershipBasis.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("partnership_bases", "update")
  end

  def delete_partnership_basis(%PartnershipBasis{} = pb) do
    Repo.delete(pb)
    |> audit_and_broadcast("partnership_bases", "delete")
  end

  @doc """
  Computes the ending basis from the component fields of a partnership basis record.

  ending_basis = beginning_basis + capital_contributions + share_of_income
                 - share_of_losses - distributions_received
                 + special_allocations + section_754_adjustments
  """
  def calculate_ending_basis(%PartnershipBasis{} = pb) do
    pb.beginning_basis
    |> Money.add(pb.capital_contributions)
    |> Money.add(pb.share_of_income)
    |> Money.sub(pb.share_of_losses)
    |> Money.sub(pb.distributions_received)
    |> Money.add(pb.special_allocations)
    |> Money.add(pb.section_754_adjustments)
  end

  @doc """
  Returns multi-year basis history for a given company and partner name,
  ordered by tax_year ascending.
  """
  def basis_history(company_id, partner_name) do
    from(pb in PartnershipBasis,
      where: pb.company_id == ^company_id and pb.partner_name == ^partner_name,
      order_by: [asc: pb.tax_year],
      preload: [:company]
    )
    |> Repo.all()
  end

  # PubSub
  def subscribe, do: Phoenix.PubSub.subscribe(Holdco.PubSub, "fund")
  defp broadcast(message), do: Phoenix.PubSub.broadcast(Holdco.PubSub, "fund", message)

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
