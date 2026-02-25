"""Back up the SQLite database to a local destination.

Usage examples:
    python manage.py backup_db
    python manage.py backup_db --destination /mnt/backups
    python manage.py backup_db --retention 7
    python manage.py backup_db --all
"""

import os
import shutil
from datetime import datetime, timedelta
from pathlib import Path

from django.conf import settings
from django.core.management.base import BaseCommand
from django.utils import timezone

from core.models import BackupConfig, BackupLog


class Command(BaseCommand):
    help = "Copy the SQLite database to a backup location and clean up old backups"

    def add_arguments(self, parser):
        parser.add_argument(
            "--destination",
            type=str,
            default="./backups/",
            help="Directory to store backup files (default: ./backups/)",
        )
        parser.add_argument(
            "--retention",
            type=int,
            default=30,
            help="Delete backups older than this many days (default: 30)",
        )
        parser.add_argument(
            "--all",
            action="store_true",
            help="Run backup for all active BackupConfig entries in the database",
        )

    def handle(self, *args, **options):
        if options["all"]:
            self._backup_all_configs()
        else:
            destination = options["destination"]
            retention = options["retention"]
            self._run_backup(destination, retention, config=None)

    def _backup_all_configs(self):
        configs = BackupConfig.objects.filter(is_active=True)
        if not configs.exists():
            self.stdout.write(self.style.WARNING("No active BackupConfig entries found."))
            return

        for config in configs:
            self.stdout.write(f"\nProcessing backup config: {config.name}")
            self._run_backup(
                destination=config.destination_path,
                retention=config.retention_days,
                config=config,
            )

    def _run_backup(self, destination, retention, config=None):
        db_path = settings.DATABASES["default"]["NAME"]

        if not os.path.isfile(db_path):
            msg = f"Database file not found: {db_path}"
            self.stderr.write(self.style.ERROR(msg))
            if config:
                BackupLog.objects.create(
                    config=config,
                    status="failed",
                    error_message=msg,
                    completed_at=timezone.now(),
                )
            return

        dest_dir = Path(destination)
        dest_dir.mkdir(parents=True, exist_ok=True)

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_name = f"holdco_{timestamp}.db"
        backup_path = dest_dir / backup_name

        log = None
        if config:
            log = BackupLog.objects.create(config=config, status="running")

        try:
            shutil.copy2(db_path, backup_path)
            file_size = backup_path.stat().st_size

            self.stdout.write(
                self.style.SUCCESS(
                    f"Backup created: {backup_path} ({file_size:,} bytes)"
                )
            )

            if log:
                log.status = "completed"
                log.file_path = str(backup_path)
                log.file_size_bytes = file_size
                log.completed_at = timezone.now()
                log.save()

            if config:
                config.last_backup_at = timezone.now()
                config.save()

        except Exception as exc:
            msg = str(exc)
            self.stderr.write(self.style.ERROR(f"Backup failed: {msg}"))
            if log:
                log.status = "failed"
                log.error_message = msg
                log.completed_at = timezone.now()
                log.save()
            return

        # Clean up old backups beyond retention
        self._cleanup_old_backups(dest_dir, retention)

    def _cleanup_old_backups(self, dest_dir, retention_days):
        cutoff = datetime.now() - timedelta(days=retention_days)
        removed = 0

        for f in dest_dir.glob("holdco_*.db"):
            # Parse the timestamp from the filename: holdco_YYYYMMDD_HHMMSS.db
            stem = f.stem  # e.g. holdco_20250101_120000
            parts = stem.replace("holdco_", "")
            try:
                file_dt = datetime.strptime(parts, "%Y%m%d_%H%M%S")
            except ValueError:
                continue

            if file_dt < cutoff:
                f.unlink()
                removed += 1

        if removed:
            self.stdout.write(
                self.style.WARNING(
                    f"Cleaned up {removed} backup(s) older than {retention_days} days."
                )
            )
        else:
            self.stdout.write(f"No backups older than {retention_days} days to clean up.")
