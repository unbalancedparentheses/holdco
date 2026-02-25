import math

from rest_framework import serializers

from core.models import (
    Account,
    AccountingSyncConfig,
    AccountingSyncLog,
    AnnualFiling,
    APIKey,
    ApprovalRequest,
    AssetHolding,
    AuditLog,
    BackupConfig,
    BackupLog,
    BankAccount,
    BankFeedConfig,
    BankFeedTransaction,
    BeneficialOwner,
    BoardMeeting,
    Budget,
    CapitalContribution,
    CapTableEntry,
    CashPool,
    CashPoolEntry,
    Category,
    Company,
    ComplianceChecklist,
    CostBasisLot,
    CryptoWallet,
    CustomField,
    CustomFieldValue,
    CustodianAccount,
    Deal,
    Dividend,
    Document,
    DocumentUpload,
    DocumentVersion,
    EmailDigestConfig,
    EntityPermission,
    EquityGrant,
    EquityIncentivePlan,
    ESGScore,
    FatcaReport,
    Financial,
    FundInvestment,
    InsurancePolicy,
    InterCompanyTransfer,
    InvestorAccess,
    JointVenture,
    JournalEntry,
    JournalLine,
    KeyPersonnel,
    Liability,
    OwnershipChange,
    PortfolioSnapshot,
    PowerOfAttorney,
    PriceHistory,
    RealEstateProperty,
    RegulatoryFiling,
    RegulatoryLicense,
    SanctionsCheck,
    SanctionsEntry,
    SanctionsList,
    ServiceProvider,
    Setting,
    ShareholderResolution,
    SignatureRequest,
    TaxDeadline,
    TaxPayment,
    TenantGroup,
    TenantMembership,
    Transaction,
    TransferPricingDoc,
    Webhook,
    WithholdingTax,
)


class ValidateCompanyIdMixin:
    def validate_company_id(self, value):
        if not Company.objects.filter(id=value).exists():
            raise serializers.ValidationError("Company does not exist.")
        return value


class SafeFloatField(serializers.FloatField):
    def to_internal_value(self, data):
        value = super().to_internal_value(data)
        if math.isnan(value) or math.isinf(value):
            raise serializers.ValidationError("NaN and Infinity are not allowed.")
        return value


class CategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = "__all__"


class SettingSerializer(serializers.Serializer):
    key = serializers.CharField()
    value = serializers.CharField()


class CompanySerializer(serializers.ModelSerializer):
    parent_id = serializers.IntegerField(source="parent.id", allow_null=True, read_only=True)

    class Meta:
        model = Company
        fields = "__all__"


class CompanyCreateSerializer(serializers.ModelSerializer):
    parent_id = serializers.IntegerField(required=False, allow_null=True)

    class Meta:
        model = Company
        exclude = ("parent",)

    def validate_parent_id(self, value):
        if value is not None and not Company.objects.filter(id=value).exists():
            raise serializers.ValidationError("Parent company does not exist.")
        return value

    def create(self, validated_data):
        parent_id = validated_data.pop("parent_id", None)
        if parent_id:
            validated_data["parent_id"] = parent_id
        return super().create(validated_data)


class CompanyUpdateSerializer(serializers.ModelSerializer):
    parent_id = serializers.IntegerField(required=False, allow_null=True)

    class Meta:
        model = Company
        exclude = ("parent",)
        extra_kwargs = {f: {"required": False} for f in [
            "name", "country", "category",
        ]}

    def update(self, instance, validated_data):
        parent_id = validated_data.pop("parent_id", None)
        if parent_id is not None:
            validated_data["parent_id"] = parent_id
        return super().update(instance, validated_data)


class AssetHoldingSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source="company.name", read_only=True)

    class Meta:
        model = AssetHolding
        fields = "__all__"


class AssetHoldingCreateSerializer(ValidateCompanyIdMixin, serializers.ModelSerializer):
    company_id = serializers.IntegerField()

    class Meta:
        model = AssetHolding
        exclude = ("company",)

    def create(self, validated_data):
        validated_data["company_id"] = validated_data.pop("company_id")
        return super().create(validated_data)


class CustodianAccountSerializer(serializers.ModelSerializer):
    class Meta:
        model = CustodianAccount
        fields = "__all__"


class CustodianCreateSerializer(serializers.ModelSerializer):
    asset_holding_id = serializers.IntegerField()

    def validate_asset_holding_id(self, value):
        if not AssetHolding.objects.filter(id=value).exists():
            raise serializers.ValidationError("Asset holding does not exist.")
        return value

    class Meta:
        model = CustodianAccount
        exclude = ("asset_holding",)

    def create(self, validated_data):
        validated_data["asset_holding_id"] = validated_data.pop("asset_holding_id")
        return super().create(validated_data)


class DocumentSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source="company.name", read_only=True)

    class Meta:
        model = Document
        fields = "__all__"


class DocumentCreateSerializer(ValidateCompanyIdMixin, serializers.ModelSerializer):
    company_id = serializers.IntegerField()

    class Meta:
        model = Document
        exclude = ("company",)

    def create(self, validated_data):
        validated_data["company_id"] = validated_data.pop("company_id")
        return super().create(validated_data)


class TaxDeadlineSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source="company.name", read_only=True)

    class Meta:
        model = TaxDeadline
        fields = "__all__"


class TaxDeadlineCreateSerializer(ValidateCompanyIdMixin, serializers.ModelSerializer):
    company_id = serializers.IntegerField()

    class Meta:
        model = TaxDeadline
        exclude = ("company",)

    def create(self, validated_data):
        validated_data["company_id"] = validated_data.pop("company_id")
        return super().create(validated_data)


class FinancialSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source="company.name", read_only=True)

    class Meta:
        model = Financial
        fields = "__all__"


class FinancialCreateSerializer(ValidateCompanyIdMixin, serializers.ModelSerializer):
    company_id = serializers.IntegerField()

    class Meta:
        model = Financial
        exclude = ("company",)

    def create(self, validated_data):
        validated_data["company_id"] = validated_data.pop("company_id")
        return super().create(validated_data)


class BankAccountSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source="company.name", read_only=True)

    class Meta:
        model = BankAccount
        fields = "__all__"


class BankAccountCreateSerializer(ValidateCompanyIdMixin, serializers.ModelSerializer):
    company_id = serializers.IntegerField()

    class Meta:
        model = BankAccount
        exclude = ("company",)

    def create(self, validated_data):
        validated_data["company_id"] = validated_data.pop("company_id")
        return super().create(validated_data)


class TransactionSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source="company.name", read_only=True)

    class Meta:
        model = Transaction
        fields = "__all__"


class TransactionCreateSerializer(ValidateCompanyIdMixin, serializers.ModelSerializer):
    company_id = serializers.IntegerField()
    asset_holding_id = serializers.IntegerField(required=False, allow_null=True)
    amount = SafeFloatField()

    class Meta:
        model = Transaction
        exclude = ("company", "asset_holding")

    def create(self, validated_data):
        validated_data["company_id"] = validated_data.pop("company_id")
        ah_id = validated_data.pop("asset_holding_id", None)
        if ah_id:
            validated_data["asset_holding_id"] = ah_id
        return super().create(validated_data)


class LiabilitySerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source="company.name", read_only=True)

    class Meta:
        model = Liability
        fields = "__all__"


class LiabilityCreateSerializer(ValidateCompanyIdMixin, serializers.ModelSerializer):
    company_id = serializers.IntegerField()

    class Meta:
        model = Liability
        exclude = ("company",)

    def create(self, validated_data):
        validated_data["company_id"] = validated_data.pop("company_id")
        return super().create(validated_data)


class ServiceProviderSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source="company.name", read_only=True)

    class Meta:
        model = ServiceProvider
        fields = "__all__"


class ServiceProviderCreateSerializer(ValidateCompanyIdMixin, serializers.ModelSerializer):
    company_id = serializers.IntegerField()

    class Meta:
        model = ServiceProvider
        exclude = ("company",)

    def create(self, validated_data):
        validated_data["company_id"] = validated_data.pop("company_id")
        return super().create(validated_data)


class InsurancePolicySerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source="company.name", read_only=True)

    class Meta:
        model = InsurancePolicy
        fields = "__all__"


class InsurancePolicyCreateSerializer(ValidateCompanyIdMixin, serializers.ModelSerializer):
    company_id = serializers.IntegerField()

    class Meta:
        model = InsurancePolicy
        exclude = ("company",)

    def create(self, validated_data):
        validated_data["company_id"] = validated_data.pop("company_id")
        return super().create(validated_data)


class BoardMeetingSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source="company.name", read_only=True)

    class Meta:
        model = BoardMeeting
        fields = "__all__"


class BoardMeetingCreateSerializer(ValidateCompanyIdMixin, serializers.ModelSerializer):
    company_id = serializers.IntegerField()

    class Meta:
        model = BoardMeeting
        exclude = ("company",)

    def create(self, validated_data):
        validated_data["company_id"] = validated_data.pop("company_id")
        return super().create(validated_data)


class AuditLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = AuditLog
        fields = "__all__"


class PriceHistorySerializer(serializers.ModelSerializer):
    class Meta:
        model = PriceHistory
        fields = "__all__"


# --- Nested serializers for entity export ---


class CustodianNestedSerializer(serializers.ModelSerializer):
    class Meta:
        model = CustodianAccount
        fields = ("bank", "account_number", "account_type", "authorized_persons")


class HoldingNestedSerializer(serializers.ModelSerializer):
    custodian = CustodianNestedSerializer(read_only=True)

    class Meta:
        model = AssetHolding
        fields = ("asset", "ticker", "quantity", "unit", "custodian")


class CompanyNestedSerializer(serializers.ModelSerializer):
    holdings = HoldingNestedSerializer(source="asset_holdings", many=True, read_only=True)

    class Meta:
        model = Company
        fields = (
            "name", "legal_name", "country", "category", "ownership_pct",
            "tax_id", "shareholders", "directors", "lawyer_studio", "holdings",
        )


class HoldingEntitySerializer(serializers.ModelSerializer):
    holdings = HoldingNestedSerializer(source="asset_holdings", many=True, read_only=True)
    subsidiaries = CompanyNestedSerializer(many=True, read_only=True)

    class Meta:
        model = Company
        fields = (
            "name", "legal_name", "country", "category", "ownership_pct",
            "tax_id", "shareholders", "directors", "lawyer_studio",
            "holdings", "subsidiaries",
        )


# =========================================================================
# Corporate Structure & Governance
# =========================================================================


class CapTableEntrySerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source="company.name", read_only=True)

    class Meta:
        model = CapTableEntry
        fields = "__all__"


class CapTableEntryCreateSerializer(ValidateCompanyIdMixin, serializers.ModelSerializer):
    company_id = serializers.IntegerField()

    class Meta:
        model = CapTableEntry
        exclude = ("company",)

    def create(self, validated_data):
        validated_data["company_id"] = validated_data.pop("company_id")
        return super().create(validated_data)


class ShareholderResolutionSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source="company.name", read_only=True)

    class Meta:
        model = ShareholderResolution
        fields = "__all__"


class ShareholderResolutionCreateSerializer(ValidateCompanyIdMixin, serializers.ModelSerializer):
    company_id = serializers.IntegerField()

    class Meta:
        model = ShareholderResolution
        exclude = ("company",)

    def create(self, validated_data):
        validated_data["company_id"] = validated_data.pop("company_id")
        return super().create(validated_data)


class PowerOfAttorneySerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source="company.name", read_only=True)

    class Meta:
        model = PowerOfAttorney
        fields = "__all__"


class PowerOfAttorneyCreateSerializer(ValidateCompanyIdMixin, serializers.ModelSerializer):
    company_id = serializers.IntegerField()

    class Meta:
        model = PowerOfAttorney
        exclude = ("company",)

    def create(self, validated_data):
        validated_data["company_id"] = validated_data.pop("company_id")
        return super().create(validated_data)


class AnnualFilingSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source="company.name", read_only=True)

    class Meta:
        model = AnnualFiling
        fields = "__all__"


class AnnualFilingCreateSerializer(ValidateCompanyIdMixin, serializers.ModelSerializer):
    company_id = serializers.IntegerField()

    class Meta:
        model = AnnualFiling
        exclude = ("company",)

    def create(self, validated_data):
        validated_data["company_id"] = validated_data.pop("company_id")
        return super().create(validated_data)


class BeneficialOwnerSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source="company.name", read_only=True)

    class Meta:
        model = BeneficialOwner
        fields = "__all__"


class BeneficialOwnerCreateSerializer(ValidateCompanyIdMixin, serializers.ModelSerializer):
    company_id = serializers.IntegerField()

    class Meta:
        model = BeneficialOwner
        exclude = ("company",)

    def create(self, validated_data):
        validated_data["company_id"] = validated_data.pop("company_id")
        return super().create(validated_data)


class OwnershipChangeSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source="company.name", read_only=True)

    class Meta:
        model = OwnershipChange
        fields = "__all__"


class OwnershipChangeCreateSerializer(ValidateCompanyIdMixin, serializers.ModelSerializer):
    company_id = serializers.IntegerField()

    class Meta:
        model = OwnershipChange
        exclude = ("company",)

    def create(self, validated_data):
        validated_data["company_id"] = validated_data.pop("company_id")
        return super().create(validated_data)


class KeyPersonnelSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source="company.name", read_only=True)

    class Meta:
        model = KeyPersonnel
        fields = "__all__"


class KeyPersonnelCreateSerializer(ValidateCompanyIdMixin, serializers.ModelSerializer):
    company_id = serializers.IntegerField()

    class Meta:
        model = KeyPersonnel
        exclude = ("company",)

    def create(self, validated_data):
        validated_data["company_id"] = validated_data.pop("company_id")
        return super().create(validated_data)


class RegulatoryLicenseSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source="company.name", read_only=True)

    class Meta:
        model = RegulatoryLicense
        fields = "__all__"


class RegulatoryLicenseCreateSerializer(ValidateCompanyIdMixin, serializers.ModelSerializer):
    company_id = serializers.IntegerField()

    class Meta:
        model = RegulatoryLicense
        exclude = ("company",)

    def create(self, validated_data):
        validated_data["company_id"] = validated_data.pop("company_id")
        return super().create(validated_data)


class JointVentureSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source="company.name", read_only=True)

    class Meta:
        model = JointVenture
        fields = "__all__"


class JointVentureCreateSerializer(ValidateCompanyIdMixin, serializers.ModelSerializer):
    company_id = serializers.IntegerField()

    class Meta:
        model = JointVenture
        exclude = ("company",)

    def create(self, validated_data):
        validated_data["company_id"] = validated_data.pop("company_id")
        return super().create(validated_data)


class EquityIncentivePlanSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source="company.name", read_only=True)

    class Meta:
        model = EquityIncentivePlan
        fields = "__all__"


class EquityIncentivePlanCreateSerializer(ValidateCompanyIdMixin, serializers.ModelSerializer):
    company_id = serializers.IntegerField()

    class Meta:
        model = EquityIncentivePlan
        exclude = ("company",)

    def create(self, validated_data):
        validated_data["company_id"] = validated_data.pop("company_id")
        return super().create(validated_data)


class EquityGrantSerializer(serializers.ModelSerializer):
    class Meta:
        model = EquityGrant
        fields = "__all__"


class EquityGrantCreateSerializer(serializers.ModelSerializer):
    plan_id = serializers.IntegerField()

    class Meta:
        model = EquityGrant
        exclude = ("plan",)

    def validate_plan_id(self, value):
        if not EquityIncentivePlan.objects.filter(id=value).exists():
            raise serializers.ValidationError("Equity incentive plan does not exist.")
        return value

    def create(self, validated_data):
        validated_data["plan_id"] = validated_data.pop("plan_id")
        return super().create(validated_data)


class DealSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source="company.name", read_only=True)

    class Meta:
        model = Deal
        fields = "__all__"


class DealCreateSerializer(ValidateCompanyIdMixin, serializers.ModelSerializer):
    company_id = serializers.IntegerField()

    class Meta:
        model = Deal
        exclude = ("company",)

    def create(self, validated_data):
        validated_data["company_id"] = validated_data.pop("company_id")
        return super().create(validated_data)


# =========================================================================
# Financial Operations
# =========================================================================


class AccountSerializer(serializers.ModelSerializer):
    class Meta:
        model = Account
        fields = "__all__"


class JournalEntrySerializer(serializers.ModelSerializer):
    class Meta:
        model = JournalEntry
        fields = "__all__"


class JournalLineSerializer(serializers.ModelSerializer):
    class Meta:
        model = JournalLine
        fields = "__all__"


class JournalLineCreateSerializer(serializers.ModelSerializer):
    entry_id = serializers.IntegerField()
    account_id = serializers.IntegerField()

    class Meta:
        model = JournalLine
        exclude = ("entry", "account")

    def validate_entry_id(self, value):
        if not JournalEntry.objects.filter(id=value).exists():
            raise serializers.ValidationError("Journal entry does not exist.")
        return value

    def validate_account_id(self, value):
        if not Account.objects.filter(id=value).exists():
            raise serializers.ValidationError("Account does not exist.")
        return value

    def create(self, validated_data):
        validated_data["entry_id"] = validated_data.pop("entry_id")
        validated_data["account_id"] = validated_data.pop("account_id")
        return super().create(validated_data)


class InterCompanyTransferSerializer(serializers.ModelSerializer):
    class Meta:
        model = InterCompanyTransfer
        fields = "__all__"


