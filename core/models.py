from django.conf import settings
from django.db import models


class UserRole(models.Model):
    ROLE_CHOICES = [
        ("admin", "Admin"),
        ("editor", "Editor"),
        ("viewer", "Viewer"),
    ]
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="role"
    )
    role = models.CharField(max_length=10, choices=ROLE_CHOICES, default="viewer")

    class Meta:
        ordering = ["id"]

    def __str__(self):
        return f"{self.user.username}: {self.role}"


def get_user_role(user) -> str:
    try:
        return user.role.role
    except UserRole.DoesNotExist:
        return "viewer"


class Category(models.Model):
    name = models.CharField(max_length=255, unique=True)
    color = models.CharField(max_length=20, default="#e0e0e0")

    class Meta:
        verbose_name_plural = "categories"
        ordering = ["id"]

    def __str__(self):
        return self.name


class Setting(models.Model):
    key = models.CharField(max_length=255, primary_key=True)
    value = models.TextField()

    class Meta:
        ordering = ["key"]

    def __str__(self):
        return f"{self.key}={self.value}"


class Company(models.Model):
    KYC_STATUS_CHOICES = [
        ("not_started", "Not Started"),
        ("in_progress", "In Progress"),
        ("approved", "Approved"),
        ("rejected", "Rejected"),
    ]
    WIND_DOWN_CHOICES = [
        ("active", "Active"),
        ("winding_down", "Winding Down"),
        ("dissolved", "Dissolved"),
    ]
    name = models.CharField(max_length=255)
    legal_name = models.CharField(max_length=255, blank=True, null=True)
    country = models.CharField(max_length=255)
    category = models.CharField(max_length=255)
    is_holding = models.BooleanField(default=False)
    parent = models.ForeignKey(
        "self",
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name="subsidiaries",
    )
    ownership_pct = models.IntegerField(null=True, blank=True)
    tax_id = models.CharField(max_length=255, blank=True, null=True)
    shareholders = models.JSONField(default=list, blank=True)
    directors = models.JSONField(default=list, blank=True)
    lawyer_studio = models.CharField(max_length=255, blank=True, null=True)
    notes = models.TextField(blank=True, null=True)
    website = models.CharField(max_length=500, blank=True, null=True)
    kyc_status = models.CharField(
        max_length=20, choices=KYC_STATUS_CHOICES, default="not_started"
    )
    wind_down_status = models.CharField(
        max_length=20, choices=WIND_DOWN_CHOICES, default="active"
    )
    formation_date = models.CharField(max_length=20, blank=True, null=True)
    dissolution_date = models.CharField(max_length=20, blank=True, null=True)

    class Meta:
        verbose_name_plural = "companies"
        ordering = ["id"]

    def __str__(self):
        return self.name


class AssetHolding(models.Model):
    ASSET_TYPE_CHOICES = [
        ("equity", "Equity"),
        ("crypto", "Crypto"),
        ("commodity", "Commodity"),
        ("real_estate", "Real Estate"),
        ("private_equity", "Private Equity"),
        ("other", "Other"),
    ]
    company = models.ForeignKey(
        Company, on_delete=models.CASCADE, related_name="asset_holdings"
    )
    asset = models.CharField(max_length=255)
    ticker = models.CharField(max_length=50, blank=True, null=True)
    quantity = models.FloatField(null=True, blank=True)
    unit = models.CharField(max_length=50, blank=True, null=True)
    currency = models.CharField(max_length=10, default="USD")
    asset_type = models.CharField(
        max_length=20, choices=ASSET_TYPE_CHOICES, default="other"
    )

    class Meta:
        ordering = ["id"]

    def __str__(self):
        return f"{self.asset} ({self.company.name})"


class CustodianAccount(models.Model):
    asset_holding = models.OneToOneField(
        AssetHolding, on_delete=models.CASCADE, related_name="custodian"
    )
    bank = models.CharField(max_length=255)
    account_number = models.CharField(max_length=255, blank=True, null=True)
    account_type = models.CharField(max_length=100, blank=True, null=True)
    authorized_persons = models.JSONField(default=list, blank=True)

    class Meta:
        ordering = ["id"]

    def __str__(self):
        return f"{self.bank} — {self.asset_holding.asset}"


class Document(models.Model):
    company = models.ForeignKey(
        Company, on_delete=models.CASCADE, related_name="documents"
    )
    name = models.CharField(max_length=255)
    doc_type = models.CharField(max_length=100, blank=True, null=True)
    url = models.CharField(max_length=500, blank=True, null=True)
    notes = models.TextField(blank=True, null=True)
    uploaded_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["id"]

    def __str__(self):
        return f"{self.name} ({self.company.name})"


class TaxDeadline(models.Model):
    company = models.ForeignKey(
        Company, on_delete=models.CASCADE, related_name="tax_deadlines"
    )
    jurisdiction = models.CharField(max_length=255)
    description = models.CharField(max_length=500)
    due_date = models.CharField(max_length=20)
    status = models.CharField(max_length=50, default="pending")
    notes = models.TextField(blank=True, null=True)

    class Meta:
        ordering = ["due_date"]

    def __str__(self):
        return f"{self.description} ({self.jurisdiction})"


class Financial(models.Model):
    company = models.ForeignKey(
        Company, on_delete=models.CASCADE, related_name="financials"
    )
    period = models.CharField(max_length=50)
    revenue = models.FloatField(default=0)
    expenses = models.FloatField(default=0)
    currency = models.CharField(max_length=10, default="USD")
    notes = models.TextField(blank=True, null=True)

    class Meta:
        ordering = ["-period"]

    def __str__(self):
        return f"{self.period} — {self.company.name}"


