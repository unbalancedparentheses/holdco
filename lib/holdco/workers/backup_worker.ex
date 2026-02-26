defmodule Holdco.Workers.BackupWorker do
  @moduledoc """
  Oban worker that performs SQLite database backups.
  Reads active BackupConfigs and runs sqlite3 .backup for each.
  """
  use Oban.Worker, queue: :default, max_attempts: 3

  alias Holdco.Platform

  @impl Oban.Worker
  def perform(_job) do
    configs = Platform.list_backup_configs()
    db_path = Application.get_env(:holdco, Holdco.Repo)[:database]

    for config <- configs, config.is_active do
      backup_log = create_log(config.id)
      run_backup(db_path, config, backup_log)
    end

    :ok
  end

  defp create_log(config_id) do
    {:ok, log} = Platform.create_backup_log(%{config_id: config_id, status: "running"})
    log
  end

  defp run_backup(db_path, config, log) do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d_%H%M%S")
    dest = Path.join(config.destination_path, "holdco_backup_#{timestamp}.db")

    File.mkdir_p!(config.destination_path)

    case System.cmd("sqlite3", [db_path, ".backup '#{dest}'"], stderr_to_stdout: true) do
      {_output, 0} ->
        file_size = File.stat!(dest).size

        Platform.create_backup_log(%{
          config_id: config.id,
          status: "completed",
          file_path: dest,
          file_size_bytes: file_size,
          completed_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

        Platform.update_backup_config(config, %{
          last_backup_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

        cleanup_old_backups(config)

        Platform.log_action(
          "backup_completed",
          "backup_configs",
          config.id,
          "Backup saved to #{dest}"
        )

      {error_output, _code} ->
        Platform.create_backup_log(%{
          config_id: config.id,
          status: "failed",
          error_message: error_output,
          completed_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

        Platform.log_action("backup_failed", "backup_configs", config.id, error_output)

        Holdco.Notifications.notify_all_admins(
          "Backup Failed",
          "Database backup failed: #{String.slice(error_output, 0..100)}",
          type: "error",
          entity_type: "backup_configs",
          entity_id: config.id
        )
    end

    # Delete the initial "running" log since we created a final status log
    Holdco.Repo.delete(log)
  rescue
    e ->
      Platform.create_backup_log(%{
        config_id: log.config_id,
        status: "failed",
        error_message: Exception.message(e),
        completed_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })
  end

  defp cleanup_old_backups(config) do
    cutoff = DateTime.utc_now() |> DateTime.add(-config.retention_days * 86400, :second)

    config.destination_path
    |> File.ls!()
    |> Enum.filter(&String.starts_with?(&1, "holdco_backup_"))
    |> Enum.each(fn file ->
      path = Path.join(config.destination_path, file)

      case File.stat(path) do
        {:ok, %{mtime: mtime}} ->
          mtime_dt = NaiveDateTime.from_erl!(mtime) |> DateTime.from_naive!("Etc/UTC")
          if DateTime.before?(mtime_dt, cutoff), do: File.rm(path)

        _ ->
          :ok
      end
    end)
  rescue
    _ -> :ok
  end
end