class InterCompanyTransferCreateSerializer(serializers.ModelSerializer):
    from_company_id = serializers.IntegerField()
    to_company_id = serializers.IntegerField()

    class Meta:
        model = InterCompanyTransfer
        exclude = ("from_company", "to_company")

    def validate_from_company_id(self, value):
        if not Company.objects.filter(id=value).exists():
            raise serializers.ValidationError("Company does not exist.")
        return value

    def validate_to_company_id(self, value):
        if not Company.objects.filter(id=value).exists():
            raise serializers.ValidationError("Company does not exist.")
        return value

    def create(self, validated_data):
        validated_data["from_company_id"] = validated_data.pop("from_company_id")
        validated_data["to_company_id"] = validated_data.pop("to_company_id")
        return super().create(validated_data)


class DividendSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source="company.name", read_only=True)

    class Meta:
        model = Dividend
        fields = "__all__"


class DividendCreateSerializer(ValidateCompanyIdMixin, serializers.ModelSerializer):
    company_id = serializers.IntegerField()

    class Meta:
        model = Dividend
        exclude = ("company",)

    def create(self, validated_data):
        validated_data["company_id"] = validated_data.pop("company_id")
        return super().create(validated_data)


class CapitalContributionSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source="company.name", read_only=True)

    class Meta:
        model = CapitalContribution
        fields = "__all__"


class CapitalContributionCreateSerializer(ValidateCompanyIdMixin, serializers.ModelSerializer):
    company_id = serializers.IntegerField()

    class Meta:
        model = CapitalContribution
        exclude = ("company",)

    def create(self, validated_data):
        validated_data["company_id"] = validated_data.pop("company_id")
        return super().create(validated_data)


class TaxPaymentSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source="company.name", read_only=True)

    class Meta:
        model = TaxPayment
        fields = "__all__"


class TaxPaymentCreateSerializer(ValidateCompanyIdMixin, serializers.ModelSerializer):
    company_id = serializers.IntegerField()

    class Meta:
        model = TaxPayment
        exclude = ("company",)

    def create(self, validated_data):
        validated_data["company_id"] = validated_data.pop("company_id")
        return super().create(validated_data)


class BudgetSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source="company.name", read_only=True)

    class Meta:
        model = Budget
        fields = "__all__"


class BudgetCreateSerializer(ValidateCompanyIdMixin, serializers.ModelSerializer):
    company_id = serializers.IntegerField()

    class Meta:
        model = Budget
        exclude = ("company",)

    def create(self, validated_data):
        validated_data["company_id"] = validated_data.pop("company_id")
        return super().create(validated_data)


# =========================================================================
# Asset Management & Portfolio
# =========================================================================


class CostBasisLotSerializer(serializers.ModelSerializer):
    class Meta:
        model = CostBasisLot
        fields = "__all__"


class CostBasisLotCreateSerializer(serializers.ModelSerializer):
    holding_id = serializers.IntegerField()

    class Meta:
        model = CostBasisLot
        exclude = ("holding",)

    def validate_holding_id(self, value):
        if not AssetHolding.objects.filter(id=value).exists():
            raise serializers.ValidationError("Asset holding does not exist.")
        return value

    def create(self, validated_data):
        validated_data["holding_id"] = validated_data.pop("holding_id")
        return super().create(validated_data)


class RealEstatePropertySerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source="company.name", read_only=True)

    class Meta:
        model = RealEstateProperty
        fields = "__all__"


class RealEstatePropertyCreateSerializer(ValidateCompanyIdMixin, serializers.ModelSerializer):
    company_id = serializers.IntegerField()

    class Meta:
        model = RealEstateProperty
        exclude = ("company",)

    def create(self, validated_data):
        validated_data["company_id"] = validated_data.pop("company_id")
        return super().create(validated_data)


class FundInvestmentSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source="company.name", read_only=True)

    class Meta:
        model = FundInvestment
        fields = "__all__"


class FundInvestmentCreateSerializer(ValidateCompanyIdMixin, serializers.ModelSerializer):
    company_id = serializers.IntegerField()

    class Meta:
        model = FundInvestment
        exclude = ("company",)

    def create(self, validated_data):
        validated_data["company_id"] = validated_data.pop("company_id")
        return super().create(validated_data)


class CryptoWalletSerializer(serializers.ModelSerializer):
    class Meta:
        model = CryptoWallet
        fields = "__all__"


class CryptoWalletCreateSerializer(serializers.ModelSerializer):
    holding_id = serializers.IntegerField()

    class Meta:
        model = CryptoWallet
        exclude = ("holding",)

    def validate_holding_id(self, value):
        if not AssetHolding.objects.filter(id=value).exists():
            raise serializers.ValidationError("Asset holding does not exist.")
        return value

    def create(self, validated_data):
        validated_data["holding_id"] = validated_data.pop("holding_id")
        return super().create(validated_data)


