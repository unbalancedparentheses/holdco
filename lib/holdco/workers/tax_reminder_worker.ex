defmodule Holdco.Workers.TaxReminderWorker do
  use Oban.Worker, queue: :default, max_attempts: 3

  alias Holdco.Compliance

  @impl Oban.Worker
  def perform(_job) do
    today = Date.utc_today()
    upcoming_days = 14

    deadlines =
      Compliance.list_tax_deadlines()
      |> Enum.filter(fn td ->
        case Date.from_iso8601(td.due_date) do
          {:ok, due} ->
            diff = Date.diff(due, today)
            diff >= 0 and diff <= upcoming_days and td.status == "pending"

          _ ->
            false
        end
      end)

    for deadline <- deadlines do
      Holdco.Platform.log_action(
        "reminder",
        "tax_deadlines",
        deadline.id,
        "Tax deadline approaching: #{deadline.description} due #{deadline.due_date}"
      )

      Holdco.Notifications.notify_all_admins(
        "Tax Deadline Approaching",
        "#{deadline.description} due #{deadline.due_date}",
        type: "warning",
        entity_type: "tax_deadlines",
        entity_id: deadline.id,
        action_url: "/tax-calendar"
      )
    end

    :ok
  end
end
