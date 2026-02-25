import io
import json
import time

from django.contrib.auth.decorators import login_required
from django.db.models import Count, Sum
from django.http import HttpResponse, StreamingHttpResponse
from django.shortcuts import get_object_or_404, render
from rest_framework import status
from rest_framework.decorators import api_view
from rest_framework.response import Response

from core.models import get_user_role
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
    CustodianAccount,
    CustomField,
    CustomFieldValue,
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
from core.serializers import (
    AccountSerializer,
    AccountingSyncConfigSerializer,
    AccountingSyncConfigCreateSerializer,
    AccountingSyncLogSerializer,
    AccountingSyncLogCreateSerializer,
    AnnualFilingSerializer,
    AnnualFilingCreateSerializer,
    APIKeySerializer,
    ApprovalRequestSerializer,
    AssetHoldingCreateSerializer,
    AssetHoldingSerializer,
    AuditLogSerializer,
    BackupConfigSerializer,
    BackupLogSerializer,
    BackupLogCreateSerializer,
    BankAccountCreateSerializer,
    BankAccountSerializer,
    BankFeedConfigSerializer,
    BankFeedConfigCreateSerializer,
    BankFeedTransactionSerializer,
    BankFeedTransactionCreateSerializer,
    BeneficialOwnerSerializer,
    BeneficialOwnerCreateSerializer,
    BoardMeetingCreateSerializer,
    BoardMeetingSerializer,
    BudgetSerializer,
    BudgetCreateSerializer,
    CapitalContributionSerializer,
    CapitalContributionCreateSerializer,
    CapTableEntrySerializer,
    CapTableEntryCreateSerializer,
    CashPoolSerializer,
    CashPoolEntrySerializer,
    CashPoolEntryCreateSerializer,
    CategorySerializer,
    CompanyCreateSerializer,
    CompanyNestedSerializer,
    CompanySerializer,
    CompanyUpdateSerializer,
    ComplianceChecklistSerializer,
    ComplianceChecklistCreateSerializer,
    CostBasisLotSerializer,
    CostBasisLotCreateSerializer,
    CryptoWalletSerializer,
    CryptoWalletCreateSerializer,
    CustodianCreateSerializer,
    CustomFieldSerializer,
    CustomFieldValueSerializer,
    DealSerializer,
    DealCreateSerializer,
    DividendSerializer,
    DividendCreateSerializer,
    DocumentCreateSerializer,
    DocumentSerializer,
    DocumentUploadSerializer,
    DocumentUploadCreateSerializer,
    DocumentVersionSerializer,
    DocumentVersionCreateSerializer,
    EmailDigestConfigSerializer,
    EntityPermissionSerializer,
    EquityGrantSerializer,
    EquityGrantCreateSerializer,
    EquityIncentivePlanSerializer,
    EquityIncentivePlanCreateSerializer,
    ESGScoreSerializer,
    ESGScoreCreateSerializer,
    FatcaReportSerializer,
    FatcaReportCreateSerializer,
    FinancialCreateSerializer,
    FinancialSerializer,
    FundInvestmentSerializer,
    FundInvestmentCreateSerializer,
    HoldingEntitySerializer,
    InsurancePolicyCreateSerializer,
    InsurancePolicySerializer,
    InterCompanyTransferSerializer,
    InterCompanyTransferCreateSerializer,
    InvestorAccessSerializer,
    InvestorAccessCreateSerializer,
    JointVentureSerializer,
    JointVentureCreateSerializer,
    JournalEntrySerializer,
    JournalLineSerializer,
    JournalLineCreateSerializer,
    KeyPersonnelSerializer,
    KeyPersonnelCreateSerializer,
    LiabilityCreateSerializer,
    LiabilitySerializer,
    OwnershipChangeSerializer,
    OwnershipChangeCreateSerializer,
    PortfolioSnapshotSerializer,
    PowerOfAttorneySerializer,
    PowerOfAttorneyCreateSerializer,
    PriceHistorySerializer,
    RealEstatePropertySerializer,
    RealEstatePropertyCreateSerializer,
    RegulatoryFilingSerializer,
    RegulatoryFilingCreateSerializer,
    RegulatoryLicenseSerializer,
    RegulatoryLicenseCreateSerializer,
    SanctionsCheckSerializer,
    SanctionsCheckCreateSerializer,
    SanctionsEntrySerializer,
    SanctionsEntryCreateSerializer,
    SanctionsListSerializer,
    ServiceProviderCreateSerializer,
    ServiceProviderSerializer,
    ShareholderResolutionSerializer,
    ShareholderResolutionCreateSerializer,
    SignatureRequestSerializer,
    SignatureRequestCreateSerializer,
    TaxDeadlineCreateSerializer,
    TaxDeadlineSerializer,
    TaxPaymentSerializer,
    TaxPaymentCreateSerializer,
    TenantGroupSerializer,
    TenantMembershipSerializer,
    TransactionCreateSerializer,
    TransactionSerializer,
    TransferPricingDocSerializer,
    TransferPricingDocCreateSerializer,
    WebhookSerializer,
    WithholdingTaxSerializer,
    WithholdingTaxCreateSerializer,
)


# --- Current User ---


@api_view(["GET"])
def current_user_role(request):
    return Response({
        "username": request.user.username,
        "email": request.user.email,
        "role": get_user_role(request.user),
    })


# --- Companies ---


@api_view(["GET", "POST"])
def company_list(request):
    if request.method == "GET":
        qs = Company.objects.all()
        return Response(CompanySerializer(qs, many=True).data)
    ser = CompanyCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["PUT", "DELETE"])
def company_detail(request, company_id):
    if request.method == "DELETE":
        Company.objects.filter(id=company_id).delete()
        return Response({"ok": True})
    # PUT
    fields = {k: v for k, v in request.data.items() if v is not None}
    if not fields:
        return Response(
            {"detail": "No fields to update"},
            status=status.HTTP_400_BAD_REQUEST,
        )
    company = get_object_or_404(Company, id=company_id)
    ser = CompanyUpdateSerializer(company, data=fields, partial=True)
    ser.is_valid(raise_exception=True)
    ser.save()
    return Response({"ok": True})


# --- Asset Holdings ---


@api_view(["GET", "POST"])
def holding_list(request):
    if request.method == "GET":
        qs = AssetHolding.objects.select_related("company").all()
        return Response(AssetHoldingSerializer(qs, many=True).data)
    ser = AssetHoldingCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def holding_delete(request, holding_id):
    AssetHolding.objects.filter(id=holding_id).delete()
    return Response({"ok": True})


# --- Custodians ---


@api_view(["POST"])
def custodian_create(request):
    ser = CustodianCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def custodian_delete(request, custodian_id):
    CustodianAccount.objects.filter(id=custodian_id).delete()
    return Response({"ok": True})


# --- Documents ---


@api_view(["GET", "POST"])
def document_list(request):
    if request.method == "GET":
        qs = Document.objects.select_related("company").all()
        return Response(DocumentSerializer(qs, many=True).data)
    ser = DocumentCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def document_delete(request, doc_id):
    Document.objects.filter(id=doc_id).delete()
    return Response({"ok": True})


# --- Tax Deadlines ---


@api_view(["GET", "POST"])
def tax_deadline_list(request):
    if request.method == "GET":
        qs = TaxDeadline.objects.select_related("company").all()
        return Response(TaxDeadlineSerializer(qs, many=True).data)
    ser = TaxDeadlineCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def tax_deadline_delete(request, deadline_id):
    TaxDeadline.objects.filter(id=deadline_id).delete()
    return Response({"ok": True})


# --- Financials ---


@api_view(["GET", "POST"])
def financial_list(request):
    if request.method == "GET":
        qs = Financial.objects.select_related("company").all()
        return Response(FinancialSerializer(qs, many=True).data)
    ser = FinancialCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def financial_delete(request, financial_id):
    Financial.objects.filter(id=financial_id).delete()
    return Response({"ok": True})


# --- Categories ---


@api_view(["GET", "POST"])
def category_list(request):
    if request.method == "GET":
        qs = Category.objects.all()
        return Response(CategorySerializer(qs, many=True).data)
    ser = CategorySerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def category_delete(request, category_id):
    Category.objects.filter(id=category_id).delete()
    return Response({"ok": True})


# --- Settings ---


@api_view(["GET"])
def settings_list(request):
    qs = Setting.objects.all()
    return Response({s.key: s.value for s in qs})


@api_view(["PUT"])
def setting_update(request, key):
    value = request.data.get("value", "")
    Setting.objects.update_or_create(key=key, defaults={"value": value})
    return Response({"ok": True})


# --- Bank Accounts ---


@api_view(["GET", "POST"])
def bank_account_list(request):
    if request.method == "GET":
        qs = BankAccount.objects.select_related("company").all()
        return Response(BankAccountSerializer(qs, many=True).data)
    ser = BankAccountCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def bank_account_delete(request, account_id):
    BankAccount.objects.filter(id=account_id).delete()
    return Response({"ok": True})


# --- Transactions ---


@api_view(["GET", "POST"])
def transaction_list(request):
    if request.method == "GET":
        qs = Transaction.objects.select_related("company").all()
        return Response(TransactionSerializer(qs, many=True).data)
    ser = TransactionCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def transaction_delete(request, transaction_id):
    Transaction.objects.filter(id=transaction_id).delete()
    return Response({"ok": True})


# --- Liabilities ---


