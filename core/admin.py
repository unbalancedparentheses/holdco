from django.contrib import admin
from unfold.admin import ModelAdmin, TabularInline

from core.models import (
    AssetHolding,
    AuditLog,
    BankAccount,
    BoardMeeting,
    Category,
    Company,
    CustodianAccount,
    Document,
    Financial,
    InsurancePolicy,
    Liability,
    PriceHistory,
    ServiceProvider,
    Setting,
    TaxDeadline,
    Transaction,
    UserRole,
)


# --- Inlines ---


class SubsidiaryInline(TabularInline):
    model = Company
    fk_name = "parent"
    extra = 0
    fields = ("name", "country", "category", "ownership_pct", "is_holding")
    show_change_link = True


class AssetHoldingInline(TabularInline):
    model = AssetHolding
    extra = 0
    fields = ("asset", "ticker", "quantity", "unit", "currency", "asset_type")
    show_change_link = True


class CustodianInline(TabularInline):
    model = CustodianAccount
    extra = 0
    fields = ("bank", "account_number", "account_type", "authorized_persons")


class DocumentInline(TabularInline):
    model = Document
    extra = 0
    fields = ("name", "doc_type", "url", "notes")


class TaxDeadlineInline(TabularInline):
    model = TaxDeadline
    extra = 0
    fields = ("jurisdiction", "description", "due_date", "status")


class FinancialInline(TabularInline):
    model = Financial
    extra = 0
    fields = ("period", "revenue", "expenses", "currency")


class BankAccountInline(TabularInline):
    model = BankAccount
    extra = 0
    fields = ("bank_name", "account_number", "currency", "account_type", "balance")


class TransactionInline(TabularInline):
    model = Transaction
    extra = 0
    fields = ("transaction_type", "description", "amount", "currency", "date")


class LiabilityInline(TabularInline):
    model = Liability
    extra = 0
    fields = ("liability_type", "creditor", "principal", "currency", "status")


class ServiceProviderInline(TabularInline):
    model = ServiceProvider
    extra = 0
    fields = ("role", "name", "firm", "email", "phone")


class InsurancePolicyInline(TabularInline):
    model = InsurancePolicy
    extra = 0
    fields = ("policy_type", "provider", "policy_number", "coverage_amount", "premium")


class BoardMeetingInline(TabularInline):
    model = BoardMeeting
    extra = 0
    fields = ("meeting_type", "scheduled_date", "status")


# --- ModelAdmins ---


@admin.register(Company)
class CompanyAdmin(ModelAdmin):
    list_display = ("name", "country", "category", "is_holding", "parent", "ownership_pct")
    list_filter = ("category", "country", "is_holding")
    search_fields = ("name", "legal_name", "country")
    inlines = [
        SubsidiaryInline,
        AssetHoldingInline,
        BankAccountInline,
        DocumentInline,
        TaxDeadlineInline,
        FinancialInline,
        TransactionInline,
        LiabilityInline,
        ServiceProviderInline,
        InsurancePolicyInline,
        BoardMeetingInline,
    ]


@admin.register(AssetHolding)
class AssetHoldingAdmin(ModelAdmin):
    list_display = ("asset", "company", "ticker", "quantity", "unit", "currency", "asset_type")
    list_filter = ("currency", "asset_type")
    search_fields = ("asset", "ticker")
    inlines = [CustodianInline]


@admin.register(CustodianAccount)
class CustodianAccountAdmin(ModelAdmin):
    list_display = ("bank", "asset_holding", "account_type")
    search_fields = ("bank",)


@admin.register(Document)
class DocumentAdmin(ModelAdmin):
    list_display = ("name", "company", "doc_type", "uploaded_at")
    list_filter = ("doc_type",)
    search_fields = ("name",)


@admin.register(TaxDeadline)
class TaxDeadlineAdmin(ModelAdmin):
    list_display = ("description", "company", "jurisdiction", "due_date", "status")
    list_filter = ("status", "jurisdiction")
    search_fields = ("description",)


@admin.register(Financial)
class FinancialAdmin(ModelAdmin):
    list_display = ("period", "company", "revenue", "expenses", "currency")
    list_filter = ("currency",)
    search_fields = ("period",)


@admin.register(BankAccount)
class BankAccountAdmin(ModelAdmin):
    list_display = ("bank_name", "company", "account_type", "currency", "balance")
    list_filter = ("account_type", "currency")
    search_fields = ("bank_name",)


@admin.register(Transaction)
class TransactionAdmin(ModelAdmin):
    list_display = ("transaction_type", "description", "company", "amount", "currency", "date")
    list_filter = ("transaction_type", "currency")
    search_fields = ("description", "counterparty")


@admin.register(Liability)
class LiabilityAdmin(ModelAdmin):
    list_display = ("liability_type", "creditor", "company", "principal", "currency", "status")
    list_filter = ("liability_type", "status")
    search_fields = ("creditor",)


@admin.register(ServiceProvider)
class ServiceProviderAdmin(ModelAdmin):
    list_display = ("name", "role", "company", "firm", "email")
    list_filter = ("role",)
    search_fields = ("name", "firm")


@admin.register(InsurancePolicy)
class InsurancePolicyAdmin(ModelAdmin):
    list_display = ("policy_type", "provider", "company", "coverage_amount", "premium", "expiry_date")
    list_filter = ("policy_type",)
    search_fields = ("provider", "policy_number")


@admin.register(BoardMeeting)
class BoardMeetingAdmin(ModelAdmin):
    list_display = ("meeting_type", "company", "scheduled_date", "status")
    list_filter = ("meeting_type", "status")


@admin.register(Category)
class CategoryAdmin(ModelAdmin):
    list_display = ("name", "color")
    search_fields = ("name",)


@admin.register(Setting)
class SettingAdmin(ModelAdmin):
    list_display = ("key", "value")
    search_fields = ("key",)


@admin.register(PriceHistory)
class PriceHistoryAdmin(ModelAdmin):
    list_display = ("ticker", "price", "currency", "recorded_at")
    list_filter = ("ticker",)


@admin.register(AuditLog)
class AuditLogAdmin(ModelAdmin):
    list_display = ("timestamp", "action", "table_name", "record_id", "details")
    list_filter = ("action", "table_name")
    readonly_fields = ("timestamp", "action", "table_name", "record_id", "details")

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False


@admin.register(UserRole)
class UserRoleAdmin(ModelAdmin):
    list_display = ("user", "role")
    list_filter = ("role",)
    search_fields = ("user__username", "user__email")