class PriceHistory(models.Model):
    ticker = models.CharField(max_length=50)
    price = models.FloatField()
    currency = models.CharField(max_length=10, default="USD")
    recorded_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name_plural = "price history"
        ordering = ["-recorded_at"]

    def __str__(self):
        return f"{self.ticker} @ {self.price}"


class AuditLog(models.Model):
    timestamp = models.DateTimeField(auto_now_add=True)
    action = models.CharField(max_length=50)
    table_name = models.CharField(max_length=100)
    record_id = models.IntegerField(null=True, blank=True)
    details = models.TextField(blank=True, null=True)

    class Meta:
        ordering = ["-timestamp"]

    def __str__(self):
        return f"{self.action} {self.table_name} #{self.record_id}"


class BankAccount(models.Model):
    company = models.ForeignKey(
        Company, on_delete=models.CASCADE, related_name="bank_accounts"
    )
    bank_name = models.CharField(max_length=255)
    account_number = models.CharField(max_length=255, blank=True, null=True)
    iban = models.CharField(max_length=50, blank=True, null=True)
    swift = models.CharField(max_length=20, blank=True, null=True)
    currency = models.CharField(max_length=10, default="USD")
    account_type = models.CharField(max_length=50, default="operating")
    balance = models.FloatField(default=0)
    authorized_signers = models.JSONField(default=list, blank=True)
    notes = models.TextField(blank=True, null=True)

    class Meta:
        ordering = ["id"]

    def __str__(self):
        return f"{self.bank_name} — {self.company.name}"


class Transaction(models.Model):
    company = models.ForeignKey(
        Company, on_delete=models.CASCADE, related_name="transactions"
    )
    transaction_type = models.CharField(max_length=50)
    description = models.CharField(max_length=500)
    amount = models.FloatField()
    currency = models.CharField(max_length=10, default="USD")
    counterparty = models.CharField(max_length=255, blank=True, null=True)
    date = models.CharField(max_length=20)
    asset_holding = models.ForeignKey(
        AssetHolding,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="transactions",
    )
    notes = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-date"]

    def __str__(self):
        return f"{self.transaction_type}: {self.description}"


class Liability(models.Model):
    company = models.ForeignKey(
        Company, on_delete=models.CASCADE, related_name="liabilities"
    )
    liability_type = models.CharField(max_length=100)
    creditor = models.CharField(max_length=255)
    principal = models.FloatField()
    currency = models.CharField(max_length=10, default="USD")
    interest_rate = models.FloatField(null=True, blank=True)
    maturity_date = models.CharField(max_length=20, blank=True, null=True)
    status = models.CharField(max_length=50, default="active")
    notes = models.TextField(blank=True, null=True)

    class Meta:
        verbose_name_plural = "liabilities"
        ordering = ["id"]

    def __str__(self):
        return f"{self.liability_type}: {self.creditor}"


class ServiceProvider(models.Model):
    company = models.ForeignKey(
        Company, on_delete=models.CASCADE, related_name="service_providers"
    )
    role = models.CharField(max_length=100)
    name = models.CharField(max_length=255)
    firm = models.CharField(max_length=255, blank=True, null=True)
    email = models.CharField(max_length=255, blank=True, null=True)
    phone = models.CharField(max_length=50, blank=True, null=True)
    notes = models.TextField(blank=True, null=True)

    class Meta:
        ordering = ["id"]

    def __str__(self):
        return f"{self.name} ({self.role})"


class InsurancePolicy(models.Model):
    company = models.ForeignKey(
        Company, on_delete=models.CASCADE, related_name="insurance_policies"
    )
    policy_type = models.CharField(max_length=100)
    provider = models.CharField(max_length=255)
    policy_number = models.CharField(max_length=100, blank=True, null=True)
    coverage_amount = models.FloatField(null=True, blank=True)
    premium = models.FloatField(null=True, blank=True)
    currency = models.CharField(max_length=10, default="USD")
    start_date = models.CharField(max_length=20, blank=True, null=True)
    expiry_date = models.CharField(max_length=20, blank=True, null=True)
    notes = models.TextField(blank=True, null=True)

    class Meta:
        verbose_name_plural = "insurance policies"
        ordering = ["expiry_date"]

    def __str__(self):
        return f"{self.policy_type} — {self.provider}"


class BoardMeeting(models.Model):
    company = models.ForeignKey(
        Company, on_delete=models.CASCADE, related_name="board_meetings"
    )
    meeting_type = models.CharField(max_length=50, default="regular")
    scheduled_date = models.CharField(max_length=20)
    status = models.CharField(max_length=50, default="scheduled")
    notes = models.TextField(blank=True, null=True)

    class Meta:
        ordering = ["scheduled_date"]

    def __str__(self):
        return f"{self.meeting_type} — {self.scheduled_date}"


# =========================================================================
# Corporate Structure & Governance
# =========================================================================


class CapTableEntry(models.Model):
    company = models.ForeignKey(
        Company, on_delete=models.CASCADE, related_name="cap_table"
    )
    round_name = models.CharField(max_length=255)
    investor = models.CharField(max_length=255)
    instrument_type = models.CharField(max_length=50, default="equity")
    shares = models.FloatField(default=0)
    price_per_share = models.FloatField(null=True, blank=True)
    amount_invested = models.FloatField(default=0)
    currency = models.CharField(max_length=10, default="USD")
    date = models.CharField(max_length=20, blank=True, null=True)
    notes = models.TextField(blank=True, null=True)

    class Meta:
        ordering = ["id"]

    def __str__(self):
        return f"{self.round_name}: {self.investor}"