@api_view(["GET", "POST"])
def liability_list(request):
    if request.method == "GET":
        qs = Liability.objects.select_related("company").all()
        return Response(LiabilitySerializer(qs, many=True).data)
    ser = LiabilityCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def liability_delete(request, liability_id):
    Liability.objects.filter(id=liability_id).delete()
    return Response({"ok": True})


# --- Service Providers ---


@api_view(["GET", "POST"])
def service_provider_list(request):
    if request.method == "GET":
        qs = ServiceProvider.objects.select_related("company").all()
        return Response(ServiceProviderSerializer(qs, many=True).data)
    ser = ServiceProviderCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def service_provider_delete(request, provider_id):
    ServiceProvider.objects.filter(id=provider_id).delete()
    return Response({"ok": True})


# --- Insurance Policies ---


@api_view(["GET", "POST"])
def insurance_policy_list(request):
    if request.method == "GET":
        qs = InsurancePolicy.objects.select_related("company").all()
        return Response(InsurancePolicySerializer(qs, many=True).data)
    ser = InsurancePolicyCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def insurance_policy_delete(request, policy_id):
    InsurancePolicy.objects.filter(id=policy_id).delete()
    return Response({"ok": True})


# --- Board Meetings ---


@api_view(["GET", "POST"])
def board_meeting_list(request):
    if request.method == "GET":
        qs = BoardMeeting.objects.select_related("company").all()
        return Response(BoardMeetingSerializer(qs, many=True).data)
    ser = BoardMeetingCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def board_meeting_delete(request, meeting_id):
    BoardMeeting.objects.filter(id=meeting_id).delete()
    return Response({"ok": True})


# --- Prices ---


@api_view(["GET"])
def price_ticker(request, ticker):
    from yahoo import get_price

    price = get_price(ticker, record=True)
    history = PriceHistory.objects.filter(ticker=ticker).order_by("-recorded_at")[:30]
    return Response({
        "ticker": ticker,
        "price": price,
        "history": PriceHistorySerializer(history, many=True).data,
    })


# --- Audit Log ---


@api_view(["GET"])
def audit_log_list(request):
    limit = int(request.query_params.get("limit", 50))
    qs = AuditLog.objects.all()[:limit]
    return Response(AuditLogSerializer(qs, many=True).data)


# --- Stats ---


@api_view(["GET"])
def stats_view(request):
    total = Company.objects.count()
    top_level = Company.objects.filter(parent__isnull=True).count()
    subsidiaries = Company.objects.filter(parent__isnull=False).count()

    by_category = {}
    for row in Company.objects.values("category").annotate(cnt=Count("id")).order_by("-cnt"):
        by_category[row["category"]] = row["cnt"]

    by_country = {}
    for row in Company.objects.values("country").annotate(cnt=Count("id")).order_by("-cnt"):
        by_country[row["country"]] = row["cnt"]

    return Response({
        "total_companies": total,
        "top_level_entities": top_level,
        "subsidiaries": subsidiaries,
        "by_category": by_category,
        "by_country": by_country,
        "asset_holdings": AssetHolding.objects.count(),
        "custodian_accounts": CustodianAccount.objects.count(),
        "documents": Document.objects.count(),
        "tax_deadlines": TaxDeadline.objects.count(),
        "bank_accounts": BankAccount.objects.count(),
        "transactions": Transaction.objects.count(),
        "liabilities": Liability.objects.count(),
        "service_providers": ServiceProvider.objects.count(),
        "insurance_policies": InsurancePolicy.objects.count(),
        "board_meetings": BoardMeeting.objects.count(),
    })


# --- Export ---


@api_view(["GET"])
def export_view(request):
    return Response(_build_export())


# --- Entities ---


@api_view(["GET"])
def entities_view(request):
    return Response(_build_export())


def _build_export():
    top_companies = Company.objects.filter(parent__isnull=True).prefetch_related(
        "subsidiaries__asset_holdings__custodian",
        "asset_holdings__custodian",
    )

    entities = []
    for c in top_companies:
        if c.is_holding:
            entities.append(HoldingEntitySerializer(c).data)
        else:
            entities.append(CompanyNestedSerializer(c).data)

    return {
        "entities": entities,
        "documents": DocumentSerializer(
            Document.objects.select_related("company").all(), many=True
        ).data,
        "tax_deadlines": TaxDeadlineSerializer(
            TaxDeadline.objects.select_related("company").all(), many=True
        ).data,
        "financials": FinancialSerializer(
            Financial.objects.select_related("company").all(), many=True
        ).data,
        "bank_accounts": BankAccountSerializer(
            BankAccount.objects.select_related("company").all(), many=True
        ).data,
        "transactions": TransactionSerializer(
            Transaction.objects.select_related("company").all(), many=True
        ).data,
        "liabilities": LiabilitySerializer(
            Liability.objects.select_related("company").all(), many=True
        ).data,
        "service_providers": ServiceProviderSerializer(
            ServiceProvider.objects.select_related("company").all(), many=True
        ).data,
        "insurance_policies": InsurancePolicySerializer(
            InsurancePolicy.objects.select_related("company").all(), many=True
        ).data,
        "board_meetings": BoardMeetingSerializer(
            BoardMeeting.objects.select_related("company").all(), many=True
        ).data,
    }


# --- Portfolio ---


def _calculate_portfolio(companies=None, base_currency="USD"):
    """Returns dict with liquid, marketable, illiquid, liabilities, nav."""
    from yahoo import get_prices, get_fx_rate

    if companies is None:
        companies = Company.objects.all()

    def _to_base(amount, currency):
        if currency == base_currency:
            return amount
        rate = get_fx_rate(currency)
        if rate is None:
            return amount  # fallback: treat as 1:1
        return amount * rate

    # Liquid: sum all BankAccount balances, FX-converted
    liquid = 0.0
    for ba in BankAccount.objects.filter(company__in=companies):
        liquid += _to_base(ba.balance, ba.currency)

    # Marketable vs Illiquid holdings
    marketable = 0.0
    illiquid = 0.0
    holdings = AssetHolding.objects.filter(company__in=companies)
    tickers = [h.ticker for h in holdings if h.ticker]
    prices = get_prices(tickers, record=True) if tickers else {}

    by_asset_type = {}
    per_company = {}

    for h in holdings:
        qty = h.quantity or 0
        co_key = h.company_id
        if co_key not in per_company:
            per_company[co_key] = {
                "company_name": h.company.name,
                "liquid": 0.0, "marketable": 0.0, "illiquid": 0.0,
            }

        if h.ticker and h.ticker in prices and prices[h.ticker] is not None:
            val = _to_base(qty * prices[h.ticker], h.currency)
            marketable += val
            per_company[co_key]["marketable"] += val
        else:
            val = _to_base(qty, h.currency)
            illiquid += val
            per_company[co_key]["illiquid"] += val

        by_asset_type.setdefault(h.asset_type, 0.0)
        by_asset_type[h.asset_type] += val

    # Add liquid to per_company
    for ba in BankAccount.objects.filter(company__in=companies).select_related("company"):
        co_key = ba.company_id
        if co_key not in per_company:
            per_company[co_key] = {
                "company_name": ba.company.name,
                "liquid": 0.0, "marketable": 0.0, "illiquid": 0.0,
            }
        per_company[co_key]["liquid"] += _to_base(ba.balance, ba.currency)

    # Liabilities: sum active
    total_liabilities = 0.0
    for lia in Liability.objects.filter(company__in=companies, status="active"):
        total_liabilities += _to_base(lia.principal, lia.currency)

    nav = liquid + marketable + illiquid - total_liabilities

    return {
        "liquid": round(liquid, 2),
        "marketable": round(marketable, 2),
        "illiquid": round(illiquid, 2),
        "liabilities": round(total_liabilities, 2),
        "nav": round(nav, 2),
        "currency": base_currency,
        "by_asset_type": {k: round(v, 2) for k, v in by_asset_type.items()},
        "per_company": {
            str(k): {kk: round(vv, 2) if isinstance(vv, float) else vv for kk, vv in v.items()}
            for k, v in per_company.items()
        },
    }


@api_view(["GET"])
def portfolio_view(request):
    base = request.query_params.get("currency", "USD")
    return Response(_calculate_portfolio(base_currency=base))


# --- SSE Audit Log ---


@login_required
def audit_log_stream(request):
    def event_generator():
        last_id = AuditLog.objects.order_by("-id").values_list("id", flat=True).first() or 0
        while True:
            new = AuditLog.objects.filter(id__gt=last_id).order_by("id")
            for entry in new:
                last_id = entry.id
                data = json.dumps({
                    "id": entry.id,
                    "timestamp": entry.timestamp.isoformat(),
                    "action": entry.action,
                    "table_name": entry.table_name,
                    "record_id": entry.record_id,
                    "details": entry.details or "",
                })
                yield f"data: {data}\n\n"
            time.sleep(2)

    response = StreamingHttpResponse(event_generator(), content_type="text/event-stream")
    response["Cache-Control"] = "no-cache"
    response["X-Accel-Buffering"] = "no"
    return response


# --- Dashboard ---


