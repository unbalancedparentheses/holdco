defmodule Holdco.Workers.ScheduledReportWorker do
  @moduledoc """
  Oban worker that processes scheduled reports.
  Runs daily at 6am, finds due reports, generates content, and sends via email.
  """
  use Oban.Worker, queue: :default, max_attempts: 3

  alias Holdco.{Analytics, Portfolio, Finance, Compliance, Platform, Mailer}
  import Swoosh.Email

  @impl Oban.Worker
  def perform(_job) do
    reports = Analytics.list_due_scheduled_reports()

    for report <- reports do
      send_report(report)
    end

    :ok
  end

  defp send_report(report) do
    recipients = parse_recipients(report.recipients)

    if recipients == [] do
      Platform.log_action(
        "scheduled_report_skipped",
        "scheduled_reports",
        report.id,
        "No valid recipients"
      )
    else
      content = generate_report_content(report)

      Enum.each(recipients, fn recipient ->
        email = build_email(report, recipient, content)

        case Mailer.deliver(email) do
          {:ok, _} ->
            :ok

          {:error, reason} ->
            Platform.log_action(
              "scheduled_report_failed",
              "scheduled_reports",
              report.id,
              "Failed to send to #{recipient}: #{inspect(reason)}"
            )
        end
      end)

      Analytics.advance_next_run_date(report)

      Platform.log_action(
        "scheduled_report_sent",
        "scheduled_reports",
        report.id,
        "Report '#{report.name}' sent to #{Enum.join(recipients, ", ")}"
      )
    end
  rescue
    e ->
      Platform.log_action(
        "scheduled_report_failed",
        "scheduled_reports",
        report.id,
        "Error: #{Exception.message(e)}"
      )
  end

  defp parse_recipients(nil), do: []
  defp parse_recipients(""), do: []

  defp parse_recipients(recipients) when is_binary(recipients) do
    recipients
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp build_email(report, recipient, content) do
    subject = "#{report.name} - #{Date.utc_today()}"

    email =
      new()
      |> to(recipient)
      |> from(Holdco.Config.mail_from())
      |> subject(subject)

    case report.format do
      "csv" ->
        email |> text_body(content)

      _ ->
        email |> html_body(wrap_html(report.name, content)) |> text_body(strip_html(content))
    end
  end

  def generate_report_content(report) do
    case report.report_type do
      "portfolio_summary" -> generate_portfolio_summary()
      "financial_report" -> generate_financial_report(report.company_id)
      "compliance_report" -> generate_compliance_report(report.company_id)
      "board_pack" -> generate_board_pack(report.company_id)
      _ -> "<p>Unknown report type: #{report.report_type}</p>"
    end
  end

  defp generate_portfolio_summary do
    nav = Portfolio.calculate_nav()

    """
    <h2>Portfolio Summary</h2>
    <table border="1" cellpadding="8" cellspacing="0" style="border-collapse: collapse;">
    <tr><th>Metric</th><th>Value</th></tr>
    <tr><td>Net Asset Value (NAV)</td><td>$#{format_num(nav.nav)}</td></tr>
    <tr><td>Liquid Assets</td><td>$#{format_num(nav.liquid)}</td></tr>
    <tr><td>Marketable Securities</td><td>$#{format_num(nav.marketable)}</td></tr>
    <tr><td>Illiquid Holdings</td><td>$#{format_num(nav.illiquid)}</td></tr>
    <tr><td>Total Liabilities</td><td>$#{format_num(nav.liabilities)}</td></tr>
    </table>
    <p>Generated on #{Date.utc_today()}</p>
    """
  end

  defp generate_financial_report(company_id) do
    trial_balance = Finance.trial_balance(company_id)
    income = Finance.income_statement(company_id)

    tb_rows =
      trial_balance
      |> Enum.take(20)
      |> Enum.map(fn row ->
        "<tr><td>#{row.code}</td><td>#{row.name}</td><td>$#{format_num(row.debit)}</td><td>$#{format_num(row.credit)}</td><td>$#{format_num(row.balance)}</td></tr>"
      end)
      |> Enum.join("\n")

    all_income_items = Map.get(income, :revenue, []) ++ Map.get(income, :expenses, [])

    income_rows =
      all_income_items
      |> Enum.take(20)
      |> Enum.map(fn row ->
        "<tr><td>#{Map.get(row, :name, "")}</td><td>$#{format_num(Map.get(row, :amount, 0))}</td></tr>"
      end)
      |> Enum.join("\n")

    net_income = Map.get(income, :net_income, Decimal.new(0))

    """
    <h2>Financial Report</h2>
    <h3>Trial Balance</h3>
    <table border="1" cellpadding="8" cellspacing="0" style="border-collapse: collapse;">
    <tr><th>Code</th><th>Account</th><th>Debit</th><th>Credit</th><th>Balance</th></tr>
    #{tb_rows}
    </table>
    <h3>Income Statement</h3>
    <table border="1" cellpadding="8" cellspacing="0" style="border-collapse: collapse;">
    <tr><th>Account</th><th>Amount</th></tr>
    #{income_rows}
    <tr><td><strong>Net Income</strong></td><td><strong>$#{format_num(net_income)}</strong></td></tr>
    </table>
    <p>Generated on #{Date.utc_today()}</p>
    """
  end

  defp generate_compliance_report(company_id) do
    deadlines = Compliance.list_tax_deadlines(company_id)

    upcoming =
      deadlines
      |> Enum.filter(fn td ->
        case Date.from_iso8601(td.due_date || "") do
          {:ok, d} -> Date.diff(d, Date.utc_today()) in 0..90 and td.status == "pending"
          _ -> false
        end
      end)

    rows =
      upcoming
      |> Enum.map(fn td ->
        days = Date.diff(Date.from_iso8601!(td.due_date), Date.utc_today())
        urgency = if days <= 14, do: "style=\"color: red;\"", else: ""

        "<tr #{urgency}><td>#{td.due_date}</td><td>#{td.description}</td><td>#{td.jurisdiction}</td><td>#{days} days</td></tr>"
      end)
      |> Enum.join("\n")

    """
    <h2>Compliance Report</h2>
    <h3>Upcoming Deadlines (90 days)</h3>
    <table border="1" cellpadding="8" cellspacing="0" style="border-collapse: collapse;">
    <tr><th>Due Date</th><th>Description</th><th>Jurisdiction</th><th>Days Remaining</th></tr>
    #{if rows == "", do: "<tr><td colspan=\"4\">No upcoming deadlines</td></tr>", else: rows}
    </table>
    <p>Generated on #{Date.utc_today()}</p>
    """
  end

  defp generate_board_pack(company_id) do
    portfolio = generate_portfolio_summary()
    financial = generate_financial_report(company_id)
    compliance = generate_compliance_report(company_id)

    """
    <h1>Board Pack - #{Date.utc_today()}</h1>
    <hr/>
    #{portfolio}
    <hr/>
    #{financial}
    <hr/>
    #{compliance}
    """
  end

  defp wrap_html(title, body) do
    """
    <!DOCTYPE html>
    <html>
    <head><meta charset="utf-8"><title>#{title}</title></head>
    <body style="font-family: Arial, sans-serif; padding: 20px; max-width: 800px; margin: 0 auto;">
    #{body}
    </body>
    </html>
    """
  end

  defp strip_html(html) do
    html
    |> String.replace(~r/<[^>]+>/, "")
    |> String.replace(~r/\n{3,}/, "\n\n")
    |> String.trim()
  end

  defp format_num(n) when is_struct(n, Decimal), do: Decimal.to_string(n, :normal)
  defp format_num(n) when is_float(n), do: :erlang.float_to_binary(n, decimals: 2)
  defp format_num(n) when is_integer(n), do: Integer.to_string(n)
  defp format_num(nil), do: "0"
  defp format_num(n), do: to_string(n)
end