class ShareholderResolution(models.Model):
    company = models.ForeignKey(
        Company, on_delete=models.CASCADE, related_name="resolutions"
    )
    title = models.CharField(max_length=500)
    resolution_type = models.CharField(max_length=100, default="ordinary")
    date = models.CharField(max_length=20)
    passed = models.BooleanField(default=False)
    votes_for = models.IntegerField(default=0)
    votes_against = models.IntegerField(default=0)
    abstentions = models.IntegerField(default=0)
    notes = models.TextField(blank=True, null=True)

    class Meta:
        ordering = ["-date"]

    def __str__(self):
        return self.title


class PowerOfAttorney(models.Model):
    company = models.ForeignKey(
        Company, on_delete=models.CASCADE, related_name="powers_of_attorney"
    )
    grantor = models.CharField(max_length=255)
    grantee = models.CharField(max_length=255)
    scope = models.TextField(blank=True, null=True)
    start_date = models.CharField(max_length=20, blank=True, null=True)
    end_date = models.CharField(max_length=20, blank=True, null=True)
    status = models.CharField(max_length=20, default="active")
    notes = models.TextField(blank=True, null=True)

    class Meta:
        verbose_name_plural = "powers of attorney"
        ordering = ["id"]

    def __str__(self):
        return f"{self.grantor} → {self.grantee}"


class AnnualFiling(models.Model):
    company = models.ForeignKey(
        Company, on_delete=models.CASCADE, related_name="annual_filings"
    )
    jurisdiction = models.CharField(max_length=255)
    filing_type = models.CharField(max_length=255)
    due_date = models.CharField(max_length=20)
    filed_date = models.CharField(max_length=20, blank=True, null=True)
    status = models.CharField(max_length=50, default="pending")
    notes = models.TextField(blank=True, null=True)

    class Meta:
        ordering = ["due_date"]

    def __str__(self):
        return f"{self.filing_type} ({self.jurisdiction})"


class BeneficialOwner(models.Model):
    company = models.ForeignKey(
        Company, on_delete=models.CASCADE, related_name="beneficial_owners"
    )
    name = models.CharField(max_length=255)
    nationality = models.CharField(max_length=255, blank=True, null=True)
    ownership_pct = models.FloatField(default=0)
    control_type = models.CharField(max_length=50, default="direct")
    verified = models.BooleanField(default=False)
    verified_date = models.CharField(max_length=20, blank=True, null=True)
    notes = models.TextField(blank=True, null=True)

    class Meta:
        ordering = ["id"]

    def __str__(self):
        return f"{self.name} ({self.ownership_pct}%)"


class OwnershipChange(models.Model):
    company = models.ForeignKey(
        Company, on_delete=models.CASCADE, related_name="ownership_changes"
    )
    date = models.CharField(max_length=20)
    from_owner = models.CharField(max_length=255)
    to_owner = models.CharField(max_length=255)
    ownership_pct = models.FloatField(default=0)
    transaction_type = models.CharField(max_length=50, default="transfer")
    notes = models.TextField(blank=True, null=True)

    class Meta:
        ordering = ["-date"]

    def __str__(self):
        return f"{self.from_owner} → {self.to_owner} ({self.date})"


class KeyPersonnel(models.Model):
    company = models.ForeignKey(
        Company, on_delete=models.CASCADE, related_name="key_personnel"
    )
    name = models.CharField(max_length=255)
    title = models.CharField(max_length=255)
    department = models.CharField(max_length=255, blank=True, null=True)
    email = models.CharField(max_length=255, blank=True, null=True)
    phone = models.CharField(max_length=50, blank=True, null=True)
    start_date = models.CharField(max_length=20, blank=True, null=True)
    end_date = models.CharField(max_length=20, blank=True, null=True)
    notes = models.TextField(blank=True, null=True)

    class Meta:
        verbose_name_plural = "key personnel"
        ordering = ["id"]

    def __str__(self):
        return f"{self.name} — {self.title}"


class RegulatoryLicense(models.Model):
    company = models.ForeignKey(
        Company, on_delete=models.CASCADE, related_name="regulatory_licenses"
    )
    license_type = models.CharField(max_length=255)
    issuing_authority = models.CharField(max_length=255)
    license_number = models.CharField(max_length=255, blank=True, null=True)
    issue_date = models.CharField(max_length=20, blank=True, null=True)
    expiry_date = models.CharField(max_length=20, blank=True, null=True)
    status = models.CharField(max_length=50, default="active")
    notes = models.TextField(blank=True, null=True)

    class Meta:
        ordering = ["id"]

    def __str__(self):
        return f"{self.license_type} ({self.issuing_authority})"


class JointVenture(models.Model):
    company = models.ForeignKey(
        Company, on_delete=models.CASCADE, related_name="joint_ventures"
    )
    partner = models.CharField(max_length=255)
    name = models.CharField(max_length=255)
    ownership_pct = models.FloatField(default=50)
    formation_date = models.CharField(max_length=20, blank=True, null=True)
    status = models.CharField(max_length=50, default="active")
    total_value = models.FloatField(null=True, blank=True)
    currency = models.CharField(max_length=10, default="USD")
    notes = models.TextField(blank=True, null=True)

    class Meta:
        ordering = ["id"]

    def __str__(self):
        return f"{self.name} (with {self.partner})"


class EquityIncentivePlan(models.Model):
    company = models.ForeignKey(
        Company, on_delete=models.CASCADE, related_name="equity_plans"
    )
    plan_name = models.CharField(max_length=255)
    total_pool = models.IntegerField(default=0)
    vesting_schedule = models.CharField(max_length=255, blank=True, null=True)
    board_approval_date = models.CharField(max_length=20, blank=True, null=True)
    notes = models.TextField(blank=True, null=True)

    class Meta:
        ordering = ["id"]

    def __str__(self):
        return self.plan_name