@login_required
def dashboard(request):
    companies = Company.objects.all()
    top_level = companies.filter(parent__isnull=True).prefetch_related(
        "subsidiaries", "asset_holdings"
    )
    total_companies = companies.count()
    total_subsidiaries = companies.filter(parent__isnull=False).count()
    total_holdings = AssetHolding.objects.count()

    # Bank accounts with aggregated balance
    bank_accounts = BankAccount.objects.all()
    total_bank_accounts = bank_accounts.count()
    balances_by_currency = {}
    for ba in bank_accounts:
        balances_by_currency.setdefault(ba.currency, 0)
        balances_by_currency[ba.currency] += ba.balance

    # Liabilities
    active_liabilities = Liability.objects.filter(status="active")
    total_liabilities = active_liabilities.count()
    liability_by_currency = {}
    for lia in active_liabilities:
        liability_by_currency.setdefault(lia.currency, 0)
        liability_by_currency[lia.currency] += lia.principal

    by_category = {}
    for row in companies.values("category").annotate(cnt=Count("id")).order_by("-cnt"):
        by_category[row["category"]] = row["cnt"]

    by_country = {}
    for row in companies.values("country").annotate(cnt=Count("id")).order_by("-cnt"):
        by_country[row["country"]] = row["cnt"]

    # Recent transactions
    recent_transactions = Transaction.objects.select_related("company").order_by("-date")[:8]

    # Upcoming deadlines
    upcoming_deadlines = TaxDeadline.objects.select_related("company").exclude(
        status="completed"
    ).order_by("due_date")[:6]

    # Insurance policies
    insurance_policies = InsurancePolicy.objects.select_related("company").order_by("expiry_date")[:6]

    # Upcoming board meetings
    upcoming_meetings = BoardMeeting.objects.select_related("company").exclude(
        status="completed"
    ).order_by("scheduled_date")[:5]

    # Service providers
    providers = ServiceProvider.objects.select_related("company").all()[:6]

    # Portfolio summary (graceful fallback if Yahoo is unavailable)
    try:
        portfolio = _calculate_portfolio()
    except Exception:
        portfolio = {"liquid": 0, "marketable": 0, "illiquid": 0, "liabilities": 0, "nav": 0, "currency": "USD"}

    context = {
        "total_companies": total_companies,
        "total_subsidiaries": total_subsidiaries,
        "total_holdings": total_holdings,
        "total_bank_accounts": total_bank_accounts,
        "balances_by_currency": balances_by_currency,
        "total_liabilities": total_liabilities,
        "liability_by_currency": liability_by_currency,
        "by_category": by_category,
        "by_country": by_country,
        "top_level": top_level,
        "recent_transactions": recent_transactions,
        "upcoming_deadlines": upcoming_deadlines,
        "insurance_policies": insurance_policies,
        "upcoming_meetings": upcoming_meetings,
        "providers": providers,
        "recent_audit": AuditLog.objects.all()[:10],
        "portfolio": portfolio,
    }
    return render(request, "core/dashboard.html", context)


@login_required
def company_page(request, company_id):
    company = get_object_or_404(
        Company.objects.prefetch_related(
            "subsidiaries__asset_holdings",
            "asset_holdings__custodian",
            "bank_accounts",
            "liabilities",
            "transactions",
            "tax_deadlines",
            "documents",
            "service_providers",
            "insurance_policies",
            "board_meetings",
            "financials",
        ),
        id=company_id,
    )

    # Aggregate bank balances
    balances_by_currency = {}
    for ba in company.bank_accounts.all():
        balances_by_currency.setdefault(ba.currency, 0)
        balances_by_currency[ba.currency] += ba.balance

    # Aggregate liabilities
    active_liabilities = [l for l in company.liabilities.all() if l.status == "active"]
    liability_by_currency = {}
    for lia in active_liabilities:
        liability_by_currency.setdefault(lia.currency, 0)
        liability_by_currency[lia.currency] += lia.principal

    # Annotate holdings with live prices
    holdings = list(company.asset_holdings.all())
    tickers = [h.ticker for h in holdings if h.ticker]
    if tickers:
        from yahoo import get_prices
        try:
            prices = get_prices(tickers, record=True)
        except Exception:
            prices = {}
    else:
        prices = {}
    for h in holdings:
        if h.ticker and h.ticker in prices and prices[h.ticker] is not None:
            h.live_price = prices[h.ticker]
            h.live_value = (h.quantity or 0) * prices[h.ticker]
        else:
            h.live_price = None
            h.live_value = None

    context = {
        "company": company,
        "holdings": holdings,
        "subsidiaries": company.subsidiaries.all(),
        "bank_accounts": company.bank_accounts.all(),
        "transactions": company.transactions.all()[:10],
        "liabilities": company.liabilities.all(),
        "deadlines": company.tax_deadlines.all(),
        "documents": company.documents.all(),
        "providers": company.service_providers.all(),
        "policies": company.insurance_policies.all(),
        "meetings": company.board_meetings.all(),
        "financials": company.financials.all()[:4],
        "balances_by_currency": balances_by_currency,
        "liability_by_currency": liability_by_currency,
        "total_active_liabilities": len(active_liabilities),
    }
    return render(request, "core/company_detail.html", context)


# =====================================================================
# CRUD Views for New Models
# =====================================================================


# --- Cap Table ---


@api_view(["GET", "POST"])
def cap_table_list(request):
    if request.method == "GET":
        qs = CapTableEntry.objects.select_related("company").all()
        return Response(CapTableEntrySerializer(qs, many=True).data)
    ser = CapTableEntryCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def cap_table_delete(request, entry_id):
    CapTableEntry.objects.filter(id=entry_id).delete()
    return Response({"ok": True})


# --- Shareholder Resolutions ---


@api_view(["GET", "POST"])
def shareholder_resolution_list(request):
    if request.method == "GET":
        qs = ShareholderResolution.objects.select_related("company").all()
        return Response(ShareholderResolutionSerializer(qs, many=True).data)
    ser = ShareholderResolutionCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def shareholder_resolution_delete(request, resolution_id):
    ShareholderResolution.objects.filter(id=resolution_id).delete()
    return Response({"ok": True})


# --- Powers of Attorney ---


@api_view(["GET", "POST"])
def power_of_attorney_list(request):
    if request.method == "GET":
        qs = PowerOfAttorney.objects.select_related("company").all()
        return Response(PowerOfAttorneySerializer(qs, many=True).data)
    ser = PowerOfAttorneyCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def power_of_attorney_delete(request, poa_id):
    PowerOfAttorney.objects.filter(id=poa_id).delete()
    return Response({"ok": True})


# --- Annual Filings ---


@api_view(["GET", "POST"])
def annual_filing_list(request):
    if request.method == "GET":
        qs = AnnualFiling.objects.select_related("company").all()
        return Response(AnnualFilingSerializer(qs, many=True).data)
    ser = AnnualFilingCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def annual_filing_delete(request, filing_id):
    AnnualFiling.objects.filter(id=filing_id).delete()
    return Response({"ok": True})


# --- Beneficial Owners ---


@api_view(["GET", "POST"])
def beneficial_owner_list(request):
    if request.method == "GET":
        qs = BeneficialOwner.objects.select_related("company").all()
        return Response(BeneficialOwnerSerializer(qs, many=True).data)
    ser = BeneficialOwnerCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def beneficial_owner_delete(request, owner_id):
    BeneficialOwner.objects.filter(id=owner_id).delete()
    return Response({"ok": True})


# --- Ownership Changes ---


@api_view(["GET", "POST"])
def ownership_change_list(request):
    if request.method == "GET":
        qs = OwnershipChange.objects.select_related("company").all()
        return Response(OwnershipChangeSerializer(qs, many=True).data)
    ser = OwnershipChangeCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def ownership_change_delete(request, change_id):
    OwnershipChange.objects.filter(id=change_id).delete()
    return Response({"ok": True})


# --- Key Personnel ---


@api_view(["GET", "POST"])
def key_personnel_list(request):
    if request.method == "GET":
        qs = KeyPersonnel.objects.select_related("company").all()
        return Response(KeyPersonnelSerializer(qs, many=True).data)
    ser = KeyPersonnelCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def key_personnel_delete(request, personnel_id):
    KeyPersonnel.objects.filter(id=personnel_id).delete()
    return Response({"ok": True})


# --- Regulatory Licenses ---


@api_view(["GET", "POST"])
def regulatory_license_list(request):
    if request.method == "GET":
        qs = RegulatoryLicense.objects.select_related("company").all()
        return Response(RegulatoryLicenseSerializer(qs, many=True).data)
    ser = RegulatoryLicenseCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def regulatory_license_delete(request, license_id):
    RegulatoryLicense.objects.filter(id=license_id).delete()
    return Response({"ok": True})


# --- Joint Ventures ---


@api_view(["GET", "POST"])
def joint_venture_list(request):
    if request.method == "GET":
        qs = JointVenture.objects.select_related("company").all()
        return Response(JointVentureSerializer(qs, many=True).data)
    ser = JointVentureCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def joint_venture_delete(request, venture_id):
    JointVenture.objects.filter(id=venture_id).delete()
    return Response({"ok": True})


# --- Equity Incentive Plans ---


@api_view(["GET", "POST"])
def equity_plan_list(request):
    if request.method == "GET":
        qs = EquityIncentivePlan.objects.select_related("company").all()
        return Response(EquityIncentivePlanSerializer(qs, many=True).data)
    ser = EquityIncentivePlanCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def equity_plan_delete(request, plan_id):
    EquityIncentivePlan.objects.filter(id=plan_id).delete()
    return Response({"ok": True})


# --- Equity Grants ---


@api_view(["GET", "POST"])
def equity_grant_list(request):
    if request.method == "GET":
        qs = EquityGrant.objects.select_related("plan").all()
        return Response(EquityGrantSerializer(qs, many=True).data)
    ser = EquityGrantCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def equity_grant_delete(request, grant_id):
    EquityGrant.objects.filter(id=grant_id).delete()
    return Response({"ok": True})


# --- Deals ---


