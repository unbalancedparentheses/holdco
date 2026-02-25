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
    CapTableEntry,
    ShareholderResolution,
    PowerOfAttorney,
    AnnualFiling,
    BeneficialOwner,
    OwnershipChange,
    KeyPersonnel,
    RegulatoryLicense,
    JointVenture,
    EquityIncentivePlan,
    EquityGrant,
    Deal,
    Account,
    JournalEntry,
    JournalLine,
    InterCompanyTransfer,
    Dividend,
    CapitalContribution,
    TaxPayment,
    Budget,
    CostBasisLot,
    RealEstateProperty,
    FundInvestment,
    CryptoWallet,
    TransferPricingDoc,
    WithholdingTax,
    FatcaReport,
    ESGScore,
    RegulatoryFiling,
    ComplianceChecklist,
    DocumentVersion,
    Webhook,
    ApprovalRequest,
    CustomField,
    CustomFieldValue,
    APIKey,
    EntityPermission,
    BackupConfig,
    BackupLog,
    TenantGroup,
    TenantMembership,
    CashPool,
    CashPoolEntry,
    SanctionsList,
    SanctionsEntry,
    SanctionsCheck,
    PortfolioSnapshot,
    AccountingSyncConfig,
    AccountingSyncLog,
    BankFeedConfig,
    BankFeedTransaction,
    SignatureRequest,
    EmailDigestConfig,
    InvestorAccess,
    DocumentUpload,
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


class EquityGrantInline(TabularInline):
    model = EquityGrant
    extra = 0
    fields = ("recipient", "grant_type", "quantity", "strike_price", "grant_date", "vesting_start")
    show_change_link = True


class JournalLineInline(TabularInline):
    model = JournalLine
    extra = 0
    fields = ("account", "debit", "credit", "notes")


class CostBasisLotInline(TabularInline):
    model = CostBasisLot
    extra = 0
    fields = ("purchase_date", "quantity", "price_per_unit", "fees", "currency")
    show_change_link = True


class CryptoWalletInline(TabularInline):
    model = CryptoWallet
    extra = 0
    fields = ("wallet_address", "blockchain", "wallet_type")
    show_change_link = True


class DocumentVersionInline(TabularInline):
    model = DocumentVersion
    extra = 0
    fields = ("version_number", "url", "uploaded_by", "notes")
    show_change_link = True


class BackupLogInline(TabularInline):
    model = BackupLog
    extra = 0
    fields = ("started_at", "completed_at", "status", "file_path", "file_size_bytes")
    readonly_fields = ("started_at",)
    show_change_link = True


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
    inlines = [CustodianInline, CostBasisLotInline, CryptoWalletInline]


@admin.register(CustodianAccount)
class CustodianAccountAdmin(ModelAdmin):
    list_display = ("bank", "asset_holding", "account_type")
    search_fields = ("bank",)


@admin.register(Document)
class DocumentAdmin(ModelAdmin):
    list_display = ("name", "company", "doc_type", "uploaded_at")
    list_filter = ("doc_type",)
    search_fields = ("name",)
    inlines = [DocumentVersionInline]


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


# --- Corporate Structure & Governance ---


@admin.register(CapTableEntry)
class CapTableEntryAdmin(ModelAdmin):
    list_display = ("round_name", "investor", "company", "instrument_type", "shares", "amount_invested", "currency")
    list_filter = ("instrument_type", "currency")
    search_fields = ("round_name", "investor")


@admin.register(ShareholderResolution)
class ShareholderResolutionAdmin(ModelAdmin):
    list_display = ("title", "company", "resolution_type", "date", "passed", "votes_for", "votes_against")
    list_filter = ("resolution_type", "passed")
    search_fields = ("title",)


@admin.register(PowerOfAttorney)
class PowerOfAttorneyAdmin(ModelAdmin):
    list_display = ("grantor", "grantee", "company", "status", "start_date", "end_date")
    list_filter = ("status",)
    search_fields = ("grantor", "grantee")


@admin.register(AnnualFiling)
class AnnualFilingAdmin(ModelAdmin):
    list_display = ("filing_type", "company", "jurisdiction", "due_date", "filed_date", "status")
    list_filter = ("status", "jurisdiction")
    search_fields = ("filing_type", "jurisdiction")


