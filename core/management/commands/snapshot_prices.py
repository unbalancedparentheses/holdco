"""Fetch and record current prices for all tickers in AssetHolding.

Usage:
    python manage.py snapshot_prices
"""

from django.core.management.base import BaseCommand

from core.models import AssetHolding, PriceHistory
from yahoo import get_prices


class Command(BaseCommand):
    help = "Fetch current prices for all tickers in AssetHolding and record them in PriceHistory"

    def handle(self, *args, **options):
        holdings = AssetHolding.objects.exclude(ticker__isnull=True).exclude(ticker="")
        tickers = list(holdings.values_list("ticker", flat=True).distinct())

        if not tickers:
            self.stdout.write(self.style.WARNING("No tickers found in AssetHolding."))
            return

        self.stdout.write(f"Fetching prices for {len(tickers)} ticker(s)...")

        results = get_prices(tickers, record=True)

        # Print summary
        successes = 0
        failures = 0

        self.stdout.write("")
        self.stdout.write(f"{'Ticker':<15} {'Price':>15} {'Status'}")
        self.stdout.write("-" * 45)

        for ticker, price in sorted(results.items()):
            if price is not None:
                self.stdout.write(f"{ticker:<15} {price:>15.4f} OK")
                successes += 1
            else:
                self.stdout.write(
                    self.style.ERROR(f"{ticker:<15} {'N/A':>15} FAILED")
                )
                failures += 1

        self.stdout.write("-" * 45)
        self.stdout.write(
            self.style.SUCCESS(f"Fetched {successes} price(s) successfully.")
        )
        if failures:
            self.stdout.write(
                self.style.WARNING(f"Failed to fetch {failures} price(s).")
            )

        total_records = PriceHistory.objects.count()
        self.stdout.write(f"Total PriceHistory records: {total_records}")
