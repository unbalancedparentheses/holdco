"""List upcoming tax deadlines and optionally notify via webhooks.

Usage:
    python manage.py tax_reminders
    python manage.py tax_reminders --days 60
"""

import json
from datetime import datetime, timedelta

import requests
from django.core.management.base import BaseCommand

from core.models import TaxDeadline, Webhook


class Command(BaseCommand):
    help = "List upcoming tax deadlines and send reminders to configured webhooks"

    def add_arguments(self, parser):
        parser.add_argument(
            "--days",
            type=int,
            default=30,
            help="Show deadlines due within this many days (default: 30)",
        )

    def handle(self, *args, **options):
        days = options["days"]
        today = datetime.now().date()
        cutoff = today + timedelta(days=days)

        # Fetch non-completed deadlines whose due_date is within the window.
        # TaxDeadline.due_date is stored as a CharField in YYYY-MM-DD format.
        deadlines = TaxDeadline.objects.exclude(status="completed")

        upcoming = []
        for deadline in deadlines:
            try:
                due = datetime.strptime(deadline.due_date, "%Y-%m-%d").date()
            except (ValueError, TypeError):
                continue
            if due <= cutoff:
                upcoming.append(deadline)

        if not upcoming:
            self.stdout.write(self.style.SUCCESS("No upcoming tax deadlines."))
            return

        # Sort by due date
        upcoming.sort(key=lambda d: d.due_date)

        # Print formatted table
        header = (
            f"{'Company':<25} {'Jurisdiction':<15} {'Description':<35} "
            f"{'Due Date':<12} {'Status':<12}"
        )
        self.stdout.write("")
        self.stdout.write(f"Upcoming tax deadlines (within {days} days):")
        self.stdout.write("=" * len(header))
        self.stdout.write(header)
        self.stdout.write("-" * len(header))

        for d in upcoming:
            company_name = str(d.company) if d.company else "N/A"
            self.stdout.write(
                f"{company_name:<25} {d.jurisdiction:<15} {d.description:<35} "
                f"{d.due_date:<12} {d.status:<12}"
            )

        self.stdout.write("-" * len(header))
        self.stdout.write(f"Total: {len(upcoming)} deadline(s)")
        self.stdout.write("")

        # Send webhook notifications if any webhook has "tax_reminder" in events
        self._send_webhook_notifications(upcoming)

    def _send_webhook_notifications(self, deadlines):
        webhooks = Webhook.objects.filter(is_active=True)
        tax_webhooks = [
            wh for wh in webhooks
            if "tax_reminder" in (wh.events or [])
        ]

        if not tax_webhooks:
            return

        payload = {
            "event": "tax_reminder",
            "count": len(deadlines),
            "deadlines": [
                {
                    "id": d.id,
                    "company": str(d.company),
                    "jurisdiction": d.jurisdiction,
                    "description": d.description,
                    "due_date": d.due_date,
                    "status": d.status,
                    "notes": d.notes or "",
                }
                for d in deadlines
            ],
        }

        for wh in tax_webhooks:
            headers = {"Content-Type": "application/json"}
            if wh.secret:
                headers["X-Webhook-Secret"] = wh.secret

            try:
                resp = requests.post(
                    wh.url,
                    data=json.dumps(payload),
                    headers=headers,
                    timeout=10,
                )
                self.stdout.write(
                    self.style.SUCCESS(
                        f"Webhook {wh.url} notified (HTTP {resp.status_code})"
                    )
                )
            except requests.RequestException as exc:
                self.stderr.write(
                    self.style.ERROR(
                        f"Webhook {wh.url} failed: {exc}"
                    )
                )