@admin.register(BeneficialOwner)
class BeneficialOwnerAdmin(ModelAdmin):
    list_display = ("name", "company", "nationality", "ownership_pct", "control_type", "verified")
    list_filter = ("control_type", "verified")
    search_fields = ("name", "nationality")


@admin.register(OwnershipChange)
class OwnershipChangeAdmin(ModelAdmin):
    list_display = ("from_owner", "to_owner", "company", "ownership_pct", "transaction_type", "date")
    list_filter = ("transaction_type",)
    search_fields = ("from_owner", "to_owner")


@admin.register(KeyPersonnel)
class KeyPersonnelAdmin(ModelAdmin):
    list_display = ("name", "title", "company", "department", "email", "start_date")
    list_filter = ("department",)
    search_fields = ("name", "title", "email")


@admin.register(RegulatoryLicense)
class RegulatoryLicenseAdmin(ModelAdmin):
    list_display = ("license_type", "issuing_authority", "company", "license_number", "status", "expiry_date")
    list_filter = ("status",)
    search_fields = ("license_type", "issuing_authority", "license_number")


@admin.register(JointVenture)
class JointVentureAdmin(ModelAdmin):
    list_display = ("name", "partner", "company", "ownership_pct", "status", "total_value", "currency")
    list_filter = ("status", "currency")
    search_fields = ("name", "partner")


@admin.register(EquityIncentivePlan)
class EquityIncentivePlanAdmin(ModelAdmin):
    list_display = ("plan_name", "company", "total_pool", "vesting_schedule", "board_approval_date")
    search_fields = ("plan_name",)
    inlines = [EquityGrantInline]


@admin.register(EquityGrant)
class EquityGrantAdmin(ModelAdmin):
    list_display = ("recipient", "plan", "grant_type", "quantity", "strike_price", "grant_date", "exercised")
    list_filter = ("grant_type",)
    search_fields = ("recipient",)


@admin.register(Deal)
class DealAdmin(ModelAdmin):
    list_display = ("deal_type", "counterparty", "company", "status", "value", "currency", "target_close_date")
    list_filter = ("deal_type", "status")
    search_fields = ("counterparty",)


# --- Financial Operations ---


@admin.register(Account)
class AccountAdmin(ModelAdmin):
    list_display = ("code", "name", "account_type", "parent", "currency")
    list_filter = ("account_type", "currency")
    search_fields = ("name", "code")


@admin.register(JournalEntry)
class JournalEntryAdmin(ModelAdmin):
    list_display = ("date", "description", "reference", "created_at")
    search_fields = ("description", "reference")
    inlines = [JournalLineInline]


@admin.register(JournalLine)
class JournalLineAdmin(ModelAdmin):
    list_display = ("entry", "account", "debit", "credit")
    list_filter = ("account",)
    search_fields = ("notes",)


@admin.register(InterCompanyTransfer)
class InterCompanyTransferAdmin(ModelAdmin):
    list_display = ("from_company", "to_company", "amount", "currency", "date", "status")
    list_filter = ("status", "currency")
    search_fields = ("description",)


@admin.register(Dividend)
class DividendAdmin(ModelAdmin):
    list_display = ("company", "dividend_type", "amount", "currency", "date", "recipient")
    list_filter = ("dividend_type", "currency")
    search_fields = ("recipient",)


@admin.register(CapitalContribution)
class CapitalContributionAdmin(ModelAdmin):
    list_display = ("contributor", "company", "amount", "currency", "date", "contribution_type")
    list_filter = ("contribution_type", "currency")
    search_fields = ("contributor",)


@admin.register(TaxPayment)
class TaxPaymentAdmin(ModelAdmin):
    list_display = ("tax_type", "company", "jurisdiction", "amount", "currency", "date", "status")
    list_filter = ("tax_type", "status", "jurisdiction")
    search_fields = ("tax_type", "jurisdiction")


@admin.register(Budget)
class BudgetAdmin(ModelAdmin):
    list_display = ("period", "category", "company", "budgeted", "actual", "currency")
    list_filter = ("currency",)
    search_fields = ("period", "category")


# --- Asset Management & Portfolio ---


@admin.register(CostBasisLot)
class CostBasisLotAdmin(ModelAdmin):
    list_display = ("holding", "purchase_date", "quantity", "price_per_unit", "fees", "currency", "sold_quantity")
    list_filter = ("currency",)
    search_fields = ("holding__asset",)