@api_view(["GET", "POST"])
def deal_list(request):
    if request.method == "GET":
        qs = Deal.objects.select_related("company").all()
        return Response(DealSerializer(qs, many=True).data)
    ser = DealCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def deal_delete(request, deal_id):
    Deal.objects.filter(id=deal_id).delete()
    return Response({"ok": True})


# --- Accounts (no company FK) ---


@api_view(["GET", "POST"])
def account_list(request):
    if request.method == "GET":
        qs = Account.objects.all()
        return Response(AccountSerializer(qs, many=True).data)
    ser = AccountSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def account_delete(request, account_id):
    Account.objects.filter(id=account_id).delete()
    return Response({"ok": True})


# --- Journal Entries (no company FK) ---


@api_view(["GET", "POST"])
def journal_entry_list(request):
    if request.method == "GET":
        qs = JournalEntry.objects.all()
        return Response(JournalEntrySerializer(qs, many=True).data)
    ser = JournalEntrySerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def journal_entry_delete(request, entry_id):
    JournalEntry.objects.filter(id=entry_id).delete()
    return Response({"ok": True})


# --- Journal Lines (FK to JournalEntry and Account) ---


@api_view(["GET", "POST"])
def journal_line_list(request):
    if request.method == "GET":
        qs = JournalLine.objects.select_related("entry", "account").all()
        return Response(JournalLineSerializer(qs, many=True).data)
    ser = JournalLineCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def journal_line_delete(request, line_id):
    JournalLine.objects.filter(id=line_id).delete()
    return Response({"ok": True})


# --- InterCompany Transfers (FK to from_company and to_company) ---


@api_view(["GET", "POST"])
def intercompany_transfer_list(request):
    if request.method == "GET":
        qs = InterCompanyTransfer.objects.select_related("from_company", "to_company").all()
        return Response(InterCompanyTransferSerializer(qs, many=True).data)
    ser = InterCompanyTransferCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def intercompany_transfer_delete(request, transfer_id):
    InterCompanyTransfer.objects.filter(id=transfer_id).delete()
    return Response({"ok": True})


# --- Dividends ---


@api_view(["GET", "POST"])
def dividend_list(request):
    if request.method == "GET":
        qs = Dividend.objects.select_related("company").all()
        return Response(DividendSerializer(qs, many=True).data)
    ser = DividendCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def dividend_delete(request, dividend_id):
    Dividend.objects.filter(id=dividend_id).delete()
    return Response({"ok": True})


# --- Capital Contributions ---


@api_view(["GET", "POST"])
def capital_contribution_list(request):
    if request.method == "GET":
        qs = CapitalContribution.objects.select_related("company").all()
        return Response(CapitalContributionSerializer(qs, many=True).data)
    ser = CapitalContributionCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def capital_contribution_delete(request, contribution_id):
    CapitalContribution.objects.filter(id=contribution_id).delete()
    return Response({"ok": True})


# --- Tax Payments ---


@api_view(["GET", "POST"])
def tax_payment_list(request):
    if request.method == "GET":
        qs = TaxPayment.objects.select_related("company").all()
        return Response(TaxPaymentSerializer(qs, many=True).data)
    ser = TaxPaymentCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def tax_payment_delete(request, payment_id):
    TaxPayment.objects.filter(id=payment_id).delete()
    return Response({"ok": True})


# --- Budgets ---


@api_view(["GET", "POST"])
def budget_list(request):
    if request.method == "GET":
        qs = Budget.objects.select_related("company").all()
        return Response(BudgetSerializer(qs, many=True).data)
    ser = BudgetCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def budget_delete(request, budget_id):
    Budget.objects.filter(id=budget_id).delete()
    return Response({"ok": True})


# --- Cost Basis Lots (FK to AssetHolding) ---


@api_view(["GET", "POST"])
def cost_basis_lot_list(request):
    if request.method == "GET":
        qs = CostBasisLot.objects.select_related("holding").all()
        return Response(CostBasisLotSerializer(qs, many=True).data)
    ser = CostBasisLotCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def cost_basis_lot_delete(request, lot_id):
    CostBasisLot.objects.filter(id=lot_id).delete()
    return Response({"ok": True})


# --- Real Estate Properties ---


@api_view(["GET", "POST"])
def real_estate_property_list(request):
    if request.method == "GET":
        qs = RealEstateProperty.objects.select_related("company").all()
        return Response(RealEstatePropertySerializer(qs, many=True).data)
    ser = RealEstatePropertyCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def real_estate_property_delete(request, property_id):
    RealEstateProperty.objects.filter(id=property_id).delete()
    return Response({"ok": True})


# --- Fund Investments ---


@api_view(["GET", "POST"])
def fund_investment_list(request):
    if request.method == "GET":
        qs = FundInvestment.objects.select_related("company").all()
        return Response(FundInvestmentSerializer(qs, many=True).data)
    ser = FundInvestmentCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def fund_investment_delete(request, investment_id):
    FundInvestment.objects.filter(id=investment_id).delete()
    return Response({"ok": True})


# --- Crypto Wallets (FK to AssetHolding) ---


@api_view(["GET", "POST"])
def crypto_wallet_list(request):
    if request.method == "GET":
        qs = CryptoWallet.objects.select_related("holding").all()
        return Response(CryptoWalletSerializer(qs, many=True).data)
    ser = CryptoWalletCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def crypto_wallet_delete(request, wallet_id):
    CryptoWallet.objects.filter(id=wallet_id).delete()
    return Response({"ok": True})


# --- Transfer Pricing Docs (FK to from_company and to_company) ---


@api_view(["GET", "POST"])
def transfer_pricing_list(request):
    if request.method == "GET":
        qs = TransferPricingDoc.objects.select_related("from_company", "to_company").all()
        return Response(TransferPricingDocSerializer(qs, many=True).data)
    ser = TransferPricingDocCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def transfer_pricing_delete(request, doc_id):
    TransferPricingDoc.objects.filter(id=doc_id).delete()
    return Response({"ok": True})


# --- Withholding Taxes ---


@api_view(["GET", "POST"])
def withholding_tax_list(request):
    if request.method == "GET":
        qs = WithholdingTax.objects.select_related("company").all()
        return Response(WithholdingTaxSerializer(qs, many=True).data)
    ser = WithholdingTaxCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def withholding_tax_delete(request, tax_id):
    WithholdingTax.objects.filter(id=tax_id).delete()
    return Response({"ok": True})


# --- FATCA Reports ---


@api_view(["GET", "POST"])
def fatca_report_list(request):
    if request.method == "GET":
        qs = FatcaReport.objects.select_related("company").all()
        return Response(FatcaReportSerializer(qs, many=True).data)
    ser = FatcaReportCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def fatca_report_delete(request, report_id):
    FatcaReport.objects.filter(id=report_id).delete()
    return Response({"ok": True})


# --- ESG Scores ---


@api_view(["GET", "POST"])
def esg_score_list(request):
    if request.method == "GET":
        qs = ESGScore.objects.select_related("company").all()
        return Response(ESGScoreSerializer(qs, many=True).data)
    ser = ESGScoreCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def esg_score_delete(request, score_id):
    ESGScore.objects.filter(id=score_id).delete()
    return Response({"ok": True})


# --- Regulatory Filings ---


@api_view(["GET", "POST"])
def regulatory_filing_list(request):
    if request.method == "GET":
        qs = RegulatoryFiling.objects.select_related("company").all()
        return Response(RegulatoryFilingSerializer(qs, many=True).data)
    ser = RegulatoryFilingCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def regulatory_filing_delete(request, filing_id):
    RegulatoryFiling.objects.filter(id=filing_id).delete()
    return Response({"ok": True})


# --- Compliance Checklists ---


@api_view(["GET", "POST"])
def compliance_checklist_list(request):
    if request.method == "GET":
        qs = ComplianceChecklist.objects.select_related("company").all()
        return Response(ComplianceChecklistSerializer(qs, many=True).data)
    ser = ComplianceChecklistCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def compliance_checklist_delete(request, checklist_id):
    ComplianceChecklist.objects.filter(id=checklist_id).delete()
    return Response({"ok": True})


# --- Document Versions (FK to Document) ---


@api_view(["GET", "POST"])
def document_version_list(request):
    if request.method == "GET":
        qs = DocumentVersion.objects.select_related("document").all()
        return Response(DocumentVersionSerializer(qs, many=True).data)
    ser = DocumentVersionCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def document_version_delete(request, version_id):
    DocumentVersion.objects.filter(id=version_id).delete()
    return Response({"ok": True})


# --- Webhooks (no company FK) ---


@api_view(["GET", "POST"])
def webhook_list(request):
    if request.method == "GET":
        qs = Webhook.objects.all()
        return Response(WebhookSerializer(qs, many=True).data)
    ser = WebhookSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def webhook_delete(request, webhook_id):
    Webhook.objects.filter(id=webhook_id).delete()
    return Response({"ok": True})


# --- Approval Requests (no company FK) ---


@api_view(["GET", "POST"])
def approval_request_list(request):
    if request.method == "GET":
        qs = ApprovalRequest.objects.all()
        return Response(ApprovalRequestSerializer(qs, many=True).data)
    ser = ApprovalRequestSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def approval_request_delete(request, request_id):
    ApprovalRequest.objects.filter(id=request_id).delete()
    return Response({"ok": True})


# --- Custom Fields (no company FK) ---


