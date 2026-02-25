from django.contrib.auth.decorators import login_required
from django.db.models import Count, Sum
from django.shortcuts import get_object_or_404, render
from rest_framework import status
from rest_framework.decorators import api_view
from rest_framework.response import Response

from core.models import get_user_role
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
from core.serializers import (
    AssetHoldingCreateSerializer,
    AssetHoldingSerializer,
    AuditLogSerializer,
    BankAccountCreateSerializer,
    BankAccountSerializer,
    BoardMeetingCreateSerializer,
    BoardMeetingSerializer,
    CategorySerializer,
    CompanyCreateSerializer,
    CompanyNestedSerializer,
    CompanySerializer,
    CompanyUpdateSerializer,
    CustodianCreateSerializer,
    DocumentCreateSerializer,
    DocumentSerializer,
    FinancialCreateSerializer,
    FinancialSerializer,
    HoldingEntitySerializer,
    InsurancePolicyCreateSerializer,
    InsurancePolicySerializer,
    LiabilityCreateSerializer,
    LiabilitySerializer,
    PriceHistorySerializer,
    ServiceProviderCreateSerializer,
    ServiceProviderSerializer,
    TaxDeadlineCreateSerializer,
    TaxDeadlineSerializer,
    TransactionCreateSerializer,
    TransactionSerializer,
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
    company = Company.objects.get(id=company_id)
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

    context = {
        "company": company,
        "holdings": company.asset_holdings.all(),
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
