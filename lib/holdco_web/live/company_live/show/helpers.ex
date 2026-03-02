defmodule HoldcoWeb.CompanyLive.ShowHelpers do
  @moduledoc false

  alias Holdco.Money

  # --- Data helpers ---

  def rows(assigns, field) do
    if assigns.is_consolidated,
      do: consolidated_with_company(assigns.company, assigns.sub_companies, field),
      else: Enum.map(Map.get(assigns.company, field) || [], &{&1, nil})
  end

  defp consolidated_with_company(company, sub_companies, field) do
    for c <- [company | sub_companies],
        item <- Map.get(c, field) || [] do
      {item, c.name}
    end
  end

  # --- Number helpers ---

  def parse_float(nil), do: 0.0
  def parse_float(""), do: 0.0

  def parse_float(val) when is_binary(val) do
    case Float.parse(val) do
      {f, _} -> f
      :error -> 0.0
    end
  end

  def parse_float(val) when is_float(val), do: val
  def parse_float(val) when is_integer(val), do: val * 1.0
  def parse_float(%Decimal{} = d), do: Decimal.to_float(d)

  def format_number(%Decimal{} = n), do: n |> Decimal.round(2) |> Decimal.to_string()
  def format_number(n) when is_float(n), do: Money.format(n, 2)
  def format_number(n) when is_integer(n), do: Integer.to_string(n) <> ".00"
  def format_number(_), do: "0.00"

  def format_qbo_sync_count({:ok, count}), do: "#{count} synced"
  def format_qbo_sync_count({:error, reason}), do: "Error: #{inspect(reason)}"
  def format_qbo_sync_count(_), do: "—"

  def entry_totals(entry) do
    lines = entry.lines || []
    total_debit = Enum.reduce(lines, Decimal.new(0), fn l, acc -> Money.add(acc, Money.to_decimal(l.debit)) end)
    total_credit = Enum.reduce(lines, Decimal.new(0), fn l, acc -> Money.add(acc, Money.to_decimal(l.credit)) end)
    {total_debit, total_credit}
  end

  # --- Tab labels ---

  def tab_label("overview"), do: "Overview"
  def tab_label("holdings"), do: "Positions"
  def tab_label("bank_accounts"), do: "Bank Accounts"
  def tab_label("transactions"), do: "Transactions"
  def tab_label("documents"), do: "Documents"
  def tab_label("governance"), do: "Governance"
  def tab_label("compliance"), do: "Compliance"
  def tab_label("financials"), do: "Financials"
  def tab_label("accounting"), do: "Accounting"
  def tab_label("integrations"), do: "Integrations"
  def tab_label("comments"), do: "Comments"

  # --- Tag helpers ---

  def kyc_tag("approved"), do: "tag-jade"
  def kyc_tag("in_progress"), do: "tag-lemon"
  def kyc_tag("rejected"), do: "tag-crimson"
  def kyc_tag(_), do: "tag-ink"

  def status_tag("active"), do: "tag-jade"
  def status_tag("winding_down"), do: "tag-lemon"
  def status_tag("dissolved"), do: "tag-crimson"
  def status_tag(_), do: "tag-ink"

  def meeting_status_tag("completed"), do: "tag-jade"
  def meeting_status_tag("scheduled"), do: "tag-lemon"
  def meeting_status_tag("cancelled"), do: "tag-crimson"
  def meeting_status_tag(_), do: "tag-ink"

  def deadline_status_tag("completed"), do: "tag-jade"
  def deadline_status_tag("filed"), do: "tag-jade"
  def deadline_status_tag("pending"), do: "tag-lemon"
  def deadline_status_tag("overdue"), do: "tag-crimson"
  def deadline_status_tag(_), do: "tag-ink"

  def sanctions_status_tag("clear"), do: "tag-jade"
  def sanctions_status_tag("flagged"), do: "tag-crimson"
  def sanctions_status_tag("pending"), do: "tag-lemon"
  def sanctions_status_tag(_), do: "tag-ink"

  # --- Upload helpers ---

  def humanize_upload_error(:too_large), do: "File is too large (max 20 MB)"
  def humanize_upload_error(:too_many_files), do: "Too many files"
  def humanize_upload_error(:not_accepted), do: "File type not accepted"
  def humanize_upload_error(err), do: "Upload error: #{inspect(err)}"
end
