defmodule Holdco.Workers.EmailDigestWorker do
  @moduledoc """
  Oban worker that compiles and sends email digests.
  Reads active EmailDigestConfigs and sends summaries via Swoosh.
  """
  use Oban.Worker, queue: :default, max_attempts: 3

  alias Holdco.{Integrations, Platform, Portfolio, Compliance, Banking, Repo}
  alias Holdco.Mailer
  import Swoosh.Email

  @impl Oban.Worker
  def perform(_job) do
    configs = Integrations.list_email_digest_configs()

    for config <- configs, config.is_active do
      send_digest(config)
    end

    :ok
  end

  defp send_digest(config) do
    case Repo.get(Holdco.Accounts.User, config.user_id) do
      nil ->
        Platform.log_action(
          "email_digest_skipped",
          "email_digest_configs",
          config.id,
          "User #{config.user_id} not found, skipping digest"
        )

      user ->
        do_send_digest(config, user)
    end
  end

  defp do_send_digest(config, user) do
    since = config.last_sent_at || DateTime.add(DateTime.utc_now(), -7 * 86400, :second)
    sections = build_sections(config, since)

    email =
      new()
      |> to(user.email)
      |> from(Holdco.Config.mail_from())
      |> subject("Holdco Digest - #{Date.utc_today()}")
      |> text_body(sections)

    case Mailer.deliver(email) do
      {:ok, _} ->
        Integrations.update_email_digest_config(config, %{
          last_sent_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      {:error, reason} ->
        Platform.log_action(
          "email_digest_failed",
          "email_digest_configs",
          config.id,
          "Failed to send digest: #{inspect(reason)}"
        )
    end
  end

  defp build_sections(config, since) do
    sections = ["Holdco Digest - #{Date.utc_today()}", ""]

    sections =
      if config.include_portfolio do
        nav = Portfolio.calculate_nav()

        sections ++
          [
            "== Portfolio ==",
            "NAV: $#{format_num(nav.nav)}",
            "Liquid: $#{format_num(nav.liquid)} | Marketable: $#{format_num(nav.marketable)} | Illiquid: $#{format_num(nav.illiquid)}",
            "Liabilities: $#{format_num(nav.liabilities)}",
            ""
          ]
      else
        sections
      end

    sections =
      if config.include_deadlines do
        deadlines = Compliance.list_tax_deadlines()

        upcoming =
          deadlines
          |> Enum.filter(fn td ->
            case Date.from_iso8601(td.due_date || "") do
              {:ok, d} -> Date.diff(d, Date.utc_today()) in 0..30 and td.status == "pending"
              _ -> false
            end
          end)

        sections ++
          [
            "== Upcoming Deadlines (30 days) ==",
            if(upcoming == [],
              do: "No upcoming deadlines.",
              else:
                Enum.map_join(upcoming, "\n", fn td ->
                  "- #{td.due_date}: #{td.description}"
                end)
            ),
            ""
          ]
      else
        sections
      end

    sections =
      if config.include_audit_log do
        logs = Platform.list_audit_logs(%{limit: 20})

        recent =
          Enum.filter(logs, fn log ->
            DateTime.after?(log.inserted_at, since)
          end)

        sections ++
          [
            "== Recent Activity ==",
            if(recent == [],
              do: "No recent activity.",
              else:
                Enum.map_join(recent, "\n", fn log ->
                  "- [#{log.action}] #{log.table_name} ##{log.record_id}"
                end)
            ),
            ""
          ]
      else
        sections
      end

    sections =
      if config.include_transactions do
        transactions = Banking.list_transactions()

        recent =
          Enum.filter(transactions, fn t ->
            case Date.from_iso8601(t.date || "") do
              {:ok, d} ->
                since_date = DateTime.to_date(since)
                Date.compare(d, since_date) != :lt

              _ ->
                false
            end
          end)
          |> Enum.take(20)

        sections ++
          [
            "== Recent Transactions ==",
            if(recent == [],
              do: "No recent transactions.",
              else:
                Enum.map_join(recent, "\n", fn t ->
                  "- #{t.date}: #{t.description} #{t.amount} #{t.currency}"
                end)
            ),
            ""
          ]
      else
        sections
      end

    Enum.join(sections, "\n")
  end

  defp format_num(n) when is_float(n), do: :erlang.float_to_binary(n, decimals: 0)
  defp format_num(n) when is_integer(n), do: Integer.to_string(n)
  defp format_num(_), do: "0"
end
