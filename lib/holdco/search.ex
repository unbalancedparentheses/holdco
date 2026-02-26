defmodule Holdco.Search do
  @moduledoc """
  Cross-table search across companies, holdings, transactions, and documents.
  """
  import Ecto.Query
  alias Holdco.Repo

  def search(query) when is_binary(query) and byte_size(query) > 0 do
    term = "%#{query}%"

    companies = search_companies(term)
    holdings = search_holdings(term)
    transactions = search_transactions(term)
    documents = search_documents(term)

    %{
      companies: companies,
      holdings: holdings,
      transactions: transactions,
      documents: documents,
      total: length(companies) + length(holdings) + length(transactions) + length(documents)
    }
  end

  def search(_), do: %{companies: [], holdings: [], transactions: [], documents: [], total: 0}

  defp search_companies(term) do
    from(c in Holdco.Corporate.Company,
      where: like(c.name, ^term) or like(c.country, ^term) or like(c.category, ^term),
      order_by: c.name,
      limit: 10
    )
    |> Repo.all()
    |> Enum.map(&%{id: &1.id, name: &1.name, type: :company, detail: &1.country})
  end

  defp search_holdings(term) do
    from(h in Holdco.Assets.AssetHolding,
      where: like(h.asset, ^term) or like(h.ticker, ^term),
      order_by: h.asset,
      limit: 10
    )
    |> Repo.all()
    |> Enum.map(&%{id: &1.id, name: &1.asset, type: :holding, detail: &1.ticker})
  end

  defp search_transactions(term) do
    from(t in Holdco.Banking.Transaction,
      where: like(t.description, ^term) or like(t.counterparty, ^term),
      order_by: [desc: t.date],
      limit: 10
    )
    |> Repo.all()
    |> Enum.map(&%{id: &1.id, name: &1.description, type: :transaction, detail: &1.date})
  end

  defp search_documents(term) do
    from(d in Holdco.Documents.Document,
      where: like(d.name, ^term) or like(d.doc_type, ^term),
      order_by: d.name,
      limit: 10
    )
    |> Repo.all()
    |> Enum.map(&%{id: &1.id, name: &1.name, type: :document, detail: &1.doc_type})
  end
end