@admin.register(RealEstateProperty)
class RealEstatePropertyAdmin(ModelAdmin):
    list_display = ("name", "company", "property_type", "purchase_price", "current_valuation", "currency")
    list_filter = ("property_type", "currency")
    search_fields = ("name", "address")


@admin.register(FundInvestment)
class FundInvestmentAdmin(ModelAdmin):
    list_display = ("fund_name", "company", "fund_type", "commitment", "called", "distributed", "nav", "currency")
    list_filter = ("fund_type", "currency")
    search_fields = ("fund_name",)


@admin.register(CryptoWallet)
class CryptoWalletAdmin(ModelAdmin):
    list_display = ("holding", "blockchain", "wallet_type", "wallet_address")
    list_filter = ("blockchain", "wallet_type")
    search_fields = ("wallet_address",)


# --- Tax & Compliance ---


@admin.register(TransferPricingDoc)
class TransferPricingDocAdmin(ModelAdmin):
    list_display = ("description", "from_company", "to_company", "method", "amount", "currency", "period")
    list_filter = ("method", "currency")
    search_fields = ("description",)


@admin.register(WithholdingTax)
class WithholdingTaxAdmin(ModelAdmin):
    list_display = ("payment_type", "company", "country_from", "country_to", "gross_amount", "rate", "tax_amount", "date")
    list_filter = ("payment_type",)
    search_fields = ("country_from", "country_to")


@admin.register(FatcaReport)
class FatcaReportAdmin(ModelAdmin):
    list_display = ("report_type", "company", "reporting_year", "jurisdiction", "status", "filed_date")
    list_filter = ("report_type", "status", "jurisdiction")
    search_fields = ("jurisdiction",)


@admin.register(ESGScore)
class ESGScoreAdmin(ModelAdmin):
    list_display = ("company", "period", "environmental_score", "social_score", "governance_score", "overall_score", "framework")
    list_filter = ("framework",)
    search_fields = ("period",)


@admin.register(RegulatoryFiling)
class RegulatoryFilingAdmin(ModelAdmin):
    list_display = ("filing_type", "company", "jurisdiction", "due_date", "filed_date", "status", "reference_number")
    list_filter = ("status", "jurisdiction")
    search_fields = ("filing_type", "jurisdiction", "reference_number")


@admin.register(ComplianceChecklist)
class ComplianceChecklistAdmin(ModelAdmin):
    list_display = ("item", "company", "jurisdiction", "category", "completed", "due_date", "completed_date")
    list_filter = ("category", "completed", "jurisdiction")
    search_fields = ("item", "jurisdiction")


# --- Documents ---


@admin.register(DocumentVersion)
class DocumentVersionAdmin(ModelAdmin):
    list_display = ("document", "version_number", "uploaded_by", "created_at")
    list_filter = ("version_number",)
    search_fields = ("document__name", "uploaded_by")


# --- Platform: Webhooks, Approvals, Custom Fields, API Keys, Permissions ---


@admin.register(Webhook)
class WebhookAdmin(ModelAdmin):
    list_display = ("url", "is_active", "created_at")
    list_filter = ("is_active",)
    search_fields = ("url",)


@admin.register(ApprovalRequest)
class ApprovalRequestAdmin(ModelAdmin):
    list_display = ("action", "table_name", "record_id", "requested_by", "status", "reviewed_by", "created_at")
    list_filter = ("status", "action", "table_name")
    search_fields = ("requested_by", "reviewed_by", "table_name")


@admin.register(CustomField)
class CustomFieldAdmin(ModelAdmin):
    list_display = ("name", "field_type", "entity_type", "required")
    list_filter = ("field_type", "entity_type", "required")
    search_fields = ("name",)


@admin.register(CustomFieldValue)
class CustomFieldValueAdmin(ModelAdmin):
    list_display = ("custom_field", "entity_type", "entity_id", "value")
    list_filter = ("entity_type",)
    search_fields = ("value",)


@admin.register(APIKey)
class APIKeyAdmin(ModelAdmin):
    list_display = ("name", "user", "is_active", "created_at", "last_used_at")
    list_filter = ("is_active",)
    search_fields = ("name", "user__username")


@admin.register(EntityPermission)
class EntityPermissionAdmin(ModelAdmin):
    list_display = ("user", "company", "permission_level")
    list_filter = ("permission_level",)
    search_fields = ("user__username", "company__name")


# --- Disaster Recovery / Backup ---


