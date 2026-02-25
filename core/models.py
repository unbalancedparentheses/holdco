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

    class Meta:
        verbose_name_plural = "companies"
        ordering = ["id"]

    def __str__(self):
        return self.name


class AssetHolding(models.Model):
    company = models.ForeignKey(
        Company, on_delete=models.CASCADE, related_name="asset_holdings"
    )
    asset = models.CharField(max_length=255)
    ticker = models.CharField(max_length=50, blank=True, null=True)
    quantity = models.FloatField(null=True, blank=True)
    unit = models.CharField(max_length=50, blank=True, null=True)
    currency = models.CharField(max_length=10, default="USD")

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
