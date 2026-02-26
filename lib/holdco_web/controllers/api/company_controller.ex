defmodule HoldcoWeb.Api.CompanyController do
  use HoldcoWeb, :controller

  alias Holdco.Corporate

  def index(conn, _params) do
    companies =
      Corporate.list_companies()
      |> Enum.map(&company_json/1)

    json(conn, %{companies: companies})
  end

  def show(conn, %{"id" => id}) do
    company = Corporate.get_company!(id)
    json(conn, %{company: company_json(company)})
  end

  defp company_json(c) do
    %{
      id: c.id,
      name: c.name,
      country: c.country,
      entity_type: c.entity_type,
      category: c.category,
      ownership_pct: c.ownership_pct,
      kyc_status: c.kyc_status,
      parent_id: c.parent_id,
      inserted_at: c.inserted_at,
      updated_at: c.updated_at
    }
  end
end
