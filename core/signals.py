import json

from django.db.models.signals import post_delete, post_save
from django.dispatch import receiver

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
    ServiceProvider,
    Setting,
    TaxDeadline,
    Transaction,
)

_AUDITED_MODELS = [
    Category,
    Company,
    AssetHolding,
    CustodianAccount,
    Document,
    TaxDeadline,
    Financial,
    BankAccount,
    Transaction,
    Liability,
    ServiceProvider,
    InsurancePolicy,
    BoardMeeting,
    Setting,
]


def _table_name(instance):
    return instance._meta.db_table


def _safe_record_id(instance):
    pk = getattr(instance, "pk", None)
    if isinstance(pk, int):
        return pk
    return None


def _safe_details(instance):
    try:
        return str(instance)
    except Exception:
        return f"{instance.__class__.__name__} pk={instance.pk}"


@receiver(post_save)
def audit_save(sender, instance, created, **kwargs):
    if sender not in _AUDITED_MODELS:
        return
    action = "insert" if created else "update"
    AuditLog.objects.create(
        action=action,
        table_name=_table_name(instance),
        record_id=_safe_record_id(instance),
        details=_safe_details(instance),
    )


@receiver(post_delete)
def audit_delete(sender, instance, **kwargs):
    if sender not in _AUDITED_MODELS:
        return
    AuditLog.objects.create(
        action="delete",
        table_name=_table_name(instance),
        record_id=_safe_record_id(instance),
        details=_safe_details(instance),
    )
