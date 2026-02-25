from rest_framework import serializers

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
)


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


class AssetHoldingCreateSerializer(serializers.ModelSerializer):
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


class DocumentCreateSerializer(serializers.ModelSerializer):
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


class TaxDeadlineCreateSerializer(serializers.ModelSerializer):
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


class FinancialCreateSerializer(serializers.ModelSerializer):
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


class BankAccountCreateSerializer(serializers.ModelSerializer):
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


class TransactionCreateSerializer(serializers.ModelSerializer):
    company_id = serializers.IntegerField()
    asset_holding_id = serializers.IntegerField(required=False, allow_null=True)

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


class LiabilityCreateSerializer(serializers.ModelSerializer):
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


class ServiceProviderCreateSerializer(serializers.ModelSerializer):
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


class InsurancePolicyCreateSerializer(serializers.ModelSerializer):
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


class BoardMeetingCreateSerializer(serializers.ModelSerializer):
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