@api_view(["GET", "POST"])
def custom_field_list(request):
    if request.method == "GET":
        qs = CustomField.objects.all()
        return Response(CustomFieldSerializer(qs, many=True).data)
    ser = CustomFieldSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def custom_field_delete(request, field_id):
    CustomField.objects.filter(id=field_id).delete()
    return Response({"ok": True})


# --- Custom Field Values (no company FK) ---


@api_view(["GET", "POST"])
def custom_field_value_list(request):
    if request.method == "GET":
        qs = CustomFieldValue.objects.all()
        return Response(CustomFieldValueSerializer(qs, many=True).data)
    ser = CustomFieldValueSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def custom_field_value_delete(request, value_id):
    CustomFieldValue.objects.filter(id=value_id).delete()
    return Response({"ok": True})


# --- API Keys (no company FK) ---


@api_view(["GET", "POST"])
def api_key_list(request):
    if request.method == "GET":
        qs = APIKey.objects.all()
        return Response(APIKeySerializer(qs, many=True).data)
    ser = APIKeySerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def api_key_delete(request, key_id):
    APIKey.objects.filter(id=key_id).delete()
    return Response({"ok": True})


# --- Entity Permissions (no company FK) ---


@api_view(["GET", "POST"])
def entity_permission_list(request):
    if request.method == "GET":
        qs = EntityPermission.objects.all()
        return Response(EntityPermissionSerializer(qs, many=True).data)
    ser = EntityPermissionSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def entity_permission_delete(request, permission_id):
    EntityPermission.objects.filter(id=permission_id).delete()
    return Response({"ok": True})


# --- Backup Configs (no company FK) ---


@api_view(["GET", "POST"])
def backup_config_list(request):
    if request.method == "GET":
        qs = BackupConfig.objects.all()
        return Response(BackupConfigSerializer(qs, many=True).data)
    ser = BackupConfigSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def backup_config_delete(request, config_id):
    BackupConfig.objects.filter(id=config_id).delete()
    return Response({"ok": True})


# --- Backup Logs (FK to BackupConfig) ---


@api_view(["GET", "POST"])
def backup_log_list(request):
    if request.method == "GET":
        qs = BackupLog.objects.select_related("config").all()
        return Response(BackupLogSerializer(qs, many=True).data)
    ser = BackupLogCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def backup_log_delete(request, log_id):
    BackupLog.objects.filter(id=log_id).delete()
    return Response({"ok": True})


# =====================================================================
# Computed Endpoint Views
# =====================================================================


# --- Full-text Search ---


@api_view(["GET"])
def search_view(request):
    q = request.query_params.get("q", "").strip()
    if not q:
        return Response({"results": []})
    results = []
    # Search companies
    for c in Company.objects.filter(name__icontains=q):
        results.append({"type": "company", "id": c.id, "name": c.name, "detail": c.country})
    # Search holdings
    for h in AssetHolding.objects.filter(asset__icontains=q).select_related("company"):
        results.append({"type": "holding", "id": h.id, "name": h.asset, "detail": h.company.name})
    # Search documents
    for d in Document.objects.filter(name__icontains=q).select_related("company"):
        results.append({"type": "document", "id": d.id, "name": d.name, "detail": d.company.name})
    # Search service providers
    for sp in ServiceProvider.objects.filter(name__icontains=q).select_related("company"):
        results.append({"type": "service_provider", "id": sp.id, "name": sp.name, "detail": sp.company.name})
    # Search key personnel
    for kp in KeyPersonnel.objects.filter(name__icontains=q).select_related("company"):
        results.append({"type": "key_personnel", "id": kp.id, "name": kp.name, "detail": kp.company.name})
    # Search beneficial owners
    for bo in BeneficialOwner.objects.filter(name__icontains=q).select_related("company"):
        results.append({"type": "beneficial_owner", "id": bo.id, "name": bo.name, "detail": bo.company.name})
    # Search deals
    for dl in Deal.objects.filter(counterparty__icontains=q).select_related("company"):
        results.append({"type": "deal", "id": dl.id, "name": dl.counterparty, "detail": dl.company.name})
    return Response({"query": q, "count": len(results), "results": results})


# --- CSV Export ---


import csv
import io
from django.http import HttpResponse


@api_view(["GET"])
def csv_export(request):
    table = request.query_params.get("table", "companies")
    response = HttpResponse(content_type="text/csv")
    response["Content-Disposition"] = f'attachment; filename="{table}.csv"'
    writer = csv.writer(response)

    if table == "companies":
        writer.writerow(["id", "name", "country", "category", "tax_id", "is_holding"])
        for c in Company.objects.all():
            writer.writerow([c.id, c.name, c.country, c.category, c.tax_id, c.is_holding])
    elif table == "holdings":
        writer.writerow(["id", "company", "asset", "ticker", "quantity", "currency", "asset_type"])
        for h in AssetHolding.objects.select_related("company").all():
            writer.writerow([h.id, h.company.name, h.asset, h.ticker, h.quantity, h.currency, h.asset_type])
    elif table == "bank-accounts":
        writer.writerow(["id", "company", "bank_name", "account_number", "currency", "balance", "account_type"])
        for ba in BankAccount.objects.select_related("company").all():
            writer.writerow([ba.id, ba.company.name, ba.bank_name, ba.account_number, ba.currency, ba.balance, ba.account_type])
    elif table == "transactions":
        writer.writerow(["id", "company", "transaction_type", "description", "amount", "currency", "date"])
        for t in Transaction.objects.select_related("company").all():
            writer.writerow([t.id, t.company.name, t.transaction_type, t.description, t.amount, t.currency, t.date])
    elif table == "liabilities":
        writer.writerow(["id", "company", "liability_type", "creditor", "principal", "currency", "interest_rate", "status"])
        for l in Liability.objects.select_related("company").all():
            writer.writerow([l.id, l.company.name, l.liability_type, l.creditor, l.principal, l.currency, l.interest_rate, l.status])
    elif table == "financials":
        writer.writerow(["id", "company", "period", "revenue", "expenses", "currency"])
        for f in Financial.objects.select_related("company").all():
            writer.writerow([f.id, f.company.name, f.period, f.revenue, f.expenses, f.currency])
    elif table == "tax-deadlines":
        writer.writerow(["id", "company", "jurisdiction", "description", "due_date", "status"])
        for td in TaxDeadline.objects.select_related("company").all():
            writer.writerow([td.id, td.company.name, td.jurisdiction, td.description, td.due_date, td.status])
    elif table == "documents":
        writer.writerow(["id", "company", "title", "document_type", "url", "upload_date"])
        for d in Document.objects.select_related("company").all():
            writer.writerow([d.id, d.company.name, d.title, d.document_type, d.url, d.upload_date])
    else:
        writer.writerow(["error"])
        writer.writerow([f"Unknown table: {table}"])
    return response


# --- Gains/Losses ---


@api_view(["GET"])
def gains_view(request):
    """Calculate unrealized gains/losses from cost basis lots vs current prices."""
    from yahoo import get_prices

    holdings = AssetHolding.objects.filter(ticker__isnull=False).exclude(ticker="").select_related("company")
    tickers = list(set(h.ticker for h in holdings if h.ticker))
    prices = get_prices(tickers, record=False) if tickers else {}

    results = []
    total_unrealized = 0.0
    total_realized = 0.0

    for h in holdings:
        current_price = prices.get(h.ticker)
        lots = CostBasisLot.objects.filter(holding=h)
        for lot in lots:
            remaining = lot.quantity - (lot.sold_quantity or 0)
            if remaining > 0 and current_price is not None:
                cost = remaining * lot.price_per_unit
                market = remaining * current_price
                unrealized = market - cost
                total_unrealized += unrealized
                results.append({
                    "holding_id": h.id,
                    "asset": h.asset,
                    "ticker": h.ticker,
                    "lot_id": lot.id,
                    "purchase_date": lot.purchase_date,
                    "remaining_qty": remaining,
                    "cost_basis": round(cost, 2),
                    "market_value": round(market, 2),
                    "unrealized_gain": round(unrealized, 2),
                })
            if lot.sold_quantity and lot.sold_quantity > 0 and hasattr(lot, 'sold_price'):
                realized = (getattr(lot, 'sold_price', lot.price_per_unit) - lot.price_per_unit) * lot.sold_quantity
                total_realized += realized

    return Response({
        "total_unrealized": round(total_unrealized, 2),
        "total_realized": round(total_realized, 2),
        "positions": results,
    })


# --- Asset Allocation Breakdown ---


@api_view(["GET"])
def asset_allocation_view(request):
    """Breakdown of holdings by asset_type, currency, and company."""
    holdings = AssetHolding.objects.select_related("company").all()

    by_type = {}
    by_currency = {}
    by_company = {}

    for h in holdings:
        qty = h.quantity or 0
        by_type.setdefault(h.asset_type, 0.0)
        by_type[h.asset_type] += qty

        by_currency.setdefault(h.currency, 0.0)
        by_currency[h.currency] += qty

        name = h.company.name
        by_company.setdefault(name, 0.0)
        by_company[name] += qty

    return Response({
        "by_asset_type": by_type,
        "by_currency": by_currency,
        "by_company": by_company,
        "total_holdings": holdings.count(),
    })


# --- FX Exposure ---


