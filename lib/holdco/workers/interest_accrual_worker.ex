defmodule Holdco.Workers.InterestAccrualWorker do
  use Oban.Worker, queue: :default, max_attempts: 3

  alias Holdco.Finance
  alias Holdco.Finance.InterestAccrual

  @impl Oban.Worker
  def perform(_job) do
    transfers = Finance.list_inter_company_transfers()

    # Filter for active/loan transfers (status "active" or description contains "loan")
    loan_transfers =
      Enum.filter(transfers, fn t ->
        t.status == "active" or
          (is_binary(t.description) and String.contains?(String.downcase(t.description), "loan"))
      end)

    entries = InterestAccrual.generate_journal_entries(loan_transfers)

    Enum.each(entries, fn {entry_attrs, lines_attrs} ->
      # Lines need account_ids to be created via create_journal_entry_with_lines.
      # If no accounts exist, we skip the journal entry creation to avoid errors.
      # In production, specific interest expense and payable accounts would be configured.
      case find_interest_accounts(entry_attrs) do
        {:ok, expense_account_id, payable_account_id} ->
          lines_with_accounts =
            lines_attrs
            |> Enum.with_index()
            |> Enum.map(fn {line, idx} ->
              account_id = if idx == 0, do: expense_account_id, else: payable_account_id
              Map.put(line, "account_id", account_id)
            end)

          Finance.create_journal_entry_with_lines(entry_attrs, lines_with_accounts)

        :no_accounts ->
          # Log that we could not create the entry due to missing accounts
          Holdco.Platform.log_action(
            "interest_accrual_skipped",
            "inter_company_transfers",
            0,
            "No interest expense/payable accounts found"
          )
      end
    end)

    :ok
  end

  defp find_interest_accounts(_entry_attrs) do
    accounts = Finance.list_accounts()

    expense_account =
      Enum.find(accounts, fn a ->
        a.account_type == "expense" and
          (String.contains?(String.downcase(a.name), "interest") or
             String.contains?(String.downcase(a.code || ""), "interest"))
      end)

    payable_account =
      Enum.find(accounts, fn a ->
        a.account_type == "liability" and
          (String.contains?(String.downcase(a.name), "interest") or
             String.contains?(String.downcase(a.code || ""), "interest"))
      end)

    if expense_account && payable_account do
      {:ok, expense_account.id, payable_account.id}
    else
      :no_accounts
    end
  end
end
