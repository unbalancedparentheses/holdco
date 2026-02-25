"""Take a snapshot of the current portfolio NAV.

Usage:
    python manage.py portfolio_snapshot
"""

from datetime import datetime

from django.core.management.base import BaseCommand

from core.models import PortfolioSnapshot


class Command(BaseCommand):
    help = "Take a snapshot of the current portfolio NAV and store it"

    def handle(self, *args, **options):
        from core.views import _calculate_portfolio

        try:
            data = _calculate_portfolio()
        except Exception as exc:
            self.stderr.write(self.style.ERROR(f"Failed to calculate portfolio: {exc}"))
            return

        today = datetime.now().strftime("%Y-%m-%d")

        # Update or create snapshot for today
        snapshot, created = PortfolioSnapshot.objects.update_or_create(
            date=today,
            defaults={
                "liquid": data["liquid"],
                "marketable": data["marketable"],
                "illiquid": data["illiquid"],
                "liabilities": data["liabilities"],
                "nav": data["nav"],
                "currency": data["currency"],
            },
        )

        action = "Created" if created else "Updated"
        self.stdout.write(
            self.style.SUCCESS(
                f"{action} snapshot for {today}: "
                f"NAV={snapshot.nav:,.2f} "
                f"(L={snapshot.liquid:,.2f} M={snapshot.marketable:,.2f} "
                f"I={snapshot.illiquid:,.2f} Li={snapshot.liabilities:,.2f})"
            )
        )

        total = PortfolioSnapshot.objects.count()
        self.stdout.write(f"Total snapshots: {total}")