class EquityGrant(models.Model):
    plan = models.ForeignKey(
        EquityIncentivePlan, on_delete=models.CASCADE, related_name="grants"
    )
    recipient = models.CharField(max_length=255)
    grant_type = models.CharField(max_length=50, default="options")
    quantity = models.IntegerField(default=0)
    strike_price = models.FloatField(null=True, blank=True)
    grant_date = models.CharField(max_length=20, blank=True, null=True)
    vesting_start = models.CharField(max_length=20, blank=True, null=True)
    cliff_months = models.IntegerField(default=12)
    vesting_months = models.IntegerField(default=48)
    exercised = models.IntegerField(default=0)
    notes = models.TextField(blank=True, null=True)

    class Meta:
        ordering = ["id"]

    def __str__(self):
        return f"{self.recipient}: {self.quantity} {self.grant_type}"


class Deal(models.Model):
    company = models.ForeignKey(
        Company, on_delete=models.CASCADE, related_name="deals"
    )
    deal_type = models.CharField(max_length=50, default="acquisition")
    counterparty = models.CharField(max_length=255)
    status = models.CharField(max_length=50, default="pipeline")
    value = models.FloatField(null=True, blank=True)
    currency = models.CharField(max_length=10, default="USD")
    target_close_date = models.CharField(max_length=20, blank=True, null=True)
    closed_date = models.CharField(max_length=20, blank=True, null=True)
    notes = models.TextField(blank=True, null=True)

    class Meta:
        ordering = ["-target_close_date"]

    def __str__(self):
        return f"{self.deal_type}: {self.counterparty}"


# =========================================================================
# Financial Operations
# =========================================================================


class Account(models.Model):
    ACCOUNT_TYPE_CHOICES = [
        ("asset", "Asset"),
        ("liability", "Liability"),
        ("equity", "Equity"),
        ("revenue", "Revenue"),
        ("expense", "Expense"),
    ]
    name = models.CharField(max_length=255)
    account_type = models.CharField(max_length=20, choices=ACCOUNT_TYPE_CHOICES)
    code = models.CharField(max_length=50, unique=True)
    parent = models.ForeignKey(
        "self", on_delete=models.CASCADE, null=True, blank=True, related_name="children"
    )
    currency = models.CharField(max_length=10, default="USD")
    notes = models.TextField(blank=True, null=True)

    class Meta:
        ordering = ["code"]

    def __str__(self):
        return f"{self.code} — {self.name}"


