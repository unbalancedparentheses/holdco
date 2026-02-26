defmodule HoldcoWeb.Api.TransactionController do
  use HoldcoWeb, :controller

  alias Holdco.Banking

  def index(conn, _params) do
    transactions =
      Banking.list_transactions()
      |> Enum.map(&transaction_json/1)

    json(conn, %{transactions: transactions})
  end

  defp transaction_json(t) do
    %{
      id: t.id,
      description: t.description,
      amount: t.amount,
      currency: t.currency,
      date: t.date,
      transaction_type: t.transaction_type,
      company_id: t.company_id,
      company_name: if(t.company, do: t.company.name),
      inserted_at: t.inserted_at,
      updated_at: t.updated_at
    }
  end
end
