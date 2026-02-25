"""Generate compliance checklist items for a company and jurisdiction.

Usage:
    python manage.py generate_checklist --company_id 1 --jurisdiction US
    python manage.py generate_checklist --company_id 3 --jurisdiction CH
"""

from django.core.management.base import BaseCommand, CommandError

from core.models import Company, ComplianceChecklist


# Preset templates of common formation/compliance items per jurisdiction.
# Each entry is (item_description, category).
JURISDICTION_TEMPLATES = {
    "US": [
        ("File Articles of Incorporation / Certificate of Formation", "formation"),
        ("Obtain EIN (Employer Identification Number) from IRS", "tax"),
        ("Register with state Secretary of State", "formation"),
        ("Draft and adopt bylaws / operating agreement", "governance"),
        ("Appoint initial directors / managers", "governance"),
        ("Issue initial stock certificates / membership interests", "formation"),
        ("Open corporate bank account", "banking"),
        ("Register for state tax accounts (sales tax, franchise tax)", "tax"),
        ("Obtain business licenses and permits", "regulatory"),
        ("File BOI (Beneficial Ownership Information) report with FinCEN", "regulatory"),
        ("Register as foreign entity in states where operating", "formation"),
        ("Set up registered agent service", "formation"),
        ("Establish annual report filing calendar", "compliance"),
        ("Draft shareholder / operating agreement", "governance"),
        ("Obtain D&O insurance", "insurance"),
    ],
    "UK": [
        ("Incorporate at Companies House", "formation"),
        ("Register for Corporation Tax with HMRC", "tax"),
        ("Appoint directors and company secretary", "governance"),
        ("File Confirmation Statement (annual return)", "compliance"),
        ("Register for VAT (if applicable)", "tax"),
        ("Register for PAYE (if hiring employees)", "tax"),
        ("Prepare People with Significant Control (PSC) register", "regulatory"),
        ("Open UK business bank account", "banking"),
        ("Draft Articles of Association", "governance"),
        ("File annual accounts with Companies House", "compliance"),
        ("Obtain registered office address", "formation"),
        ("Set up statutory registers (members, directors, charges)", "governance"),
        ("Register with Information Commissioner's Office (ICO) for data protection", "regulatory"),
        ("Obtain professional indemnity / liability insurance", "insurance"),
    ],
    "DE": [
        ("Notarize articles of association (Gesellschaftsvertrag)", "formation"),
        ("Register with Handelsregister (Commercial Register)", "formation"),
        ("Open business bank account and deposit share capital", "banking"),
        ("Obtain tax number (Steuernummer) from Finanzamt", "tax"),
        ("Register for VAT (Umsatzsteuer)", "tax"),
        ("Register for trade tax (Gewerbesteuer)", "tax"),
        ("Register with IHK (Chamber of Commerce)", "regulatory"),
        ("File Transparenzregister (Transparency Register) entry", "regulatory"),
        ("Appoint managing director (Geschaeftsfuehrer)", "governance"),
        ("Set up payroll and social insurance registration", "tax"),
        ("Obtain Gewerbeanmeldung (trade license)", "regulatory"),
        ("Prepare annual financial statements (Jahresabschluss)", "compliance"),
        ("File with Bundesanzeiger (Federal Gazette)", "compliance"),
        ("Obtain D&O and liability insurance", "insurance"),
    ],
    "CH": [
        ("Draft and notarize articles of association (Statuten)", "formation"),
        ("Register with Handelsregister (Commercial Register)", "formation"),
        ("Open Swiss bank account and deposit share capital", "banking"),
        ("Register for VAT with Federal Tax Administration", "tax"),
        ("Register for AHV/IV social security contributions", "tax"),
        ("Register with cantonal tax authority", "tax"),
        ("Appoint statutory auditor (if required)", "governance"),
        ("Appoint board of directors", "governance"),
        ("File beneficial ownership declaration with bank", "regulatory"),
        ("Obtain business activity permit (cantonal)", "regulatory"),
        ("Set up accident insurance (UVG) with SUVA", "insurance"),
        ("File annual financial statements", "compliance"),
        ("Prepare and file annual tax return", "compliance"),
        ("Register with BFS (Federal Statistical Office) if required", "regulatory"),
    ],
    "SG": [
        ("Incorporate with ACRA (Accounting and Corporate Regulatory Authority)", "formation"),
        ("Appoint at least one local resident director", "governance"),
        ("Appoint company secretary within 6 months", "governance"),
        ("Register for GST with IRAS (if applicable)", "tax"),
        ("Obtain corporate tax registration (IRAS)", "tax"),
        ("Open corporate bank account in Singapore", "banking"),
        ("File annual return with ACRA", "compliance"),
        ("Prepare audited / unaudited financial statements", "compliance"),
        ("Hold Annual General Meeting (AGM)", "governance"),
        ("Maintain registered office address in Singapore", "formation"),
        ("Maintain statutory registers (members, directors, charges)", "governance"),
        ("Register for work passes if hiring foreign employees", "regulatory"),
        ("File Estimated Chargeable Income (ECI) with IRAS", "tax"),
        ("Obtain necessary business licenses (sector-specific)", "regulatory"),
    ],
}


class Command(BaseCommand):
    help = "Generate compliance checklist items for a company and jurisdiction"

    def add_arguments(self, parser):
        parser.add_argument(
            "--company_id",
            type=int,
            required=True,
            help="ID of the Company to generate checklist for",
        )
        parser.add_argument(
            "--jurisdiction",
            type=str,
            required=True,
            help="Jurisdiction code: US, UK, DE, CH, SG",
        )

    def handle(self, *args, **options):
        company_id = options["company_id"]
        jurisdiction = options["jurisdiction"].upper()

        try:
            company = Company.objects.get(pk=company_id)
        except Company.DoesNotExist:
            raise CommandError(f"Company with ID {company_id} does not exist.")

        if jurisdiction not in JURISDICTION_TEMPLATES:
            supported = ", ".join(sorted(JURISDICTION_TEMPLATES.keys()))
            raise CommandError(
                f"Unsupported jurisdiction '{jurisdiction}'. "
                f"Supported: {supported}"
            )

        template = JURISDICTION_TEMPLATES[jurisdiction]

        created_count = 0
        skipped_count = 0

        for item_text, category in template:
            exists = ComplianceChecklist.objects.filter(
                company=company,
                jurisdiction=jurisdiction,
                item=item_text,
            ).exists()

            if exists:
                skipped_count += 1
                self.stdout.write(f"  SKIP: {item_text}")
                continue

            ComplianceChecklist.objects.create(
                company=company,
                jurisdiction=jurisdiction,
                item=item_text,
                category=category,
                completed=False,
            )
            created_count += 1
            self.stdout.write(self.style.SUCCESS(f"  ADD:  {item_text}"))

        self.stdout.write("")
        self.stdout.write(
            f"Done. Created {created_count} item(s), "
            f"skipped {skipped_count} existing item(s) "
            f"for {company.name} [{jurisdiction}]."
        )