@api_view(["GET"])
def fx_exposure_view(request):
    """FX exposure across bank accounts, holdings, and liabilities."""
    exposure = {}

    for ba in BankAccount.objects.all():
        exposure.setdefault(ba.currency, {"assets": 0.0, "liabilities": 0.0})
        exposure[ba.currency]["assets"] += ba.balance

    for h in AssetHolding.objects.all():
        exposure.setdefault(h.currency, {"assets": 0.0, "liabilities": 0.0})
        exposure[h.currency]["assets"] += h.quantity or 0

    for lia in Liability.objects.filter(status="active"):
        exposure.setdefault(lia.currency, {"assets": 0.0, "liabilities": 0.0})
        exposure[lia.currency]["liabilities"] += lia.principal

    for cur in exposure:
        exposure[cur]["net"] = exposure[cur]["assets"] - exposure[cur]["liabilities"]

    return Response(exposure)


# --- Cash Flow ---


@api_view(["GET"])
def cash_flow_view(request):
    """Cash flow summary from transactions."""
    inflows = 0.0
    outflows = 0.0
    by_type = {}

    for t in Transaction.objects.all():
        by_type.setdefault(t.transaction_type, 0.0)
        by_type[t.transaction_type] += t.amount
        if t.amount >= 0:
            inflows += t.amount
        else:
            outflows += t.amount

    return Response({
        "inflows": round(inflows, 2),
        "outflows": round(outflows, 2),
        "net": round(inflows + outflows, 2),
        "by_type": {k: round(v, 2) for k, v in by_type.items()},
    })


# --- Consolidated Financials ---


@api_view(["GET"])
def consolidated_view(request):
    """Consolidated financials across all companies."""
    by_period = {}

    for f in Financial.objects.select_related("company").all():
        by_period.setdefault(f.period, {"revenue": 0.0, "expenses": 0.0, "companies": []})
        by_period[f.period]["revenue"] += f.revenue
        by_period[f.period]["expenses"] += f.expenses
        by_period[f.period]["companies"].append({
            "company": f.company.name,
            "revenue": f.revenue,
            "expenses": f.expenses,
            "net": f.revenue - f.expenses,
        })

    for period in by_period:
        by_period[period]["net"] = by_period[period]["revenue"] - by_period[period]["expenses"]

    return Response(by_period)


# --- Contract Expiry Alerts ---


@api_view(["GET"])
def contract_alerts_view(request):
    """Upcoming contract expirations: insurance, licenses, etc."""
    from datetime import datetime, timedelta
    days = int(request.query_params.get("days", 90))
    today = datetime.now().strftime("%Y-%m-%d")
    cutoff = (datetime.now() + timedelta(days=days)).strftime("%Y-%m-%d")

    alerts = []

    for p in InsurancePolicy.objects.select_related("company").all():
        if p.expiry_date and today <= p.expiry_date <= cutoff:
            alerts.append({"type": "insurance", "id": p.id, "company": p.company.name, "description": p.policy_type, "expiry_date": p.expiry_date})

    for rl in RegulatoryLicense.objects.select_related("company").all():
        if rl.expiry_date and today <= rl.expiry_date <= cutoff:
            alerts.append({"type": "license", "id": rl.id, "company": rl.company.name, "description": rl.license_type, "expiry_date": rl.expiry_date})

    for poa in PowerOfAttorney.objects.select_related("company").all():
        if poa.expiry_date and today <= poa.expiry_date <= cutoff:
            alerts.append({"type": "power_of_attorney", "id": poa.id, "company": poa.company.name, "description": f"{poa.grantor} -> {poa.grantee}", "expiry_date": poa.expiry_date})

    alerts.sort(key=lambda a: a["expiry_date"])
    return Response({"days": days, "count": len(alerts), "alerts": alerts})


# --- Ownership Diagram (Mermaid) ---


@api_view(["GET"])
def ownership_diagram_view(request):
    """Generate Mermaid diagram of corporate structure."""
    lines = ["graph TD"]
    for c in Company.objects.all():
        label = c.name.replace('"', "'")
        lines.append(f'    {c.id}["{label}"]')
    for c in Company.objects.filter(parent__isnull=False).select_related("parent"):
        pct = f" ({c.ownership_pct}%)" if c.ownership_pct else ""
        lines.append(f'    {c.parent_id} -->|"owns{pct}"| {c.id}')
    return Response({"mermaid": "\n".join(lines)})


# --- Benchmark Comparison ---


@api_view(["GET"])
def benchmark_view(request):
    """Compare portfolio value against benchmarks like S&P500, BTC, Gold."""
    from yahoo import get_price
    benchmarks = {
        "SPY": "S&P 500 ETF",
        "BTC-USD": "Bitcoin",
        "GLD": "Gold ETF",
    }
    result = {}
    for ticker, name in benchmarks.items():
        price = get_price(ticker, record=False)
        result[ticker] = {"name": name, "price": price}
    return Response(result)


# --- Bulk Update ---


@api_view(["POST"])
def bulk_update_view(request):
    """Bulk update companies: set category or country for multiple IDs."""
    ids = request.data.get("ids", [])
    updates = request.data.get("updates", {})
    if not ids or not updates:
        return Response({"detail": "Provide ids and updates"}, status=status.HTTP_400_BAD_REQUEST)
    allowed_fields = {"category", "country"}
    clean = {k: v for k, v in updates.items() if k in allowed_fields}
    if not clean:
        return Response({"detail": "No valid fields to update"}, status=status.HTTP_400_BAD_REQUEST)
    count = Company.objects.filter(id__in=ids).update(**clean)
    return Response({"updated": count})


# =====================================================================
# Wave 2 – CRUD Views
# =====================================================================


# --- Tenant Groups (no company FK) ---


@api_view(["GET", "POST"])
def tenant_group_list(request):
    if request.method == "GET":
        qs = TenantGroup.objects.all()
        return Response(TenantGroupSerializer(qs, many=True).data)
    ser = TenantGroupSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def tenant_group_delete(request, group_id):
    TenantGroup.objects.filter(id=group_id).delete()
    return Response({"ok": True})


# --- Tenant Memberships (no company FK) ---


@api_view(["GET", "POST"])
def tenant_membership_list(request):
    if request.method == "GET":
        qs = TenantMembership.objects.all()
        return Response(TenantMembershipSerializer(qs, many=True).data)
    ser = TenantMembershipSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def tenant_membership_delete(request, membership_id):
    TenantMembership.objects.filter(id=membership_id).delete()
    return Response({"ok": True})


# --- Cash Pools (no company FK) ---


@api_view(["GET", "POST"])
def cash_pool_list(request):
    if request.method == "GET":
        qs = CashPool.objects.all()
        return Response(CashPoolSerializer(qs, many=True).data)
    ser = CashPoolSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def cash_pool_delete(request, pool_id):
    CashPool.objects.filter(id=pool_id).delete()
    return Response({"ok": True})


# --- Sanctions Lists (no company FK) ---


@api_view(["GET", "POST"])
def sanctions_list_view(request):
    if request.method == "GET":
        qs = SanctionsList.objects.all()
        return Response(SanctionsListSerializer(qs, many=True).data)
    ser = SanctionsListSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def sanctions_list_delete_view(request, list_id):
    SanctionsList.objects.filter(id=list_id).delete()
    return Response({"ok": True})


# --- Portfolio Snapshots (no company FK) ---


@api_view(["GET", "POST"])
def portfolio_snapshot_list(request):
    if request.method == "GET":
        qs = PortfolioSnapshot.objects.all()
        return Response(PortfolioSnapshotSerializer(qs, many=True).data)
    ser = PortfolioSnapshotSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def portfolio_snapshot_delete(request, snapshot_id):
    PortfolioSnapshot.objects.filter(id=snapshot_id).delete()
    return Response({"ok": True})


# --- Email Digest Configs (no company FK) ---


@api_view(["GET", "POST"])
def email_digest_config_list(request):
    if request.method == "GET":
        qs = EmailDigestConfig.objects.all()
        return Response(EmailDigestConfigSerializer(qs, many=True).data)
    ser = EmailDigestConfigSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def email_digest_config_delete(request, config_id):
    EmailDigestConfig.objects.filter(id=config_id).delete()
    return Response({"ok": True})


# --- Cash Pool Entries (company FK) ---


@api_view(["GET", "POST"])
def cash_pool_entry_list(request):
    if request.method == "GET":
        qs = CashPoolEntry.objects.select_related("pool", "company").all()
        return Response(CashPoolEntrySerializer(qs, many=True).data)
    ser = CashPoolEntryCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def cash_pool_entry_delete(request, entry_id):
    CashPoolEntry.objects.filter(id=entry_id).delete()
    return Response({"ok": True})


# --- Sanctions Checks (company FK) ---


@api_view(["GET", "POST"])
def sanctions_check_list(request):
    if request.method == "GET":
        qs = SanctionsCheck.objects.select_related("company").all()
        return Response(SanctionsCheckSerializer(qs, many=True).data)
    ser = SanctionsCheckCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def sanctions_check_delete(request, check_id):
    SanctionsCheck.objects.filter(id=check_id).delete()
    return Response({"ok": True})


# --- Accounting Sync Configs (company FK) ---


@api_view(["GET", "POST"])
def accounting_sync_config_list(request):
    if request.method == "GET":
        qs = AccountingSyncConfig.objects.select_related("company").all()
        return Response(AccountingSyncConfigSerializer(qs, many=True).data)
    ser = AccountingSyncConfigCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def accounting_sync_config_delete(request, config_id):
    AccountingSyncConfig.objects.filter(id=config_id).delete()
    return Response({"ok": True})


# --- Bank Feed Configs (company FK) ---


@api_view(["GET", "POST"])
def bank_feed_config_list(request):
    if request.method == "GET":
        qs = BankFeedConfig.objects.select_related("company").all()
        return Response(BankFeedConfigSerializer(qs, many=True).data)
    ser = BankFeedConfigCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def bank_feed_config_delete(request, config_id):
    BankFeedConfig.objects.filter(id=config_id).delete()
    return Response({"ok": True})


