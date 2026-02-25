"""Screen companies and beneficial owners against sanctions lists.

Usage:
    python manage.py sanctions_check
    python manage.py sanctions_check --company_id 1
"""

from django.core.management.base import BaseCommand

from core.models import BeneficialOwner, Company, SanctionsCheck, SanctionsEntry


class Command(BaseCommand):
    help = "Screen companies and beneficial owners against sanctions entries"

    def add_arguments(self, parser):
        parser.add_argument(
            "--company_id",
            type=int,
            default=None,
            help="Only check a specific company (default: all)",
        )

    def handle(self, *args, **options):
        company_id = options["company_id"]

        if company_id:
            companies = Company.objects.filter(id=company_id)
        else:
            companies = Company.objects.all()

        if not companies.exists():
            self.stdout.write(self.style.WARNING("No companies to check."))
            return

        sanctions_entries = list(SanctionsEntry.objects.all())
        if not sanctions_entries:
            self.stdout.write(
                self.style.WARNING(
                    "No sanctions entries in database. "
                    "Load sanctions lists first via admin or API."
                )
            )
            return

        total_checks = 0
        total_matches = 0

        for company in companies:
            # Check company name
            matches = self._check_name(company.name, sanctions_entries)
            check = SanctionsCheck.objects.create(
                company=company,
                checked_name=company.name,
                status="match" if matches else "clear",
                matched_entry=matches[0] if matches else None,
            )
            total_checks += 1
            if matches:
                total_matches += 1
                self.stdout.write(
                    self.style.WARNING(
                        f"MATCH: {company.name} -> {matches[0].name} "
                        f"({matches[0].sanctions_list.name})"
                    )
                )
            else:
                self.stdout.write(f"CLEAR: {company.name}")

            # Check beneficial owners
            for bo in BeneficialOwner.objects.filter(company=company):
                matches = self._check_name(bo.name, sanctions_entries)
                SanctionsCheck.objects.create(
                    company=company,
                    checked_name=bo.name,
                    status="match" if matches else "clear",
                    matched_entry=matches[0] if matches else None,
                )
                total_checks += 1
                if matches:
                    total_matches += 1
                    self.stdout.write(
                        self.style.WARNING(
                            f"  MATCH (UBO): {bo.name} -> {matches[0].name}"
                        )
                    )

        self.stdout.write("")
        self.stdout.write(f"Total checks: {total_checks}")
        self.stdout.write(f"Potential matches: {total_matches}")
        if total_matches:
            self.stdout.write(
                self.style.WARNING("Review matches in admin or via API.")
            )
        else:
            self.stdout.write(self.style.SUCCESS("All clear."))

    def _check_name(self, name, entries):
        """Simple fuzzy match: case-insensitive substring matching."""
        name_lower = name.lower().strip()
        matches = []
        for entry in entries:
            entry_lower = entry.name.lower().strip()
            # Exact match or significant substring overlap
            if name_lower == entry_lower:
                matches.append(entry)
            elif len(name_lower) > 3 and name_lower in entry_lower:
                matches.append(entry)
            elif len(entry_lower) > 3 and entry_lower in name_lower:
                matches.append(entry)
        return matches