# =========================================================================
# Tax & Compliance
# =========================================================================


class TransferPricingDocSerializer(serializers.ModelSerializer):
    class Meta:
        model = TransferPricingDoc
        fields = "__all__"


class TransferPricingDocCreateSerializer(serializers.ModelSerializer):
    from_company_id = serializers.IntegerField()
    to_company_id = serializers.IntegerField()

    class Meta:
        model = TransferPricingDoc
        exclude = ("from_company", "to_company")

    def validate_from_company_id(self, value):
        if not Company.objects.filter(id=value).exists():
            raise serializers.ValidationError("Company does not exist.")
        return value

    def validate_to_company_id(self, value):
        if not Company.objects.filter(id=value).exists():
            raise serializers.ValidationError("Company does not exist.")
        return value

    def create(self, validated_data):
        validated_data["from_company_id"] = validated_data.pop("from_company_id")
        validated_data["to_company_id"] = validated_data.pop("to_company_id")
        return super().create(validated_data)


class WithholdingTaxSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source="company.name", read_only=True)

    class Meta:
        model = WithholdingTax
        fields = "__all__"


class WithholdingTaxCreateSerializer(ValidateCompanyIdMixin, serializers.ModelSerializer):
    company_id = serializers.IntegerField()

    class Meta:
        model = WithholdingTax
        exclude = ("company",)

    def create(self, validated_data):
        validated_data["company_id"] = validated_data.pop("company_id")
        return super().create(validated_data)


class FatcaReportSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source="company.name", read_only=True)

    class Meta:
        model = FatcaReport
        fields = "__all__"


class FatcaReportCreateSerializer(ValidateCompanyIdMixin, serializers.ModelSerializer):
    company_id = serializers.IntegerField()

    class Meta:
        model = FatcaReport
        exclude = ("company",)

    def create(self, validated_data):
        validated_data["company_id"] = validated_data.pop("company_id")
        return super().create(validated_data)


class ESGScoreSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source="company.name", read_only=True)

    class Meta:
        model = ESGScore
        fields = "__all__"


class ESGScoreCreateSerializer(ValidateCompanyIdMixin, serializers.ModelSerializer):
    company_id = serializers.IntegerField()

    class Meta:
        model = ESGScore
        exclude = ("company",)

    def create(self, validated_data):
        validated_data["company_id"] = validated_data.pop("company_id")
        return super().create(validated_data)


class RegulatoryFilingSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source="company.name", read_only=True)

    class Meta:
        model = RegulatoryFiling
        fields = "__all__"


class RegulatoryFilingCreateSerializer(ValidateCompanyIdMixin, serializers.ModelSerializer):
    company_id = serializers.IntegerField()

    class Meta:
        model = RegulatoryFiling
        exclude = ("company",)

    def create(self, validated_data):
        validated_data["company_id"] = validated_data.pop("company_id")
        return super().create(validated_data)


class ComplianceChecklistSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source="company.name", read_only=True)

    class Meta:
        model = ComplianceChecklist
        fields = "__all__"


class ComplianceChecklistCreateSerializer(ValidateCompanyIdMixin, serializers.ModelSerializer):
    company_id = serializers.IntegerField()

    class Meta:
        model = ComplianceChecklist
        exclude = ("company",)

    def create(self, validated_data):
        validated_data["company_id"] = validated_data.pop("company_id")
        return super().create(validated_data)


# =========================================================================
# Documents
# =========================================================================


class DocumentVersionSerializer(serializers.ModelSerializer):
    class Meta:
        model = DocumentVersion
        fields = "__all__"


class DocumentVersionCreateSerializer(serializers.ModelSerializer):
    document_id = serializers.IntegerField()

    class Meta:
        model = DocumentVersion
        exclude = ("document",)

    def validate_document_id(self, value):
        if not Document.objects.filter(id=value).exists():
            raise serializers.ValidationError("Document does not exist.")
        return value

    def create(self, validated_data):
        validated_data["document_id"] = validated_data.pop("document_id")
        return super().create(validated_data)


# =========================================================================
# Platform: Webhooks, Approvals, Custom Fields, API Keys, Permissions
# =========================================================================


class WebhookSerializer(serializers.ModelSerializer):
    class Meta:
        model = Webhook
        fields = "__all__"


class ApprovalRequestSerializer(serializers.ModelSerializer):
    class Meta:
        model = ApprovalRequest
        fields = "__all__"


