defmodule Holdco.Workers.RecurringTransactionWorker do
  use Oban.Worker, queue: :default, max_attempts: 3

  alias Holdco.Finance

  @impl Oban.Worker
  def perform(_job) do
    due_transactions = Finance.list_due_recurring_transactions()

    Enum.each(due_transactions, fn rt ->
      process_recurring_transaction(rt)
    end)

    :ok
  end

  defp process_recurring_transaction(rt) do
    today = Date.utc_today() |> Date.to_iso8601()

    entry_attrs = %{
      "company_id" => rt.company_id,
      "date" => today,
      "description" => "Recurring: #{rt.description}",
      "reference" => "RT-#{rt.id}"
    }

    lines_attrs =
      if rt.debit_account_id && rt.credit_account_id do
        [
          %{
            "account_id" => rt.debit_account_id,
            "debit" => rt.amount,
            "credit" => Decimal.new(0)
          },
          %{
            "account_id" => rt.credit_account_id,
            "debit" => Decimal.new(0),
            "credit" => rt.amount
          }
        ]
      else
        nil
      end

    if lines_attrs do
      case Finance.create_journal_entry_with_lines(entry_attrs, lines_attrs) do
        {:ok, _entry} ->
          Finance.advance_next_run_date(rt)

        {:error, _reason} ->
          # Log the error but don't fail the entire job
          Holdco.Platform.log_action(
            "error",
            "recurring_transactions",
            rt.id
          )

          Finance.advance_next_run_date(rt)
      end
    else
      # No accounts configured, just advance the date
      Finance.advance_next_run_date(rt)
    end
  end
end