# --- Signature Requests (company FK) ---


@api_view(["GET", "POST"])
def signature_request_list(request):
    if request.method == "GET":
        qs = SignatureRequest.objects.select_related("company").all()
        return Response(SignatureRequestSerializer(qs, many=True).data)
    ser = SignatureRequestCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def signature_request_delete(request, request_id):
    SignatureRequest.objects.filter(id=request_id).delete()
    return Response({"ok": True})


# --- Investor Access (company FK) ---


@api_view(["GET", "POST"])
def investor_access_list(request):
    if request.method == "GET":
        qs = InvestorAccess.objects.select_related("company").all()
        return Response(InvestorAccessSerializer(qs, many=True).data)
    ser = InvestorAccessCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def investor_access_delete(request, access_id):
    InvestorAccess.objects.filter(id=access_id).delete()
    return Response({"ok": True})


# --- Sanctions Entries (FK to SanctionsList) ---


@api_view(["GET", "POST"])
def sanctions_entry_list(request):
    if request.method == "GET":
        qs = SanctionsEntry.objects.select_related("sanctions_list").all()
        return Response(SanctionsEntrySerializer(qs, many=True).data)
    ser = SanctionsEntryCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def sanctions_entry_delete(request, entry_id):
    SanctionsEntry.objects.filter(id=entry_id).delete()
    return Response({"ok": True})


# --- Accounting Sync Logs (FK to AccountingSyncConfig) ---


@api_view(["GET", "POST"])
def accounting_sync_log_list(request):
    if request.method == "GET":
        qs = AccountingSyncLog.objects.select_related("config").all()
        return Response(AccountingSyncLogSerializer(qs, many=True).data)
    ser = AccountingSyncLogCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def accounting_sync_log_delete(request, log_id):
    AccountingSyncLog.objects.filter(id=log_id).delete()
    return Response({"ok": True})


# --- Bank Feed Transactions (FK to BankFeedConfig) ---


@api_view(["GET", "POST"])
def bank_feed_transaction_list(request):
    if request.method == "GET":
        qs = BankFeedTransaction.objects.select_related("feed_config").all()
        return Response(BankFeedTransactionSerializer(qs, many=True).data)
    ser = BankFeedTransactionCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def bank_feed_transaction_delete(request, txn_id):
    BankFeedTransaction.objects.filter(id=txn_id).delete()
    return Response({"ok": True})


# --- Document Uploads (FK to Document) ---


@api_view(["GET", "POST"])
def document_upload_list(request):
    if request.method == "GET":
        qs = DocumentUpload.objects.select_related("document").all()
        return Response(DocumentUploadSerializer(qs, many=True).data)
    ser = DocumentUploadCreateSerializer(data=request.data)
    ser.is_valid(raise_exception=True)
    obj = ser.save()
    return Response({"id": obj.id}, status=status.HTTP_201_CREATED)


@api_view(["DELETE"])
def document_upload_delete(request, upload_id):
    DocumentUpload.objects.filter(id=upload_id).delete()
    return Response({"ok": True})


# =====================================================================
# Wave 2 – Computed Endpoint Views
# =====================================================================


# --- Natural Language Query ---


@api_view(["GET"])
def nlq_view(request):
    """Parse simple natural language queries into results."""
    q = request.query_params.get("q", "").strip().lower()
    if not q:
        return Response({"query": "", "results": [], "interpretation": "empty query"})

    results = []
    interpretation = ""

    # Pattern: "companies in <country>"
    import re
    m = re.match(r"companies?\s+in\s+(.+)", q)
    if m:
        country = m.group(1).strip()
        interpretation = f"Companies in {country}"
        for c in Company.objects.filter(country__icontains=country):
            results.append({"type": "company", "id": c.id, "name": c.name, "detail": c.country})
        return Response({"query": q, "interpretation": interpretation, "count": len(results), "results": results})

    # Pattern: "holdings worth more than <amount>"
    m = re.match(r"holdings?\s+worth\s+more\s+than\s+(\d+)", q)
    if m:
        threshold = float(m.group(1))
        interpretation = f"Holdings with quantity > {threshold}"
        for h in AssetHolding.objects.filter(quantity__gte=threshold).select_related("company"):
            results.append({"type": "holding", "id": h.id, "name": h.asset, "detail": f"{h.quantity} @ {h.company.name}"})
        return Response({"query": q, "interpretation": interpretation, "count": len(results), "results": results})

    # Pattern: "liabilities over <amount>"
    m = re.match(r"liabilities?\s+over\s+(\d+)", q)
    if m:
        threshold = float(m.group(1))
        interpretation = f"Active liabilities > {threshold}"
        for l in Liability.objects.filter(principal__gte=threshold, status="active").select_related("company"):
            results.append({"type": "liability", "id": l.id, "name": l.creditor, "detail": f"{l.principal} {l.currency}"})
        return Response({"query": q, "interpretation": interpretation, "count": len(results), "results": results})

    # Pattern: "deadlines in <month/year>"
    m = re.match(r"deadlines?\s+in\s+(\d{4}(?:-\d{2})?)", q)
    if m:
        period = m.group(1)
        interpretation = f"Tax deadlines in {period}"
        for td in TaxDeadline.objects.filter(due_date__startswith=period).select_related("company"):
            results.append({"type": "deadline", "id": td.id, "name": td.description, "detail": td.due_date})
        return Response({"query": q, "interpretation": interpretation, "count": len(results), "results": results})

    # Pattern: "who owns <company name>"
    m = re.match(r"who\s+owns?\s+(.+)", q)
    if m:
        name = m.group(1).strip()
        interpretation = f"Ownership of {name}"
        for c in Company.objects.filter(name__icontains=name).select_related("parent"):
            parent = c.parent.name if c.parent else "No parent (top-level)"
            results.append({"type": "company", "id": c.id, "name": c.name, "detail": f"Parent: {parent}, Ownership: {c.ownership_pct}%"})
        for bo in BeneficialOwner.objects.filter(company__name__icontains=name).select_related("company"):
            results.append({"type": "beneficial_owner", "id": bo.id, "name": bo.name, "detail": f"{bo.ownership_pct}% of {bo.company.name}"})
        return Response({"query": q, "interpretation": interpretation, "count": len(results), "results": results})

    # Pattern: "total nav" or "portfolio"
    if "nav" in q or "portfolio" in q or "net asset" in q:
        interpretation = "Portfolio NAV summary"
        try:
            data = _calculate_portfolio()
            results.append({"type": "portfolio", "id": 0, "name": "Portfolio NAV", "detail": f"NAV: {data['nav']:,.2f} {data['currency']}"})
        except Exception:
            results.append({"type": "portfolio", "id": 0, "name": "Portfolio NAV", "detail": "Unavailable"})
        return Response({"query": q, "interpretation": interpretation, "count": len(results), "results": results})

    # Fallback: search across company names
    interpretation = f"Search for '{q}'"
    for c in Company.objects.filter(name__icontains=q):
        results.append({"type": "company", "id": c.id, "name": c.name, "detail": c.country})

    return Response({"query": q, "interpretation": interpretation, "count": len(results), "results": results})


# --- Tax-Loss Harvesting Suggestions ---


@api_view(["GET"])
def tax_loss_harvesting_view(request):
    """Identify holdings with unrealized losses for tax-loss harvesting."""
    from yahoo import get_prices

    holdings = AssetHolding.objects.filter(ticker__isnull=False).exclude(ticker="").select_related("company")
    tickers = list(set(h.ticker for h in holdings if h.ticker))
    prices = get_prices(tickers, record=False) if tickers else {}

    suggestions = []
    total_harvestable = 0.0

    for h in holdings:
        current_price = prices.get(h.ticker)
        if current_price is None:
            continue
        lots = CostBasisLot.objects.filter(holding=h)
        for lot in lots:
            remaining = lot.quantity - (lot.sold_quantity or 0)
            if remaining <= 0:
                continue
            cost = remaining * lot.price_per_unit
            market = remaining * current_price
            loss = market - cost
            if loss < 0:  # Only losses
                total_harvestable += abs(loss)
                suggestions.append({
                    "holding_id": h.id,
                    "asset": h.asset,
                    "ticker": h.ticker,
                    "company": h.company.name,
                    "lot_id": lot.id,
                    "purchase_date": lot.purchase_date,
                    "remaining_qty": remaining,
                    "cost_basis": round(cost, 2),
                    "market_value": round(market, 2),
                    "unrealized_loss": round(loss, 2),
                    "tax_savings_estimate": round(abs(loss) * 0.25, 2),
                })

    suggestions.sort(key=lambda s: s["unrealized_loss"])
    return Response({
        "total_harvestable_loss": round(total_harvestable, 2),
        "estimated_tax_savings": round(total_harvestable * 0.25, 2),
        "suggestions": suggestions,
    })


# --- P&L Trend Charts ---


