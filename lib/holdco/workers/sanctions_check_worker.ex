defmodule Holdco.Workers.SanctionsCheckWorker do
  @moduledoc """
  Oban worker that screens all companies and beneficial owners
  against active sanctions lists. Creates SanctionsCheck records.
  """
  use Oban.Worker, queue: :default, max_attempts: 3

  alias Holdco.{Corporate, Compliance}

  @impl Oban.Worker
  def perform(_job) do
    sanctions_lists = Compliance.list_sanctions_lists()
    companies = Corporate.list_companies()

    for company <- companies do
      entries = Enum.flat_map(sanctions_lists, fn sl -> sl.entries end)
      screen_entity(company.id, company.name, entries)

      # Also screen beneficial owners
      owners = Corporate.list_beneficial_owners(company.id)

      for owner <- owners do
        screen_entity(company.id, owner.name, entries)
      end
    end

    :ok
  end

  defp screen_entity(company_id, name, entries) do
    normalized = String.downcase(name) |> String.trim()

    match =
      Enum.find(entries, fn entry ->
        entry_name = String.downcase(entry.name) |> String.trim()
        String.jaro_distance(normalized, entry_name) > 0.85
      end)

    case match do
      nil ->
        Compliance.create_sanctions_check(%{
          company_id: company_id,
          checked_name: name,
          status: "clear",
          notes: "Automated screening - no match found"
        })

      entry ->
        Compliance.create_sanctions_check(%{
          company_id: company_id,
          checked_name: name,
          status: "match",
          matched_entry_id: entry.id,
          notes: "Potential match: #{entry.name} (similarity > 0.85)"
        })

        Holdco.Platform.log_action(
          "sanctions_match",
          "sanctions_checks",
          company_id,
          "Potential sanctions match for #{name} against #{entry.name}"
        )

        Holdco.Notifications.notify_all_admins(
          "Sanctions Match Detected",
          "#{name} matched against #{entry.name}",
          type: "warning",
          entity_type: "companies",
          entity_id: company_id,
          action_url: "/compliance"
        )
    end
  end
end