class CustomFieldSerializer(serializers.ModelSerializer):
    class Meta:
        model = CustomField
        fields = "__all__"


class CustomFieldValueSerializer(serializers.ModelSerializer):
    class Meta:
        model = CustomFieldValue
        fields = "__all__"


class APIKeySerializer(serializers.ModelSerializer):
    class Meta:
        model = APIKey
        fields = "__all__"


class EntityPermissionSerializer(serializers.ModelSerializer):
    class Meta:
        model = EntityPermission
        fields = "__all__"


# =========================================================================
# Disaster Recovery / Backup Configuration
# =========================================================================


class BackupConfigSerializer(serializers.ModelSerializer):
    class Meta:
        model = BackupConfig
        fields = "__all__"


class BackupLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = BackupLog
        fields = "__all__"


class BackupLogCreateSerializer(serializers.ModelSerializer):
    config_id = serializers.IntegerField()

    class Meta:
        model = BackupLog
        exclude = ("config",)

    def validate_config_id(self, value):
        if not BackupConfig.objects.filter(id=value).exists():
            raise serializers.ValidationError("Backup config does not exist.")
        return value

    def create(self, validated_data):
        validated_data["config_id"] = validated_data.pop("config_id")
        return super().create(validated_data)


# =========================================================================
# Multi-tenant
# =========================================================================


class TenantGroupSerializer(serializers.ModelSerializer):
    class Meta:
        model = TenantGroup
        fields = "__all__"


class TenantMembershipSerializer(serializers.ModelSerializer):
    class Meta:
        model = TenantMembership
        fields = "__all__"


# =========================================================================
# Treasury
# =========================================================================


class CashPoolSerializer(serializers.ModelSerializer):
    class Meta:
        model = CashPool
        fields = "__all__"


class CashPoolEntrySerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source="company.name", read_only=True)

    class Meta:
        model = CashPoolEntry
        fields = "__all__"


class CashPoolEntryCreateSerializer(ValidateCompanyIdMixin, serializers.ModelSerializer):
    company_id = serializers.IntegerField()
    pool_id = serializers.IntegerField()

    class Meta:
        model = CashPoolEntry
        exclude = ("company", "pool")

    def validate_pool_id(self, value):
        if not CashPool.objects.filter(id=value).exists():
            raise serializers.ValidationError("CashPool does not exist.")
        return value

    def create(self, validated_data):
        validated_data["company_id"] = validated_data.pop("company_id")
        validated_data["pool_id"] = validated_data.pop("pool_id")
        return CashPoolEntry.objects.create(**validated_data)


# =========================================================================
# Sanctions
# =========================================================================


class SanctionsListSerializer(serializers.ModelSerializer):
    class Meta:
        model = SanctionsList
        fields = "__all__"


class SanctionsEntrySerializer(serializers.ModelSerializer):
    class Meta:
        model = SanctionsEntry
        fields = "__all__"


class SanctionsEntryCreateSerializer(serializers.ModelSerializer):
    sanctions_list_id = serializers.IntegerField()

    class Meta:
        model = SanctionsEntry
        exclude = ("sanctions_list",)

    def validate_sanctions_list_id(self, value):
        if not SanctionsList.objects.filter(id=value).exists():
            raise serializers.ValidationError("SanctionsList does not exist.")
        return value

    def create(self, validated_data):
        validated_data["sanctions_list_id"] = validated_data.pop("sanctions_list_id")
        return SanctionsEntry.objects.create(**validated_data)


class SanctionsCheckSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source="company.name", read_only=True)

    class Meta:
        model = SanctionsCheck
        fields = "__all__"


class SanctionsCheckCreateSerializer(ValidateCompanyIdMixin, serializers.ModelSerializer):
    company_id = serializers.IntegerField()

    class Meta:
        model = SanctionsCheck
        exclude = ("company",)

    def create(self, validated_data):
        validated_data["company_id"] = validated_data.pop("company_id")
        return SanctionsCheck.objects.create(**validated_data)


# =========================================================================
# Portfolio Snapshots
# =========================================================================


class PortfolioSnapshotSerializer(serializers.ModelSerializer):
    class Meta:
        model = PortfolioSnapshot
        fields = "__all__"


# =========================================================================
# Accounting Sync
# =========================================================================


class AccountingSyncConfigSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source="company.name", read_only=True)

    class Meta:
        model = AccountingSyncConfig
        fields = "__all__"