@api_view(["GET"])
def pnl_trends_view(request):
    """P&L trend data per company over time, suitable for charting."""
    company_id = request.query_params.get("company_id")
    financials = Financial.objects.select_related("company").all().order_by("period")
    if company_id:
        financials = financials.filter(company_id=company_id)

    by_period = {}
    for f in financials:
        by_period.setdefault(f.period, [])
        by_period[f.period].append({
            "company": f.company.name,
            "company_id": f.company_id,
            "revenue": f.revenue,
            "expenses": f.expenses,
            "net": f.revenue - f.expenses,
            "currency": f.currency,
        })

    periods = sorted(by_period.keys())
    chart_data = {
        "periods": periods,
        "series": {},
    }

    for period in periods:
        for entry in by_period[period]:
            name = entry["company"]
            if name not in chart_data["series"]:
                chart_data["series"][name] = {"revenue": [], "expenses": [], "net": [], "periods": []}
            chart_data["series"][name]["revenue"].append(entry["revenue"])
            chart_data["series"][name]["expenses"].append(entry["expenses"])
            chart_data["series"][name]["net"].append(entry["net"])
            chart_data["series"][name]["periods"].append(period)

    return Response(chart_data)


# --- Asset Allocation Pie Chart ---


@api_view(["GET"])
def asset_allocation_chart_view(request):
    """Asset allocation data formatted for pie charts."""
    holdings = AssetHolding.objects.select_related("company").all()

    by_type = {}
    for h in holdings:
        by_type.setdefault(h.asset_type, {"count": 0, "total_qty": 0.0})
        by_type[h.asset_type]["count"] += 1
        by_type[h.asset_type]["total_qty"] += h.quantity or 0

    slices = [
        {"label": k, "value": v["total_qty"], "count": v["count"]}
        for k, v in sorted(by_type.items(), key=lambda x: -x[1]["total_qty"])
    ]

    return Response({"slices": slices, "total_holdings": holdings.count()})


# --- PDF Board Package ---


@api_view(["GET"])
def board_package_pdf_view(request):
    """Generate a PDF board package for a company."""
    from reportlab.lib.pagesizes import letter
    from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
    from reportlab.lib.styles import getSampleStyleSheet
    from reportlab.lib import colors

    company_id = request.query_params.get("company_id")
    if not company_id:
        return Response({"detail": "company_id required"}, status=400)

    company = Company.objects.filter(id=company_id).first()
    if not company:
        return Response({"detail": "Company not found"}, status=404)

    buffer = io.BytesIO()
    doc = SimpleDocTemplate(buffer, pagesize=letter)
    styles = getSampleStyleSheet()
    elements = []

    # Title
    elements.append(Paragraph(f"Board Package — {company.name}", styles["Title"]))
    elements.append(Spacer(1, 20))
    elements.append(Paragraph(f"Country: {company.country} | Category: {company.category}", styles["Normal"]))
    elements.append(Spacer(1, 20))

    # Holdings
    holdings = AssetHolding.objects.filter(company=company)
    if holdings:
        elements.append(Paragraph("Asset Holdings", styles["Heading2"]))
        data = [["Asset", "Ticker", "Quantity", "Currency", "Type"]]
        for h in holdings:
            data.append([h.asset, h.ticker or "", str(h.quantity or 0), h.currency, h.asset_type])
        t = Table(data)
        t.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (-1, 0), colors.grey),
            ("TEXTCOLOR", (0, 0), (-1, 0), colors.whitesmoke),
            ("GRID", (0, 0), (-1, -1), 1, colors.black),
            ("FONTSIZE", (0, 0), (-1, -1), 8),
        ]))
        elements.append(t)
        elements.append(Spacer(1, 20))

    # Bank Accounts
    accounts = BankAccount.objects.filter(company=company)
    if accounts:
        elements.append(Paragraph("Bank Accounts", styles["Heading2"]))
        data = [["Bank", "Type", "Currency", "Balance"]]
        for ba in accounts:
            data.append([ba.bank_name, ba.account_type, ba.currency, f"{ba.balance:,.2f}"])
        t = Table(data)
        t.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (-1, 0), colors.grey),
            ("TEXTCOLOR", (0, 0), (-1, 0), colors.whitesmoke),
            ("GRID", (0, 0), (-1, -1), 1, colors.black),
            ("FONTSIZE", (0, 0), (-1, -1), 8),
        ]))
        elements.append(t)
        elements.append(Spacer(1, 20))

    # Liabilities
    liabilities = Liability.objects.filter(company=company)
    if liabilities:
        elements.append(Paragraph("Liabilities", styles["Heading2"]))
        data = [["Creditor", "Type", "Principal", "Rate", "Status"]]
        for l in liabilities:
            data.append([l.creditor, l.liability_type, f"{l.principal:,.2f}", f"{l.interest_rate}%", l.status])
        t = Table(data)
        t.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (-1, 0), colors.grey),
            ("TEXTCOLOR", (0, 0), (-1, 0), colors.whitesmoke),
            ("GRID", (0, 0), (-1, -1), 1, colors.black),
            ("FONTSIZE", (0, 0), (-1, -1), 8),
        ]))
        elements.append(t)

    doc.build(elements)
    buffer.seek(0)

    response = HttpResponse(buffer, content_type="application/pdf")
    response["Content-Disposition"] = f'attachment; filename="board_package_{company.name}.pdf"'
    return response


# --- iCal Calendar Export ---


@api_view(["GET"])
def ical_export_view(request):
    """Export tax deadlines and board meetings as iCal calendar."""
    from icalendar import Calendar, Event
    from datetime import datetime

    cal = Calendar()
    cal.add("prodid", "-//Holdco//holdco.app//")
    cal.add("version", "2.0")
    cal.add("calscale", "GREGORIAN")
    cal.add("x-wr-calname", "Holdco Calendar")

    # Tax deadlines
    for td in TaxDeadline.objects.select_related("company").exclude(status="completed"):
        try:
            dt = datetime.strptime(td.due_date, "%Y-%m-%d")
        except (ValueError, TypeError):
            continue
        event = Event()
        event.add("summary", f"[Tax] {td.description} — {td.company.name}")
        event.add("dtstart", dt.date())
        event.add("dtend", dt.date())
        event.add("description", f"Jurisdiction: {td.jurisdiction}\nStatus: {td.status}\nNotes: {td.notes or ''}")
        cal.add_component(event)

    # Board meetings
    for bm in BoardMeeting.objects.select_related("company").exclude(status="completed"):
        try:
            dt = datetime.strptime(bm.scheduled_date, "%Y-%m-%d")
        except (ValueError, TypeError):
            continue
        event = Event()
        event.add("summary", f"[Board] {bm.meeting_type} — {bm.company.name}")
        event.add("dtstart", dt.date())
        event.add("dtend", dt.date())
        event.add("description", f"Type: {bm.meeting_type}\nStatus: {bm.status}\nNotes: {bm.notes or ''}")
        cal.add_component(event)

    # Insurance expiries
    for ip in InsurancePolicy.objects.select_related("company").all():
        if not ip.expiry_date:
            continue
        try:
            dt = datetime.strptime(ip.expiry_date, "%Y-%m-%d")
        except (ValueError, TypeError):
            continue
        event = Event()
        event.add("summary", f"[Insurance] {ip.policy_type} expires — {ip.company.name}")
        event.add("dtstart", dt.date())
        event.add("dtend", dt.date())
        cal.add_component(event)

    response = HttpResponse(cal.to_ical(), content_type="text/calendar")
    response["Content-Disposition"] = 'attachment; filename="holdco.ics"'
    return response


# --- Investor Portal ---


@api_view(["GET"])
def investor_portal_view(request):
    """Read-only investor portal showing accessible companies and data."""
    user = request.user
    access_records = InvestorAccess.objects.filter(user=user).select_related("company")

    if not access_records.exists():
        return Response({"detail": "No investor access configured for this user.", "companies": []})

    companies_data = []
    for access in access_records:
        company = access.company
        data = {"id": company.id, "name": company.name, "country": company.country}

        if access.can_view_holdings:
            data["holdings"] = list(
                AssetHolding.objects.filter(company=company).values("asset", "ticker", "quantity", "currency", "asset_type")
            )

        if access.can_view_financials:
            data["financials"] = list(
                Financial.objects.filter(company=company).values("period", "revenue", "expenses", "currency")
            )
            data["bank_accounts"] = list(
                BankAccount.objects.filter(company=company).values("bank_name", "currency", "balance", "account_type")
            )

        if access.can_view_cap_table:
            data["cap_table"] = list(
                CapTableEntry.objects.filter(company=company).values(
                    "round_name", "investor", "instrument_type", "shares", "amount_invested", "currency"
                )
            )

        if access.can_view_documents:
            data["documents"] = list(
                Document.objects.filter(company=company).values("name", "doc_type", "url", "uploaded_at")
            )

        companies_data.append(data)

    return Response({"companies": companies_data})


# --- Portfolio Performance Over Time ---


@api_view(["GET"])
def portfolio_performance_view(request):
    """Portfolio performance over time from snapshots."""
    days = int(request.query_params.get("days", 365))
    from datetime import datetime, timedelta
    cutoff = (datetime.now() - timedelta(days=days)).strftime("%Y-%m-%d")

    snapshots = PortfolioSnapshot.objects.filter(date__gte=cutoff).order_by("date")
    data = PortfolioSnapshotSerializer(snapshots, many=True).data

    # Calculate returns if we have data
    chart = {
        "dates": [s["date"] for s in data],
        "nav": [s["nav"] for s in data],
        "liquid": [s["liquid"] for s in data],
        "marketable": [s["marketable"] for s in data],
        "illiquid": [s["illiquid"] for s in data],
        "liabilities": [s["liabilities"] for s in data],
    }

    if len(data) >= 2:
        first_nav = data[0]["nav"] if data[0]["nav"] != 0 else 1
        chart["return_pct"] = round((data[-1]["nav"] - data[0]["nav"]) / first_nav * 100, 2)
    else:
        chart["return_pct"] = 0

    return Response(chart)
