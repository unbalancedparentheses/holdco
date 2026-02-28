defmodule Holdco.Workers.BackupWorker do
  @moduledoc """
  Oban worker that performs PostgreSQL database backups.
  Reads active BackupConfigs and runs pg_dump for each.
  After a successful local backup, uploads to S3/R2 if configured.
  """
  use Oban.Worker, queue: :default, max_attempts: 3

  require Logger

  alias Holdco.Platform
  alias Holdco.Workers.S3Upload

  @impl Oban.Worker
  def perform(_job) do
    configs = Platform.list_backup_configs()
    repo_config = Application.get_env(:holdco, Holdco.Repo)

    for config <- configs, config.is_active do
      backup_log = create_log(config.id)
      run_backup(repo_config, config, backup_log)
    end

    :ok
  end

  defp create_log(config_id) do
    {:ok, log} = Platform.create_backup_log(%{config_id: config_id, status: "running"})
    log
  end

  defp run_backup(repo_config, config, log) do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d_%H%M%S")
    dest = Path.join(config.destination_path, "holdco_backup_#{timestamp}.dump")

    File.mkdir_p!(config.destination_path)

    database_url = repo_config[:url] || build_database_url(repo_config)

    case System.cmd("pg_dump", [database_url, "-f", dest, "-Fc"], stderr_to_stdout: true) do
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

        maybe_upload_to_s3(dest, timestamp, config)

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

  defp maybe_upload_to_s3(file_path, timestamp, config) do
    if S3Upload.configured?() do
      s3_key = "backups/holdco_backup_#{timestamp}.dump"

      case S3Upload.upload(file_path, s3_key) do
        {:ok, %{url: url}} ->
          Logger.info("Backup uploaded to S3: #{url}")

          Platform.log_action(
            "backup_s3_uploaded",
            "backup_configs",
            config.id,
            "Backup uploaded to S3: #{s3_key}"
          )

        {:error, reason} ->
          Logger.warning("S3 upload failed: #{reason}")

          Platform.log_action(
            "backup_s3_failed",
            "backup_configs",
            config.id,
            "S3 upload failed: #{reason}"
          )
      end
    end
  end

  defp build_database_url(repo_config) do
    username = repo_config[:username] || "postgres"
    password = repo_config[:password] || "postgres"
    hostname = repo_config[:hostname] || "localhost"
    database = repo_config[:database]
    port = repo_config[:port] || 5432

    "ecto://#{username}:#{password}@#{hostname}:#{port}/#{database}"
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
