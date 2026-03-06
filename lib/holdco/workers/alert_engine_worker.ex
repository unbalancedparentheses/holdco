defmodule Holdco.Workers.AlertEngineWorker do
  use Oban.Worker, queue: :default, max_attempts: 3

  alias Holdco.Platform
  alias Holdco.Notifications.Dispatcher

  @impl Oban.Worker
  def perform(_job) do
    rules = Platform.list_active_alert_rules()

    Enum.each(rules, fn rule ->
      unless Platform.within_cooldown?(rule) do
        case Platform.evaluate_metric(rule) do
          {:ok, value} ->
            if Platform.check_condition(rule, value) do
              message =
                "Alert: #{rule.name} - #{rule.metric} is #{value} (threshold: #{rule.condition} #{rule.threshold})"

              {:ok, alert} =
                Platform.create_alert(%{
                  "alert_rule_id" => rule.id,
                  "metric_value" => value,
                  "threshold_value" => rule.threshold,
                  "message" => message,
                  "severity" => rule.severity
                })

              if rule.severity in ["warning", "critical"] do
                Dispatcher.dispatch_to_all_users(
                  "[#{String.upcase(rule.severity)}] #{rule.name}",
                  message,
                  "alert",
                  type: rule.severity,
                  entity_type: "alert",
                  entity_id: alert.id
                )
              end

              Platform.update_alert_rule(rule, %{
                "last_triggered_at" => DateTime.utc_now() |> DateTime.truncate(:second)
              })
            end

          {:error, _reason} ->
            :skip
        end
      end
    end)

    :ok
  end
end