class JournalEntry(models.Model):
    date = models.CharField(max_length=20)
    description = models.CharField(max_length=500)
    reference = models.CharField(max_length=255, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name_plural = "journal entries"
        ordering = ["-date"]

    def __str__(self):
        return f"{self.date}: {self.description}"


class JournalLine(models.Model):
    entry = models.ForeignKey(
        JournalEntry, on_delete=models.CASCADE, related_name="lines"
    )
    account = models.ForeignKey(
        Account, on_delete=models.CASCADE, related_name="journal_lines"
    )
    debit = models.FloatField(default=0)
    credit = models.FloatField(default=0)
    notes = models.CharField(max_length=500, blank=True, null=True)

    class Meta:
        ordering = ["id"]

    def __str__(self):
        return f"Dr {self.debit} / Cr {self.credit}"


class InterCompanyTransfer(models.Model):
    from_company = models.ForeignKey(
        Company, on_delete=models.CASCADE, related_name="transfers_out"
    )
    to_company = models.ForeignKey(
        Company, on_delete=models.CASCADE, related_name="transfers_in"
    )
    amount = models.FloatField()
    currency = models.CharField(max_length=10, default="USD")
    date = models.CharField(max_length=20)
    description = models.CharField(max_length=500, blank=True, null=True)
    status = models.CharField(max_length=50, default="completed")
    notes = models.TextField(blank=True, null=True)

    class Meta:
        ordering = ["-date"]

    def __str__(self):
        return f"{self.from_company} → {self.to_company}: {self.amount}"


class Dividend(models.Model):
    company = models.ForeignKey(
        Company, on_delete=models.CASCADE, related_name="dividends"
    )
    amount = models.FloatField()
    currency = models.CharField(max_length=10, default="USD")
    date = models.CharField(max_length=20)
    recipient = models.CharField(max_length=255, blank=True, null=True)
    dividend_type = models.CharField(max_length=50, default="regular")
    notes = models.TextField(blank=True, null=True)

    class Meta:
        ordering = ["-date"]

    def __str__(self):
        return f"{self.dividend_type} dividend: {self.amount} {self.currency}"


class CapitalContribution(models.Model):
    company = models.ForeignKey(
        Company, on_delete=models.CASCADE, related_name="capital_contributions"
    )
    contributor = models.CharField(max_length=255)
    amount = models.FloatField()
    currency = models.CharField(max_length=10, default="USD")
    date = models.CharField(max_length=20)
    contribution_type = models.CharField(max_length=50, default="cash")
    notes = models.TextField(blank=True, null=True)

    class Meta:
        ordering = ["-date"]

    def __str__(self):
        return f"{self.contributor}: {self.amount} {self.currency}"


class TaxPayment(models.Model):
    company = models.ForeignKey(
        Company, on_delete=models.CASCADE, related_name="tax_payments"
    )
    jurisdiction = models.CharField(max_length=255)
    tax_type = models.CharField(max_length=100)
    amount = models.FloatField()
    currency = models.CharField(max_length=10, default="USD")
    date = models.CharField(max_length=20)
    period = models.CharField(max_length=50, blank=True, null=True)
    status = models.CharField(max_length=50, default="paid")
    notes = models.TextField(blank=True, null=True)

    class Meta:
        ordering = ["-date"]

    def __str__(self):
        return f"{self.tax_type} ({self.jurisdiction}): {self.amount}"


class Budget(models.Model):
    company = models.ForeignKey(
        Company, on_delete=models.CASCADE, related_name="budgets"
    )
    period = models.CharField(max_length=50)
    category = models.CharField(max_length=255)
    budgeted = models.FloatField(default=0)
    actual = models.FloatField(default=0)
    currency = models.CharField(max_length=10, default="USD")
    notes = models.TextField(blank=True, null=True)

    class Meta:
        ordering = ["-period"]

    def __str__(self):
        return f"{self.period} — {self.category}"


# =========================================================================
# Asset Management & Portfolio
# =========================================================================


class CostBasisLot(models.Model):
    holding = models.ForeignKey(
        AssetHolding, on_delete=models.CASCADE, related_name="cost_basis_lots"
    )
    purchase_date = models.CharField(max_length=20)
    quantity = models.FloatField()
    price_per_unit = models.FloatField()
    fees = models.FloatField(default=0)
    currency = models.CharField(max_length=10, default="USD")
    sold_quantity = models.FloatField(default=0)
    sold_date = models.CharField(max_length=20, blank=True, null=True)
    sold_price = models.FloatField(null=True, blank=True)
    notes = models.TextField(blank=True, null=True)

    class Meta:
        ordering = ["purchase_date"]

    def __str__(self):
        return f"{self.quantity} @ {self.price_per_unit} ({self.purchase_date})"


class RealEstateProperty(models.Model):
    company = models.ForeignKey(
        Company, on_delete=models.CASCADE, related_name="real_estate_properties"
    )
    name = models.CharField(max_length=255)
    address = models.TextField(blank=True, null=True)
    property_type = models.CharField(max_length=50, default="commercial")
    purchase_date = models.CharField(max_length=20, blank=True, null=True)
    purchase_price = models.FloatField(null=True, blank=True)
    current_valuation = models.FloatField(null=True, blank=True)
    rental_income_annual = models.FloatField(null=True, blank=True)
    currency = models.CharField(max_length=10, default="USD")
    notes = models.TextField(blank=True, null=True)

    class Meta:
        verbose_name_plural = "real estate properties"
        ordering = ["id"]

    def __str__(self):
        return self.name


class FundInvestment(models.Model):
    company = models.ForeignKey(
        Company, on_delete=models.CASCADE, related_name="fund_investments"
    )
    fund_name = models.CharField(max_length=255)
    fund_type = models.CharField(max_length=100, default="private_equity")
    commitment = models.FloatField(default=0)
    called = models.FloatField(default=0)
    distributed = models.FloatField(default=0)
    nav = models.FloatField(default=0)
    currency = models.CharField(max_length=10, default="USD")
    vintage_year = models.IntegerField(null=True, blank=True)
    notes = models.TextField(blank=True, null=True)

    class Meta:
        ordering = ["id"]

    def __str__(self):
        return self.fund_name


class CryptoWallet(models.Model):
    holding = models.ForeignKey(
        AssetHolding, on_delete=models.CASCADE, related_name="crypto_wallets"
    )
    wallet_address = models.CharField(max_length=500)
    blockchain = models.CharField(max_length=50, default="ethereum")
    wallet_type = models.CharField(max_length=50, default="hot")
    notes = models.TextField(blank=True, null=True)

    class Meta:
        ordering = ["id"]

    def __str__(self):
        return f"{self.blockchain}: {self.wallet_address[:16]}..."


# =========================================================================
# Tax & Compliance
# =========================================================================


class TransferPricingDoc(models.Model):
    from_company = models.ForeignKey(
        Company, on_delete=models.CASCADE, related_name="tp_docs_from"
    )
    to_company = models.ForeignKey(
        Company, on_delete=models.CASCADE, related_name="tp_docs_to"
    )
    description = models.CharField(max_length=500)
    method = models.CharField(max_length=100, default="comparable_uncontrolled")
    amount = models.FloatField(default=0)
    currency = models.CharField(max_length=10, default="USD")
    period = models.CharField(max_length=50, blank=True, null=True)
    notes = models.TextField(blank=True, null=True)

    class Meta:
        ordering = ["id"]

    def __str__(self):
        return f"{self.from_company} → {self.to_company}: {self.description}"


class WithholdingTax(models.Model):
    company = models.ForeignKey(
        Company, on_delete=models.CASCADE, related_name="withholding_taxes"
    )
    payment_type = models.CharField(max_length=100)
    country_from = models.CharField(max_length=255)
    country_to = models.CharField(max_length=255)
    gross_amount = models.FloatField()
    rate = models.FloatField()
    tax_amount = models.FloatField()
    currency = models.CharField(max_length=10, default="USD")
    date = models.CharField(max_length=20)
    notes = models.TextField(blank=True, null=True)

    class Meta:
        ordering = ["-date"]

    def __str__(self):
        return f"WHT {self.payment_type}: {self.tax_amount} {self.currency}"


class FatcaReport(models.Model):
    company = models.ForeignKey(
        Company, on_delete=models.CASCADE, related_name="fatca_reports"
    )
    reporting_year = models.IntegerField()
    jurisdiction = models.CharField(max_length=255)
    report_type = models.CharField(max_length=20, default="fatca")
    status = models.CharField(max_length=50, default="not_started")
    filed_date = models.CharField(max_length=20, blank=True, null=True)
    notes = models.TextField(blank=True, null=True)

    class Meta:
        ordering = ["-reporting_year"]

    def __str__(self):
        return f"{self.report_type} {self.reporting_year} ({self.jurisdiction})"


class ESGScore(models.Model):
    company = models.ForeignKey(
        Company, on_delete=models.CASCADE, related_name="esg_scores"
    )
    period = models.CharField(max_length=50)
    environmental_score = models.FloatField(null=True, blank=True)
    social_score = models.FloatField(null=True, blank=True)
    governance_score = models.FloatField(null=True, blank=True)
    overall_score = models.FloatField(null=True, blank=True)
    framework = models.CharField(max_length=50, default="custom")
    notes = models.TextField(blank=True, null=True)

    class Meta:
        ordering = ["-period"]

    def __str__(self):
        return f"ESG {self.period}: {self.overall_score}"


class RegulatoryFiling(models.Model):
    company = models.ForeignKey(
        Company, on_delete=models.CASCADE, related_name="regulatory_filings"
    )
    jurisdiction = models.CharField(max_length=255)
    filing_type = models.CharField(max_length=255)
    due_date = models.CharField(max_length=20)
    filed_date = models.CharField(max_length=20, blank=True, null=True)
    status = models.CharField(max_length=50, default="pending")
    reference_number = models.CharField(max_length=255, blank=True, null=True)
    notes = models.TextField(blank=True, null=True)

    class Meta:
        ordering = ["due_date"]

    def __str__(self):
        return f"{self.filing_type} ({self.jurisdiction})"


class ComplianceChecklist(models.Model):
    company = models.ForeignKey(
        Company, on_delete=models.CASCADE, related_name="compliance_checklists"
    )
    jurisdiction = models.CharField(max_length=255)
    item = models.CharField(max_length=500)
    category = models.CharField(max_length=100, default="regulatory")
    completed = models.BooleanField(default=False)
    due_date = models.CharField(max_length=20, blank=True, null=True)
    completed_date = models.CharField(max_length=20, blank=True, null=True)
    notes = models.TextField(blank=True, null=True)

    class Meta:
        ordering = ["due_date"]

    def __str__(self):
        return f"{self.item} ({self.jurisdiction})"


# =========================================================================
# Documents
# =========================================================================


class DocumentVersion(models.Model):
    document = models.ForeignKey(
        Document, on_delete=models.CASCADE, related_name="versions"
    )
    version_number = models.IntegerField(default=1)
    url = models.CharField(max_length=500, blank=True, null=True)
    uploaded_by = models.CharField(max_length=255, blank=True, null=True)
    notes = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-version_number"]

    def __str__(self):
        return f"v{self.version_number} — {self.document.name}"


# =========================================================================
# Platform: Webhooks, Approvals, Custom Fields, API Keys, Permissions
# =========================================================================


class Webhook(models.Model):
    url = models.CharField(max_length=500)
    events = models.JSONField(default=list, blank=True)
    is_active = models.BooleanField(default=True)
    secret = models.CharField(max_length=255, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    notes = models.TextField(blank=True, null=True)

    class Meta:
        ordering = ["id"]

    def __str__(self):
        return self.url


class ApprovalRequest(models.Model):
    requested_by = models.CharField(max_length=255)
    table_name = models.CharField(max_length=100)
    record_id = models.IntegerField(null=True, blank=True)
    action = models.CharField(max_length=50)
    payload = models.JSONField(default=dict, blank=True)
    status = models.CharField(max_length=50, default="pending")
    reviewed_by = models.CharField(max_length=255, blank=True, null=True)
    notes = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    reviewed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.action} {self.table_name} ({self.status})"


class CustomField(models.Model):
    name = models.CharField(max_length=255)
    field_type = models.CharField(max_length=50, default="text")
    entity_type = models.CharField(max_length=100, default="company")
    options = models.JSONField(default=list, blank=True)
    required = models.BooleanField(default=False)

    class Meta:
        ordering = ["id"]

    def __str__(self):
        return f"{self.name} ({self.field_type})"


class CustomFieldValue(models.Model):
    custom_field = models.ForeignKey(
        CustomField, on_delete=models.CASCADE, related_name="values"
    )
    entity_type = models.CharField(max_length=100)
    entity_id = models.IntegerField()
    value = models.TextField(blank=True, null=True)

    class Meta:
        ordering = ["id"]

    def __str__(self):
        return f"{self.custom_field.name}: {self.value}"


class APIKey(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="api_keys"
    )
    key = models.CharField(max_length=255, unique=True)
    name = models.CharField(max_length=255)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    last_used_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.name} ({self.user.username})"