class AccountingSyncConfigCreateSerializer(ValidateCompanyIdMixin, serializers.ModelSerializer):
    company_id = serializers.IntegerField()

    class Meta:
        model = AccountingSyncConfig
        exclude = ("company",)

    def create(self, validated_data):
        validated_data["company_id"] = validated_data.pop("company_id")
        return AccountingSyncConfig.objects.create(**validated_data)


class AccountingSyncLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = AccountingSyncLog
        fields = "__all__"


class AccountingSyncLogCreateSerializer(serializers.ModelSerializer):
    config_id = serializers.IntegerField()

    class Meta:
        model = AccountingSyncLog
        exclude = ("config",)

    def validate_config_id(self, value):
        if not AccountingSyncConfig.objects.filter(id=value).exists():
            raise serializers.ValidationError("AccountingSyncConfig does not exist.")
        return value

    def create(self, validated_data):
        validated_data["config_id"] = validated_data.pop("config_id")
        return AccountingSyncLog.objects.create(**validated_data)


# =========================================================================
# Bank Feed
# =========================================================================


class BankFeedConfigSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source="company.name", read_only=True)

    class Meta:
        model = BankFeedConfig
        fields = "__all__"


class BankFeedConfigCreateSerializer(ValidateCompanyIdMixin, serializers.ModelSerializer):
    company_id = serializers.IntegerField()
    bank_account_id = serializers.IntegerField()

    class Meta:
        model = BankFeedConfig
        exclude = ("company", "bank_account")

    def create(self, validated_data):
        validated_data["company_id"] = validated_data.pop("company_id")
        validated_data["bank_account_id"] = validated_data.pop("bank_account_id")
        return BankFeedConfig.objects.create(**validated_data)


class BankFeedTransactionSerializer(serializers.ModelSerializer):
    class Meta:
        model = BankFeedTransaction
        fields = "__all__"


class BankFeedTransactionCreateSerializer(serializers.ModelSerializer):
    feed_config_id = serializers.IntegerField()

    class Meta:
        model = BankFeedTransaction
        exclude = ("feed_config",)

    def validate_feed_config_id(self, value):
        if not BankFeedConfig.objects.filter(id=value).exists():
            raise serializers.ValidationError("BankFeedConfig does not exist.")
        return value

    def create(self, validated_data):
        validated_data["feed_config_id"] = validated_data.pop("feed_config_id")
        return BankFeedTransaction.objects.create(**validated_data)


# =========================================================================
# E-Signature
# =========================================================================


class SignatureRequestSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source="company.name", read_only=True)

    class Meta:
        model = SignatureRequest
        fields = "__all__"


class SignatureRequestCreateSerializer(ValidateCompanyIdMixin, serializers.ModelSerializer):
    company_id = serializers.IntegerField()
    document_id = serializers.IntegerField()

    class Meta:
        model = SignatureRequest
        exclude = ("company", "document")

    def validate_document_id(self, value):
        from core.models import Document
        if not Document.objects.filter(id=value).exists():
            raise serializers.ValidationError("Document does not exist.")
        return value

    def create(self, validated_data):
        validated_data["company_id"] = validated_data.pop("company_id")
        validated_data["document_id"] = validated_data.pop("document_id")
        return SignatureRequest.objects.create(**validated_data)


# =========================================================================
# Email Digest
# =========================================================================


class EmailDigestConfigSerializer(serializers.ModelSerializer):
    class Meta:
        model = EmailDigestConfig
        fields = "__all__"


# =========================================================================
# Investor Access
# =========================================================================


class InvestorAccessSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source="company.name", read_only=True)

    class Meta:
        model = InvestorAccess
        fields = "__all__"


class InvestorAccessCreateSerializer(ValidateCompanyIdMixin, serializers.ModelSerializer):
    company_id = serializers.IntegerField()

    class Meta:
        model = InvestorAccess
        exclude = ("company",)

    def create(self, validated_data):
        validated_data["company_id"] = validated_data.pop("company_id")
        return InvestorAccess.objects.create(**validated_data)


# =========================================================================
# Document Upload
# =========================================================================


class DocumentUploadSerializer(serializers.ModelSerializer):
    class Meta:
        model = DocumentUpload
        fields = "__all__"


class DocumentUploadCreateSerializer(serializers.ModelSerializer):
    document_id = serializers.IntegerField()

    class Meta:
        model = DocumentUpload
        exclude = ("document",)

    def validate_document_id(self, value):
        from core.models import Document
        if not Document.objects.filter(id=value).exists():
            raise serializers.ValidationError("Document does not exist.")
        return value

    def create(self, validated_data):
        validated_data["document_id"] = validated_data.pop("document_id")
        return DocumentUpload.objects.create(**validated_data)