@admin.register(BackupConfig)
class BackupConfigAdmin(ModelAdmin):
    list_display = ("name", "destination_type", "schedule", "retention_days", "is_active", "last_backup_at")
    list_filter = ("destination_type", "schedule", "is_active")
    search_fields = ("name", "destination_path")
    inlines = [BackupLogInline]


@admin.register(BackupLog)
class BackupLogAdmin(ModelAdmin):
    list_display = ("config", "started_at", "completed_at", "status", "file_size_bytes")
    list_filter = ("status",)
    search_fields = ("config__name", "file_path")


# --- Multi-Tenancy ---


@admin.register(TenantGroup)
class TenantGroupAdmin(ModelAdmin):
    list_display = ("name", "slug", "created_at")
    search_fields = ("name", "slug")


@admin.register(TenantMembership)
class TenantMembershipAdmin(ModelAdmin):
    list_display = ("user", "tenant", "role")
    list_filter = ("role",)


# --- Cash Pooling ---


@admin.register(CashPool)
class CashPoolAdmin(ModelAdmin):
    list_display = ("name", "currency", "target_balance", "created_at")
    search_fields = ("name",)


@admin.register(CashPoolEntry)
class CashPoolEntryAdmin(ModelAdmin):
    list_display = ("pool", "company", "bank_account", "allocated_amount")
    list_filter = ("pool",)


# --- Sanctions / AML ---


@admin.register(SanctionsList)
class SanctionsListAdmin(ModelAdmin):
    list_display = ("name", "list_type", "entry_count", "last_updated")
    list_filter = ("list_type",)


@admin.register(SanctionsEntry)
class SanctionsEntryAdmin(ModelAdmin):
    list_display = ("name", "sanctions_list", "entity_type", "country")
    list_filter = ("sanctions_list", "entity_type")
    search_fields = ("name", "country")


@admin.register(SanctionsCheck)
class SanctionsCheckAdmin(ModelAdmin):
    list_display = ("checked_name", "company", "status", "checked_at", "matched_entry")
    list_filter = ("status",)
    search_fields = ("checked_name",)


# --- Portfolio Snapshots ---


@admin.register(PortfolioSnapshot)
class PortfolioSnapshotAdmin(ModelAdmin):
    list_display = ("date", "nav", "liquid", "marketable", "illiquid", "liabilities", "currency")


# --- Accounting Sync ---


@admin.register(AccountingSyncConfig)
class AccountingSyncConfigAdmin(ModelAdmin):
    list_display = ("company", "provider", "is_active", "sync_direction", "last_sync_at")
    list_filter = ("provider", "is_active")


@admin.register(AccountingSyncLog)
class AccountingSyncLogAdmin(ModelAdmin):
    list_display = ("config", "started_at", "completed_at", "status", "records_synced")
    list_filter = ("status",)


# --- Bank Feeds ---


@admin.register(BankFeedConfig)
class BankFeedConfigAdmin(ModelAdmin):
    list_display = ("company", "bank_account", "provider", "is_active", "last_sync_at")
    list_filter = ("provider", "is_active")


@admin.register(BankFeedTransaction)
class BankFeedTransactionAdmin(ModelAdmin):
    list_display = ("feed_config", "date", "description", "amount", "currency", "is_matched")
    list_filter = ("is_matched", "currency")


# --- E-Signatures ---


@admin.register(SignatureRequest)
class SignatureRequestAdmin(ModelAdmin):
    list_display = ("document", "company", "provider", "status", "sent_at", "completed_at")
    list_filter = ("provider", "status")


# --- Notifications ---


@admin.register(EmailDigestConfig)
class EmailDigestConfigAdmin(ModelAdmin):
    list_display = ("user", "frequency", "is_active", "last_sent_at")
    list_filter = ("frequency", "is_active")


# --- Investor Portal ---


@admin.register(InvestorAccess)
class InvestorAccessAdmin(ModelAdmin):
    list_display = ("user", "company", "can_view_financials", "can_view_holdings", "can_view_documents", "can_view_cap_table", "expires_at")


# --- Document Storage ---


@admin.register(DocumentUpload)
class DocumentUploadAdmin(ModelAdmin):
    list_display = ("file_name", "document", "storage_backend", "file_size", "uploaded_at", "uploaded_by")
    list_filter = ("storage_backend",)
    search_fields = ("file_name",)