class EntityPermission(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="entity_permissions"
    )
    company = models.ForeignKey(
        Company, on_delete=models.CASCADE, related_name="entity_permissions"
    )
    permission_level = models.CharField(max_length=20, default="view")

    class Meta:
        unique_together = ("user", "company")
        ordering = ["id"]

    def __str__(self):
        return f"{self.user.username} → {self.company.name}: {self.permission_level}"


# =========================================================================
# Disaster Recovery / Backup Configuration
# =========================================================================


class BackupConfig(models.Model):
    name = models.CharField(max_length=255)
    destination_type = models.CharField(max_length=50, default="local")
    destination_path = models.CharField(max_length=500)
    schedule = models.CharField(max_length=100, default="daily")
    retention_days = models.IntegerField(default=30)
    is_active = models.BooleanField(default=True)
    last_backup_at = models.DateTimeField(null=True, blank=True)
    notes = models.TextField(blank=True, null=True)

    class Meta:
        ordering = ["id"]

    def __str__(self):
        return f"{self.name} ({self.destination_type})"


class BackupLog(models.Model):
    config = models.ForeignKey(
        BackupConfig, on_delete=models.CASCADE, related_name="logs"
    )
    started_at = models.DateTimeField(auto_now_add=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    status = models.CharField(max_length=50, default="running")
    file_path = models.CharField(max_length=500, blank=True, null=True)
    file_size_bytes = models.BigIntegerField(null=True, blank=True)
    error_message = models.TextField(blank=True, null=True)

    class Meta:
        ordering = ["-started_at"]

    def __str__(self):
        return f"{self.config.name} — {self.status} ({self.started_at})"


# ---------------------------------------------------------------------------
# Multi-tenant
# ---------------------------------------------------------------------------

class TenantGroup(models.Model):
    name = models.CharField(max_length=200)
    slug = models.SlugField(unique=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["name"]

    def __str__(self):
        return self.name


class TenantMembership(models.Model):
    ROLE_CHOICES = [("owner", "Owner"), ("member", "Member"), ("viewer", "Viewer")]
    tenant = models.ForeignKey(TenantGroup, on_delete=models.CASCADE, related_name="memberships")
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="tenant_memberships")
    role = models.CharField(max_length=10, choices=ROLE_CHOICES, default="member")

    class Meta:
        ordering = ["id"]
        unique_together = ("tenant", "user")

    def __str__(self):
        return f"{self.user.username} @ {self.tenant.name}"


# ---------------------------------------------------------------------------
# Treasury Management
# ---------------------------------------------------------------------------

class CashPool(models.Model):
    name = models.CharField(max_length=200)
    currency = models.CharField(max_length=10, default="USD")
    target_balance = models.FloatField(default=0)
    notes = models.TextField(blank=True, default="")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["name"]

    def __str__(self):
        return self.name


class CashPoolEntry(models.Model):
    pool = models.ForeignKey(CashPool, on_delete=models.CASCADE, related_name="entries")
    company = models.ForeignKey("Company", on_delete=models.CASCADE, related_name="cash_pool_entries")
    bank_account = models.ForeignKey("BankAccount", on_delete=models.SET_NULL, null=True, blank=True, related_name="cash_pool_entries")
    allocated_amount = models.FloatField(default=0)
    notes = models.TextField(blank=True, default="")

    class Meta:
        ordering = ["id"]

    def __str__(self):
        return f"{self.company.name} -> {self.pool.name}: {self.allocated_amount}"


# ---------------------------------------------------------------------------
# Sanctions Screening
# ---------------------------------------------------------------------------

class SanctionsList(models.Model):
    LIST_CHOICES = [
        ("ofac_sdn", "OFAC SDN"),
        ("ofac_consolidated", "OFAC Consolidated"),
        ("eu_consolidated", "EU Consolidated"),
        ("un_consolidated", "UN Consolidated"),
        ("uk_sanctions", "UK Sanctions"),
        ("custom", "Custom"),
    ]
    name = models.CharField(max_length=200)
    list_type = models.CharField(max_length=30, choices=LIST_CHOICES)
    source_url = models.URLField(blank=True, default="")
    last_updated = models.DateTimeField(null=True, blank=True)
    entry_count = models.IntegerField(default=0)

    class Meta:
        ordering = ["name"]

    def __str__(self):
        return self.name


class SanctionsEntry(models.Model):
    sanctions_list = models.ForeignKey(SanctionsList, on_delete=models.CASCADE, related_name="entries")
    name = models.CharField(max_length=500)
    entity_type = models.CharField(max_length=50, blank=True, default="individual")
    country = models.CharField(max_length=200, blank=True, default="")
    identifiers = models.TextField(blank=True, default="")
    notes = models.TextField(blank=True, default="")

    class Meta:
        ordering = ["name"]

    def __str__(self):
        return self.name


class SanctionsCheck(models.Model):
    STATUS_CHOICES = [("clear", "Clear"), ("match", "Potential Match"), ("confirmed", "Confirmed Match"), ("false_positive", "False Positive")]
    company = models.ForeignKey("Company", on_delete=models.CASCADE, related_name="sanctions_checks")
    checked_name = models.CharField(max_length=500)
    checked_at = models.DateTimeField(auto_now_add=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="clear")
    matched_entry = models.ForeignKey(SanctionsEntry, on_delete=models.SET_NULL, null=True, blank=True)
    notes = models.TextField(blank=True, default="")

    class Meta:
        ordering = ["-checked_at"]

    def __str__(self):
        return f"{self.checked_name}: {self.status}"


# ---------------------------------------------------------------------------
# Portfolio Performance Snapshots
# ---------------------------------------------------------------------------

class PortfolioSnapshot(models.Model):
    date = models.CharField(max_length=10)
    liquid = models.FloatField(default=0)
    marketable = models.FloatField(default=0)
    illiquid = models.FloatField(default=0)
    liabilities = models.FloatField(default=0)
    nav = models.FloatField(default=0)
    currency = models.CharField(max_length=10, default="USD")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-date"]

    def __str__(self):
        return f"{self.date}: NAV {self.nav}"


# ---------------------------------------------------------------------------
# Accounting Software Sync
# ---------------------------------------------------------------------------

class AccountingSyncConfig(models.Model):
    PROVIDER_CHOICES = [("quickbooks", "QuickBooks"), ("xero", "Xero"), ("sage", "Sage"), ("freshbooks", "FreshBooks")]
    company = models.ForeignKey("Company", on_delete=models.CASCADE, related_name="accounting_syncs")
    provider = models.CharField(max_length=20, choices=PROVIDER_CHOICES)
    external_id = models.CharField(max_length=200, blank=True, default="")
    access_token = models.TextField(blank=True, default="")
    refresh_token = models.TextField(blank=True, default="")
    token_expires_at = models.DateTimeField(null=True, blank=True)
    is_active = models.BooleanField(default=True)
    last_sync_at = models.DateTimeField(null=True, blank=True)
    sync_direction = models.CharField(max_length=10, default="both", choices=[("push", "Push"), ("pull", "Pull"), ("both", "Both")])
    notes = models.TextField(blank=True, default="")

    class Meta:
        ordering = ["id"]

    def __str__(self):
        return f"{self.company.name} <-> {self.provider}"


class AccountingSyncLog(models.Model):
    config = models.ForeignKey(AccountingSyncConfig, on_delete=models.CASCADE, related_name="logs")
    started_at = models.DateTimeField(auto_now_add=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    status = models.CharField(max_length=20, default="running")
    records_synced = models.IntegerField(default=0)
    error_message = models.TextField(blank=True, default="")

    class Meta:
        ordering = ["-started_at"]

    def __str__(self):
        return f"{self.config}: {self.status}"


# ---------------------------------------------------------------------------
# Bank Feed Integration
# ---------------------------------------------------------------------------

class BankFeedConfig(models.Model):
    PROVIDER_CHOICES = [("plaid", "Plaid"), ("open_banking", "Open Banking"), ("yodlee", "Yodlee"), ("manual", "Manual")]
    company = models.ForeignKey("Company", on_delete=models.CASCADE, related_name="bank_feeds")
    bank_account = models.ForeignKey("BankAccount", on_delete=models.CASCADE, related_name="feed_configs")
    provider = models.CharField(max_length=20, choices=PROVIDER_CHOICES)
    external_account_id = models.CharField(max_length=200, blank=True, default="")
    access_token = models.TextField(blank=True, default="")
    is_active = models.BooleanField(default=True)
    last_sync_at = models.DateTimeField(null=True, blank=True)
    notes = models.TextField(blank=True, default="")

    class Meta:
        ordering = ["id"]

    def __str__(self):
        return f"{self.bank_account} via {self.provider}"


class BankFeedTransaction(models.Model):
    feed_config = models.ForeignKey(BankFeedConfig, on_delete=models.CASCADE, related_name="transactions")
    external_id = models.CharField(max_length=200)
    date = models.CharField(max_length=10)
    description = models.TextField(blank=True, default="")
    amount = models.FloatField(default=0)
    currency = models.CharField(max_length=10, default="USD")
    category = models.CharField(max_length=200, blank=True, default="")
    is_matched = models.BooleanField(default=False)
    matched_transaction = models.ForeignKey("Transaction", on_delete=models.SET_NULL, null=True, blank=True)

    class Meta:
        ordering = ["-date"]

    def __str__(self):
        return f"{self.date}: {self.amount} {self.currency}"


# ---------------------------------------------------------------------------
# E-Signature Integration
# ---------------------------------------------------------------------------

class SignatureRequest(models.Model):
    PROVIDER_CHOICES = [("docusign", "DocuSign"), ("hellosign", "HelloSign"), ("adobe_sign", "Adobe Sign")]
    STATUS_CHOICES = [("draft", "Draft"), ("sent", "Sent"), ("viewed", "Viewed"), ("signed", "Signed"), ("declined", "Declined"), ("expired", "Expired")]
    company = models.ForeignKey("Company", on_delete=models.CASCADE, related_name="signature_requests")
    document = models.ForeignKey("Document", on_delete=models.CASCADE, related_name="signature_requests")
    provider = models.CharField(max_length=20, choices=PROVIDER_CHOICES)
    external_id = models.CharField(max_length=200, blank=True, default="")
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="draft")
    signers = models.TextField(blank=True, default="")
    sent_at = models.DateTimeField(null=True, blank=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    notes = models.TextField(blank=True, default="")

    class Meta:
        ordering = ["-sent_at"]

    def __str__(self):
        return f"{self.document.name}: {self.status}"


# ---------------------------------------------------------------------------
# Email Digest
# ---------------------------------------------------------------------------

class EmailDigestConfig(models.Model):
    FREQUENCY_CHOICES = [("daily", "Daily"), ("weekly", "Weekly"), ("monthly", "Monthly")]
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="digest_configs")
    frequency = models.CharField(max_length=10, choices=FREQUENCY_CHOICES, default="weekly")
    is_active = models.BooleanField(default=True)
    include_portfolio = models.BooleanField(default=True)
    include_deadlines = models.BooleanField(default=True)
    include_audit_log = models.BooleanField(default=True)
    include_transactions = models.BooleanField(default=True)
    last_sent_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["id"]

    def __str__(self):
        return f"{self.user.username}: {self.frequency}"


# ---------------------------------------------------------------------------
# Investor Portal
# ---------------------------------------------------------------------------

class InvestorAccess(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="investor_access")
    company = models.ForeignKey("Company", on_delete=models.CASCADE, related_name="investor_access")
    can_view_financials = models.BooleanField(default=True)
    can_view_holdings = models.BooleanField(default=True)
    can_view_documents = models.BooleanField(default=False)
    can_view_cap_table = models.BooleanField(default=True)
    expires_at = models.DateTimeField(null=True, blank=True)
    notes = models.TextField(blank=True, default="")

    class Meta:
        ordering = ["id"]
        unique_together = ("user", "company")

    def __str__(self):
        return f"{self.user.username} -> {self.company.name}"


# ---------------------------------------------------------------------------
# Document Upload (S3/cloud tracking)
# ---------------------------------------------------------------------------

class DocumentUpload(models.Model):
    STORAGE_CHOICES = [("local", "Local"), ("s3", "S3"), ("minio", "MinIO"), ("gcs", "Google Cloud Storage")]
    document = models.ForeignKey("Document", on_delete=models.CASCADE, related_name="uploads")
    storage_backend = models.CharField(max_length=10, choices=STORAGE_CHOICES, default="local")
    file_path = models.TextField()
    file_name = models.CharField(max_length=500)
    file_size = models.BigIntegerField(default=0)
    content_type = models.CharField(max_length=200, blank=True, default="")
    checksum = models.CharField(max_length=128, blank=True, default="")
    uploaded_at = models.DateTimeField(auto_now_add=True)
    uploaded_by = models.CharField(max_length=200, blank=True, default="")

    class Meta:
        ordering = ["-uploaded_at"]

    def __str__(self):
        return self.file_name
