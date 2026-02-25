"""Send email digest summaries to subscribed users.

Usage:
    python manage.py email_digest
    python manage.py email_digest --frequency weekly
"""

from datetime import datetime, timedelta

from django.core.mail import send_mail
from django.core.management.base import BaseCommand
from django.conf import settings
from django.utils import timezone

from core.models import (
    AuditLog,
    BankAccount,
    Company,
    EmailDigestConfig,
    Liability,
    TaxDeadline,
    Transaction,
)


class Command(BaseCommand):
    help = "Send email digest summaries to subscribed users"

    def add_arguments(self, parser):
        parser.add_argument(
            "--frequency",
            type=str,
            default=None,
            help="Only send to users with this frequency (daily, weekly, monthly)",
        )
        parser.add_argument(
            "--dry-run",
            action="store_true",
            help="Print digests to stdout instead of sending emails",
        )

    def handle(self, *args, **options):
        frequency = options["frequency"]
        dry_run = options["dry_run"]

        configs = EmailDigestConfig.objects.filter(is_active=True).select_related("user")
        if frequency:
            configs = configs.filter(frequency=frequency)

        if not configs.exists():
            self.stdout.write(self.style.WARNING("No active digest configs found."))
            return

        for config in configs:
            body = self._build_digest(config)
            subject = f"Holdco {config.frequency.title()} Digest — {datetime.now().strftime('%Y-%m-%d')}"

            if dry_run:
                self.stdout.write(f"\n{'='*60}")
                self.stdout.write(f"TO: {config.user.email}")
                self.stdout.write(f"SUBJECT: {subject}")
                self.stdout.write(f"{'='*60}")
                self.stdout.write(body)
            else:
                try:
                    send_mail(
                        subject=subject,
                        message=body,
                        from_email=settings.DEFAULT_FROM_EMAIL,
                        recipient_list=[config.user.email],
                        fail_silently=False,
                    )
                    config.last_sent_at = timezone.now()
                    config.save()
                    self.stdout.write(
                        self.style.SUCCESS(f"Sent digest to {config.user.email}")
                    )
                except Exception as exc:
                    self.stderr.write(
                        self.style.ERROR(f"Failed to send to {config.user.email}: {exc}")
                    )

    def _build_digest(self, config):
        lines = []
        lines.append(f"Hello {config.user.username},\n")
        lines.append(f"Here is your {config.frequency} Holdco digest.\n")

        if config.include_portfolio:
            lines.append("--- Portfolio Summary ---")
            total_companies = Company.objects.count()
            total_balance = sum(ba.balance for ba in BankAccount.objects.all())
            total_liabilities = sum(
                l.principal for l in Liability.objects.filter(status="active")
            )
            lines.append(f"Companies: {total_companies}")
            lines.append(f"Total bank balances: {total_balance:,.2f}")
            lines.append(f"Active liabilities: {total_liabilities:,.2f}")
            lines.append("")

        if config.include_deadlines:
            lines.append("--- Upcoming Tax Deadlines ---")
            deadlines = TaxDeadline.objects.exclude(status="completed").order_by("due_date")[:10]
            if deadlines:
                for d in deadlines:
                    lines.append(f"  {d.due_date} | {d.company} | {d.description} [{d.status}]")
            else:
                lines.append("  No upcoming deadlines.")
            lines.append("")

        if config.include_transactions:
            lines.append("--- Recent Transactions ---")
            txns = Transaction.objects.order_by("-date")[:10]
            if txns:
                for t in txns:
                    lines.append(
                        f"  {t.date} | {t.company} | {t.transaction_type} | "
                        f"{t.amount:,.2f} {t.currency}"
                    )
            else:
                lines.append("  No recent transactions.")
            lines.append("")

        if config.include_audit_log:
            lines.append("--- Recent Activity ---")
            cutoff = timezone.now() - timedelta(days=7)
            logs = AuditLog.objects.filter(timestamp__gte=cutoff).order_by("-timestamp")[:15]
            if logs:
                for log in logs:
                    lines.append(
                        f"  {log.timestamp.strftime('%Y-%m-%d %H:%M')} | "
                        f"{log.action} | {log.table_name} #{log.record_id}"
                    )
            else:
                lines.append("  No recent activity.")
            lines.append("")

        lines.append("---")
        lines.append("This is an automated email from Holdco.")
        return "\n".join(lines)
