defmodule Holdco.Platform do
  import Ecto.Query
  alias Holdco.Repo

  alias Holdco.Platform.{
    Setting,
    Category,
    AuditLog,
    Webhook,
    ApprovalRequest,
    ApprovalVote,
    CustomField,
    CustomFieldValue,
    BackupConfig,
    BackupLog,
    AlertRule,
    Alert
  }

  # Audit Log
  def list_audit_logs(opts \\ %{}) do
    AuditLog
    |> apply_audit_filters(opts)
    |> order_by([a], desc: a.inserted_at)
    |> limit(^Map.get(opts, :limit, 100))
    |> Repo.all()
    |> Repo.preload(:user)
  end

  defp apply_audit_filters(query, opts) do
    query
    |> maybe_filter_action(opts)
    |> maybe_filter_table_name(opts)
    |> maybe_filter_user_id(opts)
    |> maybe_filter_from(opts)
    |> maybe_filter_to(opts)
  end

  defp maybe_filter_action(query, %{action: action}) when action not in [nil, ""],
    do: where(query, [a], a.action == ^action)

  defp maybe_filter_action(query, _opts), do: query

  defp maybe_filter_table_name(query, %{table_name: table_name}) when table_name not in [nil, ""],
    do: where(query, [a], a.table_name == ^table_name)

  defp maybe_filter_table_name(query, _opts), do: query

  defp maybe_filter_user_id(query, %{user_id: user_id}) when user_id not in [nil, ""],
    do: where(query, [a], a.user_id == ^user_id)

  defp maybe_filter_user_id(query, _opts), do: query

  defp maybe_filter_from(query, %{from: from}) when from not in [nil, ""] do
    case parse_datetime(from) do
      {:ok, dt} -> where(query, [a], a.inserted_at >= ^dt)
      _ -> query
    end
  end

  defp maybe_filter_from(query, _opts), do: query

  defp maybe_filter_to(query, %{to: to}) when to not in [nil, ""] do
    case parse_datetime_end_of_day(to) do
      {:ok, dt} -> where(query, [a], a.inserted_at <= ^dt)
      _ -> query
    end
  end

  defp maybe_filter_to(query, _opts), do: query

  defp parse_datetime(%DateTime{} = dt), do: {:ok, dt}

  defp parse_datetime(str) when is_binary(str) do
    # Try full datetime first, then date-only (assume start/end of day)
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} ->
        {:ok, dt}

      _ ->
        case Date.from_iso8601(str) do
          {:ok, date} -> {:ok, DateTime.new!(date, ~T[00:00:00], "Etc/UTC")}
          error -> error
        end
    end
  end

  defp parse_datetime(_), do: :error

  defp parse_datetime_end_of_day(%DateTime{} = dt), do: {:ok, dt}

  defp parse_datetime_end_of_day(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} ->
        {:ok, dt}

      _ ->
        case Date.from_iso8601(str) do
          {:ok, date} -> {:ok, DateTime.new!(date, ~T[23:59:59], "Etc/UTC")}
          error -> error
        end
    end
  end

  defp parse_datetime_end_of_day(_), do: :error

  def create_audit_log(attrs) do
    %AuditLog{}
    |> AuditLog.changeset(attrs)
    |> Repo.insert()
    |> tap(fn
      {:ok, log} -> broadcast("audit", {:audit_log_created, log})
      _ -> :ok
    end)
  end

  def log_action(action, table_name, record_id, details \\ nil, user_id \\ nil) do
    effective_user_id = user_id || Process.get(:current_user_id)

    result =
      create_audit_log(%{
        action: action,
        table_name: table_name,
        record_id: record_id,
        details: details,
        user_id: effective_user_id
      })

    # Fire-and-forget webhook delivery (skip for webhook events to avoid loops)
    # Skip entirely in test to avoid sandbox/HTTP issues
    unless String.starts_with?(to_string(action), "webhook") or
             Application.get_env(:holdco, :skip_async_webhooks, false) do
      Task.start(fn -> deliver_webhooks(action, table_name, record_id) end)
    end

    result
  end

  # Webhook Delivery

  def deliver_webhooks(action, table_name, record_id) do
    webhooks = list_webhooks()
    action_str = to_string(action)

    for webhook <- webhooks, webhook.is_active, webhook_matches_event?(webhook, action_str) do
      deliver_webhook(webhook, %{
        event: action_str,
        table: table_name,
        record_id: record_id,
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      })
    end
  end

  defp webhook_matches_event?(webhook, action) do
    case webhook.events do
      nil -> true
      "" -> true
      "[]" -> true
      events_json when is_binary(events_json) ->
        case Jason.decode(events_json) do
          {:ok, []} -> true
          {:ok, events} when is_list(events) -> action in events
          _ -> true
        end
      _ -> true
    end
  end

  def deliver_webhook(webhook, payload) do
    headers = [{"content-type", "application/json"}]

    headers =
      if webhook.secret do
        signature =
          :crypto.mac(:hmac, :sha256, webhook.secret, Jason.encode!(payload))
          |> Base.encode16(case: :lower)

        [{"x-holdco-signature", signature} | headers]
      else
        headers
      end

    case Req.post(webhook.url,
           json: payload,
           headers: headers,
           receive_timeout: 10_000,
           retry: :transient,
           max_retries: 2
         ) do
      {:ok, %{status: status}} when status in 200..299 ->
        :ok

      {:ok, %{status: status}} ->
        create_audit_log(%{
          action: "webhook_failed",
          table_name: "webhooks",
          record_id: webhook.id,
          details: "HTTP #{status} for #{webhook.url}"
        })

        {:error, :http_error}

      {:error, reason} ->
        create_audit_log(%{
          action: "webhook_failed",
          table_name: "webhooks",
          record_id: webhook.id,
          details: "Error: #{inspect(reason)} for #{webhook.url}"
        })

        {:error, reason}
    end
  rescue
    e ->
      create_audit_log(%{
        action: "webhook_failed",
        table_name: "webhooks",
        record_id: webhook.id,
        details: "Exception: #{Exception.message(e)}"
      })

      {:error, e}
  end

  # Settings
  def list_settings, do: Repo.all(Setting)
  def get_setting(key), do: Repo.get_by(Setting, key: key)

  def get_setting_value(key, default \\ nil) do
    case get_setting(key) do
      %Setting{value: value} -> value
      nil -> default
    end
  end

  def upsert_setting(key, value) do
    case get_setting(key) do
      nil -> %Setting{} |> Setting.changeset(%{key: key, value: value}) |> Repo.insert()
      setting -> setting |> Setting.changeset(%{value: value}) |> Repo.update()
    end
    |> tap(fn
      {:ok, _} -> broadcast("platform", {:setting_updated, key})
      _ -> :ok
    end)
  end

  def delete_setting(id) when is_integer(id) do
    Repo.get!(Setting, id) |> Repo.delete()
  end

  # Categories
  def list_categories, do: Repo.all(from c in Category, order_by: c.name)
  def get_category!(id), do: Repo.get!(Category, id)

  def create_category(attrs) do
    %Category{}
    |> Category.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("categories", "create")
  end

  def update_category(%Category{} = cat, attrs) do
    cat
    |> Category.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("categories", "update")
  end

  def delete_category(%Category{} = cat) do
    Repo.delete(cat) |> audit_and_broadcast("categories", "delete")
  end

  # Webhooks
  def list_webhooks, do: Repo.all(Webhook)
  def get_webhook!(id), do: Repo.get!(Webhook, id)

  def create_webhook(attrs),
    do:
      %Webhook{}
      |> Webhook.changeset(attrs)
      |> Repo.insert()
      |> audit_and_broadcast("webhooks", "create")

  def update_webhook(%Webhook{} = w, attrs),
    do:
      w |> Webhook.changeset(attrs) |> Repo.update() |> audit_and_broadcast("webhooks", "update")

  def delete_webhook(%Webhook{} = w),
    do: Repo.delete(w) |> audit_and_broadcast("webhooks", "delete")

  # Approval Requests
  def list_approval_requests do
    from(a in ApprovalRequest, order_by: [desc: a.inserted_at])
    |> Repo.all()
    |> Repo.preload(votes: [:user])
  end

  def get_approval_request!(id) do
    Repo.get!(ApprovalRequest, id)
    |> Repo.preload(votes: [:user])
  end

  def create_approval_request(attrs),
    do:
      %ApprovalRequest{}
      |> ApprovalRequest.changeset(attrs)
      |> Repo.insert()
      |> audit_and_broadcast("approval_requests", "create")

  def update_approval_request(%ApprovalRequest{} = a, attrs),
    do:
      a
      |> ApprovalRequest.changeset(attrs)
      |> Repo.update()
      |> audit_and_broadcast("approval_requests", "update")

  def delete_approval_request(%ApprovalRequest{} = a),
    do: Repo.delete(a) |> audit_and_broadcast("approval_requests", "delete")

  def pending_approval_count,
    do: Repo.aggregate(from(a in ApprovalRequest, where: a.status == "pending"), :count)

  # Approval Votes

  def cast_vote(request_id, user_id, decision, notes \\ nil) do
    request = get_approval_request!(request_id)

    if request.status != "pending" do
      {:error, :already_decided}
    else
      case %ApprovalVote{}
           |> ApprovalVote.changeset(%{
             approval_request_id: request_id,
             user_id: user_id,
             decision: decision,
             notes: notes
           })
           |> Repo.insert() do
        {:ok, vote} ->
          check_approval_threshold(request)
          {:ok, vote}

        {:error, changeset} ->
          {:error, changeset}
      end
    end
  end

  defp check_approval_threshold(request) do
    request = Repo.preload(request, [votes: [:user]], force: true)
    required = request.required_approvals || 1

    approve_count = Enum.count(request.votes, &(&1.decision == "approved"))
    reject_count = Enum.count(request.votes, &(&1.decision == "rejected"))

    cond do
      approve_count >= required ->
        update_approval_request(request, %{
          status: "approved",
          reviewed_by: "N-of-M threshold met (#{approve_count}/#{required})",
          reviewed_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      reject_count >= required ->
        update_approval_request(request, %{
          status: "rejected",
          reviewed_by: "N-of-M rejection threshold met (#{reject_count}/#{required})",
          reviewed_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      true ->
        :pending
    end
  end

  def list_votes(request_id) do
    from(v in ApprovalVote,
      where: v.approval_request_id == ^request_id,
      order_by: [desc: v.inserted_at],
      preload: [:user]
    )
    |> Repo.all()
  end

  # Custom Fields
  def list_custom_fields, do: Repo.all(CustomField)
  def get_custom_field!(id), do: Repo.get!(CustomField, id)

  def create_custom_field(attrs),
    do: %CustomField{} |> CustomField.changeset(attrs) |> Repo.insert()

  def update_custom_field(%CustomField{} = cf, attrs),
    do: cf |> CustomField.changeset(attrs) |> Repo.update()

  def delete_custom_field(%CustomField{} = cf), do: Repo.delete(cf)

  # Custom Field Values
  def list_custom_field_values(entity_type, entity_id) do
    from(v in CustomFieldValue,
      where: v.entity_type == ^entity_type and v.entity_id == ^entity_id,
      preload: [:custom_field]
    )
    |> Repo.all()
  end

  def create_custom_field_value(attrs),
    do: %CustomFieldValue{} |> CustomFieldValue.changeset(attrs) |> Repo.insert()

  def delete_custom_field_value(%CustomFieldValue{} = v), do: Repo.delete(v)

  # Backup Configs
  def list_backup_configs, do: Repo.all(BackupConfig)
  def get_backup_config!(id), do: Repo.get!(BackupConfig, id)

  def create_backup_config(attrs),
    do:
      %BackupConfig{}
      |> BackupConfig.changeset(attrs)
      |> Repo.insert()
      |> audit_and_broadcast("backup_configs", "create")

  def update_backup_config(%BackupConfig{} = bc, attrs),
    do:
      bc
      |> BackupConfig.changeset(attrs)
      |> Repo.update()
      |> audit_and_broadcast("backup_configs", "update")

  def delete_backup_config(%BackupConfig{} = bc),
    do: Repo.delete(bc) |> audit_and_broadcast("backup_configs", "delete")

  # Backup Logs
  def list_backup_logs,
    do: Repo.all(from l in BackupLog, order_by: [desc: l.inserted_at], preload: [:config])

  def create_backup_log(attrs), do: %BackupLog{} |> BackupLog.changeset(attrs) |> Repo.insert()

  # ── Alert Rules ──────────────────────────────────────────

  def subscribe_alerts, do: Phoenix.PubSub.subscribe(Holdco.PubSub, "alerts")
  defp broadcast_alert(message), do: Phoenix.PubSub.broadcast(Holdco.PubSub, "alerts", message)

  def list_alert_rules(company_id \\ nil) do
    query = from(ar in AlertRule, order_by: [desc: ar.updated_at], preload: [:company, :created_by])
    query = if company_id, do: where(query, [ar], ar.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def list_active_alert_rules do
    from(ar in AlertRule, where: ar.is_active == true, preload: [:company])
    |> Repo.all()
  end

  def get_alert_rule!(id), do: Repo.get!(AlertRule, id) |> Repo.preload([:company, :created_by, :alerts])

  def create_alert_rule(attrs) do
    %AlertRule{}
    |> AlertRule.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("alert_rules", "create")
  end

  def update_alert_rule(%AlertRule{} = rule, attrs) do
    rule
    |> AlertRule.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("alert_rules", "update")
  end

  def delete_alert_rule(%AlertRule{} = rule) do
    Repo.delete(rule)
    |> audit_and_broadcast("alert_rules", "delete")
  end

  # ── Alerts ──────────────────────────────────────────────

  def list_alerts(opts \\ []) do
    query = from(a in Alert, order_by: [desc: a.inserted_at], preload: [:alert_rule, :acknowledged_by])
    query = if opts[:status], do: where(query, [a], a.status == ^opts[:status]), else: query
    query = if opts[:severity], do: where(query, [a], a.severity == ^opts[:severity]), else: query
    query = if opts[:limit], do: limit(query, ^opts[:limit]), else: query
    Repo.all(query)
  end

  def count_unread_alerts do
    from(a in Alert, where: a.status == "unread", select: count(a.id))
    |> Repo.one()
  end

  def get_alert!(id), do: Repo.get!(Alert, id) |> Repo.preload([:alert_rule, :acknowledged_by])

  def create_alert(attrs) do
    result =
      %Alert{}
      |> Alert.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, alert} ->
        broadcast_alert({:new_alert, Repo.preload(alert, [:alert_rule])})
        {:ok, alert}

      error ->
        error
    end
  end

  def acknowledge_alert(%Alert{} = alert, user_id) do
    alert
    |> Alert.changeset(%{
      status: "acknowledged",
      acknowledged_at: DateTime.utc_now() |> DateTime.truncate(:second),
      acknowledged_by_id: user_id
    })
    |> Repo.update()
  end

  def resolve_alert(%Alert{} = alert) do
    alert
    |> Alert.changeset(%{
      status: "resolved",
      resolved_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.update()
  end

  def mark_alert_read(%Alert{} = alert) do
    alert
    |> Alert.changeset(%{status: "read"})
    |> Repo.update()
  end

  # ── Metric Evaluation ──────────────────────────────────

  def evaluate_metric(rule) do
    case rule.metric do
      "nav" ->
        nav = Holdco.Portfolio.calculate_nav()
        {:ok, nav.nav}

      "cash_balance" ->
        accounts = Holdco.Banking.list_bank_accounts()

        accounts =
          if rule.company_id,
            do: Enum.filter(accounts, &(&1.company_id == rule.company_id)),
            else: accounts

        total =
          Enum.reduce(accounts, Decimal.new(0), fn ba, acc ->
            Holdco.Money.add(acc, Holdco.Money.to_decimal(ba.balance))
          end)

        {:ok, total}

      "holding_value" ->
        case rule.target do
          nil ->
            {:error, "target ticker required for holding_value metric"}

          ticker ->
            holdings = Holdco.Assets.list_holdings()
            matching = Enum.filter(holdings, fn h -> h.ticker == ticker end)

            total =
              Enum.reduce(matching, Decimal.new(0), fn h, acc ->
                Holdco.Money.add(acc, Holdco.Portfolio.holding_value(h))
              end)

            {:ok, total}
        end

      "liability_total" ->
        liabilities = Holdco.Finance.list_liabilities(rule.company_id)

        total =
          Enum.reduce(liabilities, Decimal.new(0), fn l, acc ->
            if l.status == "active",
              do: Holdco.Money.add(acc, Holdco.Money.to_decimal(l.principal)),
              else: acc
          end)

        {:ok, total}

      "portfolio_concentration" ->
        nav = Holdco.Portfolio.calculate_nav()
        holdings = Holdco.Assets.list_holdings()

        if Decimal.compare(nav.nav, 0) == :gt do
          max_pct =
            holdings
            |> Enum.map(fn h ->
              Decimal.div(Holdco.Portfolio.holding_value(h), nav.nav)
              |> Decimal.mult(100)
            end)
            |> Enum.max(fn -> Decimal.new(0) end)

          {:ok, max_pct}
        else
          {:ok, Decimal.new(0)}
        end

      _ ->
        {:error, "unknown metric: #{rule.metric}"}
    end
  end

  def check_condition(rule, metric_value) do
    threshold = Holdco.Money.to_decimal(rule.threshold)
    value = Holdco.Money.to_decimal(metric_value)

    case rule.condition do
      "above" -> Decimal.compare(value, threshold) == :gt
      "below" -> Decimal.compare(value, threshold) == :lt
      _ -> false
    end
  end

  def within_cooldown?(rule) do
    case rule.last_triggered_at do
      nil ->
        false

      last ->
        cooldown_seconds = (rule.cooldown_minutes || 60) * 60
        diff = DateTime.diff(DateTime.utc_now(), last, :second)
        diff < cooldown_seconds
    end
  end

  # PubSub
  def subscribe(topic), do: Phoenix.PubSub.subscribe(Holdco.PubSub, topic)
  defp broadcast(topic, message), do: Phoenix.PubSub.broadcast(Holdco.PubSub, topic, message)

  defp audit_and_broadcast(result, table, action) do
    case result do
      {:ok, record} ->
        log_action(action, table, record.id)
        broadcast("platform", {String.to_atom("#{table}_#{action}d"), record})
        {:ok, record}

      error ->
        error
    end
  end
end
