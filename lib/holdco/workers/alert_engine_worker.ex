defmodule Holdco.Workers.AlertEngineWorker do
  use Oban.Worker, queue: :default, max_attempts: 3

  alias Holdco.Platform

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

              Platform.create_alert(%{
                "alert_rule_id" => rule.id,
                "metric_value" => value,
                "threshold_value" => rule.threshold,
                "message" => message,
                "severity" => rule.severity
              })

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
